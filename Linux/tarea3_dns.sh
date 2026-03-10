#!/bin/bash

# Definición de colores para la interfaz
VERDE='\e[32m'
ROJO='\e[31m'
AMARILLO='\e[33m'
AZUL='\e[34m'
RESET='\e[0m'

# ==========================================================
#   DNS SECCION LOGICA
# ==========================================================

# --- SECCIÓN DE VALIDACIONES ---
validar_ip() {
    local ip
    # Lista negra de IPs
    local prohibidas=("0.0.0.0" "127.0.0.1" "255.255.255.255")

    while true; do
        read -p "$(echo -e "${VERDE}$1: ${RESET}")" ip

        # Regla: IPs prohibidas
        if [[ " ${prohibidas[@]} " =~ " ${ip} " ]]; then
            echo -e "${ROJO}[!] Error: La IP $ip no es válida (reservada o loopback).${RESET}" >&2

        # Regla: Formato IPv4 válido
        elif [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
            echo "$ip"
            return 0
        else
            echo -e "${ROJO}[!] Error: Formato incorrecto. Intente de nuevo.${RESET}" >&2
        fi
    done
}

# Variables de configuración BIND
BIND_CONF_LOCAL="/etc/bind/named.conf.local"
ZONES_PATH="/var/cache/bind"

# --- INSTALACIÓN DE BIND9 (CON AUTO-REPARACIÓN DE RED) ---
instalacion_dns() {
    echo -e "${AZUL}--- Verificando servicio DNS (BIND9) ---${RESET}"

    # 1. IDEMPOTENCIA: Si ya está instalado y existe el archivo conf, salimos.
    if dpkg -l | grep -q "^ii.*bind9 " && [ -f "/etc/bind/named.conf.local" ]; then
         echo -e "${VERDE}[OK] BIND9 ya está instalado y configurado.${RESET}"
         return 0
    fi

    # 2. SOLUCIÓN AL ERROR "FALLO TEMPORAL AL RESOLVER"
    if ! ping -c 1 deb.debian.org > /dev/null 2>&1; then
        echo -e "${AMARILLO}[i] Ajustando conexión a internet para la descarga...${RESET}"
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
    fi

    echo -e "${AMARILLO}[+] Instalando paquetes (esto puede tardar)...${RESET}"

    # 3. INSTALACIÓN SILENCIOSA
    apt-get update -qq > /dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq bind9 bind9utils bind9-doc > /dev/null 2>&1

    # 4. VERIFICACIÓN VERDADERA
    if dpkg -l | grep -q "^ii.*bind9 "; then
         systemctl enable bind9 > /dev/null 2>&1
         systemctl start bind9 > /dev/null 2>&1
         echo -e "${VERDE}[OK] Instalación completada exitosamente.${RESET}"
    else
         echo -e "${ROJO}[ERROR] Falló la descarga. Verifica que tu máquina virtual tenga adaptador NAT.${RESET}"
         return 1
    fi
}

# --- VERIFICAR IP ESTÁTICA ---
verificar_ip_estatica() {
    # Detectamos la interfaz que se configuró en DHCP
    INTERFAZ="enp0s8"
    IP_ACTUAL=$(ip -4 addr show $INTERFAZ | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [[ -z "$IP_ACTUAL" ]]; then
        echo -e "${ROJO}[!] ALERTA: La interfaz $INTERFAZ no tiene IP.${RESET}"
        echo -e "${AMARILLO}Ejecuta primero la opción 3 (Configuración DHCP) para asignar la IP base.${RESET}"
    else
        echo -e "${VERDE}[OK] IP detectada en $INTERFAZ: $IP_ACTUAL${RESET}"
    fi
}

# --- AGREGAR DOMINIO ---
agregar_dominio() {
    echo -e "${AZUL}--- Agregar Nuevo Dominio DNS (Directa + Inversa) ---${RESET}"

    # 1. Obtener la IP actual del servidor y el nombre del host
    INTERFAZ="enp0s8"
    IP_SERVER=$(ip -4 addr show $INTERFAZ | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    NOMBRE_EQUIPO=$(hostname)

    if [[ -z "$IP_SERVER" ]]; then
        echo -e "${ROJO}[!] Error: No hay IP configurada en $INTERFAZ.${RESET}"
        echo -e "${AMARILLO}Primero configura el DHCP para establecer la IP del servidor.${RESET}"
        return 1
    fi

    # 2. Pedir datos
    read -p "Nombre del dominio (ej. reprobados.com): " DOMINIO
    read -p "IP a la que debe apuntar (Enter para usar $IP_SERVER): " IP_INPUT
    
    # Si el usuario presiona Enter, usa la IP del servidor
    if [[ -z "$IP_INPUT" ]]; then
        IP_DESTINO=$IP_SERVER
    else
        IP_DESTINO=$IP_INPUT
    fi

    ARCHIVO_ZONA="db.$DOMINIO"
    RUTA_COMPLETA="$ZONES_PATH/$ARCHIVO_ZONA"
    
    # Extraer octetos para la zona inversa
    IFS='.' read -r o1 o2 o3 o4 <<< "$IP_DESTINO"
    ZONA_INVERSA="$o3.$o2.$o1.in-addr.arpa"
    ARCHIVO_INVERSA="db.$o1.$o2.$o3"
    RUTA_INVERSA="$ZONES_PATH/$ARCHIVO_INVERSA"

    # 3. Validar existencia de la zona directa
    if grep -q "zone \"$DOMINIO\"" "$BIND_CONF_LOCAL"; then
        echo -e "${ROJO}[ERROR] El dominio $DOMINIO ya existe.${RESET}"
    else
        echo -e "${AMARILLO}[i] Configurando zonas en named.conf.local...${RESET}"
        
        # 4. Configurar named.conf.local (Añade ambas zonas)
        cat <<EOF >> "$BIND_CONF_LOCAL"

// Zona Directa
zone "$DOMINIO" {
    type master;
    file "$RUTA_COMPLETA";
};

// Zona Inversa
zone "$ZONA_INVERSA" {
    type master;
    file "$RUTA_INVERSA";
};
EOF
        
        echo -e "${AMARILLO}[i] Creando archivo de Zona Directa...${RESET}"
        # 5. Crear archivo de Zona Directa
        cat <<EOF > "$RUTA_COMPLETA"
\$TTL    604800
@       IN      SOA     $NOMBRE_EQUIPO.$DOMINIO. root.$DOMINIO. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $NOMBRE_EQUIPO.$DOMINIO.
@       IN      A       $IP_DESTINO
$NOMBRE_EQUIPO IN      A       $IP_DESTINO
www     IN      A       $IP_DESTINO
EOF

        echo -e "${AMARILLO}[i] Creando archivo de Zona Inversa...${RESET}"
        # 6. Crear archivo de Zona Inversa (PTR)
        cat <<EOF > "$RUTA_INVERSA"
\$TTL    604800
@       IN      SOA     $NOMBRE_EQUIPO.$DOMINIO. root.$DOMINIO. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $NOMBRE_EQUIPO.$DOMINIO.
$o4     IN      PTR     $NOMBRE_EQUIPO.$DOMINIO.
EOF

        # 7. Validar sintaxis de BIND9
        named-checkconf
        if [ $? -eq 0 ]; then
            systemctl reload bind9
            echo -e "${VERDE}[EXITO] Zonas DNS (Directa e Inversa) creadas y cargadas.${RESET}"
            
            # 8. Forzar a Debian a usar su propia IP como DNS principal
            echo -e "${AMARILLO}[i] Ajustando /etc/resolv.conf para usar la IP $IP_DESTINO...${RESET}"
            
            # Limpiamos el resolv.conf y le ponemos nuestra IP y dominio de búsqueda
            echo "domain $DOMINIO" > /etc/resolv.conf
            echo "search $DOMINIO" >> /etc/resolv.conf
            echo "nameserver $IP_DESTINO" >> /etc/resolv.conf
            
            echo -e "${VERDE}[OK] Servidor Debian configurado para usar su propio DNS.${RESET}"
            
        else
            echo -e "${ROJO}[FALLO] Error de sintaxis detectado por named-checkconf.${RESET}"
        fi
    fi
}

# --- LISTAR DOMINIOS REGISTRADOS ---
listar_dominios() {
    echo -e "${AZUL}--- Dominios Registrados ---${RESET}"

    if [ ! -f "$BIND_CONF_LOCAL" ]; then
        echo -e "${ROJO}[!] No se encuentra el archivo de configuración ($BIND_CONF_LOCAL).${RESET}"
        echo -e "${AMARILLO}Intenta reinstalar el servicio DNS (Opción 5).${RESET}"
        return 1
    fi

    if grep -q 'zone "' "$BIND_CONF_LOCAL"; then
      echo -e "${VERDE}Zonas encontradas:${RESET}"
        grep 'zone "' "$BIND_CONF_LOCAL" | cut -d'"' -f2 | while read -r line; do
            echo -e " -> $line"
        done
    else
        echo -e "${AMARILLO}[i] No hay dominios configurados aún.${RESET}"
    fi
}

# --- DESINSTALAR DNS ---
desinstalar_dns() {
    echo -e "${ROJO}=========================================${RESET}"
    echo -e "${ROJO}   ¡PELIGRO! DESINSTALACIÓN DE DNS       ${RESET}"
    echo -e "${ROJO}=========================================${RESET}"

    read -p "¿Eliminar BIND9 y todas las zonas? (s/n): " CONFIRM

    if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
        echo -e "${AMARILLO}[+] Eliminando paquetes...${RESET}"
        systemctl stop bind9 > /dev/null 2>&1
        systemctl disable bind9 > /dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq bind9 bind9utils bind9-doc > /dev/null 2>&1
        apt-get autoremove -y -qq > /dev/null 2>&1
        rm -rf /etc/bind > /dev/null 2>&1
        rm -rf /var/cache/bind > /dev/null 2>&1
        echo -e "${VERDE}[OK] Servicio DNS eliminado completamente.${RESET}"
    else
        echo -e "${VERDE}Operación cancelada.${RESET}"
    fi
}

# --- ELIMINAR DOMINIO ---
eliminar_dominio() {
    echo -e "${AZUL}--- Eliminar Dominio DNS ---${RESET}"
    read -p "Nombre del dominio a eliminar: " DOMINIO

    if grep -q "$DOMINIO" "$BIND_CONF_LOCAL"; then
        sed -i "/zone \"$DOMINIO\"/,+3d" "$BIND_CONF_LOCAL"
        rm "$ZONES_PATH/db.$DOMINIO" 2>/dev/null
        systemctl reload bind9
        echo -e "${VERDE}[EXITO] Dominio $DOMINIO eliminado.${RESET}"
    else
        echo -e "${ROJO}[ERROR] El dominio no existe.${RESET}"
    fi
}

#!/bin/bash

# Definición de colores para la interfaz
VERDE='\e[32m'
ROJO='\e[31m'
AMARILLO='\e[33m'
AZUL='\e[34m'
RESET='\e[0m'

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

validar_tiempo() {
    local seg
    while true; do
        read -p "$(echo -e "${VERDE}Tiempo de concesión (segundos): ${RESET}")" seg
        # Regla: Solo números enteros positivos (sin punto decimal ni signo menos)
        if [[ "$seg" =~ ^[0-9]+$ ]]; then
            echo "$seg"
            return 0
        fi
        echo -e "${ROJO}[!] Error: Ingrese solo números enteros positivos.${RESET}" >&2
    done
}

# --- SECCIÓN DE INSTALACIÓN ---

instalacion_dhcp() {
    # Regla: Preguntar reinstalación si ya existe
    if dpkg -l | grep -q "^ii.*isc-dhcp-server"; then
        echo -e "${AMARILLO}[!] El servicio DHCP ya está instalado.${RESET}"
        read -p "¿Desea reinstalarlo? (s/n): " RESP
        if [[ "$RESP" == "s" || "$RESP" == "S" ]]; then
            echo -e "${AMARILLO}[+] Reinstalando servicio...${RESET}"
            apt-get install --reinstall -y isc-dhcp-server > /dev/null
            echo -e "${VERDE}[OK] Reinstalación completa.${RESET}"
        else
            echo -e "${VERDE}[OK] Se mantiene la instalación actual.${RESET}"
        fi
    else
        echo -e "${AMARILLO}[+] Instalando isc-dhcp-server...${RESET}"
        apt-get update -y > /dev/null
        apt-get install -y isc-dhcp-server > /dev/null
        systemctl enable isc-dhcp-server > /dev/null 2>&1
        echo -e "${VERDE}[OK] Instalado correctamente.${RESET}"
    fi
}

verificar_instalacion() {
    echo -ne "${AZUL}Estado de instalación: ${RESET}"
    if dpkg -l | grep -q "^ii.*isc-dhcp-server"; then
        echo -e "${VERDE}INSTALADO${RESET}"
    else
        echo -e "${ROJO}NO INSTALADO${RESET}"
    fi
}

# --- SECCIÓN DE CONFIGURACIÓN ---

configuracion_dhcp() {
    # Bloqueo si no está instalado
    if ! dpkg -l | grep -q "^ii.*isc-dhcp-server"; then
        echo -e "${ROJO}[!] Error: Primero debe realizar la instalación.${RESET}"
        return 1
    fi

    echo -e "${AZUL}--- CONFIGURACIÓN DE RED ---${RESET}"
    
    # 1. IP Estática y Rango Inicial (+1 logic)
    IP_BASE=$(validar_ip "IP Inicio (Se asignará al Servidor)")
    
    # La máquina toma la IP base
    SERVER_IP=$IP_BASE
    
    # El rango empieza en IP Base + 1
    # Usamos awk para sumar 1 al último octeto de forma segura
    RANGO_INICIO=$(echo $IP_BASE | awk -F. '{print $1"."$2"."$3"."$4+1}')
    
    echo -e "${AMARILLO}[i] IP Servidor será: $SERVER_IP${RESET}"
    echo -e "${AMARILLO}[i] Rango DHCP iniciará en: $RANGO_INICIO${RESET}"

    # 2. IP Final del Rango
    while true; do
        IP_FINAL=$(validar_ip "IP Fin del Rango")
        # Comparación numérica: Final debe ser mayor o igual al inicio del rango
        if [[ $(printf "%03d%03d%03d%03d" $(echo $IP_FINAL | tr '.' ' ')) -ge $(printf "%03d%03d%03d%03d" $(echo $RANGO_INICIO | tr '.' ' ')) ]]; then break; fi
        echo -e "${ROJO}[!] Error: La IP Final debe ser mayor a $RANGO_INICIO.${RESET}"
    done

    # 3. Máscara Automática y Red
    PRIMER_OCTETO=$(echo $SERVER_IP | cut -d. -f1)
    if [ $PRIMER_OCTETO -lt 128 ]; then
        MASK="255.0.0.0"; NETWORK=$(echo $SERVER_IP | cut -d. -f1).0.0.0
    elif [ $PRIMER_OCTETO -lt 192 ]; then
        MASK="255.255.0.0"; NETWORK=$(echo $SERVER_IP | cut -d. -f1-2).0.0
    else
        MASK="255.255.255.0"; NETWORK=$(echo $SERVER_IP | cut -d. -f1-3).0
    fi

    # 4. Opcionales (Gateway y DNS)
    read -p "$(echo -e "${VERDE}Gateway (Opcional - Enter para vacío): ${RESET}")" GW
    read -p "$(echo -e "${VERDE}DNS (Opcional - Enter para vacío): ${RESET}")" DNS
    
    # 5. Tiempo (Validación estricta)
    LEASE=$(validar_tiempo)

    # --- APLICACIÓN DE CAMBIOS ---
    
    # Configurar interfaz enp0s8
    INTERFAZ="enp0s8"
    echo -e "${AMARILLO}[+] Configurando interfaz $INTERFAZ...${RESET}"
    ip addr flush dev $INTERFAZ 2>/dev/null
    ip addr add "$SERVER_IP/24" dev $INTERFAZ 2>/dev/null
    ip link set $INTERFAZ up
    
    # Asignar interfaz al demonio DHCP
    echo "INTERFACESv4=\"$INTERFAZ\"" > /etc/default/isc-dhcp-server

    # Crear dhcpd.conf
    # Solo agrega las lineas de router y dns si el usuario escribió algo (-n)
    cat <<EOF > /etc/dhcp/dhcpd.conf
authoritative;
subnet $NETWORK netmask $MASK {
  range $RANGO_INICIO $IP_FINAL;
  $( [[ -n "$GW" ]] && echo "option routers $GW;" )
  $( [[ -n "$DNS" ]] && echo "option domain-name-servers $DNS;" )
  default-lease-time $LEASE;
  max-lease-time 7200;
}
EOF

    echo -e "${AMARILLO}[+] Reiniciando servicio...${RESET}"
    systemctl restart isc-dhcp-server
    
    if systemctl is-active --quiet isc-dhcp-server; then
        echo -e "${VERDE}[OK] Configuración exitosa.${RESET}"
    else
        echo -e "${ROJO}[!] Falló el servicio. Verifique compatibilidad de IP y Red.${RESET}"
    fi
}

monitorear() {
    echo -e "${AZUL}--- Clientes DHCP Detectados ---${RESET}"
    if [ -f /var/lib/dhcp/dhcpd.leases ]; then
        # Muestra IP, MAC y Hostname de forma ordenada
        printf "%-18s %-20s %-20s\n" "IP ASIGNADA" "MAC ADDRESS" "HOSTNAME"
        echo "------------------------------------------------------------"
        awk '/lease/ { ip=$2 } /hardware ethernet/ { mac=$3; gsub(/;/,"",mac) } /client-hostname/ { name=$2; gsub(/;/,"",name); gsub(/"/,"",name); print ip, mac, name }' /var/lib/dhcp/dhcpd.leases | column -t
    else
        echo -e "${AMARILLO}[!] Aún no hay registros de clientes.${RESET}"
    fi
}

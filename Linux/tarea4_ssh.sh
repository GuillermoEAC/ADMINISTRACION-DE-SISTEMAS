#!/bin/bash

# ==========================================================
#    TAREA 4: SERVICIO SSH (LINUX)
# ==========================================================

# --- INSTALACIÓN ---
instalacion_ssh() {
    clear
    echo -e "${AZUL}=========================================${RESET}"
    echo -e "${AZUL}      INSTALACIÓN Y CONFIGURACIÓN SSH    ${RESET}"
    echo -e "${AZUL}=========================================${RESET}"

    # 1. Instalación
    if dpkg -l | grep -q "^ii.*openssh-server"; then
        echo -e "${VERDE}[OK] OpenSSH-Server ya está instalado.${RESET}"
    else
        echo -e "${AMARILLO}[+] Instalando OpenSSH-Server (Silencioso)...${RESET}"
        apt-get update -qq > /dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server > /dev/null 2>&1
        echo -e "${VERDE}[OK] Instalación completada.${RESET}"
    fi

    # 2. Configuración de servicio
    echo -e "${AMARILLO}[+] Configurando servicio y arranque...${RESET}"
    systemctl enable ssh > /dev/null 2>&1
    systemctl start ssh > /dev/null 2>&1

    # Permitir acceso root
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl reload ssh > /dev/null 2>&1

    echo -e "${VERDE}[OK] Servicio SSH habilitado en el boot.${RESET}"

    # 3. Configurar Firewall (UFW) si existe
    if command -v ufw > /dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            echo -e "${AMARILLO}[+] Configurando Firewall (UFW)...${RESET}"
            ufw allow ssh > /dev/null 2>&1
            echo -e "${VERDE}[OK] Puerto 22 (SSH) permitido en el firewall.${RESET}"
        fi
    fi
}

# --- VERIFICACIÓN Y GUÍA DE CONEXIÓN ---
verificar_ssh() {
    clear
    echo -e "${AZUL}=========================================${RESET}"
    echo -e "${AZUL}      VERIFICACIÓN DE ESTADO SSH         ${RESET}"
    echo -e "${AZUL}=========================================${RESET}"

    if systemctl is-active --quiet ssh; then
        echo -e "${VERDE}[OK] El servicio SSH está ACTIVO y ejecutándose.${RESET}"
    else
        echo -e "${ROJO}[!] El servicio SSH está INACTIVO o falló.${RESET}"
    fi

    if systemctl is-enabled --quiet ssh; then
        echo -e "${VERDE}[OK] SSH está habilitado para arrancar con el sistema (Boot).${RESET}"
    else
        echo -e "${AMARILLO}[i] SSH NO está habilitado en el boot.${RESET}"
    fi

    echo -e "\n${AMARILLO}--- Puertos a la escucha ---${RESET}"
    if ss -tulpn | grep -q ":22 "; then
        echo -e "${VERDE}[OK] El servidor está escuchando en el puerto 22.${RESET}"
    else
        echo -e "${ROJO}[!] No se detectó tráfico en el puerto 22.${RESET}"
    fi

    # --- INSTRUCCIONES DE CONEXIÓN PARA EL CLIENTE ---
    # Extraemos la IP de la red interna (enp0s8)
    IP_ACTUAL=$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    
    # Si por alguna razón enp0s8 no tiene IP, buscamos cualquier otra que no sea localhost
    if [[ -z "$IP_ACTUAL" ]]; then
        IP_ACTUAL=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n1)
    fi

    echo -e "\n${VERDE}====================================================${RESET}"
    echo -e "${VERDE}      ¡LISTO! PUEDES CONECTARTE DESDE WINDOWS 10      ${RESET}"
    echo -e "${VERDE}====================================================${RESET}"
    echo -e "Abre tu terminal en tu máquina cliente y escribe:"
    echo -e ""
    echo -e "   ${CYAN}ssh root@$IP_ACTUAL${RESET}"
    echo -e ""
    echo -e "${AMARILLO}Nota:${RESET} Te pedirá la contraseña del usuario root de este servidor Debian."
    echo -e "${VERDE}====================================================${RESET}"
}

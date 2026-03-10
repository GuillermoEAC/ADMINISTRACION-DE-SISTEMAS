#!/bin/bash

# ==========================================
# 1. FUNCIÓN DE DIAGNÓSTICO
# ==========================================
ejecutar_diagnostico() {
    clear
    echo "======================================================"
    echo "          DIAGNOSTICO INICIAL - NODO 1 LINUX          "
    echo "======================================================"
    echo "Nombre del equipo: $(hostname)"
    echo "IP Actual: $(hostname -I)"
    echo "Espacio en disco (Raiz):"
    df -h / | awk 'NR==2 {print "Uso: " $5 " de " $2 " disponibles. "}'
    echo "======================================================"
    read -p "Presiona Enter para volver al menú principal..."
}

# ==========================================
# 2. FUNCIÓN PARA CONFIGURAR LA RED INTERNA
# ==========================================
configurar_red_interna() {
    clear
    local INTERFAZ="enp0s8"
    local IP_ESTATICA="192.168.10.1"
    local MASCARA="255.255.255.0"
    local ARCHIVO_REDS="/etc/network/interfaces"
    
    echo "======================================================"
    echo "               CONFIGURACIÓN DE RED                   "
    echo "======================================================"
    echo "[INFO] Verificando configuracion de $INTERFAZ..."

    # Idempotencia: Verificar si la IP ya esta en el archivo 
    if grep -q "$IP_ESTATICA" "$ARCHIVO_REDS"; then 
        echo "[OK] La interfaz $INTERFAZ ya tiene configurada la IP $IP_ESTATICA."
    else
        echo "[INFO] Configurando IP estatica en $INTERFAZ.."

        # Instalacion silenciosa: anadir configuracion sin interaccion manual
        echo -e "\nauto $INTERFAZ\niface $INTERFAZ inet static\n address $IP_ESTATICA\n  netmask $MASCARA" | tee -a "$ARCHIVO_REDS" > /dev/null
    
        # Levantar la interfaz 
        ifup $INTERFAZ 
        echo "[OK] Configuracion aplicada y servicio reiniciado."
    fi
    
    echo "======================================================"
    read -p "Presiona Enter para volver al menú principal..."
}

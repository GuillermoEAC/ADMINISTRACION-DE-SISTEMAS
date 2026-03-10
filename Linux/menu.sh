#!/bin/bash

# ==========================================
# 1. DEFINICIÓN DE COLORES
# ==========================================
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ==========================================
# 2. IMPORTAR LÓGICA DE TODAS LAS TAREAS
# ==========================================
source ./tarea1_diag.sh
source ./tarea2_dhcp.sh
source ./tarea3_dns.sh
source ./tarea4_ssh.sh   

# ==========================================
# 3. VERIFICACIÓN DE PERMISOS ROOT
# ==========================================
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}[!] Ejecutar como root (sudo).${RESET}"
   exit 1
fi

# ==========================================
# 4. SUBMENÚS POR TAREA
# ==========================================

submenu_tarea1() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}      TAREA 1: DIAGNÓSTICO Y RED         ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo "1. Ejecutar Diagnóstico de Sistema"
        echo "2. Configurar Red Interna (IP Estática)"
        echo "3. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Selecciona una opción [1-3]: " OPCION
        case $OPCION in
            1) ejecutar_diagnostico ;;
            2) configurar_red_interna ;;
            3) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac
        
        if [[ "$OPCION" != "3" ]]; then
            echo ""
            echo -e "${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

submenu_dhcp() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}               TAREA 2: MENÚ DHCP            ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo -e "1. Instalación DHCP"
        echo -e "2. Verificar instalación"
        echo -e "3. Configuración DHCP"
        echo -e "4. Monitorear"
        echo -e "5. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Seleccione una opción [1-5]: " OPCION
        case $OPCION in
            1) instalacion_dhcp ;;
            2) verificar_instalacion ;;
            3) configuracion_dhcp ;;
            4) monitorear ;;
            5) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac
        
        if [[ "$OPCION" != "5" ]]; then
            echo ""
            echo -e "${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

submenu_dns() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}               TAREA 3: DNS MENU             ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo -e "1. Instalación/Reparación DNS"
        echo -e "2. Verificar IP Estática"
        echo -e "3. Agregar Dominio"
        echo -e "4. Listar Dominios"
        echo -e "5. Eliminar Dominio"
        echo -e "6. Desinstalar DNS (Limpieza)"
        echo -e ""
        echo -e "7. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Seleccione una opción [1-7]: " OPCION
        case $OPCION in
            1) instalacion_dns ;;
            2) verificar_ip_estatica ;;
            3) agregar_dominio ;;
            4) listar_dominios ;;
            5) eliminar_dominio ;;
            6) desinstalar_dns ;;
            7) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac

        if [[ "$OPCION" != "7" ]]; then
            echo ""
            echo -e "${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

# ---  SUBMENÚ PARA SSH ---
submenu_ssh() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}               TAREA 4: MENÚ SSH             ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo -e "1. Instalar y Configurar OpenSSH"
        echo -e "2. Verificar Estado y Guía de Conexión"
        echo -e "3. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Seleccione una opción [1-3]: " OPCION
        case $OPCION in
            1) instalacion_ssh ;;
            2) verificar_ssh ;;
            3) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac

        if [[ "$OPCION" != "3" ]]; then
            echo ""
            echo -e "${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

# ==========================================
# 5. MENÚ PRINCIPAL ORQUESTADOR
# ==========================================
while true; do
    clear
    echo -e "\n${VERDE}====================================================${RESET}"
    echo -e "${VERDE}         MENÚ PRINCIPAL DE ADMINISTRACIÓN           ${RESET}"
    echo -e "${VERDE}====================================================${RESET}"
    echo "1. Módulo de Diagnóstico y Red (Tarea 1)"
    echo "2. Módulo Servidor DHCP (Tarea 2)"
    echo "3. Módulo Servidor DNS (Tarea 3)"
    echo "4. Módulo Servidor SSH (Tarea 4)" 
    echo "5. Salir completamente"
    echo -e "${VERDE}----------------------------------------------------${RESET}"
    
    read -p "Selecciona un módulo [1-5]: " OPCION_MAIN

    case $OPCION_MAIN in
        1) submenu_tarea1 ;;
        2) submenu_dhcp ;;
        3) submenu_dns ;;
        4) submenu_ssh ;; 
        5) echo -e "${VERDE}Saliendo del administrador...${RESET}"; exit 0 ;;
        *) echo -e "${ROJO}[ERROR] Opción no válida. Elige del 1 al 5.${RESET}"; sleep 2 ;;
    esac
done

#!/bin/bash

# Importar lógica (backend)
source tarea3_dns.sh

# Verificación de permisos
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}[!] Ejecutar como root (sudo).${RESET}"
   exit 1
fi

while true; do
    clear
    echo -e "\n${AZUL}=========================================${RESET}"
    echo -e "${AZUL}    		DNS MENU        	${RESET}"
    echo -e "${AZUL}=========================================${RESET}"
    echo -e "1. Instalación/Reparación DNS"
    echo -e "2. Verificar IP Estática"
    echo -e "3. Agregar Dominio"
    echo -e "4. Listar Dominios"
    echo -e "5. Eliminar Dominio"
    echo -e "6. Desinstalar DNS (Limpieza)"
    echo -e ""
    echo -e "7. Salir"
    echo -e "${AZUL}-----------------------------------------${RESET}"

    read -p "Seleccione una opción: " OPCION

    case $OPCION in    # DNS
        1) instalacion_dns ;;
        2) verificar_ip_estatica ;;
        3) agregar_dominio ;;
        4) listar_dominios ;;
        5) eliminar_dominio ;;
        6) desinstalar_dns ;;
        
        7) echo -e "${VERDE}Saliendo...${RESET}"; exit 0 ;;
        *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
    esac

    echo "" 
    echo -e "${AMARILLO}---------------------------------------${RESET}"
    read -p "Presiona Enter para volver al menú..." dummy
done

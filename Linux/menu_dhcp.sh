#!/bin/bash

# Importar lógica
source tarea2_dhcp.sh

# Verificación de permisos
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}[!] Ejecutar como root (sudo).${RESET}"
   exit 1
fi

while true; do
    echo -e "\n${AZUL}=========================================${RESET}"
    echo -e "${AZUL}       		MENÚ DHCP       ${RESET}"
    echo -e "${AZUL}=========================================${RESET}"
    echo -e "1. Instalación DHCP"
    echo -e "2. Verificar instalación"
    echo -e "3. Configuración DHCP"
    echo -e "4. Monitorear"
    echo -e "5. Salir"
    echo -e "${AZUL}-----------------------------------------${RESET}"
    
    read -p "Seleccione una opción: " OPCION

    case $OPCION in
        1) instalacion_dhcp ;;
        2) verificar_instalacion ;;
        3) configuracion_dhcp ;;
        4) monitorear ;;
        5) echo -e "${VERDE}Saliendo...${RESET}"; exit 0 ;;
        *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
    esac
done

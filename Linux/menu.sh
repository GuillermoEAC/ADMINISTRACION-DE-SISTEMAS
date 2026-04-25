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
# 2. VARIABLES GLOBALES (Para Tarea 7)
# ==========================================
export FTP_SERVER="192.168.56.104" 
export FTP_USER="kami" 
export FTP_PASS="Sistemas.2026!"
export DIR_DESCARGAS="/tmp/descargas_practica7"

# ==========================================
# 3. IMPORTAR LÓGICA DE TODAS LAS TAREAS
# ==========================================
source ./tarea1_diag.sh
source ./tarea2_dhcp.sh
source ./tarea3_dns.sh
source ./tarea4_ssh.sh
source ./tarea5_ftp.sh
source ./tarea6_http.sh
source ./tarea7_ssl.sh  

# ==========================================
# 4. VERIFICACIÓN DE PERMISOS ROOT
# ==========================================
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}[!] Ejecutar como root (sudo).${RESET}"
   exit 1
fi

mkdir -p "$DIR_DESCARGAS"
# verificar_dependencias # Función dentro de tarea7 para asegurar curl/openssl

# ==========================================
# 5. SUBMENÚS POR TAREA 
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

submenu_ftp() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}               TAREA 5: MENÚ FTP             ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo -e "1. Configuración inicial (vsftpd)"
        echo -e "2. Verificar instalación y estado"
        echo -e "3. Alta de usuarios"
        echo -e "4. Cambiar usuario de grupo"
        echo -e "5. Eliminar usuario"
        echo -e "6. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Seleccione una opción [1-6]: " OPCION
        case $OPCION in
            1) configuracion_inicial_ftp ;;
            2) verificar_instalacion_ftp ;;
            3) gestion_alta_usuarios ;;
            4) cambiar_grupo_ftp ;;
            5) eliminar_usuario_ftp ;;
            6) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac

        if [[ "$OPCION" != "6" ]]; then
            echo ""
            echo -e "${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

submenu_http() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}        TAREA 6: MENÚ SERVIDOR HTTP      ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo -e "1. Despliegue dinámico de Apache2"
        echo -e "2. Despliegue dinámico de Nginx"
        echo -e "3. Despliegue dinámico de Tomcat"
        echo -e "4. Verificar instalaciones y puertos activos"
        echo -e "5. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Seleccione una opción [1-5]: " OPCION
        case $OPCION in
            1) menu_instalar_apache ;;
            2) menu_instalar_nginx ;;
            3) menu_instalar_tomcat ;;
            4) verificar_http ;;
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

submenu_orquestador() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}    TAREA 7: ORQUESTADOR HÍBRIDO         ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo "1. Instalación Segura (Repo Web/Privado)"
        echo "2. Verificar Integridad SHA256 manual"        
        echo "3. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Selecciona una opción [1-3]: " OPCION
        case $OPCION in
            1) 
                echo -e "\n${CYAN}Servicios Disponibles:${RESET}"
                echo "1) vsftpd  2) Apache  3) Nginx  4) Tomcat"
                read -p "Elige servicio: " sel_serv
                case $sel_serv in
                    1) serv="vsftpd" ;; 2) serv="Apache" ;; 
                    3) serv="Nginx" ;;  4) serv="Tomcat" ;;
                esac

                echo -e "\n${CYAN}Origen de instalación:${RESET}"
                echo "1) Web (apt-get)  2) Privado (FTP)"
                read -p "Elige origen: " orig

                read -p "Puerto principal a asignar para $serv: " pto
                if validar_puerto_ingresado "$pto"; then
                    if [ "$orig" == "2" ]; then
                        if navegar_y_descargar_ftp "$serv"; then
                            echo -e "${VERDE}Listo para instalar $serv desde $PAQUETE_DESCARGADO${RESET}"
                            instalar_y_configurar_servicio "$serv" "ftp" "$pto" "$PAQUETE_DESCARGADO"
                            aplicar_ssl_servicio "$serv" "$pto"
                            realizar_resumen_instalacion "$serv" "$pto"
                        fi
                    else
                        echo -e "${AMARILLO}Iniciando instalación Web de $serv...${RESET}"
                        instalar_y_configurar_servicio "$serv" "web" "$pto" ""
                        aplicar_ssl_servicio "$serv" "$pto"
                        realizar_resumen_instalacion "$serv" "$pto"
                    fi
                fi
                ;;
            2) echo "Función de verificación manual en construcción..." ;;
            3) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac

        if [[ "$OPCION" != "3" ]]; then
            echo -e "\n${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

# --- NUEVO SUBMENÚ PARA CONTENEDORES (TAREA 10) ---
submenu_tarea10() {
    while true; do
        clear
        echo -e "\n${AZUL}=========================================${RESET}"
        echo -e "${AZUL}   TAREA 10: CONTENEDORES Y SEGURIDAD    ${RESET}"
        echo -e "${AZUL}=========================================${RESET}"
        echo -e "1. Desplegar Infraestructura (Silencioso)"
        echo -e "2. Verificar Límites de Recursos (Test 10.4)"
        echo -e "3. Detener y Limpiar Contenedores"
        echo -e "4. Volver al Menú Principal"
        echo -e "${AZUL}-----------------------------------------${RESET}"

        read -p "Seleccione una opción [1-4]: " OPCION
        case $OPCION in
            1)
                echo -e "\n${AMARILLO}[*] Configurando redes, volúmenes y contenedores...${RESET}"
                # Navegamos a la carpeta de la práctica donde estará el archivo maestro
                cd /mnt/practicas/practica10 || { echo -e "${ROJO}[!] Carpeta no encontrada.${RESET}"; break; }
                
                # Ejecutamos docker de forma desatendida (-d) reconstruyendo las imágenes (--build)
                docker compose up -d --build
                
                echo -e "\n${VERDE}[✓] ¡Despliegue desatendido completado!${RESET}"
                echo -e "${CYAN}[i] Apache, PostgreSQL y FTP están en línea.${RESET}"
                ;;
            2)
                echo -e "\n${CYAN}[i] Mostrando consumo en tiempo real...${RESET}"
                echo -e "${AMARILLO}(Toma captura de esto para tu Prueba 10.4)${RESET}"
                # Usamos --no-stream para que imprima una vez y regrese al menú, ideal para la captura
                docker stats --no-stream
                ;;
            3)
                echo -e "\n${ROJO}[*] Deteniendo infraestructura...${RESET}"
                cd /mnt/practicas/practica10 && docker compose down
                echo -e "${VERDE}[✓] Contenedores apagados y removidos limpiamente.${RESET}"
                ;;
            4) break ;;
            *) echo -e "${ROJO}[!] Opción no válida.${RESET}" ;;
        esac

        if [[ "$OPCION" != "4" ]]; then
            echo ""
            echo -e "${AMARILLO}---------------------------------------${RESET}"
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

# ==========================================
# 6. MENÚ PRINCIPAL ORQUESTADOR
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
    echo "5. Módulo Servidor FTP (Tarea 5)"
    echo "6. Módulo Servidor HTTP (Tarea 6)" 
    echo "7. Módulo Orquestador Híbrido SSL (Tarea 7)" 
    echo -e "${CYAN}8. Módulo Práctica 10: Contenedores Docker${RESET}" 
    echo "9. Salir completamente"                
    echo -e "${VERDE}----------------------------------------------------${RESET}"

    read -p "Selecciona un módulo [1-9]: " OPCION_MAIN

    case $OPCION_MAIN in
        1) submenu_tarea1 ;;
        2) submenu_dhcp ;;
        3) submenu_dns ;;
        4) submenu_ssh ;;
        5) submenu_ftp ;;
        6) submenu_http ;; 
        7) submenu_orquestador ;; 
        8) submenu_tarea10 ;; 
        9) echo -e "${VERDE}Saliendo del administrador...${RESET}"; exit 0 ;;
        *) echo -e "${ROJO}[ERROR] Opción no válida. Elige del 1 al 9.${RESET}"; sleep 2 ;;
    esac
done

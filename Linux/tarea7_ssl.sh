#!/bin/bash

# ==========================================
# MÓDULO DE FUNCIONES - ORQUESTADOR LINUX
# ==========================================

# --- 0. INSTALACIÓN DE DEPENDENCIAS BASE ---
verificar_dependencias() {
    echo -e "${CYAN}[*] Verificando herramientas del sistema...${RESET}"
    if ! command -v curl &> /dev/null || ! command -v openssl &> /dev/null; then
        echo -e "${AMARILLO}[*] Faltan herramientas. Instalando dependencias (curl, openssl)...${RESET}"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq curl openssl >/dev/null 2>&1
        echo -e "${VERDE}[✓] Dependencias listas.${RESET}"
    fi
}

# --- 1. FUNCIÓN DE VALIDACIÓN DE PUERTOS ---
validar_puerto_ingresado() {
    local puerto=$1
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ -z "$puerto" ]; then
        echo -e "${ROJO}[ERROR] El puerto debe ser un número.${RESET}"
        return 1
    fi
    if ss -tuln | grep -q ":$puerto "; then
        echo -e "${ROJO}[ERROR] El puerto $puerto ya está ocupado.${RESET}"
        return 1
    fi
    return 0
}

# --- 2. NAVEGACIÓN Y DESCARGA (BLINDADA PARA FTP/FTPS DINÁMICO) ---
navegar_y_descargar_ftp() {
    local servicio=$1
    
    # 1. ¡LA MAGIA! El script busca en qué puerto está viviendo el FTP actualmente
    local puerto_ftp_actual=$(grep "^listen_port=" /etc/vsftpd.conf 2>/dev/null | cut -d'=' -f2)
    # Si no encuentra nada, asume el 21 por defecto (para la primera vez)
    puerto_ftp_actual=${puerto_ftp_actual:-21} 

    # 2. Armamos la URL con el puerto detectado dinámicamente
    local url_servicio="ftp://$FTP_SERVER:$puerto_ftp_actual/general/http/Linux/$servicio/"
    echo -e "${CYAN}[*] Explorando $servicio (Puerto FTP detectado: $puerto_ftp_actual)...${RESET}"

    # Usamos --ssl-reqd para que curl se adapte si el FTP ya está cifrado
    mapfile -t archivos_versiones < <(curl -s -l -k --ssl-reqd -u "$FTP_USER:$FTP_PASS" "$url_servicio" | grep -v '\.sha256$')
    
    if [ ${#archivos_versiones[@]} -eq 0 ]; then
        echo -e "${ROJO}[!] No se encontraron instaladores para $servicio en el FTP.${RESET}"
        return 1
    fi

    local archivo_elegido=$(echo "${archivos_versiones[0]}" | tr -d '\r')
    echo -e "${AMARILLO}[*] Descargando $archivo_elegido...${RESET}"
    
    curl -s -k --ssl-reqd -u "$FTP_USER:$FTP_PASS" "$url_servicio$archivo_elegido" -o "$DIR_DESCARGAS/$archivo_elegido"
    curl -s -k --ssl-reqd -u "$FTP_USER:$FTP_PASS" "$url_servicio$archivo_elegido.sha256" -o "$DIR_DESCARGAS/$archivo_elegido.sha256"

    cd "$DIR_DESCARGAS" || return 1
    if sha256sum -c "$archivo_elegido.sha256" > /dev/null 2>&1; then
        echo -e "${VERDE}[✓] Hash SHA256 Correcto.${RESET}"
        PAQUETE_DESCARGADO="$DIR_DESCARGAS/$archivo_elegido"
        cd - > /dev/null
        return 0
    else
        echo -e "${ROJO}[X] Archivo corrupto.${RESET}"
        cd - > /dev/null; return 1
    fi
}

# --- 3. FUNCIÓN DE INSTALACIÓN Y CONFIGURACIÓN ---
instalar_y_configurar_servicio() {
    local serv=$1
    local metodo=$2
    local pto=$3
    local paquete=$4

    # ARREGLO DE NOMBRES PARA DEBIAN
    local pkg_apt=""
    case $serv in
        "Apache") pkg_apt="apache2" ;;
        "Nginx") pkg_apt="nginx" ;;
        "vsftpd") pkg_apt="vsftpd" ;;
        "Tomcat") pkg_apt="tomcat9" ;;
    esac

    echo -e "\n${CYAN}>>> Instalando $servicio (Modo: $metodo)...${RESET}"

    if [ "$metodo" == "web" ]; then
        apt-get update -qq && apt-get install -y "$pkg_apt" -qq >/dev/null 2>&1
    else
        dpkg -i "$paquete" >/dev/null 2>&1
        apt-get install -f -y -qq >/dev/null 2>&1
    fi

    # Configuración de puertos y creación de HTML personalizado
# Configuración de puertos y creación AUTOMÁTICA de HTML
    case $serv in
        "Apache")
            sed -i "s/Listen 80/Listen $pto/g" /etc/apache2/ports.conf
            sed -i "s/<VirtualHost \*:80>/<VirtualHost \*:$pto>/g" /etc/apache2/sites-available/000-default.conf
            
            # Limpiamos basura vieja y creamos el nuevo dinámico con UTF-8
            rm -f /var/www/html/index*
            echo "<!DOCTYPE html><html><head><meta charset='UTF-8'></head><body><h1>[✓] UAS-FIM: $serv activo en puerto $pto</h1></body></html>" > /var/www/html/index.html
            
            systemctl restart apache2
            ;;
        "Nginx")
            sed -i "s/listen 80/listen $pto/g" /etc/nginx/sites-enabled/default
            
            # Limpiamos basura vieja y creamos el nuevo dinámico con UTF-8
            rm -f /var/www/html/index*
            echo "<!DOCTYPE html><html><head><meta charset='UTF-8'></head><body><h1>[✓] UAS-FIM: $serv activo en puerto $pto</h1></body></html>" > /var/www/html/index.html
            
            systemctl restart nginx
            ;;
        "Tomcat")
            sed -i "s/port=\"8080\"/port=\"$pto\"/g" /etc/tomcat9/server.xml
            mkdir -p /var/lib/tomcat9/webapps/ROOT
            
            # Limpiamos basura vieja en Tomcat
            rm -f /var/lib/tomcat9/webapps/ROOT/index*
            echo "<!DOCTYPE html><html><head><meta charset='UTF-8'></head><body><h1>[✓] UAS-FIM: $serv activo en puerto $pto</h1></body></html>" > /var/lib/tomcat9/webapps/ROOT/index.html
            
            systemctl restart tomcat9
            ;;
        "vsftpd")
            grep -q "listen_port" /etc/vsftpd.conf || echo "listen_port=$pto" >> /etc/vsftpd.conf
            sed -i "s/listen_port=.*/listen_port=$pto/g" /etc/vsftpd.conf
            systemctl restart vsftpd
            ;;
    esac
    echo -e "${VERDE}[✓] Configuración base lista.${RESET}"
}


# --- 4. GENERACIÓN DE CERTIFICADO ÚNICO ---
generar_certificado_ssl() {
    if [ ! -f /etc/ssl/reprobados/servidor.crt ]; then
        echo -e "${CYAN}[*] Creando certificados SSL para www.reprobados.com...${RESET}"
        mkdir -p /etc/ssl/reprobados
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/reprobados/servidor.key \
        -out /etc/ssl/reprobados/servidor.crt \
        -subj "/C=MX/ST=Sinaloa/L=Mochis/O=UAS/OU=FIM/CN=www.reprobados.com" >/dev/null 2>&1
    fi
}

# --- 5. LÓGICA DE CIFRADO POR SERVICIO ---
aplicar_ssl_servicio() {
    local servicio=$1
    local puerto_http=$2
    
    read -p "¿Desea activar SSL en este servicio? [S/N]: " activar_ssl
    if [[ "$activar_ssl" =~ ^[Ss]$ ]]; then
        read -p "Ingresa el puerto SEGURO (SSL/TLS) a utilizar (ej. 443, 8443): " puerto_ssl
        export PUERTO_SSL_ACTIVO=$puerto_ssl 
        generar_certificado_ssl
        
        case $servicio in
            "Apache")
                a2enmod ssl rewrite >/dev/null 2>&1
                cat <<EOF > /etc/apache2/sites-available/default-ssl.conf
<VirtualHost *:$puerto_ssl>
    ServerName www.reprobados.com
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/reprobados/servidor.crt
    SSLCertificateKeyFile /etc/ssl/reprobados/servidor.key
</VirtualHost>
EOF
                a2ensite default-ssl >/dev/null 2>&1
                sed -i "/VirtualHost \*:$puerto_http/a \ \tRewriteEngine On\n\tRewriteCond %{HTTPS} off\n\tRewriteRule ^(.*)$ https://%{HTTP_HOST}:%{SERVER_PORT}%{REQUEST_URI} [L,R=301]" /etc/apache2/sites-available/000-default.conf
                systemctl restart apache2
                ;;
            "Nginx")
                cat <<EOF > /etc/nginx/sites-enabled/default
server {
    listen $puerto_http;
    server_name _;
    return 301 https://\$host:$puerto_ssl\$request_uri;
}
server {
    listen $puerto_ssl ssl;
    server_name _;
    ssl_certificate /etc/ssl/reprobados/servidor.crt;
    ssl_certificate_key /etc/ssl/reprobados/servidor.key;
    location / {
        root /var/www/html;
        index index.html index.nginx-debian.html;
    }
}
EOF
                systemctl restart nginx
                ;;
            "vsftpd")
                # FTP usa el mismo puerto para normal y seguro (explícito)
                export PUERTO_SSL_ACTIVO=$puerto_http
                {
                    echo "ssl_enable=YES"
                    echo "allow_anon_ssl=NO"
                    echo "force_local_data_ssl=YES"
                    echo "force_local_logins_ssl=YES"
                    echo "ssl_tlsv1=YES"
                    echo "rsa_cert_file=/etc/ssl/reprobados/servidor.crt"
                    echo "rsa_private_key_file=/etc/ssl/reprobados/servidor.key"
                } >> /etc/vsftpd.conf
                systemctl restart vsftpd
                ;;
            "Tomcat")
                sed -i "/Connector port=\"$puerto_http\"/a \    <Connector port=\"$puerto_ssl\" protocol=\"org.apache.coyote.http11.Http11NioProtocol\" maxThreads=\"150\" SSLEnabled=\"true\" scheme=\"https\" secure=\"true\" clientAuth=\"false\" sslProtocol=\"TLS\">\n      <SSLHostConfig>\n        <Certificate certificateFile=\"/etc/ssl/reprobados/servidor.crt\" certificateKeyFile=\"/etc/ssl/reprobados/servidor.key\" type=\"RSA\" />\n      </SSLHostConfig>\n    </Connector>" /etc/tomcat9/server.xml
                systemctl restart tomcat9
                ;;
        esac
        echo -e "${VERDE}[✓] SSL/TLS activado.${RESET}"
    else
        export PUERTO_SSL_ACTIVO="Ninguno"
    fi
}

# --- 6. RESUMEN DE VERIFICACIÓN (Actualizado) ---
realizar_resumen_instalacion() {
    local serv=$1
    local pto=$2
    echo -e "\n${AZUL}=========================================${RESET}"
    echo -e "${AZUL}       RESUMEN DE INSTALACIÓN            ${RESET}"
    echo -e "${AZUL}=========================================${RESET}"
    echo -e "Servicio: $serv"
    echo -ne "Estado del proceso: "
    pgrep -x "${serv,,}" >/dev/null && echo -e "Estado: ${VERDE}OK${RESET}"

    local p_name="${serv,,}"; [[ "$serv" == "Apache" ]] && p_name="apache2"; [[ "$serv" == "Tomcat" ]] && p_name="java"
    pgrep -x "$p_name" >/dev/null && echo -e "Estado: ${VERDE}OK${RESET}" || echo -e "Estado: ${ROJO}FAIL${RESET}"
    echo -ne "Puerto HTTP activo ($pto): "
    ss -tuln | grep -q ":$pto " && echo -e "${VERDE}OK${RESET}" || echo -e "${ROJO}CERRADO${RESET}"
    echo -ne "Cifrado SSL/TLS (Puerto $PUERTO_SSL_ACTIVO): "
    if [ "$PUERTO_SSL_ACTIVO" != "Ninguno" ]; then
        ss -tuln | grep -q ":$PUERTO_SSL_ACTIVO " || grep -q "ssl_enable=YES" /etc/vsftpd.conf && echo -e "${VERDE}ACTIVO${RESET}" || echo -e "${ROJO}FALLÓ${RESET}"
    else
        echo -e "${AMARILLO}OMITIDO${RESET}"
    fi
    echo -e "${AZUL}-----------------------------------------${RESET}"
}

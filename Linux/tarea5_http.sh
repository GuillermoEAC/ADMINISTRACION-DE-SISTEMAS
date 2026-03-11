#!/bin/bash
# ==========================================
# TAREA 6: FUNCIONES DE DESPLIEGUE HTTP (DEBIAN)
# ==========================================


ROJO=${ROJO:-'\033[0;31m'}
VERDE=${VERDE:-'\033[0;32m'}
AZUL=${AZUL:-'\033[0;34m'}
AMARILLO=${AMARILLO:-'\033[1;33m'}
CYAN=${CYAN:-'\033[0;36m'}
RESET=${RESET:-'\033[0m'}

# --- FUNCIÓN DE VERIFICACIÓN GLOBAL ---
verificar_http() {
    echo -e "${CYAN}=== ESTADO DE LOS SERVICIOS HTTP ===${RESET}"
    
    for servicio in apache2 nginx tomcat; do
        if systemctl is-active --quiet "$servicio"; then
            echo -e "${VERDE}[✓] $servicio está INSTALADO y EN EJECUCIÓN.${RESET}"
        else
            echo -e "${ROJO}[X] $servicio NO está en ejecución o no está instalado.${RESET}"
        fi
    done

    echo -e "\n${CYAN}=== PUERTOS A LA ESCUCHA (HTTP) ===${RESET}"
    ss -tuln | grep -E ':(80|443|8080|8888) ' || echo "No hay puertos HTTP comunes en uso."
}

# --- FUNCIÓN AUXILIAR: VALIDAR PUERTO ---
validar_puerto_ingresado() {
    local puerto=$1
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ -z "$puerto" ]; then
        echo -e "${ROJO}[ERROR] El puerto debe ser un número.${RESET}"
        return 1
    fi
    if ss -tuln | grep -q ":$puerto "; then
        echo -e "${ROJO}[ERROR] El puerto $puerto ya está ocupado por otro servicio.${RESET}"
        return 1
    fi
    return 0
}

# --- 1. DESPLIEGUE DE APACHE2 ---
menu_instalar_apache() {
    echo -e "${CYAN}Consultando versiones disponibles de Apache2...${RESET}"
    apt-cache madison apache2 | awk '{print $3}' | head -n 3
    
    echo ""
    read -p "Ingrese la versión exacta (o deje en blanco para la Latest): " version
    read -p "Ingrese el puerto de escucha (ej. 80): " puerto

    validar_puerto_ingresado "$puerto" || return 1

    echo -e "${AMARILLO}Iniciando instalación silenciosa de Apache2...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    
    if [ -z "$version" ]; then
        apt-get install -y -q apache2 > /dev/null 2>&1
    else
        apt-get install -y -q apache2="$version" > /dev/null 2>&1
    fi

    echo -e "${AMARILLO}Configurando puerto $puerto...${RESET}"
    sed -i "s/Listen [0-9]*/Listen $puerto/g" /etc/apache2/ports.conf

    echo -e "${AMARILLO}Aplicando seguridad (Cabeceras y Firmas)...${RESET}"
    sed -i 's/ServerTokens OS/ServerTokens Prod/g' /etc/apache2/conf-available/security.conf
    sed -i 's/ServerSignature On/ServerSignature Off/g' /etc/apache2/conf-available/security.conf
    a2enmod headers > /dev/null 2>&1
    echo "Header always append X-Frame-Options SAMEORIGIN" >> /etc/apache2/apache2.conf
    echo "Header always append X-Content-Type-Options nosniff" >> /etc/apache2/apache2.conf

    echo -e "${AMARILLO}Ajustando permisos y usuario (Chmod 750)...${RESET}"
    id -u webadmin_apache &>/dev/null || useradd -r -s /usr/sbin/nologin webadmin_apache
    
    # Aquí está la corrección del grupo para evitar el 403 Forbidden
    chown -R webadmin_apache:www-data /var/www/html
    chmod -R 750 /var/www/html

    # --- INICIO DE LA LÓGICA NUEVA DE FIREWALL ---
    echo -e "${AMARILLO}Instalando y configurando Firewall (UFW)...${RESET}"
    # 1. Instala ufw silenciosamente porque vimos que no viene en tu Debian
    apt-get install -y -q ufw > /dev/null 2>&1
    # 2. Asegura que el puerto 22 se abra para no perder tu conexión SSH
    ufw allow 22/tcp > /dev/null 2>&1
    # 3. Abre el puerto web que escribiste en el menú
    ufw allow "$puerto"/tcp > /dev/null 2>&1
    # 4. Enciende el firewall de forma forzada sin pedir "y/n"
    ufw --force enable > /dev/null 2>&1
    # --- FIN DE LA LÓGICA DE FIREWALL ---

    echo "<h1>Servidor: Apache2 - Version: Instalada - Puerto: $puerto</h1>" > /var/www/html/index.html

    systemctl restart apache2
    echo -e "${VERDE}[✓] Apache configurado con éxito.${RESET}"
}

# --- 2. DESPLIEGUE DE NGINX ---
menu_instalar_nginx() {
    echo -e "${CYAN}Consultando versiones disponibles de Nginx...${RESET}"
    apt-cache madison nginx | awk '{print $3}' | head -n 3
    
    echo ""
    read -p "Ingrese la versión exacta (o deje en blanco para la Latest): " version
    read -p "Ingrese el puerto de escucha (ej. 8080): " puerto

    validar_puerto_ingresado "$puerto" || return 1

    echo -e "${AMARILLO}Iniciando instalación silenciosa de Nginx...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    
    if [ -z "$version" ]; then
        apt-get install -y -q nginx > /dev/null 2>&1
    else
        apt-get install -y -q nginx="$version" > /dev/null 2>&1
    fi

    echo -e "${AMARILLO}Configurando puerto $puerto...${RESET}"
    sed -i "s/listen 80 default_server;/listen $puerto default_server;/g" /etc/nginx/sites-available/default
    sed -i "s/listen \[::\]:80 default_server;/listen \[::\]:$puerto default_server;/g" /etc/nginx/sites-available/default

    echo -e "${AMARILLO}Aplicando seguridad (Cabeceras y Firmas)...${RESET}"
    # Descomentar server_tokens off para ocultar versión
    sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf
    # Agregar headers de seguridad en el archivo principal
    sed -i '/server_tokens off;/a \        add_header X-Frame-Options "SAMEORIGIN";\n        add_header X-Content-Type-Options "nosniff";' /etc/nginx/nginx.conf

    echo -e "${AMARILLO}Ajustando permisos y usuario (Chmod 750)...${RESET}"
    id -u webadmin_nginx &>/dev/null || useradd -r -s /usr/sbin/nologin webadmin_nginx
    chown -R webadmin_nginx:webadmin_nginx /var/www/html
    chmod -R 750 /var/www/html

    echo "<h1>Servidor: Nginx - Version: Instalada - Puerto: $puerto</h1>" > /var/www/html/index.html

    systemctl restart nginx
    echo -e "${VERDE}[✓] Nginx configurado con éxito.${RESET}"
}

# --- 3. DESPLIEGUE DE TOMCAT (EXTRACCIÓN DE BINARIOS) ---
menu_instalar_tomcat() {
    echo -e "${CYAN}Opciones de versiones de Tomcat disponibles:${RESET}"
    echo "1) LTS (9.0.86)"
    echo "2) Latest / Desarrollo (10.1.19)"
    read -p "Seleccione versión [1-2]: " opc_ver
    
    if [ "$opc_ver" == "1" ]; then
        T_VER="9.0.86"
        T_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$T_VER/bin/apache-tomcat-$T_VER.tar.gz"
    elif [ "$opc_ver" == "2" ]; then
        T_VER="10.1.19"
        T_URL="https://archive.apache.org/dist/tomcat/tomcat-10/v$T_VER/bin/apache-tomcat-$T_VER.tar.gz"
    else
        echo -e "${ROJO}[ERROR] Opción inválida.${RESET}"
        return 1
    fi

    read -p "Ingrese el puerto de escucha (ej. 8888): " puerto
    validar_puerto_ingresado "$puerto" || return 1

    echo -e "${AMARILLO}Instalando Java (Requisito para Tomcat) de forma silenciosa...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y -q default-jdk > /dev/null 2>&1

    echo -e "${AMARILLO}Descargando y extrayendo Tomcat v$T_VER...${RESET}"
    wget -q $T_URL -O /tmp/tomcat.tar.gz
    
    # Crear directorio y extraer
    mkdir -p /opt/tomcat
    tar -xf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
    rm /tmp/tomcat.tar.gz

    echo -e "${AMARILLO}Configurando puerto $puerto y seguridad en server.xml...${RESET}"
    # Cambiar el puerto 8080 por el que elija el usuario y ocultar el nombre del servidor
    sed -i "s/port=\"8080\" protocol=\"HTTP\/1.1\"/port=\"$puerto\" protocol=\"HTTP\/1.1\" server=\"AppServer\"/g" /opt/tomcat/conf/server.xml

    echo -e "${AMARILLO}Creando usuario dedicado y configurando permisos...${RESET}"
    # Creamos al usuario webadmin_tomcat y le damos propiedad sobre la carpeta
    id -u webadmin_tomcat &>/dev/null || useradd -r -m -U -d /opt/tomcat -s /bin/false webadmin_tomcat
    chown -R webadmin_tomcat:webadmin_tomcat /opt/tomcat
    chmod -R 750 /opt/tomcat

    # Crear index.jsp personalizado
    echo "<h1>Servidor: Tomcat - Version: $T_VER - Puerto: $puerto</h1>" > /opt/tomcat/webapps/ROOT/index.jsp
    chown webadmin_tomcat:webadmin_tomcat /opt/tomcat/webapps/ROOT/index.jsp

    echo -e "${AMARILLO}Creando servicio de SystemD para arranque automático...${RESET}"
    cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=webadmin_tomcat
Group=webadmin_tomcat
Environment="JAVA_HOME=/usr/lib/jvm/default-java"
Environment="CATALINA_PID=/opt/tomcat/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat"
Environment="CATALINA_BASE=/opt/tomcat"
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tomcat > /dev/null 2>&1

    # --- INICIO DE LA LÓGICA DE FIREWALL PARA TOMCAT ---
    echo -e "${AMARILLO}Configurando Firewall (UFW) para Tomcat...${RESET}"
    apt-get install -y -q ufw > /dev/null 2>&1
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow "$puerto"/tcp > /dev/null 2>&1
    ufw --force enable > /dev/null 2>&1
    # --- FIN DE LA LÓGICA DE FIREWALL ---

    echo -e "${AMARILLO}Iniciando Tomcat (Esto puede tardar unos segundos)...${RESET}"
    systemctl restart tomcat
    
    echo -e "${VERDE}[✓] Tomcat configurado con éxito en el puerto $puerto.${RESET}"
}

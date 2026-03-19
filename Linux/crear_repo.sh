#!/bin/bash
BASE_DIR="/srv/ftp/grupos/general/http"

echo "=== 1. Creando estructura de directorios ==="
mkdir -p $BASE_DIR/Linux/{Apache,Nginx,Tomcat,vsftpd}
mkdir -p $BASE_DIR/Windows/{IIS,Apache,Nginx,Tomcat,vsftpd}

echo -e "\n=== 2. Descargando instaladores REALES y generando Hashes ==="

# Función para secuestrar el .deb real de Debian y crear su hash
descargar_real_y_hash() {
    local ruta=$1
    local paquete_apt=$2
    
    echo "[*] Descargando $paquete_apt original..."
    mkdir -p "$ruta"
    cd "$ruta" || exit
    
    # Limpiamos basura anterior por si acaso
    rm -f *
    
    # apt-get download baja el .deb real sin instalarlo
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get download "$paquete_apt" >/dev/null 2>&1
    
    # Buscamos el archivo que se acaba de descargar
    local archivo=$(ls *.deb 2>/dev/null | head -n 1)
    
    if [ -n "$archivo" ]; then
        # Calculamos el hash real
        sha256sum "$archivo" > "${archivo}.sha256"
        echo -e "[OK] Real: $archivo y su .sha256 creados.\n"
    else
        echo "[ERROR] No se pudo descargar $paquete_apt"
    fi
}

# Llenamos las carpetas de Linux con los paquetes REALES
descargar_real_y_hash "$BASE_DIR/Linux/Apache" "apache2"
descargar_real_y_hash "$BASE_DIR/Linux/Nginx" "nginx"
descargar_real_y_hash "$BASE_DIR/Linux/Tomcat" "tomcat10"
descargar_real_y_hash "$BASE_DIR/Linux/vsftpd" "vsftpd"

echo -e "=== 3. Ajustando permisos ==="
chown -R root:root "$BASE_DIR"
chmod -R 755 "$BASE_DIR"

echo "¡Repositorio híbrido 100% REAL creado con éxito en $BASE_DIR!"
#!/bin/bash
# Script para instalar Docker y Docker Compose de forma oficial y automática en Ubuntu Server
# Práctica 12 - Administración de Sistemas

# Salir inmediatamente si algún comando falla
set -e

echo "=========================================================="
echo "  INSTALADOR AUTOMÁTICO DE DOCKER Y DOCKER COMPOSE        "
echo "=========================================================="
echo ""

# 1. Actualizar el índice de paquetes e instalar dependencias previas
echo "[1/5] Actualizando el índice de paquetes e instalando dependencias..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 2. Agregar la clave GPG oficial de Docker
echo "[2/5] Descargando y configurando la clave GPG de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 3. Configurar el repositorio oficial de Docker
echo "[3/5] Configurando el repositorio oficial..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Instalar Docker Engine, CLI, containerd y Docker Compose Plugin
echo "[4/5] Instalando Docker Engine y el plugin de Docker Compose (v2)..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Agregar el usuario actual al grupo docker
echo "[5/5] Agregando al usuario '$USER' al grupo 'docker' para evitar usar sudo..."
sudo usermod -aG docker $USER

echo ""
echo "=========================================================="
echo "  ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!                   "
echo "=========================================================="
echo "Para aplicar los cambios del grupo 'docker' y no requerir"
echo "escribir 'sudo' en cada comando, por favor haz lo siguiente:"
echo ""
echo "  1. Cierra tu sesión actual (escribe: exit)"
echo "  2. Vuelve a iniciar sesión mediante SSH o consola."
echo "  3. Comprueba el funcionamiento ejecutando:"
echo "     docker compose version"
echo "=========================================================="

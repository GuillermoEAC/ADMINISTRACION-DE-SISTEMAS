# ==========================================
# --- FUNCIONES SSH (TAREA 4) ---
# ==========================================

function Configurar-RedSSH {
    Clear-Host
    # Definir variables
    $Interfaz = "Ethernet 3"
    $IP_Windows = "192.168.100.20"
    $Prefijo = 24 # Equivale a la máscara 255.255.255.0

    Write-Host "Asignando IP estática $IP_Windows a la interfaz $Interfaz..." -ForegroundColor Cyan

    # Eliminar cualquier IP anterior en ese adaptador
    Remove-NetIPAddress -InterfaceAlias $Interfaz -Confirm:$false -ErrorAction SilentlyContinue

    # Asignar la nueva IP fija
    New-NetIPAddress -InterfaceAlias $Interfaz -IPAddress $IP_Windows -PrefixLength $Prefijo

    Write-Host "Configuración de red aplicada con éxito. Listo para conectar por SSH" -ForegroundColor Green
}

function Install-OpenSSH {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     INSTALACIÓN Y CONFIGURACIÓN SSH     " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # 1. Verificar e Instalar
    $sshState = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($sshState.State -eq 'Installed') { 
        Write-Host "[OK] OpenSSH Server ya está instalado." -ForegroundColor Green 
    } else {
        Write-Host "[+] Instalando OpenSSH Server (Esto puede tardar)..." -ForegroundColor Yellow
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
        Write-Host "[OK] Instalación completada." -ForegroundColor Green
    }

    # 2. Configurar el servicio para que inicie automáticamente (Requisito de la rúbrica)
    Write-Host "[+] Configurando servicio y arranque automático..." -ForegroundColor Yellow
    Set-Service -Name sshd -StartupType 'Automatic'
    Start-Service sshd -ErrorAction SilentlyContinue

    # 3. Validar Firewall
    $firewallRule = Get-NetFirewallRule -Name *OpenSSH-Server* -ErrorAction SilentlyContinue
    if (-not $firewallRule) {
        Write-Host "[+] Creando regla de Firewall para el puerto 22..." -ForegroundColor Yellow
        New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }
    
    Write-Host "[OK] Servicio SSH activo y escuchando en el puerto 22." -ForegroundColor Green
}

function Verificar-SSH {
    Clear-Host
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "      VERIFICACIÓN DE ESTADO SSH         " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # 1. Estado del servicio
    $srv = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if ($srv -and $srv.Status -eq 'Running') {
        Write-Host "[OK] El servicio SSH está ACTIVO y ejecutándose." -ForegroundColor Green
    } else {
        Write-Host "[!] El servicio SSH está INACTIVO o no existe." -ForegroundColor Red
    }

    # 2. Arranque automático
    if ($srv.StartType -eq 'Automatic') {
        Write-Host "[OK] SSH está habilitado para arrancar con el sistema (Boot)." -ForegroundColor Green
    } else {
        Write-Host "[i] SSH NO está en arranque automático." -ForegroundColor Yellow
    }

    # 3. Puertos a la escucha
    Write-Host "`n--- Puertos a la escucha ---" -ForegroundColor Yellow
    $puerto22 = Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue
    if ($puerto22) {
        Write-Host "[OK] El servidor está escuchando en el puerto 22." -ForegroundColor Green
    } else {
        Write-Host "[!] No se detectó tráfico en el puerto 22." -ForegroundColor Red
    }

    # 4. Instrucciones de conexión
    # Buscamos la IP de la tarjeta que configuraste en la Tarea 1
    $ipActual = (Get-NetIPAddress -InterfaceAlias 'Ethernet 3' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    if (-not $ipActual) { 
        # Si no la encuentra, agarramos la primera IP válida que no sea la de loopback
        $ipActual = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -ne '127.0.0.1' | Select-Object -First 1).IPAddress 
    }

    Write-Host "`n====================================================" -ForegroundColor Green
    Write-Host "   ¡LISTO! CONÉCTATE DESDE TU MÁQUINA FÍSICA (HOST) " -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "Abre PuTTY, MobaXterm o la Terminal de Windows en tu equipo físico y escribe:"
    Write-Host ""
    Write-Host "   ssh Administrador@$ipActual" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Nota: Te pedirá la contraseña del Administrador de este Windows Server." -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Green
}
# --- FUNCIONES DIAGNÓSTICO Y RED (TAREA 1) ---

function Ejecutar-Diagnostico {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "      DIAGNOSTICO INICIAL - WINDOWS       " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Nombre del Equipo: $env:COMPUTERNAME"
    
    # Buscamos la IP silenciosamente para que no marque error en rojo si no existe
    $ipActual = (Get-NetIPAddress -InterfaceAlias 'Ethernet 2' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
    if (-not $ipActual) { $ipActual = "No asignada" }
    
    Write-Host "IP Actual: $ipActual"
    
    $disco = Get-PSDrive C | Select-Object Used, Free
    Write-Host "Espacio en Disco (C:):"
    Write-Host "Usado: $([Math]::Round($disco.Used/1GB,2)) GB | Libre: $([Math]::Round($disco.Free/1GB,2)) GB"
    Write-Host "==========================================" -ForegroundColor Cyan
}

function Configurar-RedInterna {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "      CONFIGURACIÓN DE RED INTERNA        " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $interfaceAlias = "Ethernet 2" 
    $ipAddress = "192.168.10.2"
    $prefixLength = 24

    Write-Host "[INFO] Validando configuracion de red..." -ForegroundColor Cyan

    $existeIP = Get-NetIPAddress | Where-Object { $_.IPAddress -eq $ipAddress }

    if ($existeIP) {
        if ($existeIP.InterfaceAlias -eq $interfaceAlias) {
            Write-Host "[OK] La IP $ipAddress ya esta configurada correctamente en $interfaceAlias." -ForegroundColor Green
        } else {
            Write-Host "[WARN] La IP existe en otra interfaz ($($existeIP.InterfaceAlias))." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[INFO] La IP no existe. Aplicando configuracion..." -ForegroundColor Yellow
        Remove-NetIPAddress -InterfaceAlias $interfaceAlias -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        
        try {
            New-NetIPAddress -InterfaceAlias $interfaceAlias -IPAddress $ipAddress -PrefixLength $prefixLength -ErrorAction Stop | Out-Null
            Write-Host "[OK] IP $ipAddress asignada exitosamente." -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] No se pudo asignar: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "[INFO] Verificando regla de Firewall para Ping..." -ForegroundColor Cyan
    Enable-NetFirewallRule -Name "FPS-ICMP4-ERQ-In" -ErrorAction SilentlyContinue
    Write-Host "[OK] Regla de Firewall habilitada." -ForegroundColor Green
}
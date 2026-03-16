# ==========================================
# MÓDULO 3: AUTOMATIZACIÓN DNS
# ==========================================

function Instalacion-DNS {
    Write-Host "`n--- INSTALACIÓN DNS ---" -ForegroundColor Cyan
    $Check = Get-WindowsFeature -Name DNS
    
    if ($Check.Installed) {
        Write-Host "[OK] El servicio DNS ya está instalado." -ForegroundColor Green
    } else {
        Write-Host "[+] Instalando Rol DNS..." -ForegroundColor Yellow
        try {
            Install-WindowsFeature -Name DNS -IncludeManagementTools -ErrorAction Stop
            Write-Host "[OK] DNS Instalado correctamente." -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] No se pudo instalar DNS." -ForegroundColor Red
        }
    }
}

function Verificar-Instalacion-DNS {
    Write-Host "`n--- VERIFICAR INSTALACIÓN DNS ---" -ForegroundColor Cyan
    $Check = Get-WindowsFeature -Name DNS
    Write-Host -NoNewline "Estado del Rol DNS: "
    if ($Check.Installed) {
        Write-Host "INSTALADO" -ForegroundColor Green
    } else {
        Write-Host "NO INSTALADO" -ForegroundColor Red
    }
}

function Agregar-Dominio {
    Write-Host "`n--- AGREGAR DOMINIO DNS (DIRECTA + INVERSA) ---" -ForegroundColor Cyan
    
    $ServerIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object PrefixOrigin -ne 'Dhcp').IPAddress[0]
    
    $NombreValido = $false
    do {
        $Dominio = Read-Host "Nombre del Dominio:"
        if ([string]::IsNullOrWhiteSpace($Dominio)) {
            Write-Host "[!] Error: El nombre no puede estar vacío." -ForegroundColor Red
        } elseif ($Dominio -match "^\d+$") {
            Write-Host "[!] Error: El dominio no puede ser solo números." -ForegroundColor Red
        } elseif ($Dominio -notmatch "^[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$") {
             Write-Host "[!] Error: Formato inválido. Debe ser tipo 'nombre.algo'." -ForegroundColor Red
        } else {
            $NombreValido = $true
        }
    } until ($NombreValido)

    $IpsProhibidas = @("0.0.0.0", "127.0.0.1", "255.255.255.255")
    $IpValida = $false
    
    do {
        $InputIP = Read-Host "IP Destino (Enter para usar $ServerIP)"
        
        if ([string]::IsNullOrWhiteSpace($InputIP)) {
            $TargetIP = $ServerIP
            $IpValida = $true
        } else {
            $EsIPReal = [System.Net.IPAddress]::TryParse($InputIP, [ref]$null)
            $TieneFormato = $InputIP -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"
            
            if (-not $EsIPReal -or -not $TieneFormato) {
                Write-Host "[!] Error: Formato inválido. Debe ser 4 octetos (ej. 192.168.10.20)." -ForegroundColor Red
            } elseif ($IpsProhibidas -contains $InputIP) {
                Write-Host "[!] Error: IP prohibida (Reservada/Loopback)." -ForegroundColor Red
            } else {
                $TargetIP = $InputIP
                $IpValida = $true
            }
        }
    } until ($IpValida)

    # ZONA DIRECTA
    if (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue) {
        Write-Host "[!] La zona directa $Dominio ya existe." -ForegroundColor Yellow
    } else {
        try {
            Add-DnsServerPrimaryZone -Name $Dominio -ZoneFile "$Dominio.dns" -ErrorAction Stop
            Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "@" -IPv4Address $TargetIP
            Add-DnsServerResourceRecordA -ZoneName $Dominio -Name "www" -IPv4Address $TargetIP
            Write-Host "[OK] Zona Directa creada." -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Falló al crear zona directa: $_" -ForegroundColor Red
        }
    }

    # ZONA INVERSA
    $Octetos = $TargetIP.Split('.') 
    $NetworkID = "$($Octetos[0]).$($Octetos[1]).$($Octetos[2]).0/24"
    $ZoneNameInv = "$($Octetos[2]).$($Octetos[1]).$($Octetos[0]).in-addr.arpa"
    $HostID = $Octetos[3]

    try {
        if (-not (Get-DnsServerZone -Name $ZoneNameInv -ErrorAction SilentlyContinue)) {
            Write-Host "[i] Creando Zona Inversa..." -ForegroundColor Yellow
            Add-DnsServerPrimaryZone -NetworkId $NetworkID -ZoneFile "$ZoneNameInv.dns" -ErrorAction Stop
        }

        $PtrCheck = Get-DnsServerResourceRecord -ZoneName $ZoneNameInv -Name $HostID -RRType Ptr -ErrorAction SilentlyContinue
        if (-not $PtrCheck) {
            Add-DnsServerResourceRecordPtr -ZoneName $ZoneNameInv -Name $HostID -PtrDomainName "$Dominio"
            Write-Host "[OK] Registro Inverso (PTR) creado." -ForegroundColor Green
        }
    } catch {
        Write-Host "[ERROR] Falló al configurar zona inversa: $_" -ForegroundColor Red
    }
}

function Listar-Dominios {
    Write-Host "`n--- DOMINIOS REGISTRADOS ---" -ForegroundColor Cyan
    $Zonas = Get-DnsServerZone | Where-Object IsAutoCreated -eq $false
    if ($Zonas) {
        $Zonas | Select-Object ZoneName, ZoneType | Format-Table -AutoSize
    } else {
        Write-Host "No hay zonas configuradas manualmente." -ForegroundColor Gray
    }
}

function Eliminar-Dominio {
    Write-Host "`n--- ELIMINAR DOMINIO ---" -ForegroundColor Cyan
    $Dominio = Read-Host "Nombre del dominio a eliminar"
    
    if (Get-DnsServerZone -Name $Dominio -ErrorAction SilentlyContinue) {
        Remove-DnsServerZone -Name $Dominio -Force -Confirm:$false
        Write-Host "[OK] Dominio $Dominio eliminado." -ForegroundColor Green
    } else {
        Write-Host "[!] El dominio no existe." -ForegroundColor Red
    }
}

function Desinstalar-DNS {
    Write-Host "`n--- DESINSTALAR DNS ---" -ForegroundColor Red
    $Conf = Read-Host "¿Seguro que desea eliminar el rol DNS? (s/n)"
    if ($Conf -eq 's') {
        Uninstall-WindowsFeature -Name DNS -IncludeManagementTools
        Write-Host "[OK] Rol DNS eliminado." -ForegroundColor Green
    }
}

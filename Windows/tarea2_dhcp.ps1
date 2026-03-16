# ==========================================
# MÓDULO 2: AUTOMATIZACIÓN DHCP
# ==========================================

# --- FUNCIONES DE VALIDACIÓN (COMPARTIDAS) ---
function Validar-IP {
    param ([string]$Mensaje)
    $Prohibidas = @("0.0.0.0", "127.0.0.1", "255.255.255.255")
    
    do {
        $InputIP = Read-Host -Prompt "$Mensaje"
        $EsFormatoValido = [System.Net.IPAddress]::TryParse($InputIP, [ref]$null)

        if ($Prohibidas -contains $InputIP) {
            Write-Host "[!] Error: La IP $InputIP no es válida (reservada)." -ForegroundColor Red
            $EsValida = $false
        } elseif (-not $EsFormatoValido) {
            Write-Host "[!] Error: Formato incorrecto (ej. 192.168.1.10)." -ForegroundColor Red
            $EsValida = $false
        } else {
            $EsValida = $true
        }
    } until ($EsValida)
    return $InputIP
}

function Validar-Tiempo {
    do {
        $Seg = Read-Host "Tiempo de concesión (segundos)"
        if ($Seg -match "^\d+$" -and [int]$Seg -gt 0) {
            return [int]$Seg
        } else {
            Write-Host "[!] Error: Ingrese solo números enteros positivos." -ForegroundColor Red
        }
    } while ($true)
}

# --- FUNCIONES LÓGICAS DHCP ---
function Instalacion-DHCP {
    Write-Host "`n--- INSTALACIÓN DHCP ---" -ForegroundColor Cyan
    $Check = Get-WindowsFeature -Name DHCP
    
    if ($Check.Installed) {
        Write-Host "[!] El servicio DHCP ya está instalado." -ForegroundColor Yellow
        $Resp = Read-Host "¿Desea reinstalarlo? (s/n)"
        if ($Resp -eq 's') { 
            Write-Host "[+] Reinstalando (Esto puede tardar)..." -ForegroundColor Yellow
            Uninstall-WindowsFeature -Name DHCP -IncludeManagementTools -WarningAction SilentlyContinue
            Instalar-Logica-Inteligente
        } else {
             Write-Host "[OK] Se mantiene instalación actual." -ForegroundColor Green
        }
    } else {
        Write-Host "[+] Iniciando instalación del Rol DHCP..." -ForegroundColor Yellow
        Instalar-Logica-Inteligente
    }
    Set-Service -Name DHCPServer -StartupType Automatic
    try { Start-Service -Name DHCPServer -ErrorAction SilentlyContinue } catch {}
}

function Instalar-Logica-Inteligente {
    try {
        Install-WindowsFeature -Name DHCP -IncludeManagementTools -ErrorAction Stop
        Write-Host "[OK] Instalado correctamente." -ForegroundColor Green
    } catch {
        Write-Host "[!] Falló instalación estándar. Buscando en unidad D:..." -ForegroundColor Yellow
        try {
            Install-WindowsFeature -Name DHCP -IncludeManagementTools -Source "D:\sources\sxs" -ErrorAction Stop
            Write-Host "[OK] Instalado correctamente desde el ISO." -ForegroundColor Green
        } catch {
            Write-Host "[ERROR FATAL] No se pudo instalar el rol DHCP." -ForegroundColor Red
        }
    }
}

function Verificar-Instalacion-DHCP {
    Write-Host "`n--- VERIFICAR INSTALACIÓN DHCP ---" -ForegroundColor Cyan
    $Check = Get-WindowsFeature -Name DHCP
    Write-Host -NoNewline "Estado del Rol DHCP: "
    if ($Check.Installed) { Write-Host "INSTALADO" -ForegroundColor Green } else { Write-Host "NO INSTALADO" -ForegroundColor Red }
}

function Configuracion-DHCP {
    Write-Host "`n--- CONFIGURACIÓN DE DHCP ---" -ForegroundColor Cyan
    
    if (-not (Get-WindowsFeature -Name DHCP).Installed) {
        Write-Host "[!] Error: Primero debe realizar la instalación." -ForegroundColor Red
        return
    }

    Write-Host "Seleccione la interfaz de red a configurar:" -ForegroundColor Yellow
    Get-NetAdapter | Select-Object Name, InterfaceIndex, Status, IPAddress | Format-Table -AutoSize
    
    do { $IfIndex = Read-Host "Ingrese el número de InterfaceIndex (ej. 4, 6, 12)" } until ($IfIndex -match "^\d+$")

    $IpEstatica = Validar-IP "IP Inicio (Se usará como IP Estática del Servidor)"
    
    $IpParts = $IpEstatica.Split('.')
    $Octeto4 = [int]$IpParts[3] + 1
    $RangoInicio = "$($IpParts[0]).$($IpParts[1]).$($IpParts[2]).$Octeto4"
    
    Write-Host "`n[RESUMEN DE LÓGICA]" -ForegroundColor Gray
    Write-Host "-> IP Servidor:   $IpEstatica" -ForegroundColor Green
    Write-Host "-> Inicio DHCP:   $RangoInicio" -ForegroundColor Green

    do {
        $IpFinal = Validar-IP "IP Fin del Rango"
        $EndOctet = [int]($IpFinal.Split('.')[3])
        $StartOctet = $Octeto4
        $BaseStart = "$($IpParts[0]).$($IpParts[1]).$($IpParts[2])"
        $BaseEnd = "$($IpFinal.Split('.')[0]).$($IpFinal.Split('.')[1]).$($IpFinal.Split('.')[2])"

        if ($BaseStart -eq $BaseEnd -and $EndOctet -ge $StartOctet) { 
            $RangoValido = $true 
        } else {
            Write-Host "[!] Error: La IP Final debe ser mayor a $RangoInicio y estar en la misma red." -ForegroundColor Red
            $RangoValido = $false
        }
    } until ($RangoValido)

    $PrimerOcteto = [int]($IpEstatica.Split('.')[0])
    if ($PrimerOcteto -lt 128) { $Mask = "255.0.0.0"; $Prefix = 8 } 
    elseif ($PrimerOcteto -lt 192) { $Mask = "255.255.0.0"; $Prefix = 16 } 
    else { $Mask = "255.255.255.0"; $Prefix = 24 }
    Write-Host "[i] Máscara detectada: $Mask (/$Prefix)" -ForegroundColor Yellow

    $Gw = Read-Host "Gateway (Enter para vacío)"
    $Dns = Read-Host "DNS (Enter para usar $IpEstatica)"
    if ($Dns -eq "") { $Dns = $IpEstatica }

    $Segundos = Validar-Tiempo
    $LeaseTimeSpan = New-TimeSpan -Seconds $Segundos

    Write-Host "`n[+] Configurando IP Estática..." -ForegroundColor Yellow
    try {
        Remove-NetIPAddress -InterfaceIndex $IfIndex -Confirm:$false -ErrorAction SilentlyContinue
        
        $IPParams = @{
            InterfaceIndex = $IfIndex
            IPAddress      = $IpEstatica
            PrefixLength   = $Prefix
            ErrorAction    = "Stop"
        }
        if ($Gw -ne "") { $IPParams.Add("DefaultGateway", $Gw) }

        New-NetIPAddress @IPParams | Out-Null
        Set-DnsClientServerAddress -InterfaceIndex $IfIndex -ServerAddresses ("127.0.0.1", "8.8.8.8")
    } catch {
        Write-Host "[!] Error crítico al poner IP Estática: $_" -ForegroundColor Red
        return
    }

    Write-Host "[+] Configurando Ámbito DHCP..." -ForegroundColor Yellow
    
    if ($Prefix -eq 24) { $ScopeID = "$($IpParts[0]).$($IpParts[1]).$($IpParts[2]).0" }
    elseif ($Prefix -eq 16) { $ScopeID = "$($IpParts[0]).$($IpParts[1]).0.0" }
    else { $ScopeID = "$($IpParts[0]).0.0.0" }

    Get-DhcpServerv4Scope | Remove-DhcpServerv4Scope -Force -ErrorAction SilentlyContinue

    try {
        Add-DhcpServerv4Scope -Name "Practica_UAS" -StartRange $RangoInicio -EndRange $IpFinal -SubnetMask $Mask -LeaseDuration $LeaseTimeSpan -State Active
        if ($Gw -ne "") { Set-DhcpServerv4OptionValue -ScopeId $ScopeID -OptionId 3 -Value $Gw }
        Set-DhcpServerv4OptionValue -ScopeId $ScopeID -OptionId 6 -Value $Dns -Force

        Write-Host "[OK] Configuración Finalizada." -ForegroundColor Green
        Write-Host "[INFO] DNS entregado a clientes: $Dns" -ForegroundColor Cyan
    } catch {
        Write-Host "[!] Error configurando DHCP: $_" -ForegroundColor Red
    }
}

function Monitorear-DHCP {
    Write-Host "`n--- MONITOREO DE SERVICIO DHCP ---" -ForegroundColor Cyan
    $Srv = Get-Service DHCPServer -ErrorAction SilentlyContinue
    if ($Srv) {
        Write-Host "Estado del Servicio: " -NoNewline
        if ($Srv.Status -eq "Running") { Write-Host "ACTIVO" -ForegroundColor Green }
        else { Write-Host "DETENIDO" -ForegroundColor Red }
    }

    Write-Host "`n--- CLIENTES CONECTADOS (LEASES) ---" -ForegroundColor Cyan
    $Scope = Get-DhcpServerv4Scope | Select-Object -First 1
    if ($Scope) {
        $Leases = Get-DhcpServerv4Lease -ScopeId $Scope.ScopeId
        if ($Leases) {
            $Leases | Select-Object @{N='IP ASIGNADA';E={$_.IPAddress}}, @{N='MAC';E={$_.ClientId}}, @{N='HOSTNAME';E={$_.HostName}} | Format-Table -AutoSize
        } else {
            Write-Host "[i] No hay clientes conectados aún." -ForegroundColor Gray
        }
    } else {
        Write-Host "[!] No hay ámbitos configurados." -ForegroundColor Red
    }
}


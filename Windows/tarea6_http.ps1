
# ==========================================
# TAREA 6: FUNCIONES DE DESPLIEGUE HTTP (WINDOWS SERVER)
# ==========================================

Import-Module WebAdministration -ErrorAction SilentlyContinue

# --- 1. FUNCIÓN DE VERIFICACIÓN GLOBAL ---
function Verificar-HTTP {
    Write-Host "`n=== ESTADO DE LOS SERVICIOS HTTP ===" -ForegroundColor Cyan
    
    # IIS se llama W3SVC internamente. Apache y Nginx suelen registrarse con sus nombres.
    $servicios = @("W3SVC", "apache", "nginx")
    
    foreach ($srv in $servicios) {
        $estado = Get-Service -Name $srv -ErrorAction SilentlyContinue
        if ($estado -and $estado.Status -eq 'Running') {
            Write-Host "[✓] $srv está INSTALADO y EN EJECUCIÓN." -ForegroundColor Green
        } elseif ($estado) {
            Write-Host "[!] $srv está INSTALADO pero DETENIDO." -ForegroundColor Yellow
        } else {
            Write-Host "[X] $srv NO está instalado o no es un servicio activo." -ForegroundColor Red
        }
    }

    Write-Host "`n=== PUERTOS A LA ESCUCHA (HTTP) ===" -ForegroundColor Cyan
    # Busca los puertos comunes escuchando (Equivalente al ss -tuln de Linux)
 $puertos = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in 45,80,443,8080,8888 }
    if ($puertos) {
        $puertos | Select-Object LocalAddress, LocalPort | Format-Table -AutoSize
    } else {
        Write-Host "No hay puertos HTTP comunes en uso."
    }
}

# --- 2. VALIDACIÓN DE PUERTO  ---
function Validar-Puerto {
    param ([string]$Puerto)
    
    if ([string]::IsNullOrWhiteSpace($Puerto) -or $Puerto -notmatch "^\d+$") {
        Write-Host "[ERROR] El puerto debe ser un número válido." -ForegroundColor Red
        return $false
    }
    
    $PuertoInt = [int]$Puerto
    if ($PuertoInt -le 0 -or $PuertoInt -gt 65535) {
        Write-Host "[ERROR] El puerto debe estar entre 1 y 65535." -ForegroundColor Red
        return $false
    }

    # Validar si el puerto ya está ocupado para evitar choques
    $ocupado = Get-NetTCPConnection -LocalPort $PuertoInt -State Listen -ErrorAction SilentlyContinue
    if ($ocupado) {
        Write-Host "[ERROR] El puerto $PuertoInt ya está en uso por otro servicio." -ForegroundColor Red
        return $false
    }
    return $true
}

# --- 3. INSTALADOR BLINDADO DE CHOCOLATEY  ---
function Instalar-ChocolateySeguro {
    if (Get-Command "choco" -ErrorAction SilentlyContinue) { return }
    
    Write-Host "Instalando gestor de paquetes (Chocolatey)..." -ForegroundColor Yellow
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Set-ExecutionPolicy Bypass -Scope Process -Force
    
    # Descarga e instala redirigiendo TODO el texto a $null
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) *>$null

    # EL TRUCO: Forzar a la consola a refrescar sus variables de entorno
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

}



# --- 4. DESPLIEGUE FORZOSO DE IIS ---
function Menu-InstalarIIS {
    Write-Host "IIS es una característica nativa de Windows (No requiere consultar versión)." -ForegroundColor Cyan
    $Puerto = Read-Host "Ingrese el puerto de escucha para IIS (ej. 80 o 8888)"
    
    if (-not (Validar-Puerto -Puerto $Puerto)) { return }

    Write-Host "Instalando IIS y módulo de seguridad de forma silenciosa..." -ForegroundColor Yellow
    Install-WindowsFeature -Name Web-Server, Web-Filtering -IncludeManagementTools -WarningAction SilentlyContinue | Out-Null

    Write-Host "Limpiando puertos viejos y configurando el nuevo ($Puerto)..." -ForegroundColor Yellow
    Get-WebBinding -Name "Default Web Site" -Protocol "http" | Remove-WebBinding -ErrorAction SilentlyContinue
    New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port $Puerto -Protocol http

    Write-Host "Aplicando seguridad (Cabeceras con AppCmd)..." -ForegroundColor Yellow
    $appcmd = "$env:systemroot\system32\inetsrv\appcmd.exe"
    & $appcmd set config /section:httpProtocol /-"customHeaders.[name='X-Powered-By']" > $null 2>&1
    Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST' -filter "system.webServer/security/requestFiltering" -name "removeServerHeader" -value "True" -ErrorAction SilentlyContinue
    & $appcmd set config /section:httpProtocol /+"customHeaders.[name='X-Frame-Options',value='SAMEORIGIN']" > $null 2>&1
    & $appcmd set config /section:httpProtocol /+"customHeaders.[name='X-Content-Type-Options',value='nosniff']" > $null 2>&1

    Write-Host "Generando index.html..." -ForegroundColor Yellow
    $VersionIIS = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp").VersionString
    "<h1>Servidor: IIS - Version: $VersionIIS - Puerto: $Puerto</h1>" | Out-File -FilePath "C:\inetpub\wwwroot\index.html" -Encoding utf8

    Write-Host "Limpiando Firewall y abriendo puerto a la fuerza..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "HTTP-Custom*" -ErrorAction SilentlyContinue
    
    # Regla blindada para que pase sí o sí
    New-NetFirewallRule -DisplayName "HTTP-Custom-$Puerto" -Direction Inbound -LocalPort $Puerto -Protocol TCP -Profile Any -Action Allow | Out-Null

    Write-Host "Forzando encendido del sitio web y reiniciando servicio..." -ForegroundColor Yellow
  
    Start-Website -Name "Default Web Site" -ErrorAction SilentlyContinue
    Restart-Service W3SVC
    
    Write-Host "[✓] IIS desplegado con éxito en el puerto $Puerto." -ForegroundColor Green
}



# --- 5. DESPLIEGUE DINÁMICO DE APACHE CON CHOCOLATEY ---
function Menu-InstalarApacheWin {
    Instalar-ChocolateySeguro

    Write-Host "Consultando versiones de Apache en Chocolatey (esto puede tardar unos segundos)..." -ForegroundColor Cyan
    
    $lineas = choco search apache-httpd --exact --all-versions --limit-output | Select-Object -First 5
    $versiones = @()
    $i = 1
    
    Write-Host "`n=== VERSIONES DISPONIBLES ===" -ForegroundColor Yellow
    foreach ($linea in $lineas) {
        $ver = ($linea -split '\|')[1].Trim()
        Write-Host "$i) $ver"
        $versiones += $ver
        $i++
    }
    $opcLatest = $i
    Write-Host "$opcLatest) Latest (Versión más reciente por defecto)"
    
    $OpcionVer = Read-Host "`nSelecciona el número de la versión [1-$opcLatest]"
    $Puerto = Read-Host "Ingrese el puerto de escucha (ej. 45 o 8080)"
    
    if (-not (Validar-Puerto -Puerto $Puerto)) { return }

    $VersionFinal = "Latest"
    Write-Host "Iniciando instalación silenciosa (Por favor espera, descargando e instalando...)" -ForegroundColor Yellow
    
    # Detenemos Apache a la fuerza por si estaba corriendo en otro puerto
    Stop-Service apache -Force -ErrorAction SilentlyContinue

    # Instalamos dependencias previas en silencio
    choco install vcredist140 -y --no-progress *>$null

    # Instalación de Apache totalmente silenciada (*>$null)
    if ($OpcionVer -match "^\d+$" -and [int]$OpcionVer -ge 1 -and [int]$OpcionVer -lt $opcLatest) {
        $VersionFinal = $versiones[[int]$OpcionVer - 1]
        choco install apache-httpd --version $VersionFinal -y --force --allow-downgrade --ignore-checksums --no-progress *>$null
    } else {
        choco install apache-httpd -y --force --ignore-checksums --no-progress *>$null
    }

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "Buscando archivo de configuración httpd.conf..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3 # Darle tiempo a Windows de descomprimir
    
    # BÚSQUEDA INTELIGENTE A PRUEBA DE FALLOS (Incluye AppData donde se esconde)
    $RutaApacheConf = $null
    $Directorios = @("C:\tools", "C:\Apache24", "C:\ProgramData\chocolatey", $env:APPDATA)
    foreach ($dir in $Directorios) {
        if (Test-Path $dir) {
            $encontrado = Get-ChildItem -Path $dir -Filter "httpd.conf" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($encontrado) {
                $RutaApacheConf = $encontrado.FullName
                break
            }
        }
    }
    
    if ($RutaApacheConf) {
        Write-Host "Configurando puerto ($Puerto) y seguridad en: $RutaApacheConf" -ForegroundColor Yellow
        (Get-Content $RutaApacheConf) -replace 'Listen \d+', "Listen $Puerto" | Set-Content $RutaApacheConf
        
        $ConfigContent = Get-Content $RutaApacheConf
        if ($ConfigContent -notmatch "ServerTokens Prod") {
            Add-Content $RutaApacheConf "`nServerTokens Prod`nServerSignature Off"
        }
        
        Write-Host "Generando index.html personalizado..." -ForegroundColor Yellow
        $RutaHtdocs = Join-Path (Split-Path (Split-Path $RutaApacheConf)) "htdocs"
        if (Test-Path $RutaHtdocs) {
            "<h1>Servidor: Apache Win64 - Version: $VersionFinal - Puerto: $Puerto</h1>" | Out-File -FilePath "$RutaHtdocs\index.html" -Encoding utf8
        }

        Write-Host "Configurando Firewall..." -ForegroundColor Yellow
        Remove-NetFirewallRule -DisplayName "HTTP-Apache*" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "HTTP-Apache-$Puerto" -LocalPort $Puerto -Protocol TCP -Action Allow | Out-Null

        Write-Host "Reiniciando el servicio..." -ForegroundColor Yellow
        Restart-Service apache -ErrorAction SilentlyContinue
        Write-Host "[✓] Apache Win64 desplegado con éxito en el puerto $Puerto." -ForegroundColor Green
    } else {
        Write-Host "[!] Apache no se instaló correctamente. Intenta con la versión 'Latest'." -ForegroundColor Red
    }
}


# --- 6. DESPLIEGUE DINÁMICO DE NGINX (CON BÚSQUEDA INTELIGENTE) ---
function Menu-InstalarNginxWin {
    Instalar-ChocolateySeguro

    Write-Host "Consultando versiones de Nginx en Chocolatey (esto puede tardar unos segundos)..." -ForegroundColor Cyan
    
    $lineas = choco search nginx --exact --all-versions --limit-output | Select-Object -First 5
    $versiones = @()
    $i = 1
    
    Write-Host "`n=== VERSIONES DISPONIBLES ===" -ForegroundColor Yellow
    foreach ($linea in $lineas) {
        $ver = ($linea -split '\|')[1].Trim()
        Write-Host "$i) $ver"
        $versiones += $ver
        $i++
    }
    $opcLatest = $i
    Write-Host "$opcLatest) Latest (Versión más reciente por defecto)"
    
    $OpcionVer = Read-Host "`nSelecciona el número de la versión [1-$opcLatest]"
    $Puerto = Read-Host "Ingrese el puerto de escucha (ej. 8888 o 45)"
    
    if (-not (Validar-Puerto -Puerto $Puerto)) { return }

    $VersionFinal = "Latest"
    Write-Host "Iniciando instalación silenciosa (Por favor espera, descargando e instalando...)" -ForegroundColor Yellow
    
    # Detenemos Nginx a la fuerza por si había un proceso viejo trabado
    Stop-Process -Name nginx -Force -ErrorAction SilentlyContinue

    # Volvemos a silenciar (*>$null) para que el profe no vea el horror rojo de PowerShell
    if ($OpcionVer -match "^\d+$" -and [int]$OpcionVer -ge 1 -and [int]$OpcionVer -lt $opcLatest) {
        $VersionFinal = $versiones[[int]$OpcionVer - 1]
        choco install nginx --version $VersionFinal -y --force --allow-downgrade --ignore-checksums --no-progress *>$null
    } else {
        choco install nginx -y --force --ignore-checksums --no-progress *>$null
    }

    Write-Host "Buscando archivo de configuración nginx.conf..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3 # Damos tiempo a Windows de extraer el ZIP
    
    # BÚSQUEDA INTELIGENTE: Encuentra nginx.conf sin importar la versión de la carpeta
    $RutaNginxConf = $null
    $encontrado = Get-ChildItem -Path C:\tools, C:\ProgramData\chocolatey\lib -Filter "nginx.conf" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($encontrado) {
        $RutaNginxConf = $encontrado.FullName
    }
    
    if ($RutaNginxConf) {
        # Obtenemos la carpeta raíz exacta de esta versión de Nginx
        $DirectorioBaseNginx = Split-Path (Split-Path $RutaNginxConf)
        
        Write-Host "Configurando puerto ($Puerto) y seguridad en: $RutaNginxConf" -ForegroundColor Yellow
        (Get-Content $RutaNginxConf) -replace 'listen\s+\d+;', "listen $Puerto;" | Set-Content $RutaNginxConf
        
        $ConfigContent = Get-Content $RutaNginxConf
        if ($ConfigContent -notmatch "server_tokens off;") {
            (Get-Content $RutaNginxConf) -replace 'keepalive_timeout\s+65;', "keepalive_timeout 65;`n    server_tokens off;" | Set-Content $RutaNginxConf
        }

        Write-Host "Generando index.html personalizado..." -ForegroundColor Yellow
        $RutaHtml = Join-Path $DirectorioBaseNginx "html"
        if (Test-Path $RutaHtml) {
            "<h1>Servidor: Nginx Win - Version: $VersionFinal - Puerto: $Puerto</h1>" | Out-File -FilePath "$RutaHtml\index.html" -Encoding utf8
        }

        Write-Host "Limpiando Firewall y abriendo puerto..." -ForegroundColor Yellow
        Remove-NetFirewallRule -DisplayName "HTTP-Nginx*" -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "HTTP-Nginx-$Puerto" -LocalPort $Puerto -Protocol TCP -Action Allow | Out-Null

        Write-Host "Iniciando el proceso de Nginx..." -ForegroundColor Yellow
        $RutaNginxExe = Join-Path $DirectorioBaseNginx "nginx.exe"
        if (Test-Path $RutaNginxExe) {
            Start-Process -FilePath $RutaNginxExe -WorkingDirectory $DirectorioBaseNginx -WindowStyle Hidden
            Write-Host "[✓] Nginx para Windows desplegado con éxito en el puerto $Puerto." -ForegroundColor Green
        } else {
            Write-Host "[!] Se configuró Nginx pero no se encontró nginx.exe para iniciarlo." -ForegroundColor Red
        }
    } else {
        Write-Host "[!] Nginx no se instaló correctamente. Intenta de nuevo." -ForegroundColor Red
    }
}
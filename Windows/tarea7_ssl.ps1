# ====================================================================
# TAREA 7: ORQUESTADOR DE INSTALACIÓN HÍBRIDA Y DESPLIEGUE SEGURO (SSL)
# ====================================================================

$global:resumenInstalaciones = @()

function Escribir-Resumen {
    param([string]$mensaje)
    $global:resumenInstalaciones += $mensaje
    Write-Host $mensaje -ForegroundColor Magenta
}

function Validar-Puerto {
    param ([string]$Puerto)
    if ([string]::IsNullOrWhiteSpace($Puerto) -or $Puerto -notmatch "^\d+$") {
        Write-Host "[X] Error: El puerto debe ser un número." -ForegroundColor Red
        return $false
    }
    $PuertoInt = [int]$Puerto
    if ($PuertoInt -le 0 -or $PuertoInt -gt 65535) {
        Write-Host "[X] Error: El puerto debe estar entre 1 y 65535." -ForegroundColor Red
        return $false
    }
    $ocupado = Get-NetTCPConnection -LocalPort $PuertoInt -State Listen -ErrorAction SilentlyContinue
    if ($ocupado) {
        Write-Host "[X] Error: El puerto $PuertoInt ya está en uso." -ForegroundColor Red
        return $false
    }
    return $true
}

function Liberar-Puertos-Web {
    Write-Host "Iniciando limpieza profunda del entorno..." -ForegroundColor Yellow
    taskkill /F /IM httpd.exe /T 2>$null
    taskkill /F /IM nginx.exe /T 2>$null

    Stop-Service -Name "W3SVC" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "WAS" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "apache" -Force -ErrorAction SilentlyContinue

    sc.exe delete "apache" | Out-Null

    Remove-Item -Path "C:\Apache24" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "C:\nginx" -Recurse -Force -ErrorAction SilentlyContinue

    Import-Module WebAdministration -ErrorAction SilentlyContinue
    Get-Website | ForEach-Object { 
        Stop-Website -Name $_.Name -ErrorAction SilentlyContinue
        Remove-Website -Name $_.Name -ErrorAction SilentlyContinue 
    }
    Write-Host "[OK] Entorno liberado." -ForegroundColor Green
}

function Administrar-FirmasRepositorio {
    Write-Host "--- GENERANDO FIRMAS SHA256 EN EL REPOSITORIO ---" -ForegroundColor Cyan
    $rutaRepo = "C:\FTP\LocalUser\repositorio\Windows"
    if (-not (Test-Path $rutaRepo)) { Write-Host "[X] Repositorio no encontrado en $rutaRepo" -ForegroundColor Red; return }

    $instaladores = Get-ChildItem -Path $rutaRepo -Recurse -Filter "*.zip"
    if ($instaladores.Count -eq 0) { Write-Host "[!] No hay archivos .zip en el repositorio." -ForegroundColor Yellow; return }

    foreach ($archivo in $instaladores) {
        $rutaCompleta = $archivo.FullName
        $rutaHash = "$rutaCompleta.sha256"
        $hashTexto = (Get-FileHash -Path $rutaCompleta -Algorithm SHA256).Hash.ToLower()
        $hashTexto | Out-File -FilePath $rutaHash -Encoding utf8 -Force
        Write-Host "[OK] Firma creada para $($archivo.Name)" -ForegroundColor Green
    }
}

function Navegar-Descargar-FTP {
    param([string]$Servicio)
    Write-Host "--- CONECTANDO AL REPOSITORIO PRIVADO FTP ---" -ForegroundColor Cyan
    
    $ftpUser = "repositorio"
    $ftpPassword = Read-Host "Ingresa la contraseña del usuario FTP '$ftpUser'" -AsSecureString
    $pwdPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPassword)
    $pwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($pwdPtr)

    $urlVersiones = "ftp://localhost:21/repositorio/Windows/${Servicio}/"
    $dirDescargas = "C:\descargas_ftp"
    if (-not (Test-Path $dirDescargas)) { New-Item -ItemType Directory -Force -Path $dirDescargas | Out-Null }

    Write-Host "Buscando instaladores de $Servicio..." -ForegroundColor Yellow
    $archivosRaw = curl.exe -s -l -k -u "${ftpUser}:${pwd}" $urlVersiones
    $archivos = $archivosRaw -split "`n" | Where-Object { $_.Trim() -match "\.zip$" }

    if ($archivos.Count -eq 0) { 
        Write-Host "[X] Error: No hay archivos .zip de $Servicio en el FTP." -ForegroundColor Red
        return $null 
    }

    for ($i = 0; $i -lt $archivos.Count; $i++) { Write-Host "$($i+1)) $($archivos[$i].Trim())" }
    $selVer = Read-Host "Selecciona el número de versión a descargar"
    $archivoElegido = $archivos[[int]$selVer - 1].Trim()

    $rutaInstalador = "$dirDescargas\$archivoElegido"
    $rutaHash = "$dirDescargas\$archivoElegido.sha256"

    Write-Host "Descargando $archivoElegido y su firma..." -ForegroundColor Cyan
    curl.exe -s --show-error -k -u "${ftpUser}:${pwd}" "${urlVersiones}${archivoElegido}" -o $rutaInstalador
    curl.exe -s --show-error -k -u "${ftpUser}:${pwd}" "${urlVersiones}${archivoElegido}.sha256" -o $rutaHash

    if ((Test-Path $rutaInstalador) -and (Test-Path $rutaHash)) {
        $hashCalculado = (Get-FileHash -Path $rutaInstalador -Algorithm SHA256).Hash.ToLower()
        $hashOriginal = ((Get-Content -Path $rutaHash -Raw) -split "\s+")[0].ToLower()

        if ($hashCalculado -eq $hashOriginal) {
            Write-Host "[OK] Integridad confirmada (SHA256 coincide)." -ForegroundColor Green
            return $rutaInstalador
        } else {
            Write-Host "[X] Error: El archivo descargado está corrupto." -ForegroundColor Red
            return $null
        }
    }
    return $null
}

function Generar-HTML-Monitor {
    param([string]$RutaArchivo, [string]$Servidor, [string]$Version, [string]$Puerto, [bool]$IsSSL)
    $protocolo = if ($IsSSL) { "HTTPS (Seguro)" } else { "HTTP (Inseguro)" }
    $bgColor = if ($IsSSL) { "#27ae60" } else { "#c0392b" } # Verde si es seguro, Rojo si no

    $htmlContent = @"
<html>
<body style='font-family: Arial; text-align: center; background-color: $bgColor; color: white; padding-top: 50px;'>
    <div style='background: rgba(0,0,0,0.5); display: inline-block; padding: 40px; border-radius: 20px; border: 3px solid white;'>
        <h1 style='margin: 0;'>SERVIDOR WEB: $Servidor</h1>
        <hr style='width: 80%; margin: 20px auto;'>
        <p style='font-size: 1.3em;'><b>Versión:</b> $Version</p>
        <p style='font-size: 1.3em;'><b>Protocolo:</b> $protocolo</p>
        <p style='font-size: 1.3em;'><b>Puerto Escucha:</b> $Puerto</p>
        <p style='font-size: 1.1em; color: #ecf0f1;'>Dominio: www.reprobados.com</p>
    </div>
</body>
</html>
"@
    Set-Content -Path $RutaArchivo -Value $htmlContent -Force
}

function Instalar-IIS-Web-Hibrido {
    Write-Host "`n--- INSTALANDO IIS WEB ---" -ForegroundColor Cyan
    Liberar-Puertos-Web
    
    $puertoHTTP = Read-Host "Ingresa el puerto HTTP libre (ej. 8080)"
    if (-not (Validar-Puerto -Puerto $puertoHTTP)) { return }

    $resSSL = Read-Host "¿Desea activar SSL en este servicio? [S/N]"
    $isSSL = ($resSSL -eq "S" -or $resSSL -eq "s")

    if ($isSSL) {
        $puertoHTTPS = Read-Host "Ingresa el puerto HTTPS libre para SSL (ej. 8443)"
        if (-not (Validar-Puerto -Puerto $puertoHTTPS)) { return }
    }

    Install-WindowsFeature -name Web-Server -IncludeManagementTools | Out-Null
    $siteName = "SitioIIS_Practica7"
    $sitePath = "C:\inetpub\wwwroot\$siteName"
    if (-not (Test-Path $sitePath)) { New-Item -ItemType Directory -Force -Path $sitePath | Out-Null }

    Import-Module WebAdministration
    $VersionIIS = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp").VersionString

    if ($isSSL) {
        Write-Host "Configurando URL Rewrite y SSL..." -ForegroundColor Yellow
        $cert = New-SelfSignedCertificate -DnsName "www.reprobados.com" -CertStoreLocation "cert:\LocalMachine\My"
        
        New-Website -Name $siteName -Port $puertoHTTP -PhysicalPath $sitePath -Force | Out-Null
        New-WebBinding -Name $siteName -Protocol "https" -Port $puertoHTTPS -IPAddress "*"
        
        Push-Location IIS:\SslBindings
        Get-Item "cert:\LocalMachine\My\$($cert.Thumbprint)" | New-Item -Path "*!$puertoHTTPS" -Force | Out-Null
        Pop-Location

        $webConfig = "$sitePath\web.config"
        $configContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <rewrite>
            <rules>
                <rule name="HTTP to HTTPS" stopProcessing="true">
                    <match url="(.*)" />
                    <conditions><add input="{HTTPS}" pattern="^OFF$" /></conditions>
                    <action type="Redirect" url="https://{HTTP_HOST}:$puertoHTTPS/{R:1}" redirectType="Permanent" />
                </rule>
            </rules>
        </rewrite>
    </system.webServer>
</configuration>
"@
        Set-Content -Path $webConfig -Value $configContent -Force
        Generar-HTML-Monitor -RutaArchivo "$sitePath\index.html" -Servidor "IIS" -Version $VersionIIS -Puerto $puertoHTTPS -IsSSL $true
        
        New-NetFirewallRule -DisplayName "IIS HTTPS $puertoHTTPS" -Direction Inbound -LocalPort $puertoHTTPS -Protocol TCP -Action Allow | Out-Null
        New-NetFirewallRule -DisplayName "IIS HTTP $puertoHTTP" -Direction Inbound -LocalPort $puertoHTTP -Protocol TCP -Action Allow | Out-Null
        Escribir-Resumen "[IIS WEB] Desplegado con SSL en puerto $puertoHTTPS (Redirección desde $puertoHTTP)."
    } else {
        New-Website -Name $siteName -Port $puertoHTTP -PhysicalPath $sitePath -Force | Out-Null
        Generar-HTML-Monitor -RutaArchivo "$sitePath\index.html" -Servidor "IIS" -Version $VersionIIS -Puerto $puertoHTTP -IsSSL $false
        New-NetFirewallRule -DisplayName "IIS HTTP $puertoHTTP" -Direction Inbound -LocalPort $puertoHTTP -Protocol TCP -Action Allow | Out-Null
        Escribir-Resumen "[IIS WEB] Desplegado (Solo HTTP) en puerto $puertoHTTP."
    }
    Start-Website -Name $siteName -ErrorAction SilentlyContinue
}

function Instalar-Apache-Hibrido {
    Write-Host "`n--- INSTALANDO APACHE ---" -ForegroundColor Cyan
    Liberar-Puertos-Web

    Write-Host "1) Descargar de la Web (Vía Chocolatey)"
    Write-Host "2) Descargar del FTP (Repositorio Privado)"
    $origen = Read-Host "Selecciona el origen [1-2]"

    if ($origen -eq "1") {
        Write-Host "Instalando Apache vía Web..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        if (-not (Get-Command "choco" -ErrorAction SilentlyContinue)) {
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) *>$null
        }
        choco install apache-httpd -y --force --params '"/NoService"' *>$null
        Move-Item -Path "C:\tools\apache24" -Destination "C:\Apache24" -Force -ErrorAction SilentlyContinue
    } else {
        $rutaZip = Navegar-Descargar-FTP -Servicio "Apache"
        if (-not $rutaZip) { return }
        Write-Host "Extrayendo Apache en C:\..." -ForegroundColor Yellow
        Expand-Archive -Path $rutaZip -DestinationPath "C:\" -Force
    }

    $apacheDir = "C:\Apache24"
    if (-not (Test-Path $apacheDir)) { Write-Host "[X] Error: Apache no se instaló correctamente." -ForegroundColor Red; return }

    $puertoHTTP = Read-Host "Ingresa el puerto HTTP libre (ej. 8081)"
    if (-not (Validar-Puerto -Puerto $puertoHTTP)) { return }

    $resSSL = Read-Host "¿Desea activar SSL en este servicio? [S/N]"
    $isSSL = ($resSSL -eq "S" -or $resSSL -eq "s")

    if ($isSSL) {
        $puertoHTTPS = Read-Host "Ingresa el puerto HTTPS libre para SSL (ej. 8444)"
        if (-not (Validar-Puerto -Puerto $puertoHTTPS)) { return }
    }

    $confPath = "$apacheDir\conf\httpd.conf"
    $conf = Get-Content $confPath | Where-Object { $_ -notmatch '^\s*Listen ' -and $_ -notmatch '^\s*ServerName ' } -join "`r`n"
    $conf = "Listen $puertoHTTP`r`nServerName localhost:$puertoHTTP`r`n" + $conf
    $conf = $conf -replace 'Define SRVROOT ".*"', 'Define SRVROOT "C:/Apache24"'

    if ($isSSL) {
        Write-Host "Generando PKI con OpenSSL para Apache..." -ForegroundColor Yellow
        $env:OPENSSL_CONF = "$apacheDir\conf\openssl.cnf"
        Set-Location "$apacheDir\bin"
        .\openssl.exe req -x509 -nodes -newkey rsa:2048 -keyout "$apacheDir\conf\server.key" -out "$apacheDir\conf\server.crt" -days 365 -subj "/CN=www.reprobados.com" 2>$null
        Set-Location "C:\"

        $conf = $conf -replace '(?m)^#?\s*LoadModule ssl_module.*$', 'LoadModule ssl_module modules/mod_ssl.so'
        $conf = $conf -replace '(?m)^#?\s*LoadModule rewrite_module.*$', 'LoadModule rewrite_module modules/mod_rewrite.so'
        
        $conf += "`r`nInclude conf/extra/httpd-ssl.conf"
        $conf += "`r`n<VirtualHost *:$puertoHTTP>`r`n    ServerName www.reprobados.com`r`n    RewriteEngine On`r`n    RewriteCond %{HTTPS} off`r`n    RewriteRule ^(.*)$ https://%{HTTP_HOST}:$puertoHTTPS%{REQUEST_URI} [L,R=301]`r`n</VirtualHost>"

        $sslConfContent = @"
Listen $puertoHTTPS
SSLCipherSuite HIGH:MEDIUM:!MD5:!RC4:!3DES
SSLProxyCipherSuite HIGH:MEDIUM:!MD5:!RC4:!3DES
SSLHonorCipherOrder on
SSLProtocol all -SSLv3
SSLProxyProtocol all -SSLv3
SSLPassPhraseDialog  builtin
SSLSessionCache "shmcb:c:/Apache24/logs/ssl_scache(512000)"
SSLSessionCacheTimeout  300

<VirtualHost _default_:$puertoHTTPS>
    DocumentRoot "c:/Apache24/htdocs"
    ServerName www.reprobados.com:$puertoHTTPS
    SSLEngine on
    SSLCertificateFile "c:/Apache24/conf/server.crt"
    SSLCertificateKeyFile "c:/Apache24/conf/server.key"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</VirtualHost>
"@
        Set-Content -Path "$apacheDir\conf\extra\httpd-ssl.conf" -Value $sslConfContent -Force
        Generar-HTML-Monitor -RutaArchivo "$apacheDir\htdocs\index.html" -Servidor "Apache" -Version "2.4" -Puerto $puertoHTTPS -IsSSL $true
        
        New-NetFirewallRule -DisplayName "Apache HTTPS $puertoHTTPS" -Direction Inbound -LocalPort $puertoHTTPS -Protocol TCP -Action Allow | Out-Null
        Escribir-Resumen "[APACHE] Desplegado con SSL en puerto $puertoHTTPS (Redirección desde $puertoHTTP)."
    } else {
        $conf = $conf -replace '(?m)^\s*LoadModule ssl_module.*$', '#LoadModule ssl_module modules/mod_ssl.so'
        Generar-HTML-Monitor -RutaArchivo "$apacheDir\htdocs\index.html" -Servidor "Apache" -Version "2.4" -Puerto $puertoHTTP -IsSSL $false
        Escribir-Resumen "[APACHE] Desplegado (Solo HTTP) en puerto $puertoHTTP."
    }

    $conf | Set-Content $confPath
    New-NetFirewallRule -DisplayName "Apache HTTP $puertoHTTP" -Direction Inbound -LocalPort $puertoHTTP -Protocol TCP -Action Allow | Out-Null
    
    Start-Process -FilePath "$apacheDir\bin\httpd.exe" -WindowStyle Hidden
    Write-Host "[OK] Apache iniciado en segundo plano." -ForegroundColor Green
}

function Instalar-Nginx-Hibrido {
    Write-Host "`n--- INSTALANDO NGINX ---" -ForegroundColor Cyan
    Liberar-Puertos-Web

    Write-Host "1) Descargar de la Web (Vía Chocolatey)"
    Write-Host "2) Descargar del FTP (Repositorio Privado)"
    $origen = Read-Host "Selecciona el origen [1-2]"

    if ($origen -eq "1") {
        Write-Host "Instalando Nginx vía Web..." -ForegroundColor Yellow
        choco install nginx -y --force *>$null
        $tempDir = (Get-ChildItem -Path "C:\tools", "C:\" -Filter "nginx-*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
        if ($tempDir) { Move-Item -Path $tempDir -Destination "C:\nginx" -Force }
    } else {
        $rutaZip = Navegar-Descargar-FTP -Servicio "Nginx"
        if (-not $rutaZip) { return }
        Write-Host "Extrayendo Nginx en C:\..." -ForegroundColor Yellow
        Expand-Archive -Path $rutaZip -DestinationPath "C:\" -Force
        $tempDir = (Get-ChildItem -Path "C:\" -Filter "nginx-*" -Directory | Select-Object -First 1).FullName
        if ($tempDir) { Move-Item -Path $tempDir -Destination "C:\nginx" -Force }
    }

    $nginxDir = "C:\nginx"
    if (-not (Test-Path $nginxDir)) { Write-Host "[X] Error: Nginx no se instaló." -ForegroundColor Red; return }

    $puertoHTTP = Read-Host "Ingresa el puerto HTTP libre (ej. 8082)"
    if (-not (Validar-Puerto -Puerto $puertoHTTP)) { return }

    $resSSL = Read-Host "¿Desea activar SSL en este servicio? [S/N]"
    $isSSL = ($resSSL -eq "S" -or $resSSL -eq "s")

    if ($isSSL) {
        $puertoHTTPS = Read-Host "Ingresa el puerto HTTPS libre para SSL (ej. 8445)"
        if (-not (Validar-Puerto -Puerto $puertoHTTPS)) { return }
    }

    if (-not (Test-Path "$nginxDir\html")) { New-Item -ItemType Directory -Path "$nginxDir\html" -Force | Out-Null }
    if (-not (Test-Path "$nginxDir\conf")) { New-Item -ItemType Directory -Path "$nginxDir\conf" -Force | Out-Null }

    if ($isSSL) {
        Write-Host "Generando PKI para Nginx..." -ForegroundColor Yellow
        $chocoExe = "C:\ProgramData\chocolatey\bin\choco.exe"
        & $chocoExe install openssl -y *>$null
        
        $env:OPENSSL_CONF = "C:\Program Files\OpenSSL-Win64\bin\openssl.cfg"
        & "C:\Program Files\OpenSSL-Win64\bin\openssl.exe" req -x509 -nodes -newkey rsa:2048 -keyout "$nginxDir\conf\server.key" -out "$nginxDir\conf\server.crt" -days 365 -subj "/CN=www.reprobados.com" 2>$null

        $nginxConf = @"
worker_processes  1;
events { worker_connections  1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       $puertoHTTP;
        server_name  www.reprobados.com;
        return 301 https://`$host:$puertoHTTPS`$request_uri;
    }

    server {
        listen       $puertoHTTPS ssl;
        server_name  www.reprobados.com;

        ssl_certificate      server.crt;
        ssl_certificate_key  server.key;

        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
"@
        Set-Content -Path "$nginxDir\conf\nginx.conf" -Value $nginxConf -Force
        Generar-HTML-Monitor -RutaArchivo "$nginxDir\html\index.html" -Servidor "Nginx" -Version "Latest" -Puerto $puertoHTTPS -IsSSL $true
        
        New-NetFirewallRule -DisplayName "Nginx HTTPS $puertoHTTPS" -Direction Inbound -LocalPort $puertoHTTPS -Protocol TCP -Action Allow | Out-Null
        Escribir-Resumen "[NGINX] Desplegado con SSL en puerto $puertoHTTPS (Redirección desde $puertoHTTP)."
    } else {
        $nginxConf = @"
worker_processes  1;
events { worker_connections  1024; }
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;
    server {
        listen       $puertoHTTP;
        server_name  localhost;
        location / {
            root   html;
            index  index.html index.htm;
        }
    }
}
"@
        Set-Content -Path "$nginxDir\conf\nginx.conf" -Value $nginxConf -Force
        Generar-HTML-Monitor -RutaArchivo "$nginxDir\html\index.html" -Servidor "Nginx" -Version "Latest" -Puerto $puertoHTTP -IsSSL $false
        Escribir-Resumen "[NGINX] Desplegado (Solo HTTP) en puerto $puertoHTTP."
    }

    New-NetFirewallRule -DisplayName "Nginx HTTP $puertoHTTP" -Direction Inbound -LocalPort $puertoHTTP -Protocol TCP -Action Allow | Out-Null
    Start-Process -FilePath "$nginxDir\nginx.exe" -WorkingDirectory $nginxDir -WindowStyle Hidden
    Write-Host "[OK] Nginx iniciado en segundo plano." -ForegroundColor Green
}

function Instalar-IIS-FTP-Hibrido {
    Write-Host "`n--- INSTALANDO IIS FTP ---" -ForegroundColor Cyan
    Install-WindowsFeature Web-FTP-Server -IncludeManagementTools | Out-Null
    
    $ftpUser = Read-Host "Ingresa el nombre del usuario FTP a utilizar (Ej. 'repositorio')"
    $ftpPath = "C:\FTP\LocalUser\$ftpUser"
    if (-not (Test-Path $ftpPath)) { Write-Host "[X] La ruta $ftpPath no existe." -ForegroundColor Red; return }

    $puertoFTP = Read-Host "Ingresa el puerto para el FTP (Libre o 21)"
    if (-not (Validar-Puerto -Puerto $puertoFTP)) { return }

    $resSSL = Read-Host "¿Desea activar SSL (FTPS) en este servicio? [S/N]"
    $isSSL = ($resSSL -eq "S" -or $resSSL -eq "s")

    Import-Module WebAdministration
    if (Get-WebSite -Name "FTP_Practica7" -ErrorAction SilentlyContinue) { Remove-WebSite -Name "FTP_Practica7" }

    New-WebFtpSite -Name "FTP_Practica7" -Port $puertoFTP -PhysicalPath $ftpPath -Force | Out-Null
    Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.userIsolation.mode -Value 0
    Remove-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Location "FTP_Practica7" -ErrorAction SilentlyContinue

    if ($isSSL) {
        Write-Host "Generando PKI FTP para FTPS..." -ForegroundColor Yellow
        $cert = New-SelfSignedCertificate -DnsName "www.reprobados.com" -CertStoreLocation "cert:\LocalMachine\My"
        
        Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.security.ssl.serverCertHash -Value $cert.Thumbprint
        Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.security.ssl.controlChannelPolicy -Value 1
        Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.security.ssl.dataChannelPolicy -Value 1
        Escribir-Resumen "[IIS FTP] Desplegado con FTPS (Túnel SSL) en puerto $puertoFTP."
    } else {
        Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
        Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
        Escribir-Resumen "[IIS FTP] Desplegado (Sin SSL) en puerto $puertoFTP."
    }
    
    New-NetFirewallRule -DisplayName "IIS FTP $puertoFTP" -Direction Inbound -LocalPort $puertoFTP -Protocol TCP -Action Allow | Out-Null
    Set-ItemProperty "IIS:\Sites\FTP_Practica7" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users=$ftpUser;permissions="Read,Write"} -PSPath IIS:\ -Location "FTP_Practica7"
    Restart-WebItem "IIS:\Sites\FTP_Practica7"
    
    Write-Host "[OK] IIS FTP configurado." -ForegroundColor Green
}


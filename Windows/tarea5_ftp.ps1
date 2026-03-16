# ====================================================================
# SCRIPT MAESTRO FTP - WINDOWS SERVER (IIS) - FUNCIONES
# ====================================================================

# --------------------------------------------------------------------
# FUNCIONES DE INSTALACIÓN Y VERIFICACIÓN
# --------------------------------------------------------------------

function Configuracion-InicialFTP {
    Write-Host "`n==================================================" -ForegroundColor Cyan
    Write-Host " INICIANDO CONFIGURACIÓN DEL SERVIDOR FTP (IIS)" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan

    Write-Host "[*] 1. Instalando IIS y Servicio FTP (Modo silencioso)..."
    Install-WindowsFeature Web-Server, Web-FTP-Server -IncludeManagementTools | Out-Null

    Write-Host "[*] 2. Creando estructura de directorios y Grupos Base..."
    $rutas = @("C:\FTP", "C:\FTP\grupos\recursadores", "C:\FTP\grupos\reprobados", "C:\FTP\LocalUser\Public\general")
    foreach ($ruta in $rutas) { if (-not (Test-Path $ruta)) { New-Item -Path $ruta -ItemType Directory -Force | Out-Null } }

    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $grupos = @("reprobados", "recursadores")
    
    # SIDs Universales (A prueba de idiomas)
    $sidAdmin = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544") # Administradores
    $sidUsers = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-545") # Usuarios
    $sidIUSR  = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-17")     # IUSR (Anónimo)

    foreach ($g in $grupos) {
        if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq 'Group' -and $_.Name -eq $g })) {
            $nuevoGrupo = $ADSI.Create("Group", $g); $nuevoGrupo.SetInfo()
        }
        
        # Parche NTFS para grupos usando el SID de Administradores
        $rutaGrupo = "C:\FTP\grupos\$g"
        $acl = Get-Acl $rutaGrupo
        $acl.SetAccessRuleProtection($true, $false)
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidAdmin, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")))
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($g, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")))
        Set-Acl $rutaGrupo $acl
    }

    # Parche NTFS para Anónimos (IUSR) usando SIDs - ESTO EVITA EL ERROR 550
    $AclGeneral = Get-Acl "C:\FTP\LocalUser\Public\general"
    $AclGeneral.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidUsers, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")))
    $AclGeneral.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sidIUSR, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")))
    Set-Acl "C:\FTP\LocalUser\Public\general" $AclGeneral

    Write-Host "[*] 3. Configurando Firewall..."
    if (-not (Get-NetFirewallRule -DisplayName "FTP_Practica" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -DisplayName "FTP_Practica" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow | Out-Null
    }

    Write-Host "[*] 4. Configurando Sitio FTP y Aislamiento en IIS..."
    Import-Module WebAdministration
    if (-not (Get-WebSite -Name "FTP" -ErrorAction SilentlyContinue)) {
        New-WebFtpSite -Name "FTP" -Port 21 -PhysicalPath "C:\FTP" -Force | Out-Null
    }
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/siteDefaults/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"

    Write-Host "[*] 5. Aplicando Reglas de IIS (Doble Cerradura)..."
    Remove-WebConfigurationProperty -Filter "/system.ftpServer/security/authorization" -Name "." -Location "FTP" -ErrorAction SilentlyContinue
    Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{ accessType = "Allow"; users = "IUSR"; permissions = 1 } -Location "FTP"
    Add-WebConfiguration "/system.ftpServer/security/authorization" -PSPath "IIS:\" -Value @{ accessType = "Allow"; roles = "reprobados,recursadores"; permissions = 3 } -Location "FTP"

    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.anonymousAuthentication.enabled -Value $true
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name ftpServer.Security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.controlChannelPolicy" -Value 0
    Set-ItemProperty -Path "IIS:\Sites\FTP" -Name "ftpServer.security.ssl.dataChannelPolicy" -Value 0

    Restart-WebItem "IIS:\Sites\FTP"
    Write-Host "[+] Servidor FTP configurado y asegurado exitosamente." -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Verificar-InstalacionFTP {
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "   VERIFICACIÓN DE ESTADO FTP (IIS)      " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    # Verificar Rol
    $ftpFeature = Get-WindowsFeature Web-FTP-Server
    if ($ftpFeature.Installed) { Write-Host "[OK] El rol FTP Server está instalado." -ForegroundColor Green }
    else { Write-Host "[!] El rol FTP Server NO está instalado." -ForegroundColor Red }

    # Verificar Servicio
    $ftpService = Get-Service ftpsvc -ErrorAction SilentlyContinue
    if ($ftpService -and $ftpService.Status -eq 'Running') { Write-Host "[OK] El servicio ftpsvc está ACTIVO y ejecutándose." -ForegroundColor Green }
    else { Write-Host "[!] El servicio ftpsvc NO está activo." -ForegroundColor Red }

    # Verificar Puerto
    $puerto = Get-NetTCPConnection -LocalPort 21 -ErrorAction SilentlyContinue
    if ($puerto) { Write-Host "[OK] El puerto 21 (FTP) está abierto y a la escucha." -ForegroundColor Green }
    else { Write-Host "[!] El puerto 21 NO está a la escucha." -ForegroundColor Red }

    # Verificar Carpetas
    if (Test-Path "C:\FTP\LocalUser\Public\general") { Write-Host "[OK] La estructura física de directorios existe." -ForegroundColor Green }
    else { Write-Host "[!] La estructura de directorios NO existe." -ForegroundColor Red }

    Write-Host "=========================================" -ForegroundColor Cyan
}

# --------------------------------------------------------------------
# FUNCIONES DE GESTIÓN DE USUARIOS
# --------------------------------------------------------------------

function Validar-Contrasena {
    param ([string]$contra)
    if ($contra.Length -lt 8 -or $contra.Length -gt 15) { Write-Host "[-] La contraseña debe tener entre 8 y 15 caracteres." -ForegroundColor Red; return $false }
    if ($contra -notmatch "[A-Z]") { Write-Host "[-] Debe contener al menos una letra MAYÚSCULA." -ForegroundColor Red; return $false }
    if ($contra -notmatch "[a-z]") { Write-Host "[-] Debe contener al menos una letra MINÚSCULA." -ForegroundColor Red; return $false }
    if ($contra -notmatch "\d") { Write-Host "[-] Debe contener al menos un NÚMERO." -ForegroundColor Red; return $false }
    if ($contra -notmatch "[^a-zA-Z0-9]") { Write-Host "[-] Debe contener al menos un CARÁCTER ESPECIAL (Ej. @, #, *)." -ForegroundColor Red; return $false }
    return $true
}

function Capturar-Contrasena {
    $esValida = $false
    do {
        $contra = Read-Host "Ingrese la contraseña (min. 8, max 15, Mayús, Minús, Núm, Especial)"
        $esValida = Validar-Contrasena -contra $contra
    } while (-not $esValida)
    return $contra
}

function Usuario-Existe {
    param ([string]$nombreUsuario)
    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $usuario = $ADSI.Children | Where-Object { $_.SchemaClassName -eq 'User' -and $_.Name -eq $nombreUsuario }
    if ($usuario) { return $true } else { return $false }
}

function Capturar-Usuario {
    $caracteresPermitidos = '^[a-zA-Z0-9]+$'
    do {
        $cadena = Read-Host "Coloque el nombre del usuario"
        if (-not $cadena) { Write-Host "[-] El nombre no puede estar vacío." -ForegroundColor Red }
        elseif ($cadena -notmatch $caracteresPermitidos) { Write-Host "[-] Solo se permiten letras y números." -ForegroundColor Red }
        elseif ($cadena -match '^[0-9]') { Write-Host "[-] No puede comenzar con un número." -ForegroundColor Red }
        elseif ($cadena.Length -gt 15) { Write-Host "[-] Máximo 15 caracteres." -ForegroundColor Red }
        elseif (Usuario-Existe -nombreUsuario $cadena) { Write-Host "[-] El usuario '$cadena' YA EXISTE." -ForegroundColor Red }
        else { return $cadena }
    } while ($true)
}

function Capturar-Grupo {
    do {
        $op = Read-Host "Ingrese el grupo (1: Reprobados, 2: Recursadores)"
        if ($op -eq "1") { return "reprobados" }
        elseif ($op -eq "2") { return "recursadores" }
        else { Write-Host "[-] Opción no válida." -ForegroundColor Red }
    } while ($true)
}

function Crear-UsuarioFTP {
    param ([string]$User, [string]$Pass, [string]$Group)

    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $NewUser = $ADSI.Create("User", $User); $NewUser.SetPassword($Pass); $NewUser.SetInfo()    
    $GroupADSI = [ADSI]"WinNT://$env:ComputerName/$Group,group"
    $GroupADSI.Invoke("Add", "WinNT://$env:ComputerName/$User,user")

    $UserPath = "C:\FTP\LocalUser\$User"
    New-Item -Path "$UserPath\$User" -ItemType Directory -Force | Out-Null

    $Acl = Get-Acl "$UserPath\$User"
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($User, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $Acl.SetAccessRule($AccessRule)
    Set-Acl "$UserPath\$User" $Acl

    cmd /c mklink /D "$UserPath\general" "C:\FTP\LocalUser\Public\general" | Out-Null
    cmd /c mklink /D "$UserPath\$Group" "C:\FTP\grupos\$Group" | Out-Null
    Write-Host "[+] Usuario $User creado correctamente en $Group." -ForegroundColor Green
}

function Cambiar-GrupoFTP {
    $User = Read-Host "Ingrese el nombre del usuario a modificar"
    if (-not (Usuario-Existe -nombreUsuario $User)) { Write-Host "[-] El usuario no existe." -ForegroundColor Red; return }

    $userADSI = [ADSI]"WinNT://$env:ComputerName/$User,user"
    $gruposActuales = $userADSI.Groups() | ForEach-Object { $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null) }
    
    $viejoGrupo = ""
    if ($gruposActuales -contains "reprobados") { $viejoGrupo = "reprobados" }
    elseif ($gruposActuales -contains "recursadores") { $viejoGrupo = "recursadores" }

    Write-Host "[*] El usuario pertenece actualmente a: $viejoGrupo" -ForegroundColor Cyan
    $nuevoGrupo = Capturar-Grupo

    if ($viejoGrupo -eq $nuevoGrupo) { Write-Host "[-] El usuario ya pertenece a ese grupo." -ForegroundColor Yellow; return }

    if ($viejoGrupo) {
        $oldGroupADSI = [ADSI]"WinNT://$env:ComputerName/$viejoGrupo,group"
        $oldGroupADSI.Invoke("Remove", "WinNT://$env:ComputerName/$User,user")
    }
    $newGroupADSI = [ADSI]"WinNT://$env:ComputerName/$nuevoGrupo,group"
    $newGroupADSI.Invoke("Add", "WinNT://$env:ComputerName/$User,user")

    $UserPath = "C:\FTP\LocalUser\$User"
    if ($viejoGrupo) { cmd /c "rmdir /S /Q `"$UserPath\$viejoGrupo`"" 2>$null }
    cmd /c mklink /D "$UserPath\$nuevoGrupo" "C:\FTP\grupos\$nuevoGrupo" | Out-Null

    Write-Host "[+] Cambio completado. $User movido a $nuevoGrupo." -ForegroundColor Green
}

function Eliminar-UsuarioFTP {
    $User = Read-Host "Ingrese el nombre del usuario a eliminar"
    if (-not (Usuario-Existe -nombreUsuario $User)) { Write-Host "[-] El usuario no existe." -ForegroundColor Red; return }

    $ADSI = [ADSI]"WinNT://$env:ComputerName"
    $ADSI.Delete("User", $User)

    $UserPath = "C:\FTP\LocalUser\$User"
    if (Test-Path $UserPath) { cmd /c "rmdir /S /Q `"$UserPath`"" 2>$null }

    Write-Host "[+] Usuario $User y sus carpetas eliminados." -ForegroundColor Green
}
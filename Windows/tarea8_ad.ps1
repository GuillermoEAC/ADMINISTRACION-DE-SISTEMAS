# ========================================================================
# MODULO TAREA 8: Gobernanza, Cuotas y Control de Aplicaciones
# ========================================================================

Function Crear-HorarioBytes {
    param([int]$Inicio, [int]$Fin)
    $horas = New-Object byte[] 21
    for ($dia = 0; $dia -lt 7; $dia++) {
        for ($hora = 0; $hora -lt 24; $hora++) {
            $permitido = $false
            if ($Inicio -lt $Fin) {
                if ($hora -ge $Inicio -and $hora -lt $Fin) { $permitido = $true }
            } else {
                if ($hora -ge $Inicio -or $hora -lt $Fin) { $permitido = $true }
            }
            if ($permitido) {
                $byteIndex = [math]::Floor(($dia * 24 + $hora) / 8)
                $bitIndex = ($dia * 24 + $hora) % 8
                $horas[$byteIndex] = $horas[$byteIndex] -bor (1 -shl $bitIndex)
            }
        }
    }
    return $horas
}

Function Crear-UsuariosGobernanza {
    Write-Host "Limpiando y creando UOs e Importando usuarios..." -ForegroundColor Cyan
    
    # 1. Crear UOs SOLO si no existen
    $ouCuates = Get-ADOrganizationalUnit -Filter "Name -eq 'Cuates'" -ErrorAction SilentlyContinue
    if (-not $ouCuates) { New-ADOrganizationalUnit -Name "Cuates" -Path "DC=reprobados,DC=com" }
    
    $ouNoCuates = Get-ADOrganizationalUnit -Filter "Name -eq 'No Cuates'" -ErrorAction SilentlyContinue
    if (-not $ouNoCuates) { New-ADOrganizationalUnit -Name "No Cuates" -Path "DC=reprobados,DC=com" }

    # 2. Calcular los bytes de los horarios
    $bytesCuates = Crear-HorarioBytes -Inicio 8 -Fin 15
    $bytesNoCuates = Crear-HorarioBytes -Inicio 15 -Fin 2

    $rutaCSV = "$env:USERPROFILE\Desktop\usuarios.csv"
    if (-not (Test-Path $rutaCSV)) {
        Write-Host "[!] No se encontró el archivo usuarios.csv en el Escritorio." -ForegroundColor Red
        return
    }

    $usuarios = Import-Csv $rutaCSV
    foreach ($u in $usuarios) {
        $nombreUsuario = $u.Nombre 
        
        if ($u.Departamento -eq "Cuates") { $rutaUO = "OU=Cuates,DC=reprobados,DC=com"; $hor = $bytesCuates } 
        else { $rutaUO = "OU=No Cuates,DC=reprobados,DC=com"; $hor = $bytesNoCuates }
        
        # 3. Si existe, lo fulminamos
        $existe = Get-ADUser -Identity $nombreUsuario -ErrorAction SilentlyContinue
        if ($existe) { Remove-ADUser -Identity $nombreUsuario -Confirm:$false }
        
        # 4. Creamos al usuario desde cero, totalmente limpio
        New-ADUser -Name $nombreUsuario -SamAccountName $nombreUsuario -UserPrincipalName "$nombreUsuario@reprobados.com" -Path $rutaUO -AccountPassword (ConvertTo-SecureString $u.Password -AsPlainText -Force) -Enabled $true
        
        # 5. Le aplicamos el horario directamente (sin limpiar, porque acaba de nacer)
        Set-ADUser -Identity $nombreUsuario -Replace @{logonhours=[byte[]]$hor} -ErrorAction SilentlyContinue
        
        Write-Host "Usuario $nombreUsuario creado limpio y horario aplicado." -ForegroundColor Green
    }
}

Function Configurar-FSRM {
    Write-Host "Configurando FSRM (Cuotas y Filtros)..." -ForegroundColor Cyan
    Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools | Out-Null
    
    New-Item -Path "C:\Perfiles\Cuates" -ItemType Directory -Force | Out-Null
    New-Item -Path "C:\Perfiles\NoCuates" -ItemType Directory -Force | Out-Null
    
    New-FsrmQuota -Path "C:\Perfiles\Cuates" -Size 10MB -Description "Cuota Cuates" -ErrorAction SilentlyContinue
    New-FsrmQuota -Path "C:\Perfiles\NoCuates" -Size 5MB -Description "Cuota No Cuates" -ErrorAction SilentlyContinue
    
    New-FsrmFileGroup -Name "Bloqueo Multimedia y Juegos" -IncludePattern @("*.mp3", "*.mp4", "*.exe", "*.msi") -ErrorAction SilentlyContinue
    New-FsrmFileScreen -Path "C:\Perfiles\Cuates" -IncludeGroup "Bloqueo Multimedia y Juegos" -Active:$true -ErrorAction SilentlyContinue
    New-FsrmFileScreen -Path "C:\Perfiles\NoCuates" -IncludeGroup "Bloqueo Multimedia y Juegos" -Active:$true -ErrorAction SilentlyContinue
    Write-Host "Cuotas (10MB/5MB) y filtros aplicados." -ForegroundColor Green
}

Function Configurar-AppLockerGPO {
    Write-Host "Configurando AppLocker (Regla Hash) y GPO de Cierre..." -ForegroundColor Cyan
    
    # 1. Crear el Grupo de Seguridad (AppLocker necesita Grupos, no carpetas UO)
    Write-Host "Creando Grupo de Seguridad para AppLocker..." -ForegroundColor Yellow
    $grupo = Get-ADGroup -Filter "Name -eq 'GrupoNoCuates'" -ErrorAction SilentlyContinue
    if (-not $grupo) {
        New-ADGroup -Name "GrupoNoCuates" -GroupCategory Security -GroupScope Global -Path "OU=No Cuates,DC=reprobados,DC=com"
    }
    
    # 2. Meter a los usuarios de la UO al Grupo de Seguridad
    Get-ADUser -SearchBase "OU=No Cuates,DC=reprobados,DC=com" -Filter * | ForEach-Object {
        Add-ADGroupMember -Identity "GrupoNoCuates" -Members $_.SamAccountName -ErrorAction SilentlyContinue
    }

    # 3. Activar el servicio de AppLocker desde el Registro (Evita el error de Acceso Denegado)
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\AppIDSvc" -Name "Start" -Value 2 -ErrorAction SilentlyContinue
    Start-Service -Name AppIDSvc -ErrorAction SilentlyContinue

    # 4. Usar los comandos de la rúbrica para bloquear el Bloc de Notas
    Write-Host "Generando regla Hash para el Bloc de Notas..." -ForegroundColor Yellow
    $polNotepad = Get-AppLockerFileInformation -Path "C:\Windows\System32\notepad.exe" | New-AppLockerPolicy -RuleType Hash -User "REPROBADOS\GrupoNoCuates" -ErrorAction SilentlyContinue
    
    # Inyectamos la orden de "Deny" (Bloquear)
    if ($polNotepad) {
        foreach ($coleccion in $polNotepad.RuleCollections) {
            foreach ($regla in $coleccion) {
                $regla.Action = 'Deny'
            }
        }
        Set-AppLockerPolicy -PolicyObject $polNotepad -Merge -ErrorAction SilentlyContinue
    }

    # 5. GPO de Cierre Forzado
    Write-Host "Aplicando GPO de cierre de sesión..." -ForegroundColor Yellow
    Install-WindowsFeature GPMC -ErrorAction SilentlyContinue | Out-Null
    Import-Module GroupPolicy
    New-GPO -Name "Politicas_FIM_CierreForzado" -ErrorAction SilentlyContinue | New-GPLink -Target "DC=reprobados,DC=com" -ErrorAction SilentlyContinue | Out-Null
    Set-GPRegistryValue -Name "Politicas_FIM_CierreForzado" -Key "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" -ValueName "enableforcedlogoff" -Type DWord -Value 1 -ErrorAction SilentlyContinue | Out-Null
    
    Write-Host "¡Opción 3 completada con éxito!" -ForegroundColor Green
}

Function Ejecutar-Tarea8Completa {
    Crear-UsuariosGobernanza
    Configurar-FSRM
    Configurar-AppLockerGPO
    Write-Host "¡Toda la Práctica 08 fue desplegada con éxito!" -ForegroundColor DarkGreen
}
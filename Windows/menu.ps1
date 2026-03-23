# ==========================================
# 1. CARGAR ARCHIVOS DE FUNCIONES (MODULAR)
# ==========================================
. .\tarea1_diag.ps1
. .\tarea2_dhcp.ps1
. .\tarea3_dns.ps1
. .\tarea4_ssh.ps1
. .\tarea5_ftp.ps1
. .\tarea6_http.ps1
. .\tarea7_ssl.ps1
. .\tarea8_ad.ps1

# ==========================================
# 2. VERIFICACIÓN DE PERMISOS DE ADMINISTRADOR
# ==========================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] Por favor, ejecuta PowerShell como Administrador." -ForegroundColor Red
    Start-Sleep -Seconds 3
    exit
}

# ==========================================
# 3. SUBMENÚS ORQUESTADORES
# ==========================================

function Invoke-SubmenuTarea1 {
    do {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "      TAREA 1: DIAGNÓSTICO Y RED         " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "1. Ejecutar Diagnóstico de Sistema"
        Write-Host "2. Configurar Red Interna (IP Fija y Ping)"
        Write-Host "3. Volver al Menú Principal"
        Write-Host "-----------------------------------------" -ForegroundColor Cyan
        
        $Op = Read-Host "Seleccione una opción"
        
        switch ($Op) {
            "1" { Ejecutar-Diagnostico }
            "2" { Configurar-RedInterna }
            "3" { return }
            Default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep 1 }
        }
        
        if ($Op -ne "3") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}

function Invoke-SubmenuDHCP {
    do {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "            TAREA 2: MENÚ DHCP           " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "1. Instalacion DHCP"
        Write-Host "2. Verificar instalacion"
        Write-Host "3. Configuracion de DHCP"
        Write-Host "4. Monitorear"
        Write-Host "5. Volver al Menú Principal"
        Write-Host "-----------------------------------------" -ForegroundColor Cyan
        
        $Op = Read-Host "Seleccione una opción"
        
        switch ($Op) {
            "1" { Instalacion-DHCP }
            "2" { Verificar-Instalacion-DHCP }
            "3" { Configuracion-DHCP }
            "4" { Monitorear-DHCP }
            "5" { return }
            Default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep 1 }
        }
        
        if ($Op -ne "5") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}

function Invoke-SubmenuDNS {
    do {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "             TAREA 3: MENÚ DNS           " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "1. Instalación DNS"
        Write-Host "2. Verificar instalación DNS" 
        Write-Host "3. Agregar Dominio"
        Write-Host "4. Listar Dominios"
        Write-Host "5. Eliminar Dominio"
        Write-Host "6. Desinstalar DNS"
        Write-Host "7. Volver al Menú Principal"
        Write-Host "-----------------------------------------" -ForegroundColor Cyan
        
        $Op = Read-Host "Seleccione una opción"
        
        switch ($Op) {
            "1" { Instalacion-DNS }
            "2" { Verificar-Instalacion-DNS } 
            "3" { Agregar-Dominio }
            "4" { Listar-Dominios }
            "5" { Eliminar-Dominio }
            "6" { Desinstalar-DNS }
            "7" { return }
            Default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep 1 }
        }
        
        if ($Op -ne "7") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}

function Invoke-SubmenuSSH {
    do {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "             TAREA 4: MENÚ SSH           " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host "1. Configurar Red para SSH"
        Write-Host "2. Instalar y Configurar OpenSSH"
        Write-Host "3. Verificar Estado y Guía de Conexión"
        Write-Host "4. Volver al Menú Principal"
        Write-Host "-----------------------------------------" -ForegroundColor Cyan
        
        $opcion = Read-Host "Seleccione una opción [1-4]"

        switch ($opcion) {
            "1" { Configurar-RedSSH }
            "2" { Install-OpenSSH } 
            "3" { Verificar-SSH }
            "4" { return }
            Default { Write-Host "[!] Opción no válida." -ForegroundColor Red; Start-Sleep 1 }
        }

        if ($opcion -ne "4") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}

function Invoke-SubmenuFTP {
    do {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor Blue
        Write-Host "   TAREA 5: MENÚ FTP (WINDOWS SERVER)    " -ForegroundColor Cyan
        Write-Host "=========================================" -ForegroundColor Blue
        Write-Host "1. Configuración inicial (IIS y FTP)"
        Write-Host "2. Verificar instalación y estado"
        Write-Host "3. Alta de usuarios"
        Write-Host "4. Cambiar usuario de grupo"
        Write-Host "5. Eliminar usuario"
        Write-Host "6. Volver al Menú Principal"
        Write-Host "-----------------------------------------" -ForegroundColor Blue
        
        $opcion = Read-Host "Seleccione una opción [1-6]"

        switch ($opcion) {
            "1" { Configuracion-InicialFTP }
            "2" { Verificar-InstalacionFTP }
            "3" {
                $num = Read-Host "¿Cuántos usuarios deseas agregar?"
                for ($i = 1; $i -le [int]$num; $i++) {
                    Write-Host "`n--- Creando usuario $i de $num ---" -ForegroundColor Cyan
                    $User = Capturar-Usuario
                    $Pass = Capturar-Contrasena
                    $Group = Capturar-Grupo
                    Crear-UsuarioFTP -User $User -Pass $Pass -Group $Group
                }
            }
            "4" { Cambiar-GrupoFTP }
            "5" { Eliminar-UsuarioFTP }
            "6" { return }
            default { Write-Host "[-] Opción no válida. Intenta de nuevo." -ForegroundColor Red; Start-Sleep 1 }
        }

        if ($opcion -ne "6") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}

function Invoke-SubmenuHTTP {
    do {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "       TAREA 6: MENÚ HTTP (WINDOWS SERVER)          " -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "1. Despliegue dinámico de IIS (Instalación Forzosa)"
        Write-Host "2. Despliegue dinámico de Apache Win64"
        Write-Host "3. Despliegue dinámico de Nginx para Windows"
        Write-Host "4. Verificar instalaciones y puertos activos"
        Write-Host "5. Volver al Menú Principal"
        Write-Host "----------------------------------------------------" -ForegroundColor Green
        
        $Opcion = Read-Host "Selecciona un módulo [1-5]"

        switch ($Opcion) {
            '1' { Menu-InstalarIIS }
            '2' { Menu-InstalarApacheWin }
            '3' { Menu-InstalarNginxWin }
            '4' { Verificar-HTTP }
            '5' { return }
            default { Write-Host "[ERROR] Opción no válida. Elige del 1 al 5." -ForegroundColor Red; Start-Sleep 1 }
        }
        
        if ($Opcion -ne "5") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}

function Invoke-SubmenuHibrido {
    do {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Magenta
        Write-Host "  TAREA 7: INFRAESTRUCTURA DE DESPLIEGUE SEGURO     " -ForegroundColor Magenta
        Write-Host "====================================================" -ForegroundColor Magenta
        Write-Host "1. Instalar IIS Web (SSL Dinámico)"
        Write-Host "2. Instalar IIS FTP (SSL Dinámico)"
        Write-Host "3. Instalar Apache (Descarga FTP/Web + SSL Dinámico)"
        Write-Host "4. Instalar Nginx (Descarga FTP/Web + SSL Dinámico)"
        Write-Host "5. Volver al Menú Principal"
        Write-Host "----------------------------------------------------" -ForegroundColor Magenta
        
        $opc = Read-Host "Selecciona una opción [1-5]"

        switch ($opc) {
            "1" { Instalar-IIS-Web-Seguro }
            "2" { Instalar-IIS-FTP-Seguro } # Adaptada similar a IIS Web
            "3" { Instalar-Apache-Seguro }
            "4" { Instalar-Nginx-Seguro }
            "5" { return }
        }
        if ($opc -ne "5") { Read-Host "`nPresiona Enter para continuar..." }
    } while ($true)
}

function Invoke-SubmenuTarea8 {
    do {
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "  TAREA 8: GOBERNANZA, CUOTAS Y CONTROL (AD/FSRM)   " -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "1. Crear Estructura, Usuarios y Horarios (CSV)"
        Write-Host "2. Configurar Cuotas y Filtros (FSRM)"
        Write-Host "3. Configurar AppLocker (Hash) y GPO de Cierre"
        Write-Host "4. Ejecutar TODA la Práctica 08 Automáticamente"
        Write-Host "5. Volver al Menú Principal"
        Write-Host "----------------------------------------------------" -ForegroundColor Cyan
        
        $Op = Read-Host "Seleccione una opción [1-5]"
        
        switch ($Op) {
            "1" { Crear-UsuariosGobernanza }
            "2" { Configurar-FSRM }
            "3" { Configurar-AppLockerGPO }
            "4" { Ejecutar-Tarea8Completa }
            "5" { return }
            Default { Write-Host "Opción inválida." -ForegroundColor Red; Start-Sleep 1 }
        }
        
        if ($Op -ne "5") {
            Write-Host "`n---------------------------------------" -ForegroundColor Yellow
            Read-Host "Presiona Enter para continuar..."
        }
    } while ($true)
}


# ==========================================
# 4. MENÚ PRINCIPAL ORQUESTADOR
# ==========================================
do {
    Clear-Host
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "      MENÚ PRINCIPAL DE ADMINISTRACIÓN (WINDOWS)    " -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "1. Módulo de Diagnóstico y Configuración de Red (Tarea 1)"
    Write-Host "2. Módulo Servidor DHCP (Tarea 2)"
    Write-Host "3. Módulo Servidor DNS (Tarea 3)"
    Write-Host "4. Módulo Servidor SSH (Tarea 4)"
    Write-Host "5. Módulo Servidor FTP (Tarea 5)"
    Write-Host "6. Módulo Servidor HTTP (Tarea 6)"
    Write-Host "7. Módulo de Servidor SSL (Tarea 7)"
    Write-Host "8. Módulo de Gobernanza y Cuotas (Tarea 8)"
    Write-Host "9. Salir completamente"
    Write-Host "----------------------------------------------------" -ForegroundColor Green
    
    $opcion = Read-Host "Selecciona un módulo [1-9]"

    switch ($opcion) {
        "1" { Invoke-SubmenuTarea1 }
        "2" { Invoke-SubmenuDHCP }
        "3" { Invoke-SubmenuDNS }
        "4" { Invoke-SubmenuSSH }
        "5" { Invoke-SubmenuFTP }
        "6" { Invoke-SubmenuHTTP }
        "7" { Invoke-SubmenuHibrido }
        "8" { Invoke-SubmenuTarea8 }
        "9" { 
            Write-Host "Saliendo del administrador..." -ForegroundColor Green
            exit 
        }
        Default { 
            Write-Host "[ERROR] Opción no válida. Elige del 1 al 9." -ForegroundColor Red
            Start-Sleep -Seconds 2 
        }
     }

} while ($true)




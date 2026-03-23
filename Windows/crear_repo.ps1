# --- CONSTRUCTOR DEL REPOSITORIO FTP (CORREGIDO) ---
$rutaRepo = "C:\FTP\LocalUser\repositorio\Windows"
# ¡Adiós Tomcat! Solo dejamos los que realmente ocupan instalador descargable, más IIS por consistencia de estructura.
$carpetas = @("Apache", "Nginx", "IIS") 

Write-Host "Creando estructura del repositorio..." -ForegroundColor Cyan
foreach ($carpeta in $carpetas) {
    $path = "$rutaRepo\$carpeta"
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
}

Write-Host "Aplicando permisos NTFS (Evitando el calvario de las 10 horas)..." -ForegroundColor Yellow
icacls "C:\FTP\LocalUser\repositorio" /grant "IUSR:(OI)(CI)(RX)" /T | Out-Null
icacls "C:\FTP\LocalUser\repositorio" /grant "IIS_IUSRS:(OI)(CI)(RX)" /T | Out-Null
icacls "C:\FTP\LocalUser\repositorio" /grant "repositorio:(OI)(CI)(RX)" /T | Out-Null

Write-Host "[OK] Repositorio listo y asegurado en $rutaRepo" -ForegroundColor Green
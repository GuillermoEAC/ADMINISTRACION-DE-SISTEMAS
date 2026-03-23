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

Write-Host "Calculando nuevos horarios..." -ForegroundColor Cyan
$bytesCuates = Crear-HorarioBytes -Inicio 8 -Fin 15
$bytesNoCuates = Crear-HorarioBytes -Inicio 15 -Fin 2

Write-Host "Forzando actualización de horarios en Active Directory..." -ForegroundColor Cyan
# Actualiza a todos los que ya existen en Cuates
Get-ADUser -Filter * -SearchBase "OU=Cuates,DC=reprobados,DC=com" | ForEach-Object {
    Set-ADUser -Identity $_.SamAccountName -Replace @{logonhours = $bytesCuates}
}

# Actualiza a todos los que ya existen en No Cuates
Get-ADUser -Filter * -SearchBase "OU=No Cuates,DC=reprobados,DC=com" | ForEach-Object {
    Set-ADUser -Identity $_.SamAccountName -Replace @{logonhours = $bytesNoCuates}
}

Write-Host "¡Horarios actualizados con éxito!" -ForegroundColor Green
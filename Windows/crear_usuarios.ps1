# 1. Crear las Unidades Organizativas (UO)
New-ADOrganizationalUnit -Name "Cuates" -Path "DC=reprobados,DC=com"
New-ADOrganizationalUnit -Name "No Cuates" -Path "DC=reprobados,DC=com"

# 2. Encontrar el escritorio y leer el CSV
$rutaCSV = "$env:USERPROFILE\Desktop\usuarios.csv"
$usuarios = Import-Csv $rutaCSV

# 3. Leer cada línea y crear el usuario en la UO correcta
foreach ($u in $usuarios) {
    if ($u.Departamento -eq "Cuates") { 
        $rutaUO = "OU=Cuates,DC=reprobados,DC=com" 
    } else { 
        $rutaUO = "OU=No Cuates,DC=reprobados,DC=com" 
    }
    
    New-ADUser -Name $u.Nombre `
               -SamAccountName $u.Nombre `
               -UserPrincipalName "$($u.Nombre)@reprobados.com" `
               -Path $rutaUO `
               -AccountPassword (ConvertTo-SecureString $u.Password -AsPlainText -Force) `
               -Enabled $true
}
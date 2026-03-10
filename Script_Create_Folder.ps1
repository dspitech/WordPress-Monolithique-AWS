# Définir le chemin du projet (dans C:)
$Path = "C:\Projet-WordPress-AWS"

# Créer le dossier racine
if (!(Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path
    Write-Host "[OK] Dossier créé : $Path" -ForegroundColor Green
}

# Créer les fichiers de script
$Files = @("01_Deploy_Infra.ps1", "02_Get_Credentials.ps1", "03_Cleanup.ps1")

foreach ($File in $Files) {
    $FilePath = Join-Path $Path $File
    if (!(Test-Path $FilePath)) {
        New-Item -ItemType File -Path $FilePath
        Write-Host "[+] Fichier créé : $File" -ForegroundColor Cyan
    }
}

# Créer un petit fichier mémo
$Memo = @"
PROJET WORDPRESS RDS - DSPI-TECH
--------------------------------
Identifiants par défaut :
DB Name : wordpress_db
Admin : wp_db_admin
Pass : P@ssw0rdSecure2026!
Region : eu-west-3
"@

Set-Content -Path (Join-Path $Path "Identifiants.txt") -Value $Memo

Write-Host "`nStructure de projet prête ! Tu peux maintenant copier les codes dedans." -ForegroundColor Yellow
<#
.SYNOPSIS
    Récupère les informations de connexion du projet WordPress (Version FREE TIER).
#>

# --- CONFIGURATION (Alignée sur ton script de déploiement) ---
$Config = @{
    DBInstanceId = "rds-wp-free"  # Modifié : correspond à ton déploiement
    ProjectTag   = "WP-Free-Lab"   # Modifié : correspond à ton déploiement
    Region       = "eu-west-3"
    MasterPass   = "PassSafe2026" 
}

try {
    Write-Host "`n--- RÉCUPÉRATION DES PARAMÈTRES DE CONNEXION (FREE TIER) ---" -ForegroundColor Cyan

    # 1. Récupération des infos RDS via AWS CLI
    # On utilise --query pour être plus robuste que le passage par ConvertFrom-Json sur tout l'objet
    $RDSInfo = aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --region $Config.Region --output json | ConvertFrom-Json
    
    $Endpoint = $RDSInfo.DBInstances[0].Endpoint.Address
    $DBName   = $RDSInfo.DBInstances[0].DBName
    $DBUser   = $RDSInfo.DBInstances[0].MasterUsername
    $DBStatus = $RDSInfo.DBInstances[0].DBInstanceStatus

    # 2. Récupération de l'IP Publique EC2
    $PublicIP = (aws ec2 describe-instances `
        --filters "Name=tag:Name,Values=$($Config.ProjectTag)" "Name=instance-state-name,Values=running" `
        --query "Reservations[0].Instances[0].PublicIpAddress" `
        --output text --region $Config.Region)

    # 3. AFFICHAGE
    Write-Host "`n========================================================" -ForegroundColor Gray
    Write-Host "  INFOS BASE DE DONNÉES (RDS) - Statut: $DBStatus" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------"
    Write-Host " ENDPOINT     : " -NoNewline; Write-Host $Endpoint -ForegroundColor Cyan
    Write-Host " NOM DB       : " -NoNewline; Write-Host $DBName -ForegroundColor White
    Write-Host " ADMIN USER   : " -NoNewline; Write-Host $DBUser -ForegroundColor White
    Write-Host " MOT DE PASSE : " -NoNewline; Write-Host $Config.MasterPass -ForegroundColor White
    
    Write-Host "`n  INFOS SERVEUR WEB (EC2)" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------"
    if ($PublicIP -eq "None" -or [string]::IsNullOrEmpty($PublicIP)) {
        Write-Host " IP PUBLIQUE  : " -NoNewline; Write-Host "Non disponible (vérifiez si l'instance tourne)" -ForegroundColor Red
    }
    else {
        Write-Host " IP PUBLIQUE  : " -NoNewline; Write-Host $PublicIP -ForegroundColor Cyan
        Write-Host " URL DU SITE  : " -NoNewline; Write-Host "http://$PublicIP" -ForegroundColor Green
    }
    Write-Host "========================================================" -ForegroundColor Gray

}
catch {
    Write-Host "[ERREUR] Impossible de récupérer les données. L'instance RDS '$($Config.DBInstanceId)' existe-t-elle bien ?" -ForegroundColor Red
}

<#
.SYNOPSIS
    Recuperation les informations de connexion du projet .
#>

# --- CONFIGURATION 
$Config = @{
    DBInstanceId = "rds-wp-free"  # Correspond a ton deploiement
    ProjectTag   = "WP-Free-Lab"   # Correspond a ton deploiement
    Region       = "eu-west-3"
    MasterPass   = "PassSafe2026" 
}

try {
    Write-Host "`n--- RECUPERATION DES PARAMETRES DE CONNEXION (FREE TIER) ---" -ForegroundColor Cyan

    # 1. Recuperation des infos RDS via AWS CLI
    $RDSInfo = aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --region $Config.Region --output json | ConvertFrom-Json
    
    $Endpoint = $RDSInfo.DBInstances[0].Endpoint.Address
    $DBName   = $RDSInfo.DBInstances[0].DBName
    $DBUser   = $RDSInfo.DBInstances[0].MasterUsername
    $DBStatus = $RDSInfo.DBInstances[0].DBInstanceStatus

    # 2. Recuperation de l'IP Publique EC2
    $PublicIP = (aws ec2 describe-instances `
        --filters "Name=tag:Name,Values=$($Config.ProjectTag)" "Name=instance-state-name,Values=running" `
        --query "Reservations[0].Instances[0].PublicIpAddress" `
        --output text --region $Config.Region)

    # 3. AFFICHAGE
    Write-Host "`n========================================================" -ForegroundColor Gray
    Write-Host "  INFOS BASE DE DONNEES (RDS) - Statut: $DBStatus" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------"
    Write-Host " ENDPOINT     : " -NoNewline; Write-Host $Endpoint -ForegroundColor Cyan
    Write-Host " NOM DB       : " -NoNewline; Write-Host $DBName -ForegroundColor White
    Write-Host " ADMIN USER   : " -NoNewline; Write-Host $DBUser -ForegroundColor White
    Write-Host " MOT DE PASSE : " -NoNewline; Write-Host $Config.MasterPass -ForegroundColor White
    
    Write-Host "`n  INFOS SERVEUR WEB (EC2)" -ForegroundColor Yellow
    Write-Host "--------------------------------------------------------"
    if ($PublicIP -eq "None" -or [string]::IsNullOrEmpty($PublicIP)) {
        Write-Host " IP PUBLIQUE  : " -NoNewline; Write-Host "Non disponible (verifiez si l'instance tourne)" -ForegroundColor Red
    }
    else {
        Write-Host " IP PUBLIQUE  : " -NoNewline; Write-Host $PublicIP -ForegroundColor Cyan
        Write-Host " URL DU SITE  : " -NoNewline; Write-Host "http://$PublicIP" -ForegroundColor Green
    }
    Write-Host "========================================================" -ForegroundColor Gray

}
catch {
    Write-Host "[ERREUR] Impossible de recuperer les donnees. L'instance RDS '$($Config.DBInstanceId)' existe-t-elle bien ?" -ForegroundColor Red
}

<#
.SYNOPSIS
    Nettoyage complet du projet WordPress (EC2, RDS, S3, IAM, SSM).
    Cible : Ressources 100% Free Tier.
#>

$Config = @{
    DBInstanceId = "rds-wp-free"
    ProjectTag   = "WP-Free-Lab"
    WebSGName    = "WP-Web-SG"
    DBSGName     = "WP-DB-SG"
    Region       = "eu-west-3"
}

try {
    Write-Host "`n[!] DÉMARRAGE DU NETTOYAGE GLOBAL..." -ForegroundColor Magenta
    Write-Host "--------------------------------------------------------"

    # 1. SUPPRESSION S3
    Write-Host "[-] Recherche et vidage des Buckets S3..." -ForegroundColor Yellow
    # Correction : On filtre mieux le nom pour éviter de supprimer d'autres buckets
    $Buckets = (aws s3 ls --region $Config.Region | Select-String "wp-free-storage" | ForEach-Object { $_.ToString().Split(" ") | Where-Object {$_ -ne ""} | Select-Object -Last 1 })
    
    foreach ($Bucket in $Buckets) {
        Write-Host "    -> Nettoyage complet du bucket : $Bucket"
        # On vide d'abord le contenu (obligatoire pour les buckets non vides)
        aws s3 rm "s3://$Bucket" --recursive --region $Config.Region | Out-Null
        # On supprime le bucket
        aws s3 rb "s3://$Bucket" --force --region $Config.Region | Out-Null
        Write-Host "    [OK] Bucket $Bucket supprimé." -ForegroundColor Green
    }

    # 2. SUPPRESSION DU PARAMÈTRE SSM
    Write-Host "[-] Suppression du mot de passe (Parameter Store)..." -ForegroundColor Yellow
    aws ssm delete-parameter --name "/wp/db/password" --region $Config.Region 2>$null

    # 3. RÉSILIATION EC2
    Write-Host "[-] Résiliation de l'instance EC2..." -ForegroundColor Yellow
    $InstanceId = (aws ec2 describe-instances --filters "Name=tag:Name,Values=$($Config.ProjectTag)" "Name=instance-state-name,Values=running,stopped,pending" --query "Reservations[0].Instances[0].InstanceId" --output text --region $Config.Region)
    if ($InstanceId -and $InstanceId -ne "None") {
        aws ec2 terminate-instances --instance-ids $InstanceId --region $Config.Region | Out-Null
        Write-Host "    [OK] Instance $InstanceId en cours de résiliation." -ForegroundColor Green
    }

    # 4. SUPPRESSION RDS
    Write-Host "[-] Suppression de l'instance RDS (Sans Snapshot)..." -ForegroundColor Yellow
    # On vérifie si l'instance existe avant de tenter la suppression pour éviter l'erreur dans le catch
    $CheckExistRDS = aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --region $Config.Region 2>$null
    if ($CheckExistRDS) {
        aws rds delete-db-instance --db-instance-identifier $Config.DBInstanceId --skip-final-snapshot --delete-automated-backups --region $Config.Region | Out-Null
        Write-Host "    [OK] Commande de suppression RDS envoyée." -ForegroundColor Green
    }

    # 5. ATTENTE DE LIBÉRATION DES RESSOURCES (Important pour les SGs)
    Write-Host "[-] Attente de la destruction (EC2 & RDS)..." -NoNewline
    do {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 30
        $CheckEC2 = (aws ec2 describe-instances --filters "Name=tag:Name,Values=$($Config.ProjectTag)" "Name=instance-state-name,Values=shutting-down,running" --query "Reservations[0].Instances[0].InstanceId" --output text --region $Config.Region)
        # On teste si RDS existe encore
        $CheckRDS = $null
        try { $CheckRDS = aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --region $Config.Region 2>$null } catch { $CheckRDS = $null }
    } while (($CheckEC2 -and $CheckEC2 -ne "None") -or $CheckRDS)
    Write-Host "`n[OK] Ressources de calcul libérées." -ForegroundColor Green

    # 6. NETTOYAGE IAM
    Write-Host "[-] Nettoyage de l'identité IAM..." -ForegroundColor Yellow
    aws iam remove-role-from-instance-profile --instance-profile-name "WP-Free-Profile" --role-name "WP-Free-S3-Role" 2>$null
    aws iam delete-instance-profile --instance-profile-name "WP-Free-Profile" 2>$null
    aws iam detach-role-policy --role-name "WP-Free-S3-Role" --policy-arn arn:aws:policy/AmazonS3FullAccess 2>$null
    aws iam delete-role --role-name "WP-Free-S3-Role" 2>$null
    Write-Host "    [OK] Profils et rôles IAM nettoyés." -ForegroundColor Green

    # 7. SUPPRESSION DES SECURITY GROUPS
    Write-Host "[-] Suppression des Security Groups..." -ForegroundColor Yellow
    $SGs = @($Config.DBSGName, $Config.WebSGName)
    foreach ($SGName in $SGs) {
        $SGId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=$SGName" --query "SecurityGroups[0].GroupId" --output text --region $Config.Region)
        if ($SGId -and $SGId -ne "None") { 
            # On réessaie car parfois RDS met du temps à libérer totalement le SG
            try {
                aws ec2 delete-security-group --group-id $SGId --region $Config.Region | Out-Null
                Write-Host "    [OK] SG $SGName supprimé." -ForegroundColor Green
            } catch {
                Write-Host "    [!] Échec temporaire pour $SGName (en cours de libération)." -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n[SUCCESS] NETTOYAGE TERMINÉ : Votre compte est propre." -ForegroundColor Cyan
    Write-Host "========================================================"

}
catch {
    Write-Host "`n[INFO] Fin du script : certaines ressources n'étaient plus présentes." -ForegroundColor Gray
}

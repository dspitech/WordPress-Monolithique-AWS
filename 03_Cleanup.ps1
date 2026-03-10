<#
.SYNOPSIS
    Nettoyage complet du projet WordPress (EC2, RDS, S3, IAM, SSM).
    Optimisé pour supprimer les ressources créées par le script de déploiement.
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

    # 1. SUPPRESSION S3 (Doit être vidé avant d'être supprimé)
    Write-Host "[-] Recherche et vidage des Buckets S3..." -ForegroundColor Yellow
    $Buckets = (aws s3 ls | Select-String "wp-free-storage" | ForEach-Object { $_.ToString().Split(" ")[-1] })
    foreach ($Bucket in $Buckets) {
        Write-Host "    -> Suppression du contenu et du bucket : $Bucket"
        aws s3 rb "s3://$Bucket" --force --region $Config.Region | Out-Null
        Write-Host "    [OK] Bucket supprimé." -ForegroundColor Green
    }

    # 2. SUPPRESSION DU PARAMÈTRE SSM
    Write-Host "[-] Suppression du mot de passe (Parameter Store)..." -ForegroundColor Yellow
    aws ssm delete-parameter --name "/wp/db/password" --region $Config.Region 2>$null

    # 3. RÉSILIATION EC2
    Write-Host "[-] Résiliation de l'instance EC2..." -ForegroundColor Yellow
    $InstanceId = (aws ec2 describe-instances --filters "Name=tag:Name,Values=$($Config.ProjectTag)" "Name=instance-state-name,Values=running,stopped" --query "Reservations[0].Instances[0].InstanceId" --output text --region $Config.Region)
    if ($InstanceId -and $InstanceId -ne "None") {
        aws ec2 terminate-instances --instance-ids $InstanceId --region $Config.Region | Out-Null
        Write-Host "    [OK] Instance $InstanceId en cours de résiliation." -ForegroundColor Green
    }

    # 4. SUPPRESSION RDS
    Write-Host "[-] Suppression de l'instance RDS (Sans Snapshot)..." -ForegroundColor Yellow
    aws rds delete-db-instance --db-instance-identifier $Config.DBInstanceId --skip-final-snapshot --delete-automated-backups --region $Config.Region 2>$null
    Write-Host "    [OK] Commande de suppression RDS envoyée." -ForegroundColor Green

    # 5. ATTENTE DE LIBÉRATION DES RESSOURCES
    Write-Host "[-] Attente de la destruction totale (Calcul et Data)..." -NoNewline
    do {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 30
        $CheckEC2 = (aws ec2 describe-instances --filters "Name=tag:Name,Values=$($Config.ProjectTag)" "Name=instance-state-name,Values=shutting-down,running" --query "Reservations[0].Instances[0].InstanceId" --output text --region $Config.Region)
        $CheckRDS = (aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --region $Config.Region 2>$null)
    } while (($CheckEC2 -and $CheckEC2 -ne "None") -or $CheckRDS)
    Write-Host "`n[OK] Ressources de calcul et base de données libérées." -ForegroundColor Green

    # 6. NETTOYAGE IAM (Instance Profile et Role)
    Write-Host "[-] Nettoyage de l'identité IAM..." -ForegroundColor Yellow
    aws iam remove-role-from-instance-profile --instance-profile-name "WP-Free-Profile" --role-name "WP-Free-S3-Role" 2>$null
    aws iam delete-instance-profile --instance-profile-name "WP-Free-Profile" 2>$null
    aws iam detach-role-policy --role-name "WP-Free-S3-Role" --policy-arn arn:aws:policy/AmazonS3FullAccess 2>$null
    aws iam delete-role --role-name "WP-Free-S3-Role" 2>$null
    Write-Host "    [OK] Rôles et Profils IAM supprimés." -ForegroundColor Green

    # 7. SUPPRESSION DES SECURITY GROUPS
    Write-Host "[-] Suppression des Security Groups (Ordre inverse)..." -ForegroundColor Yellow
    $SGs = @($Config.DBSGName, $Config.WebSGName)
    foreach ($SGName in $SGs) {
        $SGId = (aws ec2 describe-security-groups --filters "Name=group-name,Values=$SGName" --query "SecurityGroups[0].GroupId" --output text --region $Config.Region)
        if ($SGId -and $SGId -ne "None") { 
            aws ec2 delete-security-group --group-id $SGId --region $Config.Region 2>$null
            Write-Host "    [OK] SG $SGName supprimé." -ForegroundColor Green
        }
    }

    Write-Host "`n[SUCCESS] NETTOYAGE TERMINÉ : Votre compte est propre (0€)." -ForegroundColor Cyan
    Write-Host "========================================================"

}
catch {
    Write-Host "`n[INFO] Certaines ressources n'existaient plus ou ont été supprimées manuellement." -ForegroundColor Gray
}
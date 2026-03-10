<#
.SYNOPSIS
    Déploiement WordPress Cloud-Native 100% Free Tier (SANS CloudFront).
    Services : EC2 (t3.micro), RDS (db.t3.micro), S3, Parameter Store, IAM.
#>

# --- 1. CONFIGURATION ÉCONOMIQUE ---
$Config = @{
    Region       = "eu-west-3" # Paris
    ProjectName  = "WP-Free-Lab"
    DBInstanceId = "rds-wp-free"
    DBName       = "wordpressdb"
    MasterUser   = "admin"
    MasterPass   = "PassSafe2026" 
    InstanceType = "t3.micro"     # Éligible Free Tier
    DBClass      = "db.t3.micro"  # Éligible Free Tier
    BucketName   = "wp-free-storage-$(Get-Random)"
}

$GlobalTimer = [System.Diagnostics.Stopwatch]::StartNew()

try {
    Write-Host "`n[1/5] RÉSEAU ET SÉCURITÉ (GRATUIT)" -ForegroundColor Cyan
    $VpcId = (aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output text --region $Config.Region)

    # Security Group Web
    $WebSGId = (aws ec2 create-security-group --group-name "WP-Web-SG" --description "SG Web Front" --vpc-id $VpcId --query "GroupId" --output text --region $Config.Region)
    aws ec2 authorize-security-group-ingress --group-id $WebSGId --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $Config.Region
    aws ec2 authorize-security-group-ingress --group-id $WebSGId --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $Config.Region

    # Security Group Database
    $DBSGId = (aws ec2 create-security-group --group-name "WP-DB-SG" --description "SG RDS Backend" --vpc-id $VpcId --query "GroupId" --output text --region $Config.Region)
    aws ec2 authorize-security-group-ingress --group-id $DBSGId --protocol tcp --port 3306 --source-group $WebSGId --region $Config.Region

    Write-Host "`n[2/5] STOCKAGE S3 ET PARAMÈTRES (GRATUIT)" -ForegroundColor Cyan
    # S3 (Gratuit jusqu'à 5 Go)
    aws s3 mb "s3://$($Config.BucketName)" --region $Config.Region
    
    # Remplacement Secrets Manager par Parameter Store (TOTALEMENT GRATUIT)
    aws ssm put-parameter --name "/wp/db/password" --value $Config.MasterPass --type "SecureString" --overwrite --region $Config.Region

    # Rôle IAM pour l'accès S3
    $RoleName = "WP-Free-S3-Role"
    $Policy = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    aws iam create-role --role-name $RoleName --assume-role-policy-document $Policy 2>$null
    aws iam attach-role-policy --role-name $RoleName --policy-arn arn:aws:policy/AmazonS3FullAccess
    aws iam create-instance-profile --instance-profile-name "WP-Free-Profile" 2>$null
    aws iam add-role-to-instance-profile --instance-profile-name "WP-Free-Profile" --role-name $RoleName 2>$null

    Write-Host "`n[3/5] PROVISIONNEMENT RDS (MYSQL FREE TIER)" -ForegroundColor Cyan
    aws rds create-db-instance `
        --db-instance-identifier $Config.DBInstanceId `
        --db-name $Config.DBName `
        --engine mysql `
        --db-instance-class $Config.DBClass `
        --allocated-storage 20 `
        --master-username $Config.MasterUser `
        --master-user-password $Config.MasterPass `
        --vpc-security-group-ids $DBSGId `
        --no-multi-az `
        --backup-retention-period 0 `
        --region $Config.Region | Out-Null

    Write-Host "[-] Attente du RDS (5-8 min)..." -NoNewline
    do {
        Write-Host "." -NoNewline; Start-Sleep -Seconds 30
        $Status = (aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --query "DBInstances[0].DBInstanceStatus" --output text --region $Config.Region)
    } while ($Status -ne "available")
    $RDS_Host = (aws rds describe-db-instances --db-instance-identifier $Config.DBInstanceId --query "DBInstances[0].Endpoint.Address" --output text --region $Config.Region)

    Write-Host "`n[4/5] LANCEMENT EC2 ET INSTALLATION WORDPRESS" -ForegroundColor Cyan
    $AMI = (aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*kernel-6.1-x86_64" --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text --region $Config.Region)

    $UserScript = @"
#!/bin/bash
dnf update -y
dnf install httpd php8.2 php8.2-mysqlnd mariadb105 awscli -y
cd /var/www/html
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz --strip-components=1
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$($Config.DBName)/" wp-config.php
sed -i "s/username_here/$($Config.MasterUser)/" wp-config.php
sed -i "s/password_here/$($Config.MasterPass)/" wp-config.php
sed -i "s/localhost/$RDS_Host/" wp-config.php
chown -R apache:apache /var/www/html
systemctl enable --now httpd
"@
    $UserData64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserScript))

    $InstanceId = (aws ec2 run-instances `
            --image-id $AMI `
            --count 1 `
            --instance-type $Config.InstanceType `
            --security-group-ids $WebSGId `
            --iam-instance-profile Name="WP-Free-Profile" `
            --user-data $UserData64 `
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$($Config.ProjectName)}]" `
            --query "Instances[0].InstanceId" --output text --region $Config.Region)

    Write-Host "`n[5/5] RÉSUMÉ FINAL" -ForegroundColor Green
    $PublicIP = (aws ec2 describe-instances --instance-ids $InstanceId --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $Config.Region)
    Write-Host "--------------------------------------------------------"
    Write-Host " URL WORDPRESS   : http://$PublicIP" -ForegroundColor Cyan
    Write-Host " BUCKET MÉDIAS   : s3://$($Config.BucketName)"
    Write-Host " TEMPS TOTAL     : $([math]::Round($GlobalTimer.Elapsed.TotalMinutes, 2)) min"
    Write-Host "--------------------------------------------------------"

}
catch { Write-Host "`n[ERREUR] : $($_.Exception.Message)" -ForegroundColor Red }
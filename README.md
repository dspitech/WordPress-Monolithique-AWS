## Déploiement WordPress Cloud-Native 100% Free Tier sur AWS (PowerShell)

Ce projet permet de déployer automatiquement un environnement **WordPress** complet sur **AWS** dans une architecture monolithique.

L’automatisation est réalisée à l’aide de **scripts PowerShell** s’appuyant sur l’**AWS CLI**.

## Auteur

👤 **LO Pape**  
🎓 Domaine : Cloud Computing  
💻 GitHub : [dspitech](https://github.com/dspitech)

---

## 1. Architecture et périmètre

![Arcchitecture_monolithique](https://hackmd.io/_uploads/BkYARcTKbx.png)

Le déploiement réalisé par `01_Deploy_Infra.ps1` provisionne les ressources suivantes (en région `eu-west-3`, Paris) :

- **EC2**
  - Instance Linux (Amazon Linux 2023) de type **t3.micro** (éligible Free Tier).
  - Installation automatique de **Apache**, **PHP 8.2**, **WordPress**.
  - Association d’un **Instance Profile IAM** pour l’accès à S3.

- **RDS (MySQL)**
  - Instance **MySQL** de type **db.t3.micro** (Free Tier).
  - Base de données `wordpressdb` (ou valeur définie dans la configuration).
  - Mot de passe master stocké dans **SSM Parameter Store** (`/wp/db/password`).

- **S3**
  - Bucket nommé dynamiquement `wp-free-storage-<random>`.
  - Destiné au stockage des médias WordPress.

- **IAM**
  - Rôle `WP-Free-S3-Role` avec la politique gérée `AmazonS3FullAccess`.
  - Instance profile `WP-Free-Profile` attaché à l’instance EC2.

- **Réseau & Sécurité**
  - Réutilisation de la **VPC par défaut**.
  - **Security Group Web** `WP-Web-SG` (ports 80 & 22 ouverts au monde).
  - **Security Group DB** `WP-DB-SG` (port 3306 ouvert depuis `WP-Web-SG`).

---

## 2. Structure du projet

À la racine du dépôt :

- **`01_Deploy_Infra.ps1`**  
  Script principal de **déploiement** de l’infrastructure WordPress (EC2, RDS, S3, IAM, SSM).

- **`02_Get_Credentials.ps1`**  
  Script pour **récupérer les informations de connexion** (RDS + EC2) et afficher l’URL du site WordPress.

- **`03_Cleanup.ps1`**  
  Script de **nettoyage global** : suppression des buckets S3 utilisés, paramètre SSM, instance EC2, instance RDS, rôles/profils IAM et Security Groups associés.

- **`Script_Create_Folder`**  
  Script PowerShell d’initialisation locale du dossier projet et des fichiers de base.

- **`Identifiants.txt`**  
  Mémo local contenant des identifiants par défaut de base de données pour un environnement WordPress de labo.

- **`README.md`**  
  Ce fichier de documentation.

---

## 3. Prérequis

- **Compte AWS** avec accès à la console et aux API.
- **AWS CLI** installé et configuré :
  - `aws configure`
  - Un profil avec des droits suffisants pour gérer : EC2, RDS, S3, IAM, SSM.
- **PowerShell 7+** (ou PowerShell Core) sur votre machine locale (Windows, macOS ou Linux).
- Accès Internet sortant pour télécharger WordPress depuis `wordpress.org`.

---

## 4. Configuration par défaut

Les scripts utilisent des objets de configuration internes. Les éléments principaux sont :

- Dans `01_Deploy_Infra.ps1` :
  - **Region** : `eu-west-3` (Paris).
  - **ProjectName** : `WP-Free-Lab`.
  - **DBInstanceId** : `rds-wp-free`.
  - **DBName** : `wordpressdb`.
  - **MasterUser** : `admin`.
  - **MasterPass** : `PassSafe2026`.
  - **InstanceType** : `t3.micro`.
  - **DBClass** : `db.t3.micro`.
  - **BucketName** : généré dynamiquement (`wp-free-storage-<random>`).

- Dans `02_Get_Credentials.ps1` :
  - **DBInstanceId** : `rds-wp-prod`.
  - **ProjectTag** : `WordPress-Pro-Lab`.
  - **Region** : `eu-west-3`.
  - **MasterPass** : `WPAdminSecure2026`.

- Dans `03_Cleanup.ps1` :
  - **DBInstanceId** : `rds-wp-free`.
  - **ProjectTag** : `WP-Free-Lab`.
  - **WebSGName** : `WP-Web-SG`.
  - **DBSGName** : `WP-DB-SG`.
  - **Region** : `eu-west-3`.

> **Important**  
> Les identifiants présents dans les scripts et `Identifiants.txt` sont des valeurs de labo/démo.  
> Pour un environnement réel, remplacez-les par des secrets sécurisés et ne les commitez pas en clair.

---

## 5. Installation locale du projet

1. **Cloner le dépôt GitHub** :

```bash
git clone https://github.com/dspitech/WordPress-Monolithique-AWS.git
cd Projet-WordPress-AWS
```

![image](https://hackmd.io/_uploads/Sy1T7aaKbx.png)

2. **(Optionnel) Création automatique de la structure locale**  
   Vous pouvez exécuter le script `Script_Create_Folder` (PowerShell) si vous souhaitez recréer la structure sur une autre machine.

3. **Vérifier/adapter la configuration**  
   Ouvrez les fichiers `01_Deploy_Infra.ps1`, `02_Get_Credentials.ps1` et `03_Cleanup.ps1` et ajustez :
   - La région si besoin (`Region`).
   - Les identifiants DB (`DBName`, `MasterUser`, `MasterPass`).
   - Les noms de projet/tags si vous souhaitez différencier plusieurs environnements.

---

## 6. Déploiement de l’infrastructure WordPress

Depuis PowerShell (en tant qu'administrateur) (dans le dossier du projet) :

```powershell
.\01_Deploy_Infra.ps1
```
![image](https://hackmd.io/_uploads/rkwmNaaK-g.png)

![image](https://hackmd.io/_uploads/S1bBEpTY-e.png)

![image](https://hackmd.io/_uploads/HJZvHaatZl.png)

- EC2

![image](https://hackmd.io/_uploads/rySnapaKbl.png)

- Groupe de sécurité
-
![image](https://hackmd.io/_uploads/S1mAapTt-l.png)

![image](https://hackmd.io/_uploads/rJ0kAapK-e.png)

![image](https://hackmd.io/_uploads/ByoWR66YZl.png)

- S3

![image](https://hackmd.io/_uploads/HJcmCaatZe.png)


- RDS

![image](https://hackmd.io/_uploads/S1aHATaFWl.png)

![image](https://hackmd.io/_uploads/HJ3DRaaY-l.png)



Le script va :

- Créer/paramétrer les **Security Groups**.
- Créer le **bucket S3** dédié aux médias.
- Stocker le mot de passe DB dans **SSM Parameter Store**.
- Créer l’instance **RDS MySQL** en Free Tier.
- Attendre que RDS soit **disponible**.
- Récupérer l’**endpoint RDS**.
- Lancer l’instance **EC2** avec un script **User Data** qui :
  - Met à jour le système.
  - Installe Apache, PHP, MariaDB client, AWS CLI.
  - Télécharge et installe **WordPress**.
  - Configure `wp-config.php` pour pointer vers la base RDS.
  - Démarre le service Apache.

En fin d’exécution, le script affiche un résumé avec :

- L’**URL WordPress** (`http://<IP_PUBLIQUE_EC2>`).
- Le **bucket S3** créé.
- Le **temps total** de déploiement.

---

## 7. Récupération des identifiants et URLs

Le script `02_Get_Credentials.ps1` permet d’afficher les informations de connexion d’un environnement existant (DB + serveur web).

Exécution :

```powershell
.\02_Get_Credentials.ps1
```

![image](https://hackmd.io/_uploads/BJn9Daptbg.png)


Ce script affiche notamment :

- **Base de données (RDS)** :
  - Endpoint.
  - Nom de la base.
  - Utilisateur admin.
  - Mot de passe (à partir de la configuration locale).

- **Serveur web (EC2)** :
  - IP publique.
  - URL du site `http://<IP_PUBLIQUE>`.

Adaptez `DBInstanceId` et `ProjectTag` dans le script pour cibler l’environnement voulu.

## Accès au site 

![image](https://hackmd.io/_uploads/SJK9_aatZx.png)

![image](https://hackmd.io/_uploads/rJqCdaTFZg.png)

![image](https://hackmd.io/_uploads/HkvJtT6KWx.png)

![image](https://hackmd.io/_uploads/BJsgYapKWg.png)

![image](https://hackmd.io/_uploads/H1gfKTTF-e.png)

![image](https://hackmd.io/_uploads/HJ1XtTaK-l.png)

---

## 8. Nettoyage 

Pour supprimer toutes les ressources créées par `01_Deploy_Infra.ps1`, exécutez :

```powershell
 .\03_Cleanup.ps1
```

Le script réalise les actions suivantes :

- Recherche et **suppression des buckets S3** dont le nom contient `wp-free-storage` (vidage + suppression).
- Suppression du **paramètre SSM** `/wp/db/password`.
- Résiliation de l’**instance EC2** associée au projet (via tag `ProjectTag`).
- Suppression de l’**instance RDS** (sans snapshot final, pour éviter les coûts).
- Attente de la fin complète de la suppression (EC2 + RDS).
- Suppression de l’**Instance Profile** et du **Rôle IAM** utilisés (et détachement de la politique S3).
- Suppression des **Security Groups** `WP-DB-SG` et `WP-Web-SG`.

En fin de script, un message confirme que le **compte est propre** et qu’il ne reste plus de ressources facturables pour ce labo.

![image](https://hackmd.io/_uploads/BJnR5T6F-x.png)

### Vérification
- Vérifier l'instance EC2
```PowerShell
aws ec2 describe-instances --filters "Name=tag:Name,Values=WP-Free-Lab" "Name=instance-state-name,Values=running,stopped,pending" --query "Reservations[].Instances[].InstanceId" --output text --region eu-west-3
```
![image](https://hackmd.io/_uploads/B1cQ2TptWx.png)

![image](https://hackmd.io/_uploads/rykIsppK-g.png)

- Vérifier la base de données
```PowerShell
aws rds describe-db-instances --db-instance-identifier rds-wp-free --query "DBInstances[].DBInstanceStatus" --output text --region eu-west-3
```
![image](https://hackmd.io/_uploads/HkAsnapKWl.png)

![image](https://hackmd.io/_uploads/SJXvj6Tt-x.png)

- Vérifier le Bucket S3
```PowerShell
aws s3 ls | Select-String "wp-free-storage"
```
![image](https://hackmd.io/_uploads/HJUGpTpKZl.png)

![image](https://hackmd.io/_uploads/rygFs6ptZe.png)

- Vérifier les Security Groups

![image](https://hackmd.io/_uploads/rJTas6at-l.png)

![image](https://hackmd.io/_uploads/H1PdaT6Fbg.png)



---




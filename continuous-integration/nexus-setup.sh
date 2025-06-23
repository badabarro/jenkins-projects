#!/bin/bash

# Script d'installation automatisée de Nexus sur une machine basée sur Amazon Linux

# Importation de la clé publique Amazon Corretto
sudo rpm --import https://yum.corretto.aws/corretto.key

# Ajout du dépôt Amazon Corretto pour installer Java 17
sudo curl -L -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo

# Installation de Java 17 Amazon Corretto et wget (outil de téléchargement)
sudo yum install -y java-17-amazon-corretto-devel wget

# Création des répertoires nécessaires pour Nexus
mkdir -p /opt/nexus/
mkdir -p /tmp/nexus/

# Téléchargement de Nexus depuis le site officiel
cd /tmp/nexus/
NEXUSURL="https://download.sonatype.com/nexus/3/nexus-unix-x86-64-3.78.0-14.tar.gz"
wget $NEXUSURL -O nexus.tar.gz


sleep 10

# Extraction de l'archive Nexus
EXTOUT=`tar xzvf nexus.tar.gz`

# Récupération du nom du dossier extrait
NEXUSDIR=`echo $EXTOUT | cut -d '/' -f1`

# Pause pour éviter les conflits
sleep 5

rm -rf /tmp/nexus/nexus.tar.gz

cp -r /tmp/nexus/* /opt/nexus/

# Pause avant de modifier les permissions
sleep 5


useradd nexus

# Attribution des droits au dossier Nexus
chown -R nexus.nexus /opt/nexus

# Création du service systemd pour démarrer Nexus en tant que service système
cat <<EOT>> /etc/systemd/system/nexus.service
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/$NEXUSDIR/bin/nexus start
ExecStop=/opt/nexus/$NEXUSDIR/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT

# Définition de l'utilisateur qui exécutera Nexus
echo 'run_as_user="nexus"' > /opt/nexus/$NEXUSDIR/bin/nexus.rc

# Rechargement des services systemd pour prendre en compte le nouveau service Nexus
systemctl daemon-reload

# Démarrage du service Nexus
systemctl start nexus

# Activation du service Nexus au démarrage de la machine
systemctl enable nexus

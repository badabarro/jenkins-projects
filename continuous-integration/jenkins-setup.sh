#!/bin/bash
# Script d'installation automatisée de Jenkins sur une machine Debian/Ubuntu

# Mise à jour de la liste des paquets disponibles
sudo apt update

# Installation de Java 17 requis pour Jenkins
sudo apt install openjdk-17-jdk -y

# Téléchargement de la clé publique officielle de Jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

# Ajout du dépôt officiel Jenkins dans les sources APT
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Mise à jour de la liste des paquets après ajout du dépôt Jenkins
sudo apt-get update

# Installation de Jenkins
sudo apt-get install jenkins -y

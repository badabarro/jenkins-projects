#!/bin/bash
# Script d'installation complète de SonarQube avec PostgreSQL et Nginx sur Ubuntu

# Optimisation des paramètres système #

# Sauvegarde du fichier sysctl avant modification
cp /etc/sysctl.conf /root/sysctl.conf_backup

# Configuration des paramètres système nécessaires à SonarQube
cat <<EOT> /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
ulimit -n 65536
ulimit -u 4096
EOT

# Sauvegarde des limites utilisateurs
cp /etc/security/limits.conf /root/sec_limit.conf_backup

# Limites spécifiques pour l'utilisateur sonarqube
cat <<EOT> /etc/security/limits.conf
sonarqube   -   nofile   65536
sonarqube   -   nproc    409
EOT

# Installation de Java 17 (JDK) #


sudo apt-get update -y
sudo apt-get install openjdk-17-jdk -y
sudo update-alternatives --config java
java -version

# Installation de PostgreSQL #

sudo apt update
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

# Ajout du dépôt PostgreSQL
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'

sudo apt update
sudo apt install postgresql postgresql-contrib -y

sudo systemctl enable postgresql.service
sudo systemctl start postgresql.service

# Modification du mot de passe de l'utilisateur postgres
sudo echo "postgres:admin123" | chpasswd

# Création de l'utilisateur et de la base de données pour SonarQube
runuser -l postgres -c "createuser sonar"
sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

systemctl restart postgresql

# Vérification si PostgreSQL écoute correctement
netstat -tulpena | grep postgres

# Installation de SonarQube     #

# Création des dossiers nécessaires
sudo mkdir -p /sonarqube/
cd /sonarqube/

# Téléchargement et extraction de SonarQube
sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.8.100196.zip
sudo apt-get install zip -y
sudo unzip -o sonarqube-9.9.8.100196.zip -d /opt/
sudo mv /opt/sonarqube-9.9.8.100196/ /opt/sonarqube

# Création d'un utilisateur dédié SonarQube
sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
sudo chown -R sonar:sonar /opt/sonarqube/

# Sauvegarde du fichier de configuration par défaut
cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup

# Configuration de SonarQube
cat <<EOT> /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT

# Création du service systemd pour SonarQube
cat <<EOT> /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

# Activation du service SonarQube
systemctl daemon-reload
systemctl enable sonarqube.service
# systemctl start sonarqube.service
# systemctl status sonarqube.service

# Installation de Nginx (Proxy) #

apt-get install nginx -y

# Suppression de la configuration par défaut de Nginx
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default

# Configuration de Nginx en reverse proxy pour SonarQube
cat <<EOT> /etc/nginx/sites-available/sonarqube
server {
    listen      80;
    server_name sonarqube.groophy.in;

    access_log  /var/log/nginx/sonar.access.log;
    error_log   /var/log/nginx/sonar.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass  http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto http;
    }
}
EOT

# Activation du site Nginx
ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
systemctl enable nginx.service
# systemctl restart nginx.service

# Autorisation des ports nécessaires
sudo ufw allow 80,9000,9001/tcp

# Redémarrage du système        #

echo "Redémarrage du système dans 30 secondes..."
sleep 30
reboot

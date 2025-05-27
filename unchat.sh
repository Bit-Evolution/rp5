#!/bin/bash

log_file="install.log"
log() {
    echo "$(date) - $1" | tee -a "$log_file"
}

log "Deinstallation wird gestartet..."

log "Entferne Docker-Container, Images und Netzwerke..."
docker stop nginx-proxy-manager nextcloud vaultwarden etherpad gitlab
docker rm nginx-proxy-manager nextcloud vaultwarden etherpad gitlab
docker network rm proxy_netzwerk
docker system prune -af >> "$log_file" 2>&1

log "Entferne installierte Pakete..."
apt remove --purge -y docker.io docker-compose jq curl git ufw >> "$log_file" 2>&1

log "Entferne Benutzer aus der Docker-Gruppe..."
gpasswd -d $USER docker

log "Lösche Konfigurationsdateien und Docker-Daten..."
rm -rf ~/docker
rm -f ~/config.sh

log "Stelle /boot/config.txt aus einem Backup wieder her..."
cp /boot/config.txt.bak /boot/config.txt

log "Deinstallation abgeschlossen!"

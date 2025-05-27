#!/bin/bash

# Logging-Funktion
log_file="install.log"
log() {
    echo "$(date) - $1" | tee -a "$log_file"
}

log "Lade Konfiguration..."
source ~/config.sh

log "Prüfung der lokalen IP-Adresse..."
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -n 1)
log "Lokale IP: $LOCAL_IP"

log "Erstelle Docker-Netzwerk..."
docker network create proxy_netzwerk >> "$log_file" 2>&1

log "Starten der Docker-Container..."

# NGINX Proxy Manager
docker run -d --name=nginx-proxy-manager --network=proxy_netzwerk -p 80:80 -p 443:443 -p 81:81 -v ~/docker/proxy:/config jc21/nginx-proxy-manager >> "$log_file" 2>&1

# Nextcloud
docker run -d --name=nextcloud --network=proxy_netzwerk -p 8080:80 -v ~/docker/nextcloud:/var/www/html -v $MOUNT_DIR:/mnt/data nextcloud >> "$log_file" 2>&1

# Vaultwarden
docker run -d --name=vaultwarden --network=proxy_netzwerk -p 8082:80 -v ~/docker/vaultwarden:/data vaultwarden/server >> "$log_file" 2>&1

# Etherpad
docker run -d --name=etherpad --network=proxy_netzwerk -p 9001:9001 -v ~/docker/etherpad:/opt/etherpad-lite etherpad/etherpad >> "$log_file" 2>&1

# GitLab
docker run -d --name=gitlab --network=proxy_netzwerk -p 8083:80 -p 2222:22 -v ~/docker/gitlab:/var/opt/gitlab gitlab/gitlab-ce >> "$log_file" 2>&1

log "Warten auf die Initialisierung von Nextcloud und GitLab..."
sleep 60

# DynDNS Container (optional)
if [ "$DYNDNS" == "y" ]; then
    log "DynDNS-Container wird gestartet..."
    docker run -d --name=dyn-dns --network=proxy_netzwerk oznu/cloudflare-dns --username "$DYNDNS_USERNAME" --password "$DYNDNS_PASSWORD" >> "$log_file" 2>&1
fi

log "Dienste erfolgreich installiert!"


#!/bin/bash

# Logging-Funktion
log_file="install.log"
log() {
    echo "$(date) - $1" | tee -a "$log_file"
}

# Prüfen auf sudo-Rechte
if [ "$(id -u)" -ne 0 ]; then
    log "Fehler: Dieses Skript muss mit sudo-Rechten ausgeführt werden."
    exit 1
fi

log "System wird aktualisiert..."
apt update && apt upgrade -y >> "$log_file" 2>&1

log "Abhängigkeiten werden installiert..."
apt install -y curl git ufw jq docker.io docker-compose >> "$log_file" 2>&1

log "Benutzer wird zur Docker-Gruppe hinzugefügt..."
usermod -aG docker $USER

log "Bitte melden Sie sich ab und wieder an, um Docker zu verwenden."

# Konfigurationsabfrage
log "Bitte geben Sie die Domain ein (z.B. meinecloud.de):"
read -r DOMAIN
log "Domain: $DOMAIN" >> "$log_file"

log "Bitte geben Sie die E-Mail-Adresse für Let's Encrypt ein:"
read -r EMAIL
log "E-Mail: $EMAIL" >> "$log_file"

log "Bitte geben Sie die Subdomains für Nextcloud, Vaultwarden, Etherpad und GitLab ein:"
log "Nextcloud Subdomain:"
read -r NC_SUBDOMAIN
log "Vaultwarden Subdomain:"
read -r VW_SUBDOMAIN
log "Etherpad Subdomain:"
read -r EP_SUBDOMAIN
log "GitLab Subdomain:"
read -r GL_SUBDOMAIN

log "Bitte geben Sie den Mount-Ordner für Nextcloud ein:"
read -r MOUNT_DIR

log "Soll eine Firewall konfiguriert werden? (y/n)"
read -r FIREWALL

log "Soll DynDNS konfiguriert werden? (y/n)"
read -r DYNDNS

log "Konfiguration wird gespeichert..."
cat <<EOL > ~/config.sh
DOMAIN=$DOMAIN
EMAIL=$EMAIL
NC_SUBDOMAIN=$NC_SUBDOMAIN
VW_SUBDOMAIN=$VW_SUBDOMAIN
EP_SUBDOMAIN=$EP_SUBDOMAIN
GL_SUBDOMAIN=$GL_SUBDOMAIN
MOUNT_DIR=$MOUNT_DIR
FIREWALL=$FIREWALL
DYNDNS=$DYNDNS
EOL

chmod 600 ~/config.sh
log "Konfiguration gespeichert in ~/config.sh"

log "Systemvorbereitung abgeschlossen!"

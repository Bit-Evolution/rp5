#!/bin/bash

log_file="install.log"
log() {
    echo "$(date) - $1" | tee -a "$log_file"
}

log "Prüfung der Firewall-Konfiguration..."
source ~/config.sh

if [ "$FIREWALL" == "y" ]; then
    log "Konfiguriere UFW-Firewall..."
    ufw allow 80,443,22/tcp >> "$log_file" 2>&1
    ufw enable >> "$log_file" 2>&1
    log "Firewall erfolgreich konfiguriert."
else
    log "Keine Firewall-Konfiguration vorgenommen."
fi

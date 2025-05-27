#!/bin/bash

# Dieses Skript richtet eine Firewall ein, falls du eine Firewall konfiguriert hast.

set -e

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Lade die Einstellungen aus Teil 1
if [ ! -f ~/config.sh ]; then
    echo -e "${RED}Ich finde die Einstellungen nicht. Führe zuerst 'install_part1.sh' aus!${NC}"
    exit 1
fi
source ~/config.sh

# Richte die Firewall ein, falls gewünscht
if [ "$CONFIG_FIREWALL" == "j" ]; then
    echo -e "${GREEN}Richte die Firewall ein...${NC}"
    # Prüfe, ob UFW bereits aktiv ist
    if sudo ufw status | grep -q "Status: active"; then
        echo -e "${RED}Warnung: Die Firewall ist bereits aktiv. Bitte überprüfe die bestehenden Regeln, um Konflikte zu vermeiden.${NC}"
    fi
    cat << 'EOF' > ~/secure_desktop.sh
#!/bin/bash
# Firewall aktivieren und Standardregeln setzen
sudo ufw default deny incoming
sudo ufw default allow outgoing
# Öffne benötigte Ports
sudo ufw allow 80/tcp    # HTTP für NGINX Proxy Manager
sudo ufw allow 443/tcp   # HTTPS für NGINX Proxy Manager
sudo ufw allow 22/tcp    # SSH für Fernzugriff
# Starte die Firewall
sudo ufw enable
echo -e "${GREEN}Die Firewall ist jetzt aktiv. Starte dein System neu!${NC}"
EOF
    chmod +x ~/secure_desktop.sh
    sudo bash ~/secure_desktop.sh
else
    echo -e "${GREEN}Du hast keine Firewall-Konfiguration gewählt.${NC}"
fi

# Abschluss
echo -e "${GREEN}Teil 3 ist fertig!${NC}"
echo -e "${GREEN}Starte dein System bitte neu, wenn du eine Firewall konfiguriert hast.${NC}"

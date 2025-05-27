#!/bin/bash

# Dieses Skript ist der dritte Teil. Es richtet eine Firewall ein, falls du 
# Raspberry Pi OS mit Desktop verwendest, um deinen Server zu schützen.

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Funktion zur Überprüfung des letzten Befehls
check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Etwas ist schiefgelaufen. Das Skript wird abgebrochen.${NC}"
        exit 1
    fi
}

# Lade die Einstellungen aus Teil 1
if [ ! -f ~/config.sh ]; then
    echo -e "${RED}Ich finde die Einstellungen nicht. Führe zuerst 'install_part1.sh' aus!${NC}"
    exit 1
fi
source ~/config.sh

# Richte die Firewall ein, falls Desktop verwendet wird
if [ "$USE_DESKTOP" == "j" ]; then
    echo -e "${GREEN}Richte die Firewall für den Desktop ein...${NC}"
    cat << 'EOF' > ~/secure_desktop.sh
#!/bin/bash
# Firewall aktivieren und Standardregeln setzen
sudo ufw default deny incoming  # Alles blockieren, was reinkommt
sudo ufw default allow outgoing  # Alles erlauben, was rausgeht

# Öffne nur die benötigten Ports
sudo ufw allow 80/tcp    # HTTP für NGINX Proxy Manager
sudo ufw allow 443/tcp   # HTTPS für NGINX Proxy Manager

# Starte die Firewall
sudo ufw enable
echo -e "${GREEN}Die Firewall ist jetzt aktiv. Starte dein System neu!${NC}"
EOF
    chmod +x ~/secure_desktop.sh
    bash ~/secure_desktop.sh
    check_success
else
    echo -e "${GREEN}Du brauchst keine Firewall, weil du keinen Desktop verwendest.${NC}"
fi

# Abschluss
echo -e "${GREEN}Teil 3 ist fertig!${NC}"
echo -e "${GREEN}Starte dein System bitte neu, damit die Firewall aktiv wird.${NC}"

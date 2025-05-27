#!/bin/bash

# Dieses Skript ist der zweite Teil. Es installiert die Server, die du ausgewählt hast:
# Nextcloud, Vaultwarden, NGINX Proxy Manager und Etherpad.

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Prüfe, ob der letzte Befehl funktioniert hat
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

# Deine lokale IP-Adresse (nur zur Info)
LOCAL_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
echo -e "${GREEN}Nur so nebenbei: Deine lokale IP-Adresse ist $LOCAL_IP${NC}"

# Schalte Bluetooth aus, falls gewünscht
if [ "$DISABLE_BT" == "j" ]; then
    echo -e "${GREEN}Schalte Bluetooth aus...${NC}"
    echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt
    check_success
fi

# Schalte WiFi aus, falls gewünscht
if [ "$DISABLE_WIFI" == "j" ]; then
    echo -e "${GREEN}Schalte WiFi aus...${NC}"
    echo "dtoverlay=disable-wifi" | sudo tee -a /boot/config.txt
    check_success
fi

# Richte DynDNS ein (damit deine Domain immer auf deine IP zeigt)
echo -e "${GREEN}Richte DynDNS ein...${NC}"
sg docker -c "docker run -d \
  --name dyndns \
  -e USERNAME=$DYNDNS_USER \
  -e PASSWORD=$DYNDNS_PASS \
  -e DOMAIN=$DOMAIN \
  --restart=unless-stopped \
  oznu/cloudflare-dns"
check_success

# Installiere NGINX Proxy Manager (leitet Anfragen an die richtigen Server weiter)
echo -e "${GREEN}Installiere NGINX Proxy Manager...${NC}"
sg docker -c "docker run -d \
  --name nginx-proxy-manager \
  --network proxy_net \
  -p 80:80 \
  -p 443:443 \
  -p 81:81 \
  -v ~/docker/proxy/data:/data \
  -v ~/docker/proxy/letsencrypt:/etc/letsencrypt \
  --restart=unless-stopped \
  jc21/nginx-proxy-manager"
check_success

# Bitte den Benutzer, den Proxy einzurichten
echo -e "${GREEN}NGINX Proxy Manager läuft jetzt. Öffne http://$LOCAL_IP:81 in deinem Browser.${NC}"
echo "Logge dich ein mit: admin@example.com / changeme"
echo "Richte dort die Weiterleitungen für Nextcloud, Vaultwarden und Etherpad ein."
read -p "Drücke Enter, wenn du fertig bist..."

# Installiere Nextcloud (eine Cloud zum Speichern von Dateien)
echo -e "${GREEN}Installiere Nextcloud...${NC}"
sg docker -c "docker run -d \
  --name nextcloud \
  --network proxy_net \
  -p 8080:80 \
  -v ~/docker/nextcloud:/var/www/html \
  -v $MOUNT_DIR:/var/www/html/data \
  --restart=unless-stopped \
  nextcloud"
check_success

# Installiere Vaultwarden (ein Passwort-Manager)
echo -e "${GREEN}Installiere Vaultwarden...${NC}"
sg docker -c "docker run -d \
  --name vaultwarden \
  --network proxy_net \
  -p 8082:80 \
  -v ~/docker/vaultwarden:/data \
  --restart=unless-stopped \
  vaultwarden/server"
check_success

# Installiere Etherpad (zum gemeinsamen Schreiben von Texten)
echo -e "${GREEN}Installiere Etherpad...${NC}"
sg docker -c "docker run -d \
  --name etherpad \
  --network proxy_net \
  -p 9001:9001 \
  -v ~/docker/etherpad:/opt/etherpad-lite/var \
  --restart=unless-stopped \
  etherpad/etherpad"
check_success

# Hinweis zu Floccus (leider kein Docker-Image verfügbar)
echo -e "${GREEN}Hinweis: Für Floccus gibt es kein offizielles Docker-Image, daher wird es nicht installiert.${NC}"

# Fertig mit Teil 2
echo -e "${GREEN}Teil 2 ist fertig!${NC}"
echo -e "${GREEN}Starte dein System bitte neu, damit alles richtig läuft.${NC}"
echo -e "${GREEN}Führe danach 'install_part3.sh' aus, wenn du den Desktop verwendest.${NC}"

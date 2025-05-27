#!/bin/bash

# Dieses Skript ist der zweite Teil. Es installiert NGINX Proxy Manager und die Dienste:
# Nextcloud, Vaultwarden, Etherpad und GitLab.

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

# Zeige lokale IP-Adresse
LOCAL_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
echo -e "${GREEN}Deine lokale IP-Adresse ist: $LOCAL_IP${NC}"

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

# Richte DynDNS ein
echo -e "${GREEN}Richte DynDNS ein...${NC}"
sg docker -c "docker run -d \
  --name dyndns \
  -e USERNAME=$DYNDNS_USER \
  -e PASSWORD=$DYNDNS_PASS \
  -e DOMAIN=$DOMAIN \
  --restart=unless-stopped \
  oznu/cloudflare-dns"
check_success

# Installiere NGINX Proxy Manager
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

# Installiere Nextcloud
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

# Installiere Vaultwarden
echo -e "${GREEN}Installiere Vaultwarden...${NC}"
sg docker -c "docker run -d \
  --name vaultwarden \
  --network proxy_net \
  -p 8082:80 \
  -v ~/docker/vaultwarden:/data \
  --restart=unless-stopped \
  vaultwarden/server"
check_success

# Installiere Etherpad
echo -e "${GREEN}Installiere Etherpad...${NC}"
sg docker -c "docker run -d \
  --name etherpad \
  --network proxy_net \
  -p 9001:9001 \
  -v ~/docker/etherpad:/opt/etherpad-lite/var \
  --restart=unless-stopped \
  etherpad/etherpad"
check_success

# Installiere GitLab
echo -e "${GREEN}Installiere GitLab...${NC}"
sg docker -c "docker run -d \
  --name gitlab \
  --network proxy_net \
  -p 8083:80 \
  -p 2222:22 \
  -v ~/docker/gitlab/config:/etc/gitlab \
  -v ~/docker/gitlab/logs:/var/log/gitlab \
  -v ~/docker/gitlab/data:/var/opt/gitlab \
  --restart=unless-stopped \
  gitlab/gitlab-ce"
check_success

# Anleitung zur Konfiguration des NGINX Proxy Managers mit Let's Encrypt
echo -e "${GREEN}NGINX Proxy Manager ist installiert. Jetzt musst du die Subdomains konfigurieren und SSL-Zertifikate von Let's Encrypt abrufen.${NC}"
echo "Öffne http://$LOCAL_IP:81 in deinem Browser und melde dich an."
echo "Standard-Login: admin@example.com / changeme"
echo "Ändere das Passwort und richte die Proxy Hosts wie folgt ein:"

echo "1. Für Nextcloud:"
echo "   - Domain names: nextcloud.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: nextcloud"
echo "   - Port: 80"
echo "   - SSL: Request a new SSL Certificate (Let's Encrypt)"
echo "   - Aktiviere 'Force SSL' und 'HTTP/2 Support'"

echo "2. Für Vaultwarden:"
echo "   - Domain names: vaultwarden.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: vaultwarden"
echo "   - Port: 80"
echo "   - SSL: Request a new SSL Certificate"

echo "3. Für Etherpad:"
echo "   - Domain names: etherpad.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: etherpad"
echo "   - Port: 9001"
echo "   - SSL: Request a new SSL Certificate"

echo "4. Für GitLab:"
echo "   - Domain names: gitlab.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: gitlab"
echo "   - Port: 80"
echo "   - SSL: Request a new SSL Certificate"

echo "Stelle sicher, dass du deine E-Mail-Adresse ($EMAIL) für Let's Encrypt eingibst."
read -p "Drücke Enter, wenn du die Konfiguration abgeschlossen hast..."

# Abschluss
echo -e "${GREEN}Teil 2 ist fertig!${NC}"
echo -e "${GREEN}Starte dein System bitte neu, damit alles richtig läuft.${NC}"
echo -e "${GREEN}Führe danach 'install_part3.sh' aus, wenn du den Desktop verwendest.${NC}"

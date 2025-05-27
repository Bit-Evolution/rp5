#!/bin/bash

# Dieses Skript installiert NGINX Proxy Manager, Nextcloud, Vaultwarden, Etherpad und GitLab.
# Es konfiguriert trusted proxies und gibt Anleitungen für Let's Encrypt SSL.

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

# Prüfe, ob Docker installiert ist
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker ist nicht installiert! Bitte führe 'install_part1.sh' aus.${NC}"
    exit 1
fi

# Prüfe, ob der Benutzer in der Docker-Gruppe ist
if ! groups | grep -q docker; then
    echo -e "${RED}Du bist nicht in der Docker-Gruppe. Bitte melde dich ab und wieder an!${NC}"
    exit 1
fi

# Zeige lokale IP-Adresse
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -n 1)
echo -e "${GREEN}Deine lokale IP-Adresse ist: $LOCAL_IP${NC}"
echo -e "${GREEN}Hinweis: Für Let's Encrypt musst du deine DNS-Einträge auf deine öffentliche IP setzen und Ports 80/443 weiterleiten.${NC}"

# Prüfe Portkonflikte
echo -e "${GREEN}Prüfe auf Portkonflikte...${NC}"
for port in 80 443 81 8080 8082 9001 8083 2222; do
    if netstat -tuln | grep -q ":$port "; then
        echo -e "${RED}Port $port ist bereits belegt. Bitte löse den Konflikt vor der Installation!${NC}"
        exit 1
    fi
done

# Schalte Bluetooth aus, falls gewünscht
if [ "$DISABLE_BT" == "j" ]; then
    echo -e "${GREEN}Schalte Bluetooth aus...${NC}"
    sudo cp /boot/config.txt /boot/config.txt.bak  # Sichere config.txt
    sudo sh -c "echo 'dtoverlay=disable-bt' >> /boot/config.txt"
fi

# Schalte WiFi aus, falls gewünscht
if [ "$DISABLE_WIFI" == "j" ]; then
    echo -e "${GREEN}Schalte WiFi aus...${NC}"
    sudo cp /boot/config.txt /boot/config.txt.bak  # Sichere config.txt
    sudo sh -c "echo 'dtoverlay=disable-wifi' >> /boot/config.txt"
fi

# Richte DynDNS ein
echo -e "${GREEN}Richte DynDNS ein...${NC}"
read -s -p "Gib dein DynDNS-Passwort ein: " DYNDNS_PASS
echo
sg docker -c "docker run -d \
  --name dyndns \
  -e USERNAME=$DYNDNS_USER \
  -e PASSWORD=$DYNDNS_PASS \
  -e DOMAIN=$DOMAIN \
  --restart=unless-stopped \
  oznu/cloudflare-dns"

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

# Installiere Nextcloud und konfiguriere trusted proxies
echo -e "${GREEN}Installiere Nextcloud...${NC}"
sg docker -c "docker run -d \
  --name nextcloud \
  --network proxy_net \
  -p 8080:80 \
  -v ~/docker/nextcloud:/var/www/html \
  -v $MOUNT_DIR:/var/www/html/data \
  --restart=unless-stopped \
  nextcloud"
echo -e "${GREEN}Warte auf Nextcloud-Initialisierung...${NC}"
until sg docker -c "docker exec nextcloud curl -s -o /dev/null http://localhost"; do
    echo -e "${GREEN}Warte auf Nextcloud...${NC}"
    sleep 5
done
echo -e "${GREEN}Konfiguriere trusted proxies für Nextcloud...${NC}"
NETWORK_SUBNET=$(docker network inspect proxy_net | jq -r '.[0].IPAM.Config[0].Subnet')
sg docker -c "docker exec -u www-data nextcloud php occ config:system:set trusted_proxies 0 --value=$NETWORK_SUBNET"

# Installiere Vaultwarden
echo -e "${GREEN}Installiere Vaultwarden...${NC}"
sg docker -c "docker run -d \
  --name vaultwarden \
  --network proxy_net \
  -p 8082:80 \
  -v ~/docker/vaultwarden:/data \
  -e DOMAIN=https://$VAULTWARDEN_SUB.$DOMAIN \
  --restart=unless-stopped \
  vaultwarden/server"

# Installiere Etherpad und konfiguriere trusted proxies
echo -e "${GREEN}Installiere Etherpad...${NC}"
cat << EOF > ~/docker/etherpad/settings.json
{
  "trustProxy": true,
  "title": "Etherpad",
  "defaultPadText": "Willkommen bei Etherpad!"
}
EOF
sg docker -c "docker run -d \
  --name etherpad \
  --network proxy_net \
  -p 9001:9001 \
  -v ~/docker/etherpad:/opt/etherpad-lite/var \
  -v ~/docker/etherpad/settings.json:/opt/etherpad-lite/settings.json \
  --restart=unless-stopped \
  etherpad/etherpad"

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
  -e GITLAB_OMNIBUS_CONFIG="external_url 'https://$GITLAB_SUB.$DOMAIN'" \
  --restart=unless-stopped \
  gitlab/gitlab-ce"
echo -e "${GREEN}Warte auf GitLab-Initialisierung...${NC}"
until sg docker -c "docker exec gitlab curl -s -o /dev/null http://localhost"; do
    echo -e "${GREEN}Warte auf GitLab...${NC}"
    sleep 10
done

# Anleitung zur Konfiguration des NGINX Proxy Managers mit Let's Encrypt
echo -e "${GREEN}NGINX Proxy Manager ist installiert. Jetzt musst du die Subdomains konfigurieren und SSL-Zertifikate von Let's Encrypt abrufen.${NC}"
echo "1. Öffne http://$LOCAL_IP:81 in deinem Browser."
echo "2. Melde dich an mit: admin@example.com / changeme"
echo "3. Ändere das Passwort und richte die Proxy Hosts wie folgt ein:"
echo ""
echo "Für Nextcloud:"
echo "   - Domain names: $NEXTCLOUD_SUB.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: nextcloud"
echo "   - Port: 80"
echo "   - SSL: Request a new SSL Certificate (Let's Encrypt, E-Mail: $EMAIL)"
echo "   - Aktiviere 'Force SSL' und 'HTTP/2 Support'"
echo "   - Advanced Tab: Füge hinzu:"
echo "       proxy_set_header X-Real-IP \$remote_addr;"
echo "       proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
echo "       proxy_set_header X-Forwarded-Proto \$scheme;"
echo "       proxy_set_header Host \$host;"
echo "       proxy_set_header Upgrade \$http_upgrade;"
echo "       proxy_set_header Connection \"upgrade\";"
echo ""
echo "Für Vaultwarden:"
echo "   - Domain names: $VAULTWARDEN_SUB.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: vaultwarden"
echo "   - Port: 80"
echo "   - SSL: Request a new SSL Certificate (Let's Encrypt, E-Mail: $EMAIL)"
echo "   - Aktiviere 'Force SSL' und 'HTTP/2 Support'"
echo ""
echo "Für Etherpad:"
echo "   - Domain names: $ETHERPAD_SUB.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: etherpad"
echo "   - Port: 9001"
echo "   - SSL: Request a new SSL Certificate (Let's Encrypt, E-Mail: $EMAIL)"
echo "   - Aktiviere 'Force SSL' und 'HTTP/2 Support'"
echo "   - Advanced Tab: Füge hinzu:"
echo "       proxy_set_header Upgrade \$http_upgrade;"
echo "       proxy_set_header Connection \"upgrade\";"
echo ""
echo "Für GitLab:"
echo "   - Domain names: $GITLAB_SUB.$DOMAIN"
echo "   - Scheme: http"
echo "   - Forward hostname: gitlab"
echo "   - Port: 80"
echo "   - SSL: Request a new SSL Certificate (Let's Encrypt, E-Mail: $EMAIL)"
echo "   - Aktiviere 'Force SSL' und 'HTTP/2 Support'"
echo "   - Advanced Tab: Füge hinzu:"
echo "       proxy_set_header X-Real-IP \$remote_addr;"
echo "       proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
echo "       proxy_set_header X-Forwarded-Proto \$scheme;"
echo "       proxy_set_header Host \$host;"
echo "       proxy_set_header Upgrade \$http_upgrade;"
echo "       proxy_set_header Connection \"upgrade\";"
echo ""
echo "Stelle sicher, dass deine DNS-Einträge ($NEXTCLOUD_SUB.$DOMAIN, $VAULTWARDEN_SUB.$DOMAIN, $ETHERPAD_SUB.$DOMAIN, $GITLAB_SUB.$DOMAIN) auf die öffentliche IP deines Routers zeigen und die Ports 80/443 an $LOCAL_IP weitergeleitet sind."
read -p "Drücke Enter, wenn du die Konfiguration abgeschlossen hast..."

# Abschluss
echo -e "${GREEN}Teil 2 ist fertig!${NC}"
echo -e "${GREEN}Starte dein System bitte neu, damit alles richtig läuft.${NC}"
echo -e "${GREEN}Führe danach 'install_part3.sh' aus, wenn du eine Firewall konfiguriert hast.${NC}"

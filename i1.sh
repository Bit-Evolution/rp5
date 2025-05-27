#!/bin/bash

# Dieses Skript ist der erste Teil der Installation. Es aktualisiert das System,
# installiert Docker und fragt nach Einstellungen wie Domain und Subdomains.

set -e  # Beende Skript bei Fehlern

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Protokolldatei
LOGFILE=~/install_part1.log
exec > >(tee -a $LOGFILE) 2>&1

# Überprüfe sudo-Rechte
if ! sudo -v; then
    echo -e "${RED}Du hast keine sudo-Rechte. Bitte führe das Skript als Benutzer mit sudo-Rechten aus.${NC}"
    exit 1
fi

# Zeige lokale IP-Adresse und Hostnamen an
LOCAL_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -n 1)
if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}Konnte die IP-Adresse nicht finden. Überprüfe deine Netzwerkverbindung.${NC}"
    exit 1
fi
HOSTNAME=$(hostname)
echo -e "${GREEN}Deine lokale IP-Adresse ist: $LOCAL_IP${NC}"
echo -e "${GREEN}Dein aktueller Hostname ist: $HOSTNAME${NC}"

# Frage nach wichtigen Informationen mit Wiederholung bei Fehlern
while true; do
    read -p "Gib deine Domain ein (z.B. meinecloud.de): " DOMAIN
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        echo -e "${RED}Ungültige Domain. Bitte versuche es erneut.${NC}"
    fi
done

while true; do
    read -p "Gib deine E-Mail-Adresse ein (für Let's Encrypt SSL-Zertifikate): " EMAIL
    if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        echo -e "${RED}Ungültige E-Mail-Adresse. Bitte versuche es erneut.${NC}"
    fi
done

# Frage nach Subdomains für die Dienste
echo "Gib die Subdomains für die Dienste ein (z.B. 'cloud' für cloud.meinecloud.de):"
while true; do
    read -p "Subdomain für Nextcloud: " NEXTCLOUD_SUB
    if [ -n "$NEXTCLOUD_SUB" ]; then
        break
    else
        echo -e "${RED}Du musst eine Subdomain für Nextcloud angeben!${NC}"
    fi
done

while true; do
    read -p "Subdomain für Vaultwarden: " VAULTWARDEN_SUB
    if [ -n "$VAULTWARDEN_SUB" ]; then
        break
    else
        echo -e "${RED}Du musst eine Subdomain für Vaultwarden angeben!${NC}"
    fi
done

while true; do
    read -p "Subdomain für Etherpad: " ETHERPAD_SUB
    if [ -n "$ETHERPAD_SUB" ]; then
        break
    else
        echo -e "${RED}Du musst eine Subdomain für Etherpad angeben!${NC}"
    fi
done

while true; do
    read -p "Subdomain für GitLab: " GITLAB_SUB
    if [ -n "$GITLAB_SUB" ]; then
        break
    else
        echo -e "${RED}Du musst eine Subdomain für GitLab angeben!${NC}"
    fi
done

# Frage nach Hostname-Änderung
read -p "Möchtest du den Hostnamen ändern? (j/n): " CONFIG_HOSTNAME
if [ "$CONFIG_HOSTNAME" == "j" ]; then
    while true; do
        read -p "Gib den neuen Hostnamen ein: " NEW_HOSTNAME
        if [ -n "$NEW_HOSTNAME" ]; then
            sudo hostnamectl set-hostname "$NEW_HOSTNAME"
            echo -e "${GREEN}Der Hostname wurde zu $NEW_HOSTNAME geändert.${NC}"
            break
        else
            echo -e "${RED}Der Hostname darf nicht leer sein!${NC}"
        fi
    done
fi

# Frage nach einem Mount-Ordner für Nextcloud-Daten
while true; do
    read -p "Gib den Pfad für den Nextcloud-Datenordner ein (z.B. /mnt/nextcloud_data): " MOUNT_DIR
    if [ -z "$MOUNT_DIR" ]; then
        echo -e "${RED}Du musst einen Pfad angeben!${NC}"
    elif [ ! -d "$MOUNT_DIR" ]; then
        echo -e "${GREEN}Der Ordner $MOUNT_DIR existiert nicht. Ich erstelle ihn jetzt...${NC}"
        sudo mkdir -p "$MOUNT_DIR"
        sudo chown $USER:$USER "$MOUNT_DIR"
        if ! touch "$MOUNT_DIR/testfile" 2>/dev/null; then
            echo -e "${RED}Der Ordner $MOUNT_DIR ist nicht beschreibbar. Bitte wähle einen anderen Pfad.${NC}"
        else
            rm -f "$MOUNT_DIR/testfile"
            break
        fi
    else
        break
    fi
done

read -p "Möchtest du Bluetooth ausschalten? (j/n): " DISABLE_BT
read -p "Möchtest du WiFi ausschalten? (j/n): " DISABLE_WIFI
read -p "Möchtest du eine Firewall konfigurieren? (j/n): " CONFIG_FIREWALL
read -p "Gib deinen DynDNS-Benutzernamen ein: " DYNDNS_USER
if [ -z "$DYNDNS_USER" ]; then
    echo -e "${RED}Du musst einen DynDNS-Benutzernamen angeben!${NC}"
    exit 1
fi
read -s -p "Gib dein DynDNS-Passwort ein: " DYNDNS_PASS
echo
if [ -z "$DYNDNS_PASS" ]; then
    echo -e "${RED}Du musst ein DynDNS-Passwort angeben!${NC}"
    exit 1
fi

# Aktualisiere das System
echo -e "${GREEN}Aktualisiere dein System...${NC}"
sudo apt update && sudo apt upgrade -y

# Installiere grundlegende Programme (jq für JSON-Verarbeitung in install_part2.sh)
echo -e "${GREEN}Installiere Programme, die wir brauchen (curl, git, ufw, jq)...${NC}"
sudo apt install -y curl git ufw jq

# Installiere Docker
echo -e "${GREEN}Installiere Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
echo -e "${GREEN}Hinweis: Du musst dich nach diesem Skript abmelden und wieder anmelden, damit Docker-Befehle ohne sudo laufen!${NC}"

# Installiere Docker Compose
echo -e "${GREEN}Installiere Docker Compose...${NC}"
sudo apt install -y docker-compose

# Erstelle Ordner für Docker-Daten
echo -e "${GREEN}Erstelle Ordner für die Server-Daten...${NC}"
mkdir -p ~/docker/{proxy,nextcloud,vaultwarden,etherpad,gitlab}
sudo chown -R $USER:$USER ~/docker

# Erstelle ein Docker-Netzwerk für den Proxy
echo -e "${GREEN}Erstelle ein Docker-Netzwerk für den Proxy...${NC}"
sg docker -c "docker network create proxy_net" || true

# Speichere die Einstellungen (ohne Passwort)
echo -e "${GREEN}Speichere deine Einstellungen...${NC}"
cat << EOF > ~/config.sh
#!/bin/bash
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
NEXTCLOUD_SUB="$NEXTCLOUD_SUB"
VAULTWARDEN_SUB="$VAULTWARDEN_SUB"
ETHERPAD_SUB="$ETHERPAD_SUB"
GITLAB_SUB="$GITLAB_SUB"
MOUNT_DIR="$MOUNT_DIR"
DISABLE_BT="$DISABLE_BT"
DISABLE_WIFI="$DISABLE_WIFI"
CONFIG_FIREWALL="$CONFIG_FIREWALL"
DYNDNS_USER="$DYNDNS_USER"
CONFIG_HOSTNAME="$CONFIG_HOSTNAME"
NEW_HOSTNAME="$NEW_HOSTNAME"
EOF
chmod 600 ~/config.sh

# Abschluss
echo -e "${GREEN}Teil 1 ist fertig!${NC}"
echo -e "${GREEN}Bitte melde dich ab und wieder an, damit Docker richtig funktioniert.${NC}"
echo -e "${GREEN}Danach führe 'install_part2.sh' aus.${NC}"

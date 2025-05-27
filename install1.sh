#!/bin/bash

# Dieses Skript ist der erste Teil der Installation. Es aktualisiert dein System, 
# installiert wichtige Programme wie Docker und fragt dich nach einigen Einstellungen, 
# die später benötigt werden.

# Farben für die Ausgabe, damit es übersichtlicher aussieht
RED='\033[0;31m'  # Rot für Fehlermeldungen
GREEN='\033[0;32m'  # Grün für Erfolgsmeldungen
NC='\033[0m'  # Keine Farbe, um zurückzusetzen

# Eine kleine Hilfsfunktion, die prüft, ob der letzte Befehl erfolgreich war
check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Etwas ist schiefgelaufen. Das Skript wird abgebrochen.${NC}"
        exit 1
    fi
}

# Zeige die lokale IP-Adresse und den Hostnamen an
# Die IP-Adresse wird automatisch vom Netzwerk (DHCP) bezogen
LOCAL_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}Konnte die IP-Adresse nicht finden. Überprüfe deine Netzwerkverbindung.${NC}"
    exit 1
fi
HOSTNAME=$(hostname)
echo -e "${GREEN}Deine lokale IP-Adresse ist: $LOCAL_IP${NC}"
echo -e "${GREEN}Dein aktueller Hostname ist: $HOSTNAME${NC}"

# Frage nach wichtigen Informationen
echo "Ich brauche jetzt ein paar Angaben von dir:"
read -p "Gib deine Domain ein (z.B. meinecloud.de): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Du musst eine Domain angeben!${NC}"
    exit 1
fi

read -p "Gib deine E-Mail-Adresse ein (für sichere HTTPS-Zertifikate): " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}Du musst eine E-Mail-Adresse angeben!${NC}"
    exit 1
fi

# Frage, ob der Hostname geändert werden soll
read -p "Möchtest du den Hostnamen ändern? (j/n): " CONFIG_HOSTNAME
if [ "$CONFIG_HOSTNAME" == "j" ]; then
    read -p "Gib den neuen Hostnamen ein: " NEW_HOSTNAME
    if [ -z "$NEW_HOSTNAME" ]; then
        echo -e "${RED}Der Hostname darf nicht leer sein!${NC}"
        exit 1
    fi
    sudo hostnamectl set-hostname "$NEW_HOSTNAME"
    check_success
    echo -e "${GREEN}Der Hostname wurde zu $NEW_HOSTNAME geändert.${NC}"
fi

# Frage nach einem Mount-Ordner für Nextcloud-Daten
read -p "Gib den Pfad für den Nextcloud-Datenordner ein (z.B. /mnt/nextcloud_data): " MOUNT_DIR
if [ -z "$MOUNT_DIR" ]; then
    echo -e "${RED}Du musst einen Pfad angeben!${NC}"
    exit 1
fi
if [ ! -d "$MOUNT_DIR" ]; then
    echo -e "${GREEN}Der Ordner $MOUNT_DIR existiert nicht. Ich erstelle ihn jetzt...${NC}"
    sudo mkdir -p "$MOUNT_DIR"
    check_success
fi

read -p "Möchtest du Bluetooth ausschalten? (j/n): " DISABLE_BT
read -p "Möchtest du WiFi ausschalten? (j/n): " DISABLE_WIFI
read -p "Verwendest du Raspberry Pi OS mit Desktop? (j/n): " USE_DESKTOP
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

# Aktualisiere das System, damit alles auf dem neuesten Stand ist
echo -e "${GREEN}Aktualisiere dein System...${NC}"
sudo apt update && sudo apt upgrade -y
check_success

# Installiere ein paar wichtige Programme
echo -e "${GREEN}Installiere Programme, die wir brauchen...${NC}"
sudo apt install -y curl git ufw
check_success

# Installiere Docker (damit wir die Server in Containern laufen lassen können)
echo -e "${GREEN}Installiere Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
check_success
sudo usermod -aG docker $USER
echo -e "${GREEN}Hinweis: Du musst dich nach diesem Skript abmelden und wieder anmelden!${NC}"

# Installiere Docker Compose (hilft uns, mehrere Container zu verwalten)
echo -e "${GREEN}Installiere Docker Compose...${NC}"
sudo apt install -y docker-compose
check_success

# Erstelle Ordner für die Docker-Daten
echo -e "${GREEN}Erstelle Ordner für die Server-Daten...${NC}"
mkdir -p ~/docker/{proxy,nextcloud,vaultwarden,etherpad}
check_success

# Erstelle ein Netzwerk für den Proxy
echo -e "${GREEN}Erstelle ein Docker-Netzwerk für den Proxy...${NC}"
sg docker -c "docker network create proxy_net" || true  # Fehler ignorieren, falls es schon existiert
check_success

# Speichere die Einstellungen in einer Datei
echo -e "${GREEN}Speichere deine Einstellungen...${NC}"
cat << EOF > ~/config.sh
#!/bin/bash
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
MOUNT_DIR="$MOUNT_DIR"
DISABLE_BT="$DISABLE_BT"
DISABLE_WIFI="$DISABLE_WIFI"
USE_DESKTOP="$USE_DESKTOP"
DYNDNS_USER="$DYNDNS_USER"
DYNDNS_PASS="$DYNDNS_PASS"
CONFIG_HOSTNAME="$CONFIG_HOSTNAME"
NEW_HOSTNAME="$NEW_HOSTNAME"
EOF
check_success

# Fertig mit Teil 1
echo -e "${GREEN}Teil 1 ist fertig!${NC}"
echo -e "${GREEN}Bitte melde dich ab und wieder an, damit Docker richtig funktioniert.${NC}"
echo -e "${GREEN}Danach führe 'install_part2.sh' aus.${NC}"

#!/bin/bash

# Farben für die Ausgabe definieren
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Funktion zum Überprüfen des letzten Befehls
check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Fehler bei der Ausführung des letzten Befehls. Skript wird abgebrochen.${NC}"
        exit 1
    fi
}

# Automatische Erkennung der lokalen IP-Adresse
LOCAL_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}Konnte lokale IP-Adresse nicht ermitteln. Bitte überprüfe die Netzwerkverbindung.${NC}"
    exit 1
fi

# Benutzerabfragen mit Eingabevalidierung
read -p "Gib deine Domain ein (z.B. example.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain darf nicht leer sein.${NC}"
    exit 1
fi

read -p "Gib deine E-Mail-Adresse ein (für Let's Encrypt): " EMAIL
if [ -z "$EMAIL" ]; then
    echo -e "${RED}E-Mail-Adresse darf nicht leer sein.${NC}"
    exit 1
fi

read -p "Möchtest du das Netzwerk manuell konfigurieren? (y/n): " SET_NETWORK_MANUALLY
if [ "$SET_NETWORK_MANUALLY" == "y" ]; then
    read -p "Gib die statische IP-Adresse ein (z.B. 192.168.1.100): " STATIC_IP
    if [ -z "$STATIC_IP" ]; then
        echo -e "${RED}Statische IP darf nicht leer sein.${NC}"
        exit 1
    fi
    read -p "Gib das Gateway ein (z.B. 192.168.1.1): " GATEWAY
    if [ -z "$GATEWAY" ]; then
        echo -e "${RED}Gateway darf nicht leer sein.${NC}"
        exit 1
    fi
    read -p "Gib die DNS-Server ein (z.B. 192.168.1.1,8.8.8.8): " DNS_SERVERS
    if [ -z "$DNS_SERVERS" ]; then
        echo -e "${RED}DNS-Server dürfen nicht leer sein.${NC}"
        exit 1
    fi
else
    STATIC_IP=$LOCAL_IP
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    DNS_SERVERS=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}' | paste -sd "," -)
fi

read -p "Möchtest du Bluetooth deaktivieren? (y/n): " DISABLE_BT
read -p "Möchtest du WiFi deaktivieren? (y/n): " DISABLE_WIFI
read -p "Verwendest du Raspberry Pi OS mit Desktop? (y/n): " USE_DESKTOP
read -p "Gib deinen DynDNS-Benutzernamen ein: " DYNDNS_USER
if [ -z "$DYNDNS_USER" ]; then
    echo -e "${RED}DynDNS-Benutzername darf nicht leer sein.${NC}"
    exit 1
fi
read -s -p "Gib dein DynDNS-Passwort ein: " DYNDNS_PASS
echo
if [ -z "$DYNDNS_PASS" ]; then
    echo -e "${RED}DynDNS-Passwort darf nicht leer sein.${NC}"
    exit 1
fi

# System aktualisieren
echo -e "${GREEN}Aktualisiere das System...${NC}"
sudo apt update && sudo apt upgrade -y
check_success

# Erforderliche Pakete installieren
echo -e "${GREEN}Installiere erforderliche Pakete...${NC}"
sudo apt install -y curl git ufw
check_success

# Docker und Docker Compose installieren
echo -e "${GREEN}Installiere Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
check_success
sudo usermod -aG docker $USER
echo -e "${GREEN}Hinweis: Du musst dich abmelden und wieder anmelden, um die Gruppenänderung zu übernehmen.${NC}"

echo -e "${GREEN}Installiere Docker Compose...${NC}"
sudo apt install -y docker-compose
check_success

# Verzeichnisse für Docker-Daten erstellen
echo -e "${GREEN}Erstelle Verzeichnisse für Docker-Daten...${NC}"
mkdir -p ~/docker/{proxy,caprover,nextcloud,bitwarden,etherpad}
check_success

# Docker-Netzwerk für Proxy erstellen
echo -e "${GREEN}Erstelle Docker-Netzwerk proxy_net...${NC}"
sg docker -c "docker network create proxy_net" || true # Ignoriere Fehler, falls Netzwerk bereits existiert
check_success

# Variablen in config.sh speichern
echo -e "${GREEN}Speichere Konfigurationsvariablen...${NC}"
cat << EOF > ~/config.sh
#!/bin/bash
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
STATIC_IP="$STATIC_IP"
GATEWAY="$GATEWAY"
DNS_SERVERS="$DNS_SERVERS"
DISABLE_BT="$DISABLE_BT"
DISABLE_WIFI="$DISABLE_WIFI"
USE_DESKTOP="$USE_DESKTOP"
DYNDNS_USER="$DYNDNS_USER"
DYNDNS_PASS="$DYNDNS_PASS"
SET_NETWORK_MANUALLY="$SET_NETWORK_MANUALLY"
EOF
check_success

# Abschlussmeldung
echo -e "${GREEN}Teil 1 der Installation abgeschlossen!${NC}"
echo -e "${GREEN}Bitte melde dich ab und wieder an, um die Docker-Gruppenänderung zu übernehmen.${NC}"
echo -e "${GREEN}Führe danach 'install_part2.sh' aus.${NC}"

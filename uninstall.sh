#!/bin/bash

# Farben für die Ausgabe definieren
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Funktion zum Überprüfen des letzten Befehls
check_success() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Fehler bei der Ausführung des letzten Befehls. Fortfahren? (y/n)${NC}"
        read -p "" CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            echo -e "${RED}Deinstallation abgebrochen.${NC}"
            exit 1
        fi
    fi
}

# Sicherheitsabfrage vor Beginn der Deinstallation
echo -e "${RED}WICHTIG: Dieses Skript entfernt alle installierten Dienste, Docker, Konfigurationen und Datenverzeichnisse."
echo -e "Daten in ~/docker (z.B. Nextcloud, Vaultwarden, Etherpad) werden GELÖSCHT, es sei denn, du wählst 'n' bei der Abfrage."
echo -e "Bitte sichere wichtige Daten vorher!${NC}"
read -p "Möchtest du fortfahren? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo -e "${RED}Deinstallation abgebrochen.${NC}"
    exit 1
fi

# --- Docker-Dienste stoppen und entfernen ---
echo -e "${GREEN}Stoppe und entferne Docker-Container...${NC}"
for container in nginx-proxy-manager caprover nextcloudpi vaultwarden etherpad dyndns; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        docker stop "$container" >/dev/null 2>&1
        docker rm "$container" >/dev/null 2>&1
        echo -e "${GREEN}Container $container entfernt.${NC}"
    fi
done
check_success

# --- Docker-Netzwerk entfernen ---
echo -e "${GREEN}Entferne Docker-Netzwerk proxy_net...${NC}"
if docker network ls --format '{{.Name}}' | grep -q "^proxy_net$"; then
    docker network rm proxy_net >/dev/null 2>&1
    check_success
fi

# --- Docker und Docker Compose deinstallieren ---
echo -e "${GREEN}Deinstalliere Docker und Docker Compose...${NC}"
sudo apt purge -y docker.io docker-compose docker >/dev/null 2>&1
sudo apt autoremove -y >/dev/null 2>&1
sudo rm -f /usr/local/bin/docker-compose
sudo rm -rf /var/lib/docker
sudo groupdel docker >/dev/null 2>&1
check_success

# --- Entferne Docker-Installationsskript ---
echo -e "${GREEN}Entferne Docker-Installationsskript...${NC}"
rm -f ~/get-docker.sh
check_success

# --- Entferne Datenverzeichnisse (mit Bestätigung) ---
echo -e "${GREEN}Soll das Verzeichnis ~/docker mit allen Daten (z.B. Nextcloud, Vaultwarden, Etherpad) gelöscht werden?${NC}"
read -p "Löschen? (y/n): " DELETE_DATA
if [ "$DELETE_DATA" == "y" ]; then
    echo -e "${GREEN}Entferne Docker-Datenverzeichnisse...${NC}"
    rm -rf ~/docker
    check_success
else
    echo -e "${GREEN}Datenverzeichnisse werden beibehalten: ~/docker${NC}"
fi

# --- Statische IP-Konfiguration rückgängig machen ---
echo -e "${GREEN}Entferne statische IP-Konfiguration...${NC}"
if [ -f /etc/cron.d/set_static_ip ]; then
    sudo rm -f /etc/cron.d/set_static_ip
    check_success
fi
if [ -f ~/set_static_ip.sh ]; then
    rm -f ~/set_static_ip.sh
    check_success
fi
if grep -q "interface eth0" /etc/dhcpcd.conf; then
    sudo sed -i '/interface eth0/,/static domain_name_servers/d' /etc/dhcpcd.conf
    sudo systemctl restart dhcpcd
    check_success
fi

# --- Bluetooth- und WiFi-Deaktivierung rückgängig machen ---
echo -e "${GREEN}Stelle Bluetooth- und WiFi-Konfigurationen wieder her...${NC}"
if grep -q "dtoverlay=disable-bt" /boot/config.txt; then
    sudo sed -i '/dtoverlay=disable-bt/d' /boot/config.txt
    check_success
fi
if grep -q "dtoverlay=disable-wifi" /boot/config.txt; then
    sudo sed -i '/dtoverlay=disable-wifi/d' /boot/config.txt
    check_success
fi

# --- DynDNS-Client entfernen ---
echo -e "${GREEN}Entferne DynDNS-Client...${NC}"
if docker ps -a --format '{{.Names}}' | grep -q "^dyndns$"; then
    docker stop dyndns >/dev/null 2>&1
    docker rm dyndns >/dev/null 2>&1
    check_success
fi

# --- Firewall-Regeln zurücksetzen (falls Desktop-Sicherheit aktiviert) ---
echo -e "${GREEN}Setze Firewall-Regeln zurück (falls UFW installiert)...${NC}"
if command -v ufw >/dev/null 2>&1; then
    sudo ufw --force reset >/dev/null 2>&1
    sudo ufw disable >/dev/null 2>&1
    check_success
fi
if [ -f ~/secure_desktop.sh ]; then
    rm -f ~/secure_desktop.sh
    check_success
fi

# --- Entferne zusätzliche Pakete ---
echo -e "${GREEN}Entferne zusätzliche Pakete (curl, git, ufw)...${NC}"
sudo apt purge -y curl git ufw >/dev/null 2>&1
sudo apt autoremove -y >/dev/null 2>&1
check_success

# --- Abschlussmeldung ---
echo -e "${GREEN}Deinstallation abgeschlossen!${NC}"
echo -e "${GREEN}WICHTIG: Ein Neustart ist erforderlich, um alle Änderungen (z.B. Bluetooth/WiFi, Netzwerk) anzuwenden:${NC}"
echo -e "  sudo reboot"
echo -e "${GREEN}Hinweis: Falls du Daten in ~/docker behalten hast, überprüfe diese und lösche sie manuell, wenn nicht mehr benötigt.${NC}"

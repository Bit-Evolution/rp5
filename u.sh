#!/bin/bash

# Dieses Skript deinstalliert alle Komponenten der Installationsskripte.
# Es entfernt Docker-Container, Images, Netzwerke, Pakete, Ordner und Konfigurationen.
# Achtung: Alle Daten in ~/docker werden gelöscht! Sichere wichtige Daten vorher.

set -e

# Farben für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Warnung vor Datenverlust
echo -e "${RED}Warnung: Dieses Skript entfernt alle Docker-Daten und Konfigurationen in ~/docker!${NC}"
read -p "Möchtest du fortfahren? (j/n): " CONFIRM
if [ "$CONFIRM" != "j" ]; then
    echo -e "${RED}Deinstallation abgebrochen.${NC}"
    exit 1
fi

# Prüfe, ob der Benutzer in der Docker-Gruppe ist
if ! groups | grep -q docker; then
    echo -e "${RED}Du bist nicht in der Docker-Gruppe. Docker-Befehle benötigen sudo (Passwortabfrage).${NC}"
    DOCKER_PREFIX="sudo "
else
    DOCKER_PREFIX=""
fi

# Stoppe und entferne alle Docker-Container
echo -e "${GREEN}Stoppe und entferne Docker-Container...${NC}"
${DOCKER_PREFIX}docker stop $(${DOCKER_PREFIX}docker ps -a -q) || true
${DOCKER_PREFIX}docker rm $(${DOCKER_PREFIX}docker ps -a -q) || true

# Entferne alle Docker-Images
echo -e "${GREEN}Entferne Docker-Images...${NC}"
${DOCKER_PREFIX}docker rmi $(${DOCKER_PREFIX}docker images -q) || true

# Entferne ungenutzte Docker-Volumen
echo -e "${GREEN}Entferne ungenutzte Docker-Volumen...${NC}"
${DOCKER_PREFIX}docker volume prune -f || true

# Entferne das Docker-Netzwerk
echo -e "${GREEN}Entferne Docker-Netzwerk...${NC}"
${DOCKER_PREFIX}docker network rm proxy_net || true

# Deinstalliere Docker und Docker Compose
echo -e "${GREEN}Deinstalliere Docker und Docker Compose...${NC}"
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-compose jq
sudo apt autoremove -y

# Entferne den Benutzer aus der Docker-Gruppe
echo -e "${GREEN}Entferne Benutzer aus der Docker-Gruppe...${NC}"
sudo gpasswd -d $USER docker || true

# Entferne die erstellten Ordner
echo -e "${GREEN}Entferne erstellte Ordner...${NC}"
rm -rf ~/docker

# Entferne Konfigurationsdateien
echo -e "${GREEN}Entferne Konfigurationsdateien...${NC}"
rm -f ~/config.sh

# Entferne Bluetooth- und WiFi-Konfigurationen
if grep -q "dtoverlay=disable-bt" /boot/config.txt; then
    echo -e "${GREEN}Entferne Bluetooth-Konfiguration...${NC}"
    sudo sed -i '/dtoverlay=disable-bt/d' /boot/config.txt
fi
if grep -q "dtoverlay=disable-wifi" /boot/config.txt; then
    echo -e "${GREEN}Entferne WiFi-Konfiguration...${NC}"
    sudo sed -i '/dtoverlay=disable-wifi/d' /boot/config.txt
fi
# Stelle config.txt aus Backup wieder her, falls vorhanden
if [ -f /boot/config.txt.bak ]; then
    echo -e "${GREEN}Stelle /boot/config.txt aus Backup wieder her...${NC}"
    sudo mv /boot/config.txt.bak /boot/config.txt
fi

# Setze die Firewall zurück, falls sie eingerichtet wurde
if [ -f ~/secure_desktop.sh ]; then
    echo -e "${GREEN}Entferne spezifische Firewall-Regeln...${NC}"
    sudo ufw delete allow 80/tcp || true
    sudo ufw delete allow 443/tcp || true
    sudo ufw delete allow 22/tcp || true
    sudo ufw disable
    rm -f ~/secure_desktop.sh
fi

# Abschluss
echo -e "${GREEN}Deinstallation abgeschlossen!${NC}"
echo -e "${GREEN}Alle Komponenten wurden entfernt. Starte dein System bitte neu.${NC}"

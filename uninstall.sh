#!/bin/bash

# Dieses Skript deinstalliert alle Komponenten, die durch die Installationsskripte eingerichtet wurden.
# Es entfernt Docker-Container, Images, Netzwerke, installierte Pakete, Ordner und Konfigurationen.

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

# Stoppe und entferne alle Docker-Container
echo -e "${GREEN}Stoppe und entferne Docker-Container...${NC}"
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)
check_success

# Entferne alle Docker-Images
echo -e "${GREEN}Entferne Docker-Images...${NC}"
docker rmi $(docker images -q)
check_success

# Entferne das Docker-Netzwerk
echo -e "${GREEN}Entferne Docker-Netzwerk...${NC}"
docker network rm proxy_net
check_success

# Deinstalliere Docker und Docker Compose
echo -e "${GREEN}Deinstalliere Docker und Docker Compose...${NC}"
sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-compose
sudo apt autoremove -y
check_success

# Entferne die erstellten Ordner
echo -e "${GREEN}Entferne erstellte Ordner...${NC}"
rm -rf ~/docker
check_success

# Entferne die Konfigurationsdatei
echo -e "${GREEN}Entferne Konfigurationsdatei...${NC}"
rm -f ~/config.sh
check_success

# Setze die Firewall zurück, falls sie eingerichtet wurde
if [ -f ~/secure_desktop.sh ]; then
    echo -e "${GREEN}Setze Firewall zurück...${NC}"
    sudo ufw disable
    sudo ufw reset
    rm -f ~/secure_desktop.sh
    check_success
fi

# Fertig mit der Deinstallation
echo -e "${GREEN}Deinstallation abgeschlossen!${NC}"
echo -e "${GREEN}Alle Komponenten wurden entfernt.${NC}"

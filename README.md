# Tasmota32-remora
Application écrit en berry pour le gestionnaire de fil pilote remora fonctionnant sur firmware Tasmota.
Inspiré de https://github.com/Beormund/Tasmota32-Multi-Zone-Heating-Controller et du code source original https://github.com/hallard/remora_soft

## Fonctions
  - petit driver I2C pour commander le circuit mcp23017.
  - ajout sur l'interface web l'état des fils pilotes et boutons pour les piloter.
  - commande dans la console setfp permettant de les piloter avec des rules ou avec des commandes http.

## Prérequis
  - une carte remora sauf pour la version démo.
  - un esp32. Les esp8266 ne peuvent pas faire tourner les scripts berry.
  - firmware tasmota32 prenant en charge l'I2C, la téléinfo, les scripts berry. Un est disponible dans le dossier tasmota_firmware.
  - un module horloge rtc conseillé pour utiliser la programmation horaire.

## Installation
  - flasher le firmware sur l'esp32.
  - configurer les GPIOs de l'interface I2C et téléinfo.
  - envoyer le fichier remora.tapp dans Console > gestionnaire de fichier.

## Configuration
  3 sous menus sont ajoutés dans la page configuration de tasmota :<br>
  - Configurations des fils pilotes. Choisir les sorties fil pilote utilisées, les nommées.
  - Configuration remora. Réglage du délestage, utilisation du relais.
  - Programmation horaire. Facultatif, programmer des heures de changement d'ordre, programmer une dérogation (par exemple si on part en vacance).
 
## Utilisation


## TODO
  - <strike>gérer les modes eco-1 et eco-2. Reprendre la solution sur : https://github.com/bronco0/remora_soft</strike>
  - gérer les autres composants de la remora : le relais, les leds. Fait mais non testé en réel.
  - faire remonter les commandes et états en mqtt. Fait pour les états mais non testé en réel.
  - <strike>créer une commande de délestage. Soit enclenché par la téléinfo soit par un autre capteur de puissance.</strike>
  - <strike>avoir la possibilité de renommer les fils pilotes et régler le nombre utilisé, la compatibilité ou non des modes eco -1 et -2.</strike>
  - <strike>créer une programmation horaire. Comme celui de Tasmota32-Multi-Zone-Heating-Controller.</strike>
  - gérer un écran tactile.

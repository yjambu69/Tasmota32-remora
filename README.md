# Tasmota32-remora
Application écrit en berry pour le gestionnaire de fil pilote remora fonctionnant sur firmware Tasmota.
Inspiré de https://github.com/Beormund/Tasmota32-Multi-Zone-Heating-Controller

## Fonctions
  - petit driver I2C pour commander le circuit mcp23017.
  - ajout sur l'interface web l'état des fils pilotes et boutons pour les piloter.
  - commande dans la console setfp permettant de les piloters avec des rules ou avec des commandes http.

## Prérequis
  - une carte remora.
  - un esp32. Les esp8266 ne peuvent pas faire tourner les scripts berry.
  - firmware tasmota32 prenant en charge l'I2C, la téléinfo, les scripts berry. Un de disponible dans le dossier bin.

## Installation
  - flasher le firmware sur l'esp32.
  - configurer les GPIOs de l'interface I2C et téléinfo.
  - envoyer le fichier remora.tapp dans Console > gestionnaire de fichier.

## TODO
  - gerer les modes eco-1 et eco-2.
  - gerer les autres composants de la remora : le relais, les leds.
  - faire remonter les commandes et états en mqtt.
  - créer une commande de délestage. Soit enclenché par la téléinfo soit dans une rule avec un autre capteur de puissance.
  - créer un programmateur horaire. Comme celui de Tasmota32-Multi-Zone-Heating-Controller.
  - gérer un écran tactile.

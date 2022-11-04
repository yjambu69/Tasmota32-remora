# Tasmota32-remora
Application écrit en berry pour le gestionnaire de fil pilote remora fonctionnant sur firmware Tasmota.
Inspiré de https://github.com/Beormund/Tasmota32-Multi-Zone-Heating-Controller et du code source original https://github.com/hallard/remora_soft

## Fonctions
  - petit driver I2C pour commander le circuit mcp23017.
  - ajout sur l'interface web l'état des fils pilotes. En jaune délesté, en rouge dérogation manuelle, en blanc suivant le programme horaire.
  - ajout sur l'interface web de menus déroulants pour les piloter en manuel ou les remettre sur auto (programmation horaire).
  - commande dans la console setfp permettant de les piloter en dérogation manuelle avec des rules ou avec des commandes http.
  - délestage cascadocyclique des fils qui ont un ordre différent d'arrêt ou de hors gel.

## Prérequis
  - une carte remora sauf pour la version démo.
  - un esp32. Les esp8266 ne peuvent pas faire tourner les scripts berry.
  - firmware tasmota32 prenant en charge l'I2C, la téléinfo, les scripts berry. Un est disponible dans le dossier tasmota_firmware.
  - un module horloge rtc conseillé pour utiliser la programmation horaire. (perte de l'heure si redémarrage sans internet fonctionnel)

## Installation
  - flasher le firmware sur l'esp32.
  - configurer les GPIOs de l'interface I2C et téléinfo.
  - envoyer le fichier remora.tapp dans Console > gestionnaire de fichier.

## Configuration
  3 sous menus sont ajoutés dans la page configuration de tasmota :<br>
  - Configurations des fils pilotes. Choisir les sorties fil pilote utilisées, les nommés.
  - Configuration remora. Réglage du délestage, utilisation du relais.
  - Programmation horaire. Facultatif, programmer des heures de changement d'ordre, programmer une dérogation (par exemple si on part en vacance).
  
## Utilisation
  - Remora en mode autonome, mettre tout les fils pilotes sur auto et renseigner les programmes horaires.
  - Remora en mode supervisé, passer les commandes depuis une box domotique par requette http.<br>
    http://IP_DE_LA_REMORA/cm?cmnd=setfp%20<paramètres ex:0C ou AAA-CE><br>
    exemples :<br>
    http://IP_DE_LA_REMORA/cm?cmnd=setfp%202E > 2E fil pilote 2 (2) sur éco (E)<br>
    http://IP_DE_LA_REMORA/cm?cmnd=setfp%200C > 0C tous les fils pilotes (0) sur confort (C)<br>
    http://IP_DE_LA_REMORA/cm?cmnd=setfp%20AAA-CE > 3 premiers fils sur arrêt (A) ne rien faire pour le 4, le 5 sur confort, le 6 sur éco<br>
    Ordre A arrêt, H hors gel, C confort, E éco, 1 eco -1, 2 éco -2. (si éco -1 et -2 non déclaré comme supporté passage sur éco)
 
## TODO
  - Rendre le code plus propre !
  - Sortir du persist la programmation horaire et la mettre dans un fichier à part en json.
  - Revoir la page de programmation horaire pour plus de lisibilité. Piste : synthèse sur une page des déclenchements pour une semaine.
  - Créer des groupes de fil pilote.
  - Gérer les abonnements triphasés, délestages indépendants pour chaque phase.
  - <strike>gérer les modes eco-1 et eco-2. Reprendre la solution sur : https://github.com/bronco0/remora_soft</strike>
  - gérer les autres composants de la remora : le relais, les leds. Fait mais non testé en réel.
  - faire remonter les commandes et états en mqtt. Fait pour les états mais non testé en réel.
  - <strike>créer une commande de délestage. Soit enclenché par la téléinfo soit par un autre capteur de puissance.</strike>
  - <strike>avoir la possibilité de renommer les fils pilotes et régler le nombre utilisé, la compatibilité ou non des modes eco -1 et -2.</strike>
  - <strike>créer une programmation horaire. Comme celui de Tasmota32-Multi-Zone-Heating-Controller.</strike>
  - gérer un écran tactile.

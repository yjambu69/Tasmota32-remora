int NB_FP = 7 # nombre de fil pilote physique
list int SortiesFP = [14,15,12,13,10,11,1,0,3,2,5,4,7,6] # pins du mcp23037 pour chaque fils pilotes [FP1 (14,15), FP2 (12,13),...]
int LED_PIN = 8
int RELAIS_PIN = 9
modes = ['C','A','E','H','1','2','D']	# C=Confort, A=Arrêt, E=Eco, H=Hors gel, 1=Eco-1, 2=Eco-2, D=delesté
var nivDelest = 0 # Niveau de délestage actuel (par défaut = 0 pas de délestage)
var maxnivDelest = 0 # Niveau de délestage maximum atteint
var plusAncienneZoneDelestee = 1 # Numéro de la zone qui est délestée depuis le plus de temps entre 1 et nombre de zones configurées size(fps)
timer_delestage = 60000 # 60000 1min valeur de la temporisation pour faire tourner les délestages
var fps
fps = []

import string
import json
import persist

class fp : list
	var nom, phy_id, etat, etat_mem, conf12, pin1, pin2
	def init(nom, phy_id, conf12)
		self.nom = nom
		self.phy_id = phy_id #1 à 7 n° de fil pilote correspondant au bornier
		self.conf12 = conf12 # support des modes éco -1 et -2
		self.etat = 'H'
		self.etat_mem = 'H' # état mémorisé lors du passage au délestage pour reprendre son état après relestage
		self.pin1 = SortiesFP[phy_id*2-2] # correspondance pin sur le mcp23017
		self.pin2 = SortiesFP[phy_id*2-1]
	end
end

if persist.has('fps')
	if persist.fps != []
		for i:0..size(persist.fps)-1
			fps.push(fp(persist.fps[i][0],int(persist.fps[i][1]),bool(persist.fps[i][2])))
		end
	end
end

#- ======================================================================
positionne les GPIOs associés au n° du fil pilote exemple : 
setfp(1,'A') > fil pilote 1 sur arrêt
setfp(0,'E') > tous les fils pilotes sur eco
====================================================================== -#

def setfp(FP, value)
	if FP == 0
		for i:1..size(fps)
			setfp(i, value)
		end
	else
		if value == 'C'
			mcp23017.cmd_pin(fps[FP-1].pin1,0)
			mcp23017.cmd_pin(fps[FP-1].pin2,0)
		elif value == 'A'
			mcp23017.cmd_pin(fps[FP-1].pin1,0)
			mcp23017.cmd_pin(fps[FP-1].pin2,1)
		elif value == '1' || value == '2' || value == 'E'
			mcp23017.cmd_pin(fps[FP-1].pin1,1)
			mcp23017.cmd_pin(fps[FP-1].pin2,1)
			if !fps[FP-1].conf12 value = 'E' end # si eco -1 et -2 non supporté les fils pilotes sont mis sur eco
		elif value == 'H' || value == 'D'
			mcp23017.cmd_pin(fps[FP-1].pin1,1)
			mcp23017.cmd_pin(fps[FP-1].pin2,0)
		end
	fps[FP-1].etat = value
	end
end

# passe un fil pilote à l'ordre suivant de la liste modes 'C','A','E','H','1','2'
# exemple : FP1 est à C il passe à A
def inc_etat_FP(FP)
	if fps[FP-1].etat != 'D'
		if fps[FP-1].conf12
			setfp(FP,modes[ (((modes.find(fps[FP-1].etat)+1) % 6)+1)-1 ])
		else
			setfp(FP,modes[ (((modes.find(fps[FP-1].etat)+1) % 4)+1)-1 ])
		end
	end
end

def etats_FP() # retourne l'état des fils pilotes dans ce format [FP1=A,FP2=A,FP3=E...]
	var msg
	msg='['
	for i:1..size(fps)
		if i > 1 msg += ',' end
		msg += 'FP'+str(fps[i-1].phy_id)+'='+fps[i-1].etat
	end
	msg +=']'
	return msg
end

#- ======================================================================
commande dans la console usage et utilisable en http (http://<ip de la remora>/cm?cmnd=setfp%20<paramètres ex:0C ou AAA-CE>):
setfp 1A > met le fil pilote 1 sur arrêt
setfp 0E > met tous les fils pilote sur eco
setfp AE > met fil pilote 1 sur arrêt 2 sur eco
setfp A-----C > met fil pilote 1 sur arrêt 7 sur confort,
le tiret peut être remplacer par n'importe quelle autre caractère tant que ce n'est pas 1 à 7 ou C,A,E,H,1,2
attention à les commandes 1 et 11 12 2 21 22 sont abigües 11 par exemple peut signifier mettre le fil1 sur eco-1 ou fil1 et fil2 sur eco-1
pour y palier les commandes pour positionner plusieurs fils pilotes devront être composé d'au moins 3 caractères.
exemple : 11- pour fil 1 et 2 sur eco -1, 11 pour juste le fil pilote sur eco -1
====================================================================== -#

def cmd_setfp(cmd, idx, payload, payload_json)
	if payload == ""  # setfp sans arguments
		tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
	elif size(payload) > 2 && size(payload) <= size(fps) # commande de plus de 3 caractères = positionnement d'un trait des fils pilotes
		for i:0..size(payload)-1
			if modes.find(payload[i]) != nil
				setfp(i+1,payload[i])
			end
		end
	tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
	elif size(payload) == 2 && int(payload[0]) >= 0 && int(payload[0]) <= size(fps) # commande à 2 caractères
		if modes.find(payload[1]) != nil
			setfp(int(payload[0]),payload[1])
			tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
		else
			tasmota.resp_cmnd('{"setfp" : "paramètres invalides"}') # erreur de saisie des paramètres
		end
	else
		tasmota.resp_cmnd('{"setfp" : "paramètres invalides"}') # erreur de saisie des paramètres
	end
end

# DEBUT GENERATION DES SIGNAUX POUR LES MODES ECO -1 et -2

def timer_3s()
	for i:1..size(fps)
		if fps[i-1].etat == '1'
			mcp23017.cmd_pin(fps[i-1].pin1,0)
			mcp23017.cmd_pin(fps[i-1].pin2,0)
		end
	end
end

def timer_7s()
	for i:1..size(fps)
		if fps[i-1].etat == '2'
			mcp23017.cmd_pin(fps[i-1].pin1,0)
			mcp23017.cmd_pin(fps[i-1].pin2,0)
		end
	end
end

def timer_5m()
	for i:1..size(fps)
		if fps[i-1].etat == '1' || fps[i-1].etat == '2'
			mcp23017.cmd_pin(fps[i-1].pin1,1)
			mcp23017.cmd_pin(fps[i-1].pin2,1)
		end
	end
	tasmota.set_timer(300000, timer_5m) #relance la fonction dans 5 minutes
	tasmota.set_timer(3000, timer_3s) # remet les pins à 0 dans 3s pour les fils pilotes en eco -1 
	tasmota.set_timer(7000, timer_7s) # remet les pins à 0 dans 7s pour les fils pilotes en eco -2
end

# FIN GENERATION DES SIGNAUX POUR LES MODES ECO -1 et -2

# DEBUT GESTION DU DELESTAGE

#- ======================================================================
Function: delester1zone
Purpose : déleste une zone de plus
Input   : variables globales nivDelest et plusAncienneZoneDelestee
Output  : màj variable globale nivDelest
Comments: code repris sur https://github.com/hallard/remora_soft
====================================================================== -#

def delester1zone(decalage)
	var FP
	if nivDelest == 0 && !decalage # ne tient pas compte si la commande est lancée depuis la fonction decalerDelestage
		log('délestage enclenché',1)
	end
	if nivDelest < size(fps) #On s'assure que l'on n'est pas au niveau max
		nivDelest +=1
		FP = ((plusAncienneZoneDelestee-1 + nivDelest-1) % size(fps))+1
		fps[FP-1].etat_mem = fps[FP-1].etat # mémorise l'état du fil pilote avant le délestage
		setfp(FP, 'D')
		log('fil pilote '+fps[FP-1].nom+' delesté',3)
	end
	if maxnivDelest < nivDelest
	maxnivDelest = nivDelest #mémorise le niveau de délestage le plus élevé atteint
	end
end

#- ======================================================================
Function: relester1zone
Purpose : retire le délestage d'une zone
Input   : variables globales nivDelest et plusAncienneZoneDelestee
Output  : màj variable globale nivDelest et plusAncienneZoneDelestee
Comments: code repris sur https://github.com/hallard/remora_soft
====================================================================== -#

def relester1zone(decalage)
	var FP
	if nivDelest > 0 #On s'assure qu'un délestage est en cours
		nivDelest -=1
		FP = plusAncienneZoneDelestee
		setfp(FP,fps[FP-1].etat_mem) #On remet le fil pilote à ça valeur avant délestage
		log('fil pilote '+fps[FP-1].nom+' relesté',3)
		plusAncienneZoneDelestee = (plusAncienneZoneDelestee % size(fps)) + 1
	end
	if nivDelest == 0 && !decalage && maxnivDelest > 0 # ne tient pas compte si la commande est lancée depuis la fonction decalerDelestage
		log('fin délestage, niveau de délestage atteint = '+str(maxnivDelest),1)
		maxnivDelest = 0
	end
end

#- ======================================================================
Function: decalerDelestage
Purpose : fait tourner la ou les zones délestées
Input   : variables globales nivDelest et plusAncienneZoneDelestee
Output  : màj variable globale plusAncienneZoneDelestee
Comments: code repris sur https://github.com/hallard/remora_soft
====================================================================== -#

def decalerDelestage()
	if nivDelest > 0 && nivDelest < size(fps) #On ne peut pas faire tourner les zones délestées s'il n'y en a aucune en cours de délestage, ou si elles le sont toutes
		relester1zone(true)
		delester1zone(true)
	end
	tasmota.set_timer(timer_delestage, decalerDelestage) #relance la fonction de rotation des zones délestées après la temporisation
end

def toutdelester()
	log("délestage d'urgence enclenché",1)
	while nivDelest <= (size(fps)-1)
		delester1zone(true)
	end
end

def cmd_delest(cmd, idx, payload, payload_json)
	delester1zone(false)
	tasmota.resp_cmnd_done()
end

def cmd_relest(cmd, idx, payload, payload_json)
	relester1zone(false)
	tasmota.resp_cmnd_done()
end

def cmd_delesturg(cmd, idx, payload, payload_json)
	toutdelester()
	tasmota.resp_cmnd_done()
end

#FIN GESTION DU DELESTAGE

if size(fps) > 0 # ajoute les commandes à la console et lance les timers si au moins un fil pilote configuré.
	tasmota.add_cmd('setfp', cmd_setfp)
	tasmota.add_cmd('delest', cmd_delest)
	tasmota.add_cmd('relest', cmd_relest)
	tasmota.add_cmd('delesturg', cmd_delesturg)
	timer_5m()
	decalerDelestage() #lance la fonction de rotation des zones délestées après la temporisation
	setfp(0,'H')
end


import string
import json
import persist

int NB_FP = 7 # nombre de fil pilote physique
list int SortiesFP = [14,15,12,13,10,11,1,0,3,2,5,4,7,6] # pins du mcp23037 pour chaque fils pilotes [FP1 (14,15), FP2 (12,13),...]
int LED_PIN = 8
int RELAIS_PIN = 9
etat_relais_html = ['OFF','ON','Délesté','Boost']
modes = ['C','A','E','H','1','2','D','0']	# C=Confort, A=Arrêt, E=Eco, H=Hors gel, 1=Eco-1, 2=Eco-2, D=délesté 0=Auto
modes_html =  ['Confort','Arrêt','Eco','Hors-gel','Eco -1','Eco -2','Délesté']
var nivDelest = 0 # Niveau de délestage actuel (par défaut = 0 pas de délestage)
var maxnivDelest = 0 # Niveau de délestage maximum atteint
var seuil_delest, seuil_relest, seuil_delesturg, tempo_delest, tempo_relest, timer_delestage, niv_maxdelest, _charge
var fps
fps = []
if !persist.has('forcage') persist.forcage = {} end


# DEBUT fonctions pour récupérer la configuration 

def conf_get(key,default)
	if persist.has('conf')
		return persist.conf.find(key,default)
	else
		return default
	end
end

def conf_has(key,true_value,false_value)
	if persist.has('conf')
		if persist.conf.find(key) return true_value
		else return false_value
		end
	else return false_value
	end
end

def conf_is(key,value,true_value,false_value)
	if conf_get(key) == value return true_value
	else return false_value
	end
end

# FIN fonctions pour récupérer la configuration

class fp
	var nom, phy_id, etat, etat_auto, etat_forcage, deleste, conf12, pin1, pin2
	def init(nom, phy_id, conf12)
		self.nom = nom
		self.phy_id = phy_id #1 à 7 n° de fil pilote correspondant au bornier
		self.conf12 = conf12 # support des modes éco -1 et -2
		self.etat = 'H'
		self.etat_auto = 'H'
		self.etat_forcage = persist.forcage.find(str(phy_id),'0') # état du forçage 0 = pas de forçage
		self.deleste = false
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

#Fonctions pour la génération des signaux eco -1 et -2

def eco_3_7s(FP)
	mcp23017.cmd_pin(fps[FP-1].pin1,0)
	mcp23017.cmd_pin(fps[FP-1].pin2,0)
end

def eco_5m(FP,timer_eco)
	mcp23017.cmd_pin(fps[FP-1].pin1,1)
	mcp23017.cmd_pin(fps[FP-1].pin2,1)
	tasmota.set_timer(timer_eco*1000, /->eco_3_7s(FP), '3_7s'+str(FP))
	tasmota.set_timer(300000, /->eco_5m(FP,timer_eco), '5m'+str(FP))
end

def add_timers_eco(FP,timer_eco)
	tasmota.set_timer(timer_eco*1000, /->eco_3_7s(FP), '3_7s'+str(FP))
	tasmota.set_timer(300000, /->eco_5m(FP,timer_eco), '5m'+str(FP))
end

#Fin fonctions eco

class DELESTABLES : list
	def add(FP)
		if self.find(FP) == nil self.push(FP) end
	end
	def del(FP)
		if self.find(FP) != nil self.remove(self.find(FP)) end
	end
end
delestables = DELESTABLES()

#- ======================================================================
positionne les GPIOs associés au n° du fil pilote exemple : 
setfp(1,'A') > fil pilote 1 sur arrêt
setfp(0,'E') > tous les fils pilotes sur eco
====================================================================== -#

def setfp(FP, value, forcage)
	
	if FP == 0 #commande pour tous les fils pilotes
		for i:1..size(fps)
			setfp(i, value, forcage)
		end
		return nil
	end
	
	if value == 'd' #relestage du fil pilote
		fps[FP-1].deleste = false
		delestables.del(FP)
		setfp(FP, fps[FP-1].etat_auto, false)
		return nil
	end
	
	if forcage #actualise la valeur du mode manu
		fps[FP-1].etat_forcage = value
		persist.forcage.setitem(str(fps[FP-1].phy_id),value)
		persist.save()
	elif !forcage && value !='D' #actualise la valeur du mode auto
		fps[FP-1].etat_auto = value
	end
	
	#suppression des timers pour les fonctions éco -1 et -2
	tasmota.remove_timer('5m'+str(FP))
	tasmota.remove_timer('3_7s'+str(FP))
	
	if value != 'D' #on prend la commande à appliquer sauf si c'est une demande de délestage
		if fps[FP-1].etat_forcage == '0' value = fps[FP-1].etat_auto #pas de forçage en manu on reprend la valeur auto
		else value = fps[FP-1].etat_forcage end
	end
		
	if !fps[FP-1].deleste #on ne change pas l'état du fil pilote s'il est délesté.
		
		if ['C','1','2','E'].find(value) != nil delestables.add(FP)
		elif ['A','H'].find(value) != nil delestables.del(FP)
		end
		
		#positionnement des gpios suivant l'ordre demandé
		if value == 'C'
			mcp23017.cmd_pin(fps[FP-1].pin1,0)
			mcp23017.cmd_pin(fps[FP-1].pin2,0)
		elif value == 'A' || value == 'D'
			mcp23017.cmd_pin(fps[FP-1].pin1,0)
			mcp23017.cmd_pin(fps[FP-1].pin2,1)
			if value == 'D' fps[FP-1].deleste = true end
		elif value == '1' || value == '2' || value == 'E'
			mcp23017.cmd_pin(fps[FP-1].pin1,1)
			mcp23017.cmd_pin(fps[FP-1].pin2,1)
			if !fps[FP-1].conf12 value = 'E' # si eco -1 et -2 non supporté les fils pilotes sont mis sur eco
			elif value == '1' add_timers_eco(FP,3)
			elif value == '2' add_timers_eco(FP,7)
			end
		elif value == 'H'
			mcp23017.cmd_pin(fps[FP-1].pin1,1)
			mcp23017.cmd_pin(fps[FP-1].pin2,0)
		end
		fps[FP-1].etat = value
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
attention aux commandes 1 et 11 12 2 21 22 sont abigües 11 par exemple peut signifier mettre le fil 1 sur eco-1 ou fil 1 et fil 2 sur eco-1
pour y palier les commandes pour positionner plusieurs fils pilotes devront être composé d'au moins 3 caractères.
exemple : 11- pour fil 1 et 2 sur eco -1, 11 pour juste le fil pilote sur eco -1
====================================================================== -#

def cmd_setfp(cmd, idx, payload, payload_json)
	if payload == ""  # setfp sans arguments
		tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
	elif size(payload) > 2 && size(payload) <= size(fps) # commande de plus de 3 caractères = positionnement d'un trait des fils pilotes
		for i:0..size(payload)-1
			if modes.find(payload[i]) != nil || payload[i] == '0'
				setfp(i+1,payload[i],true)
			end
		end
	tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
	elif size(payload) == 2 && int(payload[0]) >= 0 && int(payload[0]) <= size(fps) # commande à 2 caractères
		if modes.find(payload[1]) != nil || payload[1] == '0'
			setfp(int(payload[0]),payload[1],true)
			tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
		else
			tasmota.resp_cmnd('{"setfp" : "paramètres invalides"}') # erreur de saisie des paramètres
		end
	else
		tasmota.resp_cmnd('{"setfp" : "paramètres invalides"}') # erreur de saisie des paramètres
	end
end

# DEBUT GESTION DU RELAIS

class RELAIS : Driver
	var etat_phy, inverse, etat_cmd, etat_auto, etat_forcage,delest
	
	def init()
		self.etat_phy = mcp23017.get_pin(RELAIS_PIN)
		self.inverse = conf_has('invers',true)
		self.etat_cmd = 0
		self.etat_auto = 0
		self.delest = false
		self.etat_forcage = persist.forcage.find('8',-1)
	end
	
	def set(etat,forcage) # etat int -1=auto 0=arret 1=marche 2=délesté 3x=boost (x multiple de 1/2h)
		if forcage
			self.etat_forcage = etat
			persist.forcage.setitem('8',etat)
			persist.save()
		elif !forcage && etat !=2 self.etat_auto = etat
		elif etat == 2 self.delest = true
		end
		
		self.etat_cmd = self.etat_auto
		if self.etat_forcage != -1 self.etat_cmd = self.etat_forcage end
		if self.delest self.etat_cmd = 2 end
		
		if conf_has('delest_relais',true)
			if self.etat_cmd == 0 delestables.del(8)
			elif self.etat_cmd != 2 delestables.add(8) end
		end
		
		if self.etat_cmd == 2 || self.etat_cmd == 0 etat = 0 else etat = 1 end
		
		mcp23017.cmd_pin(LED_PIN,etat)
		if self.inverse self.etat_phy = int(!etat)
		else self.etat_phy = etat end
		mcp23017.cmd_pin(RELAIS_PIN,self.etat_phy)
	end

	def get()
		var etat
		self.etat_phy = mcp23017.get_pin(RELAIS_PIN)
		etat = self.etat_phy
		if self.inverse etat = !etat end
		return int(etat)
	end

	def every_second()
		if conf_is('gest_relais','tele',true)
			if (json.load(tasmota.read_sensors())['TIC']['PTEC'] == 'HC' || json.load(tasmota.read_sensors())['TIC']['RELAIS'] == '1')
				self.set(1)
			else
				self.set(0)
			end
		end
	end
end

relais = RELAIS()

def cmd_setrl(cmd, idx, payload, payload_json)
	if ['-1','0','1','3'].find(payload) >= 0 relais.set(int(payload),true) end
	tasmota.resp_cmnd('{"setrl" : "'+str(relais.get())+'"}')
end

if conf_has('relais',true)
	tasmota.add_driver(relais)
	tasmota.add_cmd('setrl', cmd_setrl)
	relais.set(0)
end

# FIN GESTION DU RELAIS

# DEBUT GESTION DU DELESTAGE

seuil_delest = int(conf_get('seuil_delest',90))
seuil_relest = int(conf_get('seuil_relest',70))
seuil_delesturg = int(conf_get('seuil_delesturg',95))
tempo_delest = int(conf_get('tempo_delest',1))
tempo_relest = int(conf_get('tempo_relest',30))
timer_delestage = int(conf_get('timer_delestage',60)) # 60 1min valeur de la temporisation pour faire tourner les délestages

def delester1fp(decalage)
	if nivDelest == 0 && !decalage log('délestage enclenché',1) end # ne tient pas compte si la commande est lancée depuis la fonction decalerDelestage
	if nivDelest < size(delestables) #On s'assure que l'on n'est pas au niveau max
		nivDelest += 1
		if delestables[nivDelest-1] == 8
			relais.set(2)
			log('relais délesté',3)
		else
			setfp(delestables[nivDelest-1],'D')
			log('fil pilote '+fps[delestables[nivDelest-1]-1].nom+' délesté',3)
		end
		if maxnivDelest < nivDelest maxnivDelest = nivDelest end #mémorise le niveau de délestage le plus élevé atteint
	end
end

def relester1fp(decalage)
	if nivDelest > 0 #On s'assure qu'un délestage est en cours
		if delestables[0] == 8
			relais.delest = false
			delestables.del(8)
			relais.set(relais.etat_auto)
			log('relais relesté',3)
		else
			log('fil pilote '+fps[delestables[0]-1].nom+' relesté',3)
			setfp(delestables[0],'d')
		end
		nivDelest -= 1
	end
	if nivDelest == 0 && !decalage && maxnivDelest > 0 # ne tient pas compte si la commande est lancée depuis la fonction decalerDelestage
		tasmota.remove_timer('timer_delest')
		tasmota.remove_timer('timer_decalage')
		tasmota.remove_timer('timer_relest')
		log('fin délestage, niveau de délestage atteint = '+str(maxnivDelest),1)
		maxnivDelest = 0
	end
end

def decalerDelestage()
	if nivDelest > 0 && nivDelest < size(delestables) #On ne peut pas faire tourner les zones délestées s'il n'y en a aucune en cours de délestage, ou si elles le sont toutes
		relester1fp(true)
		delester1fp(true)
	end
	tasmota.set_timer(timer_delestage*1000, decalerDelestage,'timer_decalage') #relance la fonction de rotation des zones délestées après la temporisation
end

def toutdelester()
	log("délestage d'urgence enclenché",1)
	for i:1..size(fps)
		if fps[i-1].etat == 'H' delestables.add(i) end # ajoute les fils pilotes en hors-gel comme délestable
	end
	while size(delestables) > nivDelest
		delester1fp(true)
	end
end

def timer_relest()
	if _charge < seuil_relest relester1fp(false) end
	tasmota.set_timer(tempo_relest*1000, timer_relest, 'timer_relest')
end

def timer_delest()
	if _charge > seuil_delest delester1fp(false) end
	tasmota.set_timer(tempo_delest*1000, timer_delest, 'timer_delest')
end

def charge(value)
	_charge = value
	if _charge > seuil_delest
		if nivDelest == 0
			tasmota.set_timer(timer_delestage*1000, decalerDelestage,'timer_decalage')
			tasmota.set_timer(tempo_relest*1000, timer_relest, 'timer_relest')
			tasmota.set_timer(tempo_delest*1000, timer_delest, 'timer_delest')
			if _charge < seuil_delesturg delester1fp(false) end
		end
		if _charge > seuil_delesturg toutdelester() end
	end
end

if conf_has('delest',true)
	tasmota.add_rule(conf_get('driver','ENERGY')+'#'+conf_get('sensor','Load'),def (value) charge(value) end )
end

#FIN GESTION DU DELESTAGE

class MQTT : Driver

	def json_append()
		var msg
		msg=',"REMORA":{'
		if conf_has('relais',true) msg += '"relais":"'+etat_relais_html[relais.etat_cmd]+'"' end
		if size(fps) > 0
			for i:1..size(fps)
				if size(msg) > 10 msg += ',' end
				msg += '"'+fps[i-1].nom+'":"'+modes_html[modes.find(fps[i-1].etat)]+'"'
			end
		end
		msg +='}'
		tasmota.response_append(msg)
	end
end
mqtt = MQTT()

if size(fps) > 0 # ajoute les commandes à la console et initialise les fils pilotes
	tasmota.add_cmd('setfp', cmd_setfp)
	setfp(0,'H')
end

if conf_has('mqtt',true)
	tasmota.add_driver(mqtt)
end

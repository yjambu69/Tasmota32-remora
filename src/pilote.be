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
var seuil_delest, seuil_relest, seuil_delesturg, tempo_delest, tempo_relest, timer_delestage

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

def order_map_keys(_map)
	var order = [0]
	var j = 0
	for k:_map.keys()
		while j < size(order) && order[j] < k j +=1 end
		order.insert(j,k)
	end
	order.remove(0)
	return order
end

class fp
	var nom, phy_id, etat, etat_auto, etat_forcage, deleste, conf12, pin1, pin2, phase
	def init(phy_id, nom, conf12, phase)
		self.nom = nom
		self.phy_id = phy_id #1 à 7 n° de fil pilote correspondant au bornier
		self.conf12 = conf12 # support des modes éco -1 et -2
		self.etat = 'H'
		self.etat_auto = 'H'
		self.etat_forcage = persist.forcage.find(str(phy_id),'0') # état du forçage 0 = pas de forçage
		self.deleste = false
		self.pin1 = SortiesFP[phy_id*2-2] # correspondance pin sur le mcp23017
		self.pin2 = SortiesFP[phy_id*2-1]
		self.phase = phase
	end
end

class FPS : map
	var keys_o
	def init()
		super(self).init()
		self.keys_o = []
	end
end

fps = FPS()

if persist.has('fps')
	if  conf_has('triphase', false, true)
		for i:persist.fps.keys()
			fps.insert(int(i), fp(int(i), persist.fps.item(i)[0], bool(persist.fps.item(i)[1]), 1))
		end
	else
		for i:persist.fps.keys()
			fps.insert(int(i), fp(int(i), persist.fps.item(i)[0], bool(persist.fps.item(i)[1]), int(persist.fps.item(i)[2])))
		end
	end
	fps.keys_o = order_map_keys(fps)
end

#Fonctions pour la génération des signaux eco -1 et -2

def eco_3_7s(FP)
	mcp23017.cmd_pin(fps[FP].pin1,0)
	mcp23017.cmd_pin(fps[FP].pin2,0)
end

def eco_5m(FP,timer_eco)
	mcp23017.cmd_pin(fps[FP].pin1,1)
	mcp23017.cmd_pin(fps[FP].pin2,1)
	tasmota.set_timer(timer_eco*1000, /->eco_3_7s(FP), '3_7s'+str(FP))
	tasmota.set_timer(300000, /->eco_5m(FP,timer_eco), '5m'+str(FP))
end

def add_timers_eco(FP,timer_eco)
	tasmota.set_timer(timer_eco*1000, /->eco_3_7s(FP), '3_7s'+str(FP))
	tasmota.set_timer(300000, /->eco_5m(FP,timer_eco), '5m'+str(FP))
end

#Fin fonctions eco

class DELESTABLE : list
	var phase, nivDelest, maxnivDelest, ADIR
	def init(phase)
		super(self).init()
		self.phase = phase
		self.nivDelest = 0
		self.maxnivDelest = 0
		self.ADIR = false
	end
	def add(FP)
		if self.find(FP) == nil self.push(FP) end
	end
	def del(FP)
		if self.find(FP) != nil self.remove(self.find(FP)) end
	end
end

class DELESTABLES : map
	def init()
		super(self).init()
		self.insert(1, DELESTABLE(1))
		self.insert(2, DELESTABLE(2))
		self.insert(3, DELESTABLE(3))
	end
	
	def add(FP)
		self[fps[FP].phase].add(FP)
	end
	
	def del(FP)
		self[fps[FP].phase].del(FP)
	end
	
	def add_fp_horsgel_delestable(phase)
		for i:fps
			if i.etat == 'H' && i.phase == phase self.add(i.phy_id) end # ajoute les fils pilotes en hors-gel comme délestable
		end
	end
	
	def del_fp_horsgel_delestable(phase)
		for i:self[phase]
			if fps[i].etat == 'H' && fps[i].phase == phase self.del(i) end # enlève les fils pilotes en hors-gel comme délestable
		end
	end
	
	def add_relais(phase)
		self[phase].add(8)
	end
	
	def del_relais(phase)
		self[phase].add(8)
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
		for i:fps.keys()
			setfp(i, value, forcage)
		end
		return nil
	end
	
	if !fps.contains(FP) return nil end # pas de fil pilote configurer pour cette borne
	
	if value == 'd' #relestage du fil pilote
		fps[FP].deleste = false
		log('fil pilote '+fps[FP].nom+' relesté',3)
		delestables.del(FP)
		setfp(FP, fps[FP].etat_auto, false)
		return nil
	end
	
	if forcage #actualise la valeur du mode manu
		fps[FP].etat_forcage = value
		persist.forcage.setitem(str(fps[FP].phy_id,value)
		persist.save()
	elif !forcage && value !='D' #actualise la valeur du mode auto
		fps[FP].etat_auto = value
	end
	
	#suppression des timers pour les fonctions éco -1 et -2
	tasmota.remove_timer('5m'+str(FP))
	tasmota.remove_timer('3_7s'+str(FP))
	
	if value != 'D' #on prend la commande à appliquer sauf si c'est une demande de délestage
		if fps[FP].etat_forcage == '0' value = fps[FP].etat_auto #pas de forçage en manu on reprend la valeur auto
		else value = fps[FP].etat_forcage end
	end
		
	if !fps[FP].deleste #on ne change pas l'état du fil pilote s'il est délesté.
		
		if ['C','1','2','E'].find(value) != nil delestables.add(FP)
		elif ['A','H'].find(value) != nil delestables.del(FP)
		end
		
		#positionnement des gpios suivant l'ordre demandé
		if value == 'C'
			mcp23017.cmd_pin(fps[FP].pin1,0)
			mcp23017.cmd_pin(fps[FP].pin2,0)
		elif value == 'A' || value == 'D'
			mcp23017.cmd_pin(fps[FP].pin1,0)
			mcp23017.cmd_pin(fps[FP].pin2,1)
			if value == 'D'
				log('fil pilote '+fps[FP].nom+' délesté',3)
				fps[FP].deleste = true
			end
		elif value == '1' || value == '2' || value == 'E'
			mcp23017.cmd_pin(fps[FP].pin1,1)
			mcp23017.cmd_pin(fps[FP].pin2,1)
			if !fps[FP].conf12 value = 'E' # si eco -1 et -2 non supporté les fils pilotes sont mis sur eco
			elif value == '1' add_timers_eco(FP,3)
			elif value == '2' add_timers_eco(FP,7)
			end
		elif value == 'H'
			mcp23017.cmd_pin(fps[FP].pin1,1)
			mcp23017.cmd_pin(fps[FP].pin2,0)
		end
		fps[FP].etat = value
	end
end

def etats_FP() # retourne l'état des fils pilotes dans ce format [FP1=A,FP2=A,FP3=E...]
	var msg
	msg='['
	for i:fps.keys_o
		msg += 'FP'+str(i)+'='+fps[i].etat+','
	end
	msg = string.split(msg, size(msg)-1)[0]
	msg +=']'
	return msg
end

#- ======================================================================
commande dans la console usage et utilisable en http (http://<ip de la remora>/cm?cmnd=setfp%20<paramètres ex:0C ou AAA-CE>):
les numéros de fil pilote corresponde à ceux du bornier.
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
	elif size(payload) > 2 && size(payload) <= NB_FP # commande de plus de 3 caractères = positionnement d'un trait des fils pilotes
		for i:0..size(payload)-1
			if modes.find(payload[i]) != nil && payload[i] != 'D'
				setfp(i+1, payload[i], true)
			end
		end
	tasmota.resp_cmnd('{"setfp" : "'+etats_FP()+'"}')
	elif size(payload) == 2 && int(payload[0]) >= 0 && int(payload[0]) <= NB_FP # commande à 2 caractères
		if modes.find(payload[1]) != nil && payload[1] != 'D'
			setfp(int(payload[0]), payload[1], true)
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
	var etat_phy, phase, inverse, etat_cmd, etat_auto, etat_forcage,delest
	
	def init()
		self.etat_phy = mcp23017.get_pin(RELAIS_PIN)
		self.inverse = conf_has('invers',true)
		self.etat_cmd = 0
		self.etat_auto = 0
		self.delest = false
		self.etat_forcage = persist.forcage.find('8',-1)
		if conf_get('triphase', false) self.phase = conf_get('phase_relais',1)
		else self.phase = 1 end
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
			if self.etat_cmd == 0 delestables.del_relais(self.phase)
			elif self.etat_cmd != 2 delestables.add_relais(self.phase) end
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

seuil_delest = int(conf_get('seuil_delest',100))
seuil_relest = int(conf_get('seuil_relest',80))
seuil_delesturg = int(conf_get('seuil_delesturg',140))
tempo_delest = int(conf_get('tempo_delest',5))
tempo_relest = int(conf_get('tempo_relest',30))
timer_delestage = int(conf_get('timer_delestage',60)) # 60 1min valeur de la temporisation pour faire tourner les délestages
tempo_ADIR = 2

def delester1fp(decalage,phase)
	if !decalage && delestables[phase].nivDelest == size(delestables[phase])-1 #On est au niveau max, on tente s'il y en a de délester les fils pilotes en hors-gel
		delestables.add_fp_horsgel_delestable(phase)
	end
	if delestables[phase].nivDelest < size(delestables[phase]) #On s'assure que l'on n'est pas au niveau max
		if delestables[phase][delestables[phase].nivDelest] == 8
			relais.set(2)
			log('relais délesté',3)
		else
			setfp(delestables[phase][delestables[phase].nivDelest],'D')
		end
		delestables[phase].nivDelest += 1
		if delestables[phase].maxnivDelest < delestables[phase].nivDelest delestables[phase].maxnivDelest = delestables[phase].nivDelest end #mémorise le niveau de délestage le plus élevé atteint
	end
end

def fin_delest(phase)
	tasmota.remove_timer('timer_delest'+str(phase))
	tasmota.remove_timer('timer_decalage'+str(phase))
	tasmota.remove_timer('timer_relest'+str(phase))
	log('fin délestage sur la phase '+str(phase)+', niveau de délestage atteint = '+str(delestables[phase].maxnivDelest),1)
	delestables[phase].maxnivDelest = 0
	delestables.del_fp_horsgel_delestable(phase)
end

def relester1fp(decalage, phase)
	if delestables[phase].nivDelest > 0 #On s'assure qu'un délestage est en cours
		if delestables[phase][0] == 8
			relais.delest = false
			delestables[phase].del(8)
			relais.set(relais.etat_auto)
			log('relais relesté',3)
		else
			setfp(delestables[phase][0],'d')
		end
		delestables[phase].nivDelest -= 1
	end
	if delestables[phase].nivDelest == 0 && !decalage && delestables[phase].maxnivDelest > 0 # ne tient pas compte si la commande est lancée depuis la fonction decalerDelestage
		fin_delest(phase)
	end
end

def decalerDelestage(phase)
	if delestables[phase].nivDelest > 0 && delestables[phase].nivDelest < size(delestables[phase]) #On ne peut pas faire tourner les zones délestées s'il n'y en a aucune en cours de délestage, ou si elles le sont toutes
		relester1fp(true, phase)
		delester1fp(true, phase)
	end
	tasmota.set_timer(timer_delestage*1000, /->decalerDelestage(phase), 'timer_decalage'+str(phase)) #relance la fonction de rotation des zones délestées après la temporisation
end

def timer_relest(phase)
	if !delestables[phase].ADIR relester1fp(false, phase) end
	tasmota.set_timer(tempo_relest*1000, /->timer_relest(phase), 'timer_relest'+str(phase))
end

def timer_delest(phase)
	if delestables[phase].ADIR delester1fp(false, phase) end
	tasmota.set_timer(tempo_delest*1000, /->timer_delest(phase), 'timer_delest'+str(phase))
end

def start_timers_delestage(phase)
	tasmota.set_timer(timer_delestage*1000, /->decalerDelestage(phase),'timer_decalage'+str(phase))
	tasmota.set_timer(tempo_relest*1000, /->timer_relest(phase), 'timer_relest'+str(phase))
	tasmota.set_timer(tempo_delest*1000, /->timer_delest(phase), 'timer_delest'+str(phase))
end

def debut_delest(phase)
	log('délestage enclenché sur phase '+str(phase),1)
	delester1fp(false, phase)
	start_timers_delestage(phase)
end

def toutdelester(phase)
	log("délestage d'urgence enclenché sur la phase "+str(phase),1)
	delestables.add_fp_horsgel_delestable(phase)
	if delestables[phase].nivDelest == 0 start_timers_delestage(phase) end
	while size(delestables[phase]) > delestables[phase].nivDelest
		delester1fp(false, phase)
	end
end

def on_ADIR(phase)
	if delestables[phase].nivDelest == 0 debut_delest(phase) end
	delestables[phase].ADIR = true
	if conf_has('linky', true, false)
		tasmota.remove_timer('timer_ADIR'+str(phase))
		tasmota.set_timer(tempo_ADIR*1000, /->def () delestables[phase].ADIR = false end, 'timer_ADIR'+str(phase))
	end
end

if conf_has('delest',true)
	if conf_has('triphase', false, true)
		tasmota.add_rule(conf_get('driver1','ENERGY')+'#'+conf_get('sensor1','Load')+'>='+str(seuil_delesturg), /->toutdelester(1)) # ENERGY#Load>=140
		if conf_has('linky', true, false)
			tasmota.add_rule('TIC#ADPS', /->on_ADIR(1))
		else
			tasmota.add_rule(conf_get('driver1','ENERGY')+'#'+conf_get('sensor1','Load')+'>='+str(seuil_delest), /->on_ADIR(1) )
			tasmota.add_rule(conf_get('driver1','ENERGY')+'#'+conf_get('sensor1','Load')+'<'+str(seuil_relest), def () delestables[1].ADIR = false end )
		end
	else
		tasmota.add_rule(conf_get('driver1','ENERGY')+'#'+conf_get('sensor1','Load1')+'>='+str(seuil_delesturg), /->toutdelester(1))
		tasmota.add_rule(conf_get('driver2','ENERGY')+'#'+conf_get('sensor2','Load2')+'>='+str(seuil_delesturg), /->toutdelester(2))
		tasmota.add_rule(conf_get('driver3','ENERGY')+'#'+conf_get('sensor3','Load3')+'>='+str(seuil_delesturg), /->toutdelester(3))
		if conf_has('linky', true, false)
			tasmota.add_rule('TIC#ADIR1', /->on_ADIR(1))
			tasmota.add_rule('TIC#ADIR2', /->on_ADIR(2))
			tasmota.add_rule('TIC#ADIR3', /->on_ADIR(3))
		else
			tasmota.add_rule(conf_get('driver1','ENERGY')+'#'+conf_get('sensor1','Load1')+'>='+str(seuil_delest), /->on_ADIR(1) )
			tasmota.add_rule(conf_get('driver1','ENERGY')+'#'+conf_get('sensor1','Load1')+'<'+str(seuil_relest), def () delestables[1].ADIR = false end )
			tasmota.add_rule(conf_get('driver2','ENERGY')+'#'+conf_get('sensor2','Load2')+'>='+str(seuil_delest), /->on_ADIR(2) )
			tasmota.add_rule(conf_get('driver2','ENERGY')+'#'+conf_get('sensor2','Load2')+'<'+str(seuil_relest), def () delestables[2].ADIR = false end )
			tasmota.add_rule(conf_get('driver3','ENERGY')+'#'+conf_get('sensor3','Load3')+'>='+str(seuil_delest), /->on_ADIR(3) )
			tasmota.add_rule(conf_get('driver3','ENERGY')+'#'+conf_get('sensor3','Load3')+'<'+str(seuil_relest), def () delestables[3].ADIR = false end )
		end
	end
end

#FIN GESTION DU DELESTAGE

class MQTT : Driver

	def json_append()
		var msg
		msg=',"REMORA":{'
		if conf_has('relais',true) msg += '"relais":"'+etat_relais_html[relais.etat_cmd]+'"' end
		for i:fps
			if size(msg) > 10 msg += ',' end
			msg += '"'+fps[i].nom+'":"'+modes_html[modes.find(fps[i].etat)]+'"'
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

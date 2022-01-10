list int SortiesFP = [14,15,12,13,10,11,1,0,3,2,5,4,7,6] # pins du mcp23037 pour chaque fils pilotes [FP1 (14,15), FP2 (12,13),...]
int NB_FP = 7 # nombre de fil pilote physique
list etats_FP = [] # états des fils pilotes
etats_FP.resize(NB_FP)
int LED_PIN = 8
int RELAIS_PIN = 9
modes = ['C','A','E','H','1','2']	# C=Confort, A=Arrêt, E=Eco, H=Hors gel, 1=Eco-1, 2=Eco-2

# fonction pour récuperer l'état des fils pilotes
def getfp(FP)
	if FP == 0
		for i:1..NB_FP
			etats_FP[i-1] = getfp(i)
		end
	else
		var value
		var etat_FP = [ mcp23017.get_pin(SortiesFP[FP*2-2]) , mcp23017.get_pin(SortiesFP[FP*2-1]) ]
		if etat_FP == [0,0]
			value = 'C'
		elif etat_FP == [0,1]
			value = 'A'
		elif etat_FP == [1,1]
			value = 'E'
		elif etat_FP == [1,0]
			value = 'H'
		end
	return value
	end
end


#- positionne les GPIOs associés au n° du fil pilote exemple : 
setfp(1,'A') > fil pilote 1 sur arrêt
setfp(0,'E') > tous les fils pilotes sur eco
-#

def setfp(FP, value)
	if FP == 0
		for i:1..NB_FP
			setfp(i, value)
		end
	else
		etats_FP[FP-1] = value
		if value == 'C'
			mcp23017.cmd_pin(SortiesFP[FP*2-2],0)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],0)
		elif value == 'A'
			mcp23017.cmd_pin(SortiesFP[FP*2-2],0)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],1)
		elif value == 'E'
			mcp23017.cmd_pin(SortiesFP[FP*2-2],1)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],1)
		elif value == 'H'
			mcp23017.cmd_pin(SortiesFP[FP*2-2],1)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],0)
		elif value == '1' #met en mode eco, eco-1 non géré pour l'instant && FP_support12(FP)
			mcp23017.cmd_pin(SortiesFP[FP*2-2],1)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],1)
		elif value == '2' #met en mode eco, eco-2 non géré pour l'instant
			mcp23017.cmd_pin(SortiesFP[FP*2-2],1)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],1)
		end
	end
end

#-passe un fil pilote à l'ordre suivant de la liste modes 'C','A','E','H','1','2'
exemple : FP1 est à C il passe à A
-#
def inc_etat_FP(FP)
	if modes.find(etats_FP[FP-1]) == 5
		setfp(FP,modes[0])
	else
		setfp(FP,modes[modes.find(etats_FP[FP-1])+1])
	end
end

#- commande dans la console usage et utilisable en http (http://<ip de la remora>/cm?cmnd=setfp%20<paramètres ex:0C ou AAA-CE>):
setfp 1A > met le fil pilote 1 sur arrêt
setfp 0E > met tous les fils pilote sur eco
setfp AE > met fil pilote 1 sur arrêt 2 sur eco
setfp A-----C > met fil pilote 1 sur arrêt 7 sur confort,
le tiret peut être remplacer par n'importe quelle autre caractère tant que ce n'est pas 1 à 7 ou C,A,E,H,1,2
attention à les commandes 1 et 11 12 2 21 22 sont abigües 11 par exemple peut signifier mettre le fil1 sur eco-1 ou fil1 et fil2 sur eco-1
pour y palier les commandes pour positionner plusieurs fils pilotes devront être composé d'au moins 3 caractères.
exemple : 11- pour fil 1 et 2 sur eco -1, 11 pour juste le fil pilote sur eco -1 
-#

def cmd_setfp(cmd, idx, payload, payload_json)
	if payload == ""  # setfp sans arguments
	tasmota.resp_cmnd_done()
	elif size(payload) > 2 && size(payload) <= NB_FP #commande de plus de 3 caractères = positionnement d'un trait des fils pilotes
		for i:0..size(payload)-1
			if modes.find(payload[i]) != nil
				setfp(i+1,payload[i])
			end
		end
	tasmota.resp_cmnd_done()
	elif size(payload) == 2 && int(payload[0]) >= 0 && int(payload[0]) <= NB_FP #commande à 2 caractères
		if modes.find(payload[1]) != nil
			setfp(int(payload[0]),payload[1])
		end
	tasmota.resp_cmnd_done()
	else
	tasmota.resp_cmnd_error() # erreur de saisie des paramètres de la commande todo ajouter le message d'erreur paramètres invalides
	end
	print("Etats des fils pilotes : "+str(etats_FP)) # à remplacer par tasmota.resp_cmnd() avec la réponse d'états des fils pilotes
end

tasmota.add_cmd('setfp', cmd_setfp)
getfp(0) # met à jour l'états des fils pilotes

# Génération des signaux pour les modes eco -1 et -2

def timer_3s()
	for i:1..NB_FP
		if etats_FP[i-1] == '1'
			mcp23017.cmd_pin(SortiesFP[i*2-2],0)
			mcp23017.cmd_pin(SortiesFP[i*2-1],0)
		end
	end
end

def timer_7s()
	for i:1..NB_FP
		if etats_FP[i-1] == '2'
			mcp23017.cmd_pin(SortiesFP[i*2-2],0)
			mcp23017.cmd_pin(SortiesFP[i*2-1],0)
		end
	end
end

def timer_5m()
	for i:1..NB_FP
		if etats_FP[i-1] == '1' || etats_FP[i-1] == '2'
			mcp23017.cmd_pin(SortiesFP[i*2-2],1)
			mcp23017.cmd_pin(SortiesFP[i*2-1],1)
		end
	end
	tasmota.set_timer(300000, timer_5m) #relance la fonction dans 5 minutes
	tasmota.set_timer(3000, timer_3s) # remet les pins à 0 dans 3s pour les fils pilotes en eco -1 
	tasmota.set_timer(7000, timer_7s) # remet les pins à 0 dans 7s pour les fils pilotes en eco -2
end

timer_5m()

# Fin génération des signaux pour les modes eco -1 et -2


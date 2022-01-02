list int SortiesFP = [14,15,12,13,10,11,1,0,3,2,5,4,7,6] # pins du mcp23037 pour chaque fils pilotes [FP1 (14,15), FP2 (12,13),...]
int NB_FP = 7 # nombre de fil pilote physique
list etats_FP = ['A','A','A','A','A','A','A'] # états des fils pilotes initialisés à Arrêt [FP1,FP2,...,FP7]
int LED_PIN = 8
int RELAIS_PIN = 9
modes = ['C','A','E','H','1','2']	# C=Confort, A=Arrêt, E=Eco, H=Hors gel, 1=Eco-1, 2=Eco-2

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
		elif value == '1' #met en mode eco, eco-1 non géré pour l'instant
			mcp23017.cmd_pin(SortiesFP[FP*2-2],1)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],1)
		elif value == '2' #met en mode eco, eco-2 non géré pour l'instant
			mcp23017.cmd_pin(SortiesFP[FP*2-2],1)
			mcp23017.cmd_pin(SortiesFP[FP*2-1],1)
		end
	end
end

#-passe un fil pilote à l'ordre suivant de la liste 'C','A','E','H','1','2'
exemple : FP1 est à C il passe à A
-#
def inc_etat_FP(FP)
	var j
	for i:0..5
		if etats_FP[FP-1] == modes[i]
			j = i+1
		end
	end
	if j == 6
		j = 0
	end
	setfp(FP,modes[j])
end

#- commande dans la console usage et utilisable en http (http://ip/):
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
			for j:0..modes.size()-1
				if payload[i] == modes[j]
					setfp(i+1,payload[i])
				end
			end
		end
	tasmota.resp_cmnd_done()
	elif size(payload) == 2 && int(payload[0]) >= 0 && int(payload[0]) <= NB_FP #commande à 2 caractères
		for j:0..modes.size()-1
			if payload[1] == modes[j]
				setfp(int(payload[0]),payload[1])
			end
		end
	tasmota.resp_cmnd_done()
	else
	tasmota.resp_cmnd_error() # erreur de saisie des paramètres de la commande todo ajouter le message d'erreur paramètres invalides
	end
	print("Etats des fils pilotes : "+str(etats_FP)) # à remplacer par tasmota.resp_cmnd() avec la réponse d'états des fils pilotes
end

tasmota.add_cmd('setfp', cmd_setfp)


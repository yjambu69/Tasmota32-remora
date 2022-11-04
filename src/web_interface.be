import webserver

class WEB_INTERFACE : Driver
	static def load_json(key)
        var obj, f
        f = open(racine+'html.json', 'r') #f = open('remora.tapp#/html.json', 'r') ou f = open('html.json', 'r')
        obj = json.load(f.read())[key]
        f.close()
        return obj
    end

	def web_add_main_button()
		var html, html_json
		html_json = self.load_json('main_menu')
		tasmota.delay(1)
		html = ""
		if size(fps) > 0 
			for i:1..size(fps)
				html += string.format(html_json['fp'],i,fps[i-1].nom)
			end
			html += string.format(html_json['fp'],0,'Tous les fils pilotes')
		end
		if conf_has('relais',true)
			html += html_json['relais']
		end
		webserver.content_send(html)
	end
		
	def web_add_config_button()
		webserver.content_send("<p><form action='cfp' style='display: block;' method='get'><button>Configuration fils pilotes</button></form></p>")
		webserver.content_send("<p><form action='cfg' style='display: block;' method='get'><button>Configuration Remora</button></form></p>")	
		webserver.content_send("<p><form action='sch' style='display: block;' method='get'><button>Programmation horaire</button></form></p>")
	end

	def web_sensor()
		var msg, color
		if size(fps) > 0
			msg = ''
			for i:1..size(fps)
				color = ''
				if fps[i-1].etat_forcage != '0' color = '#FF0000' end
				if fps[i-1].deleste == true color = '#FFFF00' end
				msg += string.format("{s}%s{m}<font color='%s'>%s</font> {e}", fps[i-1].nom, color, modes_html[modes.find(fps[i-1].etat)])
			end
			tasmota.web_send_decimal(msg)
		end
		if conf_has('relais',true)
			msg =''
			color =  ''
			if relais.etat_forcage !=-1 color = '#FF0000' end
			if relais.delest color = '#FFFF00' end
			msg = string.format("{s}Relais{m}<font color='%s'>%s</font> {e}", color,etat_relais_html[relais.etat_cmd])
			tasmota.web_send_decimal(msg)
		end
	end

  # page pour la configuration des fils pilotes
	def create_html_content_conf_fp()
		var html, html_json, j, eco, nom, checked, disabled
		html_json = self.load_json('menu_fp_conf')
		html = html_json['script']
		if size(fps) > 0 j = 0 else j= -1 end
		for i :1..NB_FP
			eco = ''
			nom = 'FP'+str(i)
			checked = ''
			disabled = 'disabled'
			if j >= 0 && j <= size(fps)-1
				if i == fps[j].phy_id
					if fps[j].conf12 eco='checked' end
					nom = fps[j].nom
					checked = 'checked'
					disabled = ''
					j += 1
				end
			end
			html += string.format(html_json['field_fp'],i,disabled,i,i,checked,i)..
			string.format(html_json['nom'],i,nom)..
			string.format(html_json['eco'],i,eco)
		end
		html += html_json['button_conf_save'] + '</form>'
		return html
	end
 
	def page_conf_FP_GET()
		if !webserver.check_privileged_access() return nil end

		webserver.content_start("Configuration des fils pilotes") # titre de la page
		webserver.content_send_style()  # applique les styles                
		webserver.content_send(self.create_html_content_conf_fp()) # créer le contenu
		webserver.content_button(webserver.BUTTON_MAIN) # ajout d'un bouton pour revenir sur le menu principal
		webserver.content_stop()                        # fin de la page
	end

	def page_conf_FP_POST()
	var j , conf12
		persist.fps = []
		if webserver.arg_size() > 0
			for i:1 .. NB_FP
				j = str(i)
				if webserver.has_arg('FP_use'+j)
					if webserver.has_arg('conf12'+j) conf12 = true else conf12 = false end
					persist.fps.push([webserver.arg('nom'+j), i, conf12])
				end				
			end
		end
		webserver.redirect("/?rst=") #restart
	end
	# fin page configuration fil pilote
	
	# debut page configuration général

	def create_html_content_conf_ge()
		var html, html_json
		html_json = self.load_json('menu_ge_conf')
		html = html_json['script']..
		string.format(html_json['field_delest'],conf_has('delest','','disabled'),conf_has('delest','checked',''))..
		string.format(html_json['capteur_teleinfo'],conf_is('capteur_delest','teleinfo','checked',conf_is('capteur_delest','autre','','checked')))..
		string.format(html_json['capteur_autre'],conf_is('capteur_delest','autre','checked',''))..
		string.format(html_json['field_autre'],conf_is('capteur_delest','autre','','disabled'))..
		string.format(html_json['driver'],conf_get('driver','ENERGY'))..
		string.format(html_json['sensor'], conf_get('sensor','Power')) + '</fieldset>'..
		string.format(html_json['se1'],int(conf_get('seuil_delest',90)))..
		string.format(html_json['se2'],int(conf_get('seuil_relest',70)))..
		string.format(html_json['se3'],int(conf_get('seuil_delesturg',95)))..
		string.format(html_json['t1'],int(conf_get('tempo_delest',1)))..
		string.format(html_json['t2'],int(conf_get('tempo_relest',30)))..
		string.format(html_json['t3'],int(conf_get('timer_delestage',120))) + '</fieldset>'..
		string.format(html_json['field_relais'],conf_has('relais','','disabled'),conf_has('relais','checked',''))..
		string.format(html_json['relais_tele'],conf_is('gest_relais','teleinfo','checked',conf_is('gest_relais','prog','','checked')))..
		string.format(html_json['relais_prog'],conf_is('gest_relais','prog','checked',''))..
		string.format(html_json['delest_relais'],conf_has('delest_relais','checked',''))..
		string.format(html_json['invers_relais'],conf_has('invers','checked',''))..
		string.format(html_json['field_autre_option'],conf_has('mqtt','checked',''))..
		html_json['button_conf_save'] + '</form>'
		return html
	end
	
	def page_conf_GE_GET()
		if !webserver.check_privileged_access() return nil end

		webserver.content_start("Configuration Remora") # titre de la page
		webserver.content_send_style()  # applique les styles                
		webserver.content_send(self.create_html_content_conf_ge()) # créer le contenu
		webserver.content_button(webserver.BUTTON_MAIN) # ajout d'un bouton pour revenir sur le menu principal
		webserver.content_stop()                        # fin de la page
	end

	def page_conf_GE_POST()
		persist.remove('conf') # supprime la configuration enregistrer dans le persist
		persist.conf = {}
		if webserver.arg_size() > 0
			for i:0..webserver.arg_size()-1
				persist.conf.insert(webserver.arg_name(i),webserver.arg(i))
			end
		end
		webserver.redirect("/?rst=") #restart
	end
	# fin page configuration général
	
	# debut page programme horaire		
	def create_html_content_page_schedule()
		var html, html_json, sch, der, i, h
		html_json = self.load_json('schedules')
		tasmota.delay(1) # bug : object has no method '()'
		if webserver.has_arg('sch') sch = int(webserver.arg('sch'))
		elif webserver.has_arg('der') der = int(webserver.arg('der'))
		else sch = 1 end
		html = html_json['style']..
		html_json['onglets_schedule']
		if size(schedules) > 0 # création des onglets
			i = 1
			h = 1
			while h < size(schedules)+1 # a reprendre
				if schedules.has(i) html += string.format(html_json['onglet_schedule'],i,i,i)  h +=1 end
				i += 1
			end
		else # création d'un onglet par défaut
			html += string.format(html_json['onglet_schedule'],1,1,1)
		end
		if sch != nil #creation du menu pour un programme horaire
			html += html_json['script_schedule']..
			html_json['schedule']..
			html_json['heure']..
			html_json['jours']
			if size(fps) > 0
				for j:0..size(fps)-1
					html += string.format(html_json['fp'],fps[j].nom,fps[j].phy_id)
				end
			end
			if conf_is('gest_relais','prog',true) html += html_json['relais'] end
			html += string.format(html_json['button_sch_save'],sch)..
			html_json['button_sch_add']..
			string.format(html_json['button_sch_del'],sch)
		end
		html += html_json['onglets_dero']
		if size(derogations) > 0 # création des onglets
			i = 1
			h = 1
			while i < size(derogations)+1
				if derogations.has(i) html += string.format(html_json['onglet_dero'],i,i,i) h += 1 end
				i += 1
			end
		else # création d'un onglet par défaut
			html += string.format(html_json['onglet_dero'],1,1,1)
		end
		if der != nil
			html += html_json['script_derogation']..
			html_json['derogation']..
			html_json['date_debut']..
			html_json['heure_debut']..
			html_json['date_fin']..
			html_json['heure_fin']..
			html_json['timestamps']
			if size(fps) > 0
				for j:0..size(fps)-1
					html += string.format(html_json['fp'],fps[j].nom,fps[j].phy_id)
				end
			end
			if conf_is('gest_relais','prog',true) html += html_json['relais'] end
			html += string.format(html_json['button_der_save'],der)..
			html_json['button_der_add']..
			string.format(html_json['button_der_del'],der)
		end
		# script au chargement de la page
		html +="<script type='text/javascript'>window.onload = onpageload(); function onpageload() {"		
		if sch != nil
			if schedules.find(sch)
				for j:0..6
					if schedules.item(sch).has_jour(j) html += "document.getElementById('j"+str(j)+"').checked = true;" end
				end
				html += "document.getElementById('heure').value ='"+schedules.item(sch).heure+"';"
				for k:schedules.item(sch).cmds.keys()
					if k == 8 html += "document.getElementById('relais').selectedIndex ="+str(etat_relais_html.find(schedules.item(sch).cmds.item(k))+1)+";"
					else html +="document.getElementById('fp"+str(k)+"').selectedIndex ="+str(modes.find(schedules.item(sch).cmds.item(k))+1)+";" end
				end
			else html += "document.getElementById('save_sch').disabled = true;"
			end
		end
		if der != nil
			if derogations.find(der)
				html += "document.getElementById('date_debut').value ='"+tasmota.strftime('%Y-%m-%d',derogations.item(der).timestamp_debut)+"';"..
				"document.getElementById('heure_debut').value ='"+tasmota.strftime('%H:%M',derogations.item(der).timestamp_debut)+"';"..
				"document.getElementById('date_fin').value ='"+tasmota.strftime('%Y-%m-%d',derogations.item(der).timestamp_fin)+"';"..
				"document.getElementById('heure_fin').value ='"+tasmota.strftime('%H:%M',derogations.item(der).timestamp_fin)+"';"..
				"document.getElementById('timestamp_debut').value ='"+str(derogations.item(der).timestamp_debut)+"';"..
				"document.getElementById('timestamp_fin').value ='"+str(derogations.item(der).timestamp_fin)+"';"
				for k:derogations.item(der).cmds.keys()
					if k == 8 html += "document.getElementById('relais').selectedIndex ="+str(etat_relais_html.find(derogations.item(sch).cmds.item(k))+1)+";"
					else html +="document.getElementById('fp"+str(k)+"').selectedIndex ="+str(modes.find(derogations.item(der).cmds.item(k))+1)+";" end
				end
			else html += "document.getElementById('save_der').disabled = true;"
			end
		end
		# selection de l'onglet
		if sch != nil html += "document.getElementById('os"+str(sch)+"').style ='background : white;color: black;';"
		else html += "document.getElementById('od"+str(der)+"').style ='background : white;color: black;';" end
		html += '}</script>'
		return html
	end

	def page_schedule_GET()
		if !webserver.check_privileged_access() return nil end

		webserver.content_start("Programmes horaires") # titre de la page
		webserver.content_send_style()  # applique les styles                
		webserver.content_send(self.create_html_content_page_schedule()) # créer le contenu
		webserver.content_button(webserver.BUTTON_MAIN) # ajout d'un bouton pour revenir sur le menu principal
		webserver.content_stop()                        # fin de la page
	end
	
	def page_schedule_POST()
		var cmds, jours
		cmds = CMDS()
		jours = bytes('00')
		if webserver.arg_size() > 0
			if webserver.has_arg('del_sch')
				del_schedule(int(webserver.arg('del_sch')))
			elif webserver.has_arg('save_sch') || webserver.has_arg('add_sch')
				for i:0..webserver.arg_size()-1
					if webserver.arg(i) != ''
						if webserver.arg_name(i) == 'jour' jours.setbits(int(webserver.arg(i)),1,1) end
						if webserver.arg_name(i) == 'relais' cmds.insert(8,webserver.arg(i)) end
						if string.find(webserver.arg_name(i), 'fp') == 0 cmds.insert(int(webserver.arg_name(i)[2]),webserver.arg(i)) end
					end
				end
				if webserver.has_arg('save_sch')
					set_schedule(int(webserver.arg('save_sch')),webserver.arg('heure'),str(jours)[7..8],cmds)
				else
					set_schedule(nil,webserver.arg('heure'),str(jours)[7..8],cmds)
				end
			elif webserver.has_arg('del_der')
				del_derogation(int(webserver.arg('del_der')))
			elif webserver.has_arg('save_der') || webserver.has_arg('add_der') 
				for i:0..webserver.arg_size()-1
					if webserver.arg(i) != ''
						if webserver.arg_name(i) == 'relais' cmds.insert(8,webserver.arg(i)) end
						if string.find(webserver.arg_name(i), 'fp') == 0 cmds.insert(int(webserver.arg_name(i)[2]),webserver.arg(i)) end
					end
				end
				if webserver.has_arg('save_der')
					set_derogation(int(webserver.arg('save_der')),int(webserver.arg('timestamp_debut')),int(webserver.arg('timestamp_fin')),cmds)
				else
					set_derogation(nil,int(webserver.arg('timestamp_debut')),int(webserver.arg('timestamp_fin')),cmds)
				end
			end
		end
		webserver.redirect("/sch")
	end
	
  #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
	def web_add_handler()
    #- we need to register a closure, not just a function, that captures the current instance -#
		webserver.on("/cfp", / -> self.page_conf_FP_GET(),webserver.HTTP_GET)
		webserver.on("/cfp", / -> self.page_conf_FP_POST(), webserver.HTTP_POST)
		webserver.on("/cfg", / -> self.page_conf_GE_GET(),webserver.HTTP_GET)
		webserver.on("/cfg", / -> self.page_conf_GE_POST(), webserver.HTTP_POST)
		webserver.on("/sch", / -> self.page_schedule_POST(), webserver.HTTP_POST)
		webserver.on("/sch", / -> self.page_schedule_GET(), webserver.HTTP_GET)
	end
end

web_interface = WEB_INTERFACE()
tasmota.add_driver(web_interface)
web_interface.web_add_handler()

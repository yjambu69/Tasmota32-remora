modes_html =  ['Confort','Arrêt','Eco','Hors-gel','Eco -1','Eco -2','Delesté']
import webserver

class WEB_INTERFACE : Driver
	static def load_file(fn)
        var obj, f
        f = open(fn, 'r')
        obj = json.load(f.read())
        f.close()
        return obj
    end
    
    def create_html_boutonFP()
		var html
		html = ""
		if size(fps) > 0 
			for i:1..size(fps)
			html += "<p></p><button onclick='la(\"&inc_FP="+str(i)+"\");'>"+fps[i-1].nom+"</button>"
		end	
	end
	return html
	end

	def web_add_main_button()
		webserver.content_send(self.create_html_boutonFP())
	end
	
	def create_html_content_conf_fp()
		var html, html_json, j
		if size(fps) > 0 j = 0 else j= -1 end
		html = ''
		html_json = self.load_file('remora.tapp#/html.json')
		html += html_json['menu_fp_conf'][0]
		for i :1..NB_FP
			var a
			if j >= 0 && j <= size(fps)-1
				if i == fps[j].phy_id
					if fps[j].conf12 a='checked' else a='' end
					html += string.format(html_json['field_fp'],i,'',i,i,'checked',i,i,fps[j].nom,i,a)
					j += 1
				else
				html += string.format(html_json['field_fp'],i,'disabled',i,i,'',i,i,'FP'+str(i),i,'')
				end
			else
				html += string.format(html_json['field_fp'],i,'disabled',i,i,'',i,i,'FP'+str(i),i,'')
			end
		end
		html += html_json['button_conf_fp_save'] + html_json['menu_fp_conf'][1]
		return html
	end
	
	def web_add_config_button()
		webserver.content_send("<p><form id=conf_fp_button action='cfp' style='display: block;' method='get'><button>Configuration fils pilotes</button></form></p>")
	end

	def web_sensor()
		if size(fps) > 0
			var msg
			msg = ''
			for i:1..size(fps)
				msg += string.format("{s}%s{m}%s {e}", fps[i-1].nom, modes_html[modes.find(fps[i-1].etat)])
			end
			tasmota.web_send_decimal(msg)
		end
	
		if webserver.has_arg("inc_FP")
			var FP_to_inc = int(webserver.arg("inc_FP"))
			inc_etat_FP(FP_to_inc)			
		end
	end

  # page pour la configuration des fils pilotes 
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
		if webserver.has_arg('save')
			persist.fps = [] # supprime la configuration enregistrer dans le persist
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
  #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
  def web_add_handler()
    #- we need to register a closure, not just a function, that captures the current instance -#
    webserver.on("/cfp", / -> self.page_conf_FP_GET(),webserver.HTTP_GET)
    webserver.on("/cfp", / -> self.page_conf_FP_POST(), webserver.HTTP_POST)
  end
end

web_interface = WEB_INTERFACE()
tasmota.add_driver(web_interface)
web_interface.web_add_handler()

import webserver

modes_html =  ['Confort','Arrêt','Eco','Hors-gel','Eco -1','Eco -2']

def conv_FPUI(etat_FP)
	for i:0..5
		if etat_FP == modes[i]
			return modes_html[i]
		end
	end
end

class WEB_INTERFACE : Driver

	def create_html_boutonFP()
		var html
		html = ""
	for i:1..NB_FP
		html += "<p></p><button onclick='la(\"&inc_FP="+str(i)+"\");'>FP"+str(i)+"</button>"	
	end
	return html
	end

	def web_add_main_button()
		webserver.content_send(self.create_html_boutonFP())
	end

	def web_sensor()
		import string
		var msg = string.format(
		"{s}Fil pilote N°1{m}%s {e}"..
        "{s}Fil pilote N°2{m}%s {e}"..
        "{s}Fil pilote N°3{m}%s {e}"..
        "{s}Fil pilote N°4{m}%s {e}"..
        "{s}Fil pilote N°5{m}%s {e}"..
        "{s}Fil pilote N°6{m}%s {e}"..
        "{s}Fil pilote N°7{m}%s {e}",
        conv_FPUI(etats_FP[0]), conv_FPUI(etats_FP[1]), conv_FPUI(etats_FP[2]), conv_FPUI(etats_FP[3]),
        conv_FPUI(etats_FP[4]), conv_FPUI(etats_FP[5]), conv_FPUI(etats_FP[6]))
        tasmota.web_send_decimal(msg)
	
		if webserver.has_arg("inc_FP")
			var FP_to_inc = int(webserver.arg("inc_FP"))
			inc_etat_FP(FP_to_inc)			
		end
	end
end
web_interface = WEB_INTERFACE()
tasmota.add_driver(web_interface)

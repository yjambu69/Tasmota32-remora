var schedules = {}, derogations = {}
var time_initialized = false
if !persist.has('schedules') persist.schedules = {} end
if !persist.has('derogations') persist.derogations = {} end

def heure() # return int minutes depuis minuit
	var t
	t = tasmota.time_dump(tasmota.rtc().item('local'))
	return t.item('hour')*60+t.item('min') 
end

def jour() # return int 0 > dimanche 1 à 6 > lundi à samedi
	return tasmota.time_dump(tasmota.rtc().item('local')).item('weekday')
end

def heure_strtoint(heure) # heure format 00:00 return int minutes depuis minuit
	var H
	H = string.split(heure,':')
	return int(H[0])*60+int(H[1])
end

class CMDS : map # {fp_phy : cmd,..}
	def to_list()
		var l
		l = []
		for k:self.keys()
			l.push([k,self.item(k)])
		end
		return l
	end
end

class SCHEDULE
	var heure, jours, cmds
	def init(heure,jours,cmds)
		self.heure = heure
		self.jours = jours
		self.cmds = cmds
	end
	
	def has_jour(jour)
		return bytes(self.jours).getbits(jour,1)==1
	end
	
	def to_list()
		return [self.heure,self.jours,self.cmds.to_list()]
	end
end

class DEROGATION
	var timestamp_debut, timestamp_fin, cmds
	def init(timestamp_debut,timestamp_fin,cmds)
		self.timestamp_debut = timestamp_debut
		self.timestamp_fin = timestamp_fin
		self.cmds = cmds
	end

	def is_in_time()
		if (self.timestamp_debut <= tasmota.rtc().item('local')) && (self.timestamp_fin >= tasmota.rtc().item('local')) return true
		else return false end
	end
	def to_list()
		return [self.timestamp_debut,self.timestamp_fin,self.cmds.to_list()]
	end
end

def cmd_is_valid(cmd)
	if (cmd == 8) && (conf_is('gest_relais','prog',true,false)) return true
	elif fps.contains(cmd) return true
	end
	return false
end

def set_cmds(cmds)
	for k:cmds.keys()
		if k == 8 relais.set(cmds.item(k))
		else
			setfp(k,cmds.item(k),false)
		end
	end
end

def schedules_to_persist()
	if size(schedules) > 0
		persist.schedules = {}
		for k:schedules.keys()
			persist.schedules.insert(int(k),schedules.item(k).to_list())
		end
	end
	persist.save()
end
		
def schedules_load_from_persist()
	var _cmds, _schedule
	schedules = {}
	_schedule = []
	if persist.has('schedules')
		for k:persist.schedules.keys()
			_schedule = persist.schedules.item(k)
			_cmds = CMDS()
			for l:0..size(_schedule[2])-1
				if cmd_is_valid(_schedule[2][l][0]) _cmds.insert(_schedule[2][l][0],_schedule[2][l][1]) end
			end
			if size(_cmds) > 0 schedules.insert(int(k),SCHEDULE(_schedule[0],_schedule[1],_cmds)) end
		end
	end
end

def derogations_to_persist()
	if size(derogations) > 0
		persist.derogations = {}
		for k:derogations.keys()
			persist.derogations.insert(int(k),derogations.item(k).to_list())
		end
	end
	persist.save()
end

def derogations_load_from_persist()
	var _cmds, _derogation
	derogations = {}
	_derogation = []
	if persist.has('derogations')
		for k:persist.derogations.keys()
			_derogation = persist.derogations.item(k)
			_cmds = CMDS()
			for l:0..size(_derogation[2])-1
				if cmd_is_valid(_derogation[2][l][0]) _cmds.insert(_derogation[2][l][0],_derogation[2][l][1]) end
			end
			if size(_cmds) > 0 derogations.insert(int(k),DEROGATION(_derogation[0],_derogation[1],_cmds)) end
		end
	end
end

class TIMESTAMP_CMD
	var value,cmd
	def init(value,cmd)
		self.value=value
		self.cmd=cmd
	end
end

class TIMESTAMPS_CMD : list
	def add(value,cmd)
		if size(self) > 0
			var i=0
			while i <= size(self)-1
				if value >= self[i].value i+=1 else break end
			end
			self.insert(i,TIMESTAMP_CMD(value,cmd)) return self
		else self.push(TIMESTAMP_CMD(value,cmd)) return self end
	end
end

def sort_cmds()
	var h_cmd, i
	var now_in_the_week = heure()+jour()*1440, cmds_sort = {}, timestamps = {}
	for j:0..6
		for k:schedules.keys()
			if schedules.item(k).has_jour(j)
				h_cmd = (heure_strtoint(schedules.item(k).heure)+j*1440)
				for l:schedules.item(k).cmds.keys()
					if !timestamps.find(l) timestamps.insert(l,TIMESTAMPS_CMD().add(h_cmd,schedules.item(k).cmds.item(l)))
					else timestamps.item(l).add(h_cmd,schedules.item(k).cmds.item(l)) end					
				end
			end
		end
	end
	for k:timestamps.keys()
		i = size(timestamps.item(k))-1
		cmds_sort.insert(k,timestamps.item(k)[i].cmd)
		while i >= 0
			if timestamps.item(k)[i].value <= now_in_the_week cmds_sort.setitem(k,timestamps.item(k)[i].cmd) break end
			i -=1
		end
	end
	return cmds_sort
end

def init_schedules() #cherche et applique les commandes précédentes les plus proches.
	if !time_initialized return nil end # ne fait rien si l'heure n'a pas été initialisée.
	var cmds = CMDS()
	if size(schedules) > 0 cmds = sort_cmds() end
	#applique les dérogations
	if size(derogations) > 0
		for k:derogations.keys()
			if derogations.item(k).is_in_time()
				for i:derogations.item(k).cmds.keys()
					cmds.setitem(i,derogations.item(k).cmds.item(i))
				end
			end
		end
	end
	#applique les commandes			
	if size(cmds) > 0 set_cmds(cmds) end
end

def set_schedule(i,heure,jours,cmds)
	if i == nil #|| schedules.find(i) == nil
		if size(schedules) > 0
			i = 1
			while schedules.find(i) != nil i +=1 end
		else i = 1 end
	else
		if heure != nil schedules.item(i).heure = heure end
		if jours !=nil schedules.item(i).jours = jours end
		if cmds != nil schedules.item(i).cmds = cmds end
	end
	schedules.setitem(i,SCHEDULE(heure,jours,cmds))
	persist.schedules.setitem(i,schedules.item(i).to_list())
	persist.save()
	init_schedules()
end

def add_schedule(heure,jours,cmds)
	set_schedule(nil,heure,jours,cmds)
end

def del_schedule(i)
	if schedules.find(i) != nil
		schedules.remove(i)
		persist.schedules.remove(i)
		persist.save()
		init_schedules()
	end
end

def set_derogation(i,timestamp_debut,timestamp_fin,cmds)
	var _cmds
	if i == nil
		if size(derogations) > 0
			i = 1
			while derogations.find(i) != nil i +=1 end
		else i = 1 end
	else
		if timestamp_debut != nil derogations.item(i).timestamp_debut = timestamp_debut end
		if timestamp_fin !=nil derogations.item(i).timestamp_fin = timestamp_fin end
		if cmds != nil derogations.item(i).cmds = cmds end
	end
	derogations.setitem(i,DEROGATION(timestamp_debut,timestamp_fin,cmds))
	persist.derogations.setitem(i,derogations.item(i).to_list())
	persist.save()
	init_schedules()
end

def add_derogation(timestamp_debut,timestamp_fin,cmds)
	set_derogation(nil,timestamp_debut,timestamp_fin,cmds)
end

def del_derogation(i)
	if derogations.find(i) != nil
		derogations.remove(i)
		persist.derogations.remove(i)
		persist.save()
		init_schedules()
	end
end

def every_minute()
	var cmds
	cmds = {}
	for k:schedules.keys()
		if schedules.item(k).has_jour(jour()) && heure_strtoint(schedules.item(k).heure) == heure()
			for i:schedules.item(k).cmds.keys()
				cmds.insert(i,schedules.item(k).cmds.item(i))
			end
		end
	end
	#derogations
	for k:derogations.keys()
		if derogations.item(k).is_in_time()
			for i:derogations.item(k).cmds.keys()
				cmds.setitem(i,derogations.item(k).cmds.item(i))
			end
		end
	end
	# applique cmds
	if size(cmds) > 0 set_cmds(cmds) end
end

schedules_load_from_persist()
schedules_to_persist() #sauvegarde les programmes horaires si des fils pilotes ont été supprimés
derogations_load_from_persist()
derogations_to_persist()

def time_set()
	if !time_initialized
		tasmota.add_cron('* */1 * * * *',every_minute) # les crons ne fonctionnent pas si l'heure n'est pas à jour. (date > 01/01/2016)
		time_initialized = true
	end
	init_schedules()
end

if tasmota.rtc().find('utc') > 1640995200 time_set() # on considère que l'heure est à jour si la date > 01/01/2022. Cas avec un module rtc externe.
else tasmota.add_rule('Time#Initialized',time_set) end # après 1er synchro ntp, jamais enclenché avec un module rtc externe 
tasmota.add_rule('Time#Set',time_set) # à chaque modification d'heure, synchro ntp toutes les heures. Utile pour les changements heure été/hiver ?

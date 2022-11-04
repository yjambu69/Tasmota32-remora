import path

print("démarrage berry")

var racine
if path.exists('/remora.tapp')
	racine = '/remora.tapp#/'
else
	racine = '/'
end

load(racine+'mcp23017.be')
load(racine+'pilote.be')
load(racine+'schedule.be')
load(racine+'web_interface.be')
print("fin démarrage berry")

#-
 - I2C driver pour le chip mcp23017 écrit en Berry pour fonctionner sur la Remora
 - Les GPIOs fonctionnent uniquement en mode output et en état inverse
-#

MCP23017_ADDR = 0x20 # adresse I2C du MCP23017
class MCP23017 : Driver
  var wire          #- if wire == nil then the module is not initialized -#
  var b

  def init()
    self.b = bytes('AA57',-2) # valeur AA57 pour avoir les fils pilotes en mode arrêt au démarrage.
#- 2 octets pour les registres des GPIOs où chaque octets est composés des bits de chaque gpio. exemple 00000001 gpio A0 à 1. 10000001 gpios A7 et A0 à 1 -#
    self.wire = tasmota.wire_scan(MCP23017_ADDR, 22)
    if self.wire
      print("I2C: MCP23017 detecté sur le bus "+str(self.wire.bus))
      self.wire.write(MCP23017_ADDR, 0x05, 0x00, 1)	#reset bank mode to 0
      print("I2C: MCP23017 mis en mode 16 bit")
      tasmota.delay(10)
      self.wire.write_bytes(MCP23017_ADDR, 0x12, self.b) # initialise l'état des pins sur MCP23017_GPIOA = 0x12 et GPIOB = 0x13
      self.wire.write(MCP23017_ADDR, 0x00, 0x0000, 2) # met les pins en mode output MCP23017_IODIRA = 0x00 et IODIRB = 0x01
      print("I2C: pins mis en mode output et initialisées")
    end
  end
      
  def cmd_pin(pin,value) # pin 0 à 7 GPIOA pin > 7 GPIOB value 0 ou 1
#-	self.b = self.wire.read_bytes(MCP23017_ADDR, 0x12, 2) pas nécessaire de reprendre l'état des gpios -# 
	self.b.setbits(pin,1,!value) # logique inversée
	self.wire.write_bytes(MCP23017_ADDR, 0x12, self.b)
  end    
end

mcp23017 = MCP23017()
tasmota.add_driver(mcp23017)

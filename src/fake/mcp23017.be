#faux driver pour simuler un mcp23017

class MCP23017 : Driver
  #- 2 octets pour les registres des GPIOs où chaque octets est composés des bits de chaque gpio. exemple 00000001 gpio A0 à 1. 10000001 gpios A7 et A0 à 1 -#
  var b

  def init()
	self.b = bytes(-2)
  end
      
  def cmd_pin(pin,value) # pin 0 à 7 GPIOA pin > 7 GPIOB value 0 ou 1
	self.b.setbits(pin,1,!value) # logique inversée
  end
  
  def get_pin(pin)
	return int(!self.b.getbits(pin,1))
  end
end

mcp23017 = MCP23017()
tasmota.add_driver(mcp23017)

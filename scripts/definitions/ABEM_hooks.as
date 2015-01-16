import generic_effects;
import hooks;
import subsystem_effects;
import statuses;
import status_effects;
#section server
import ABEMCombat;
#section all

class Regeneration: SubsystemEffect {
	Document doc("Regenerates itself over time.");
	Argument amount(AT_Decimal, doc="Amount of health to heal per second.");
	Argument spread(AT_Boolean, "False", doc="If false, regeneration amount is applied to each hex individually. Otherwise, it is spread evenly across all the hexes.");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		uint Hexes = event.subsystem.get_hexCount();
		uint i = 0;
		double amount = arguments[0].decimal;
		double excess = 0;
		if(arguments[1].boolean) {
			amount = amount / Hexes;
		}
		for(i; i < Hexes; i++) {
			excess = event.blueprint.repair(event.obj, event.subsystem.hexagon(i), amount + excess);
			if(!arguments[1].boolean) {
				excess = 0;
			}
		}
		if(arguments[1].boolean) {
			for(i; i < Hexes; i++) {
				excess = event.blueprint.repair(event.obj, event.subsystem.hexagon(i), excess);
			}
		}
	}
#section all
};

class ReactorOverloadHook : StatusHook {
	Document doc("Handles the power-boosted explosion of a ship. Do not try to use on anything that isn't a ship.");
	Argument powerdamage(AT_Decimal, "5", doc="Number by which the ship's power output is multiplied when calculating damage.");
	Argument powerradius(AT_Decimal, "2", doc="Number by which the ship's power output is multiplied when calculating the blast radius.");
	Argument powerhits(AT_Decimal, "0.01", doc="Number by which the ship's power output is multiplied when calculating the amount of targets hit. Preferably less than 1 - defaults to 0.01.");
	Argument basedamage(AT_Decimal, "0", doc="Base damage. Added to the result of the power-damage calculation.");
	Argument baseradius(AT_Decimal, "0", doc="Base radius. Added to the result of the power-radius calculation.");
	Argument basehits(AT_Decimal, "4", doc="Base hit count. Added to the result of the power-hit calculation.");

#section server
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		ReactorOverload(obj, arguments[0].decimal, arguments[1].decimal, arguments[2].decimal, arguments[3].decimal, arguments[4].decimal, arguments[5].decimal);
	}

#section all
};
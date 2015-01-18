import generic_effects;
import hooks;
import subsystem_effects;
import statuses;
import status_effects;
#section server
import ABEMCombat;
#section all
import systems;
import influence;
from influence import InfluenceCardEffect;
import anomalies;
import orbitals;
import artifacts;
import resources;
from anomalies import IAnomalyHook;
from abilities import IAbilityHook, Ability, AbilityHook;

#section server
from influence_global import getInfluenceEffectOwner, canDismissInfluenceEffect;
from regions.regions import getRegion, isOutsideUniverseExtents;
#section shadow
from influence_global import getInfluenceEffectOwner, canDismissInfluenceEffect;
from regions.regions import getRegion, isOutsideUniverseExtents;
#section all
import target_filters;

class Regeneration : SubsystemEffect {
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
	Argument basedamage(AT_Decimal, "0", doc="Base damage. Added to the result of the power-damage calculation.");
	Argument baseradius(AT_Decimal, "0", doc="Base radius. Added to the result of the power-radius calculation.");

#section server
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		ReactorOverload(obj, arguments[0].decimal, arguments[1].decimal, arguments[2].decimal, arguments[3].decimal);
	}

#section all
};

class TargetRequireCommand : TargetFilter {
	Document doc("Restricts target to objects with a leader AI. (Flagships, orbitals and planets.)");
	Argument targ(TT_Object);

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Must target flagships, orbitals or planets.";
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		Object@ obj = targ.obj;
		if(obj is null)
			return false;
		return obj.hasLeaderAI;
	}
};

class TargetFilterStatus : TargetFilter {
	Document doc("Restricts target to objects with a particular status.");
	Argument targ(TT_Object);
	Argument status("Status", AT_Status, doc="Status to require.");

	string statusName = "DUMMY";

	bool instantiate() override {
		if(status.integer == -1) {
			error("Invalid argument: "+arguments[1].str);
			return false;
		}
		statusName = getStatusType(status.integer).name;
		return TargetFilter::instantiate();
	}
		

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Target must have the '" + statusName + "' status.";
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return false;
		if(targ.obj.hasStatusEffect(status.integer))
			return true;
		return false;
	}
};

class TargetFilterStatuses : TargetFilter {
	Document doc("Restricts target to objects with one of two particular statuses.");
	Argument targ(TT_Object);
	Argument status("Status", AT_Status, doc="First status to require.");
	Argument status2("Status 2", AT_Status, doc="Second status to require.");
	Argument mode("Exclusive", AT_Boolean, "False", doc="What relationship the two statuses must be in for the target to be valid. True - Must be one OR the other, can't be both. False - At least one of the statuses must be present. Defaults to false.");
	string statusName = "DUMMY";
	string status2Name = "DUMMY";


	bool instantiate() override {
		if(arguments[1].integer == -1) {
			error("Invalid argument: "+arguments[1].str);
			return false;
		}
		else if(arguments[1].str == arguments[2].str) {
			error("TargetFilterStatuses must have two different statuses: "+arguments[1].str+" "+arguments[2].str);
			return false;
		}
		else if(arguments[2].integer == -1) {
			error("Invalid argument: "+arguments[2].str);
			return false;
		}
		else {
			statusName = getStatusType(arguments[1].integer).name;
			status2Name = getStatusType(arguments[2].integer).name;
		}
		return TargetFilter::instantiate();
	}
			
	

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		if(arguments[3].boolean) {
			return "Target must have the '" + statusName + "' status or the '" + status2Name + "' status, but it must not have both!";
		}
		else {
			return "Target must have either the '" + statusName + "' status or the '" + status2Name + "' status.";
		}
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		if(targ.obj is null)
			return false;
		if(!targ.obj.hasStatuses)
			return false;
		if(targ.obj.hasStatusEffect(arguments[1].integer)) {
			if(arguments[3].boolean) {
				return !targ.obj.hasStatusEffect(arguments[2].integer);
			}
			else {
				return true;
			}
		}
		else {
			return targ.obj.hasStatusEffect(arguments[2].integer);
		}
	}
};

class TargetFilterNotType : TargetFilter {
	Document doc("Target must not be the type defined.");
	Argument targ(TT_Object);
	Argument type("Type", AT_Custom, "True", doc="Type of object.");
	int typeId = -1;

	bool instantiate() override {
		typeId = getObjectTypeId(arguments[1].str);
		if(typeId == -1) {
			error("Invalid object type: "+arguments[1].str);
			return false;
		}
		return TargetFilter::instantiate();
	}

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return "Cannot target " + localize("#OT_"+getObjectTypeName(typeId));
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(arguments[0].integer))
			return true;
		Object@ obj = targ.obj;
		if(obj is null)
			return false;
		return obj.type != typeId;
	}
};

class MaxStacks : StatusHook {
	Document doc("Cannot have more than # stacks.");
	Argument count("Maximum", AT_Integer, "10", doc="How many stacks of a status can exist on a given object. Defaults to 10.");

	#section server
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
		if(status.stacks > arguments[0].integer) {
			status.remove(obj, instance);
		}
	}
	#section all
};


class DisplayStatus : StatusHook {
	Document doc("Displays a dummy status on the origin object, IF that object isn't also the object the status is on.");
	Argument statustype("Status", AT_Status, doc="Status to display.");

	#section server
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
		if(obj !is status.originObject) {
			if(status.originObject.get_hasStatuses()) {
				status.originObject.addStatus(getStatusID(arguments[1].str));
			}
		}
	}
	#section all
};

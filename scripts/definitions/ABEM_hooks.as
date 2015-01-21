import generic_effects;
import hooks;
import subsystem_effects;
import statuses;
import status_effects;
import ability_effects;
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
		uint Hexes = event.subsystem.hexCount;
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

<<<<<<< HEAD

class AddThrustBonus : GenericEffect, TriggerableGeneric {
	Document doc("Add a bonus amount of thrust to the object. In case it is a planet, also allow the planet to move.");
	Argument amount(AT_Decimal, doc="Thrust amount to add.");

#section server
	void enable(Object& obj, any@ data) const override {
		if(obj.isPlanet) {
			Planet@ pl = cast<Planet>(obj);
			if(!pl.hasMover) {
				pl.activateMover();
				pl.maxAcceleration = 0;
			}
		}
		if(obj.hasMover)
			obj.modAccelerationBonus(+(amount.decimal * getMassFor(obj)));
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.modAccelerationBonus(-(amount.decimal * getMassFor(obj)));
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

class CombinedExpiration : StatusHook {
	Document doc("All stacks of the status expire simultaneously.");
	Argument duration("Duration", AT_Decimal, "10.0", doc="How long the status persists after its last application before expiring.");
	
	#section server
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) override {
		double timer = 0;
		data.store(timer);
	}
	
	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		double timer = 0;
		data.retrieve(timer);
		timer += time;
		data.store(timer);
		return timer < arguments[0].decimal;
	}
	#section all
}
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

class BoardingData {
	double boarders;
	double defenders;
	any data;
};

class Boarders : StatusHook {
	Document doc("Calculates the boarding strength of the origin object from a subsystem value, calculates the boarding strength of the target from another subsystem value and half of its crew. After a certain amount of time, either the boarders are repelled or the target is captured.");
	Argument offense("Offense Subsystem Value", AT_String, doc="Subsystem value to calculate strength from.");
	Argument defense("Defense Subsystem Value", AT_String, doc="Subsystem value to calculate defensive strength from.");
	Argument defaultboarders("Default Boarder Strength", AT_Decimal, "200.0", doc="If the subsystem value can't be found or is zero on the origin object, this is how strong the boarders will be. Defaults to 200.");
	Argument defaultdefenders("Default Defender Strength", AT_Decimal, "100.0", doc="If the subsystem value can't be found or is zero on the target object, and the object has no crew, this is how strong the defenders will be. Defaults to 100. Multiplied by 10000 if the target is a planet.");

	#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		// Calculating boarder strength.
		double boarders = 0;
		Ship@ caster = cast<Ship>(status.originObject);
		if(caster !is null)
			boarders = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(offense.str)));
		if(boarders <= 0)
			boarders = defaultboarders.decimal;
		
		// Calculating defender strength.
		double defenders = 0;
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null)
			// We want regular crew to count as half value; they're not as well-equipped or trained to repel boarders.
			defenders = ship.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(defense.str))) + (ship.blueprint.getEfficiencySum(SV_Crew) / 2);
		if(defenders <= 0)
			defenders = defaultdefenders.decimal;
		// We want a planet to be 10 thousand times as hard to capture via 'boarding' as other objects.
		// This means you need quite a dedicated force to conquer a world like this, even if someone allowed planets to be targeted with this ability.
		if(obj.isPlanet)
			defenders *= 10000;

		BoardingData info;
		info.boarders = boarders;
		info.defenders = defenders;
		data.store(@info);
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		BoardingData info;
		double boarders = 0;
		double defenders = 0;
		data.retrieve(@info);
		boarders = info.boarders;
		defenders = info.defenders;

		double ratio = boarders / defenders;
		// Basically, if there are 100 boarders and 100 defenders, 1 of each are lost per second. 
		// If there are 200 boarders, 0.55% of the boarders - incidentally, also 1 - are lost, but 2% of the defenders are lost.
		// This means that boarding operations will last a maximum of 100 seconds, though it will usually last less as one side will have an advantage over the other.
		// Hopefully, 100 seconds will give the boarded player enough time to respond, without allowing him to wait too long before acting. (And thus needlessly prolonging the battle.)
		boarders -= (boarders * 0.01) * ratio * time;
		defenders -= (defenders * 0.01) / ratio * time;

		if(defenders <= 0) {
			@obj.owner = status.originEmpire;
			return false;
		}
		if(boarders <= 0)
			return false;
		info.boarders = boarders;
		info.defenders = defenders;
		data.store(@info);
		return true;
	}
	#section all
};

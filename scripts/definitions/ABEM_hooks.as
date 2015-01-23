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

import hooks;
import abilities;
from abilities import AbilityHook;
from generic_effects import GenericEffect;
import bonus_effects;
from map_effects import MakePlanet, MakeStar;
import listed_values;
#section server
from objects.Artifact import createArtifact;
import bool getCheatsEverOn() from "cheats";
from game_start import generateNewSystem;
#section all

import statuses;
from statuses import StatusHook;
import planet_effects;
import tile_resources;
from bonus_effects import BonusEffect;

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
			obj.modAccelerationBonus(+(amount.decimal / getMassFor(obj)));
	}

	void disable(Object& obj, any@ data) const override {
		if(obj.hasMover)
			obj.modAccelerationBonus(-(amount.decimal / getMassFor(obj)));
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
	Argument offense("Offense Subsystem Value", AT_Custom, doc="Subsystem value to calculate strength from.");
	Argument defense("Defense Subsystem Value", AT_Custom, doc="Subsystem value to calculate defensive strength from. Defense is always multiplied by 10000 if the target is a planet.");
	Argument defaultboarders("Default Boarder Strength", AT_Decimal, "200.0", doc="If the subsystem value can't be found or is zero on the origin object, this is how strong the boarders will be. Defaults to 200.");
	Argument defaultdefenders("Default Defender Strength", AT_Decimal, "100.0", doc="If the subsystem value can't be found or is zero on the target object, and the object has no crew, this is how strong the defenders will be. Defaults to 100.");

	#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		// Calculating boarder strength.
		double boarders = 0;
		Ship@ caster = cast<Ship>(status.originObject);
		if(caster !is null)
			boarders = caster.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(offense.str)), ST_Boarders, true);
		if(boarders <= 0)
			boarders = defaultboarders.decimal;
		
		// Calculating defender strength.
		double defenders = 0;
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null)
			defenders = ship.blueprint.getEfficiencySum(SubsystemVariable(getSubsystemVariable(offense.str)));
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
		BoardingData@ info;
		double boarders = 0;
		double defenders = 0;
		data.retrieve(@info);
		boarders = info.boarders;
		defenders = info.defenders;

		double ratio = boarders / defenders;
		// Basically, if there are 100 boarders and 100 defenders, 1 of each are lost per second. 
		// If there are 200 boarders, 0.5% of the boarders - incidentally, also 1 - are lost, but 2% of the defenders are lost.
		// This means that boarding operations will last a maximum of 100 seconds, though it will usually last less as one side will have an advantage over the other.
		// Hopefully, 100 seconds will give the boarded player enough time to respond, without allowing him to wait too long before acting. (And thus needlessly prolonging the battle.)
		// EDIT: No more than 10% of all troops can be lost by either side in the engagement, so a minimum battle length is 10 seconds.
		boarders -= min((boarders * 0.01) * ratio, boarders * 0.1) * time;
		defenders -= min((defenders * 0.01) / ratio, boarders * 0.1) * time;
		debug();
		if(defenders <= 0) {
			@obj.owner = status.originEmpire;
			if(obj.hasStatuses) {
				if(obj.hasStatusEffect(getStatusID("DerelictShip")))
					obj.removeStatus(getStatusID("DerelictShip"));
			}
			return false;
		}
		if(boarders <= 0)
			return false;
		info.boarders = boarders;
		info.defenders = defenders;
		data.store(@info);
		debug();
		return true;
	}
	#section all
};

class TransferSupplyFromSubsystem : AbilityHook {
	Document doc("Gives supplies to its target while draining its own supplies, with a rate determined by a subsystem value. If the caster is not a ship, the default transfer rate is used instead, and the supply rate is irrelevant.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the transfer. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the transfer rate is 1 unit of supply per unit of HyperdriveSpeed in such a case.");
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default transfer rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null && caster.Supply == 0)
			return false;
		return true;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip) {
			Ship@ target = cast<Ship>(targ.obj);
			return target.Supply < target.MaxSupply;
		}
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ targetShip = cast<Ship>(target);
		if(targetShip is null || targetShip.Supply == targetShip.MaxSupply)
			return;

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

		float resupply = targetShip.MaxSupply - targetShip.Supply; 
		float resupplyCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			resupplyCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			resupplyCap = preset.decimal * time; // The 'default' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(resupplyCap < resupply)
			resupply = resupplyCap;

		if(castedByShip && caster.Supply < resupply)
			resupply = caster.Supply;
		
		if(castedByShip)
			caster.consumeSupply(resupply);
		targetShip.refundSupply(resupply);
	}
#section all
};

class TransferShieldFromSubsystem : AbilityHook {
	Document doc("Gives shields to its target while draining its own shields, with a rate determined by a subsystem value. If the caster is not a ship, the default transfer rate is used instead, and the subsystem value is irrelevant.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the transfer. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the transfer rate is 1 shield HP per unit of HyperdriveSpeed in such a case.");
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default transfer rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null && caster.Shield == 0)
			return false;
		return true;
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip) {
			Ship@ target = cast<Ship>(targ.obj);
			return target.Shield < target.MaxShield;
		}
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ targetShip = cast<Ship>(target);
		if(targetShip is null || targetShip.Shield == targetShip.MaxShield)
			return;

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Supply == 0) 
			return;

		float resupply = targetShip.MaxShield - targetShip.Shield; 
		float resupplyCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			resupplyCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			resupplyCap = preset.decimal * time; // The 'default' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(resupplyCap < resupply)
			resupply = resupplyCap;

		if(castedByShip && caster.Shield < resupply)
			resupply = caster.Shield;
		
		if(castedByShip)
			caster.Shield -= resupply;
		targetShip.Shield += resupply;
	}
#section all
};

class RechargeShields : GenericEffect {
	Document doc("Recharge the fleet's shields over time.");
	Argument base(AT_Decimal, doc="Base rate to recharge at per second.");
	Argument percent(AT_Decimal, "0", doc="Percentage of maximum shields to recharge per second.");
	Argument in_combat(AT_Boolean, "False", doc="Whether the recharge rate should apply in combat.");

#section server
	void tick(Object& obj, any@ data, double time) const override {
		if(!obj.isShip)
			return;
		if(!in_combat.boolean && obj.inCombat)
			return;

		Ship@ ship = cast<Ship>(obj);
		if(ship.Shield >= ship.MaxShield)
			return;

		double rate = time * base.decimal;
		if(percent.decimal != 0)
			rate += time * percent.decimal * ship.MaxShield;
		ship.Shield += rate;
		if(ship.Shield > ship.MaxShield)
			ship.Shield = ship.MaxShield;
	}
#section all
};

class ApplyToShips : StatusHook {
	Document doc("When this status is added to a system, it only applies to ships.");
	
	bool shouldApply(Empire@ emp, Region@ region, Object@ obj) const override {
		return obj !is null && obj.isShip;
	}
};

class AddOwnedStatus : AbilityHook {
	Document doc("Adds a status belonging to the specific object (and empire) activating the ability.");
	Argument objTarg(TT_Object);
	Argument status(AT_Status, doc="Type of status effect to create.");
	Argument duration(AT_Decimal, "-1", doc="How long the status effect should last. If set to -1, the status effect acts as long as this effect hook does.");
	
	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		return targ.obj.hasStatuses;
	}
	
#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		Empire@ dummyEmp = null;
		Region@ dummyReg = null;
		targ.addStatus(duration.decimal, getStatusType(status.str).id, dummyEmp, dummyReg, abl.obj.owner, abl.obj);
	}
#section all
};

class UserMustNotHaveStatus : AbilityHook {
	Document doc("The object using this ability must not be under the effects of the specified status.");
	Argument objTarg(TT_Object,  doc="Not a target, just a dummy to stave off null pointers...");
	Argument status(AT_Status, doc="Type of status effect to avoid.");
#section server
	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const {
		if(abl.obj is null)
			return false;
		if(!abl.obj.hasStatuses) {
			return true;
		}
		else {
				if(abl.obj.hasStatusEffect(getStatusType(status.str).id))
					return false;
		}
		return true;
	}
#section all
}

class DerelictData {
	double supply;
	double shield;
	any data;
}

class IsDerelict : StatusHook {
	Document doc("Marks the object as a derelict ship. Derelicts have 0 maximum shields and 0 maximum supply - which is part of what makes them incapable of repairing or otherwise defending themselves in any way. Should never be done without setting the ship's owner to defaultEmpire beforehand. Deals 1 damage per second as the ship is ravaged by time and the harsh, cold environment of space.");

#section server
	void onCreate(Object& obj, Status@ status, any@ data) override {
		Ship@ ship = cast<Ship>(obj);
		DerelictData info;
		if(ship !is null) {
			info.supply = ship.MaxSupply;
			ship.modSupplyBonus(-info.supply);
			info.shield = ship.MaxShield;
			ship.MaxShield -= info.shield;
			ship.Supply = 0;
			ship.Shield = 0;
			data.store(@info);
		}
		obj.engaged = true;
		obj.rotationSpeed = 0;
		obj.clearOrders();
	}
	
	void onDestroy(Object& obj, Status@ status, any@ data) override {
		DerelictData@ info;
		data.retrieve(@info);
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null) {
			ship.modSupplyBonus(+info.supply);
			ship.MaxShield += info.shield;
		}
		obj.rotationSpeed = 0.1;
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) override {
		DerelictData@ info;
		data.retrieve(@info);
		Ship@ ship = cast<Ship>(obj);
		if(ship !is null) {
			if(ship.MaxSupply > 0)
				info.supply += ship.MaxSupply;
			if(ship.MaxShield > 0)
				info.shield += ship.MaxShield;
			ship.Supply = 0;
			ship.Shield = 0;
			ship.modSupplyBonus(-ship.MaxSupply);
			ship.MaxShield -= ship.MaxShield;
		}
		DamageEvent dmg;
		dmg.damage = 1.0;
		dmg.partiality = 1;
		dmg.impact = 0;
		@dmg.obj = null;
		@dmg.target = obj;
		obj.damage(dmg, -1.0, vec2d(0, 0));
		obj.engaged = true;
		return true;
	}
#section all
};

class DestroyTarget: AbilityHook {
	Document doc("Destroys the target object.");
	Argument objTarg(TT_Object);
	
#section server
	void activate(Ability@ abl, any@ data, const Targets@ targs) const {
		Object@ obj = objTarg.fromConstTarget(targs).obj;
		if(obj !is null && obj.valid)
			obj.destroy();
	}
#section all
};
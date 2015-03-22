import statuses;
import abilities;
import ability_effects;
import trait_effects;
import traits;
import hooks;
import bonus_effects;
import generic_effects;
import pickups;
import pickup_effects;
import status_effects;
#section server
import empire;
#section all

class IfAtWar : IfHook {
	Document doc("Only applies the inner hook if the empire owning the object is currently at war with another player empire.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	
	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}
	
#section server
	bool condition(Object& obj) const override {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.major || owner is other)
				continue;
			if(owner.isHostile(other))
				return true;
		}
		return false;
	}
#section all
}

class IfNotAtWar : IfHook {
	Document doc("Only applies the inner hook if the empire owning the object is not currently at war with another player empire.");
	Argument hookID(AT_Hook, "planet_effects::GenericEffect");
	
	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return GenericEffect::instantiate();
	}
	
#section server
	bool condition(Object& obj) const override {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.major || owner is other)
				continue;
			if(owner.isHostile(other))
				return false;
		}
		return true;
	}
#section all
}

class AllyRemnants : TraitEffect {
	Document doc("Empires with this trait cannot attack or be attacked by the Remnants.");

#section server
	void postInit(Empire& emp, any@ data) const {
		Creeps.setHostile(emp, false);
		emp.setHostile(Creeps, false);
	}
#section all
}

class ConvertRemnants : AbilityHook {
	Document doc("Takes control of the target Remnant object. Also takes control of any support ships in the area.");
	Argument objTarg(TT_Object);

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const {
		return "Must target Remnants.";
	}

#section server	
	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(emp is null)
			return false;
		return targ.obj.owner is Creeps;
	}
	void activate(Ability@ abl, any@ data, const Targets@ targs) const {
		Object@ targ = objTarg.fromConstTarget(targs).obj;
		if(targ is null)
			return;
		if(targ.hasLeaderAI)
			targ.takeoverFleet(abl.obj.owner, 1, false);
		else
			@targ.owner = abl.obj.owner;
	}
#section all
}

class CostFromSize : AbilityHook {
	Document doc("Modifies the energy cost of this ability by comparing the object's size to another, fixed size.");
	Argument targ(TT_Object);
	Argument size(AT_Decimal, "256.0", doc="The size the object is being compared to.");
	Argument factor(AT_Decimal, "1.0", doc="The factor by which the size ratio is multiplied.");
	Argument min_pct(AT_Decimal, "0", doc="The smallest ratio allowed. If the actual ratio is lower than this, this number is used instead.");
	Argument max_pct(AT_Decimal, "1000.0", doc="The highest ratio allowed. If the actual ratio exceeds this, this number is used instead.");

	void modEnergyCost(const Ability@ abl, const Targets@ targs, double& cost) const override {
		if(targs is null)
			return;
		const Target@ trigTarg = targ.fromConstTarget(targs);
		if(trigTarg is null || trigTarg.obj is null)
			return;

		double theirScale = sqr(trigTarg.obj.radius);
		if(trigTarg.obj.isShip)
			theirScale = cast<Ship>(trigTarg.obj).blueprint.design.size;

		double rat = theirScale / size.decimal;
		cost *= clamp(rat * factor.decimal, min_pct.decimal, max_pct.decimal);
	}
}

class CannotOverrideProtection: PickupHook {
	Document doc("This pickup cannot be picked up if it is still protected, regardless of overrides such as those found in the Progenitor race.");
	Argument allow_same(AT_Boolean, "True", doc="Whether the pickup can still be picked up if it is owned by the empire trying to pick it up.");
	
#section server
	bool canPickup(Pickup& pickup, Object& obj) const {
		return pickup.isPickupProtected || (allow_same.boolean && pickup.owner is obj.owner);
	}
#section all
}

class GenerateResearchInCombat : StatusHook {
	Document doc("Fleets with this status generate research when in combat.");
	Argument amount(AT_Decimal, doc="How much research is generated each second.");
	
#section server
	void onDestroy(Object& obj, Status@ status, any@ data) {
		bool inCombat = false;
		data.retrieve(inCombat);
		if(inCombat)
			obj.owner.modResearchRate(-amount.decimal);
		data.store(false);
	}

	void onObjectDestroy(Object& obj, Status@ status, any@ data) {
		bool inCombat = false;
		data.retrieve(inCombat);
		if(inCombat)
			obj.owner.modResearchRate(-amount.decimal);
		data.store(false);
	}
	
	bool onTick(Object& obj, Status@ status, any@ data, double time) {
		bool inCombat = false;
		data.retrieve(inCombat);
		
		if(inCombat && !obj.inCombat)
			obj.owner.modResearchRate(-amount.decimal);
		else if(!inCombat && obj.inCombat)
			obj.owner.modResearchRate(+amount.decimal);
		data.store(obj.inCombat);
		return true;
	}
#section all
}
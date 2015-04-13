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
import target_filters;
#section server
import empire;
import influence_global;
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
	Document doc("This pickup cannot be picked up if it is still protected, regardless of overrides such as those found in the Progenitor race. DEPRECATED.");
	Argument allow_same(AT_Boolean, "True", doc="Whether the pickup can still be picked up if it is owned by the empire trying to pick it up.");
	
#section server
	bool canPickup(Pickup& pickup, Object& obj) const {
		return pickup.isPickupProtected || (allow_same.boolean && pickup.owner is obj.owner);
	}
#section all
}

class GenerateResearchInCombat : StatusHook {
	Document doc("Objects with this status generate research when in combat.");
	Argument amount(AT_Decimal, doc="How much research is generated each second.");
	
#section server
	void onDestroy(Object& obj, Status@ status, any@ data) {
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
	
	void save(Status@ status, any@ data, SaveFile& file) const {
		bool inCombat = false;
		data.retrieve(inCombat);

		file << inCombat;
	}

	void load(Status@ status, any@ data, SaveFile& file) const {
		bool inCombat = false;
		
		file >> inCombat;
		data.store(inCombat);
	}
#section all
}

class IfStatusHook: StatusHook {
	GenericEffect@ hook;

	bool withHook(const string& str) {
		@hook = cast<GenericEffect>(parseHook(str, "planet_effects::"));
		if(hook is null) {
			error("If<>(): could not find inner hook: "+escape(str));
			return false;
		}
		return true;
	}

	bool condition(Object& obj, Status@ status) const {
		return false;
	}

#section server
	void onCreate(Object& obj, Status@ status, any@ data) const {
		IfData info;
		info.enabled = condition(obj, status);
		data.store(@info);

		if(info.enabled)
			hook.onCreate(obj, status, info.data);
	}

	void onDestroy(Object& obj, Status@ status, any@ data) const {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.onDestroy(obj, status, info.data);
	}

	bool onTick(Object& obj, Status@ status, any@ data, double time) const {
		IfData@ info;
		data.retrieve(@info);

		bool cond = condition(obj, status);
		if(cond != info.enabled) {
			if(info.enabled)
				hook.onDestroy(obj, status, info.data);
			else
				hook.onCreate(obj, status, info.data);
			info.enabled = cond;
		}
		if(info.enabled)
			hook.onTick(obj, status, info.data, time);
		data.store(@info);
		return true;
	}

	void onOwnerChange(Object& obj, Status@ status, any@ data, Empire@ prevOwner, Empire@ newOwner) const {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.onOwnerChange(obj, status, info.data, prevOwner, newOwner);
	}

	void onRegionChange(Object& obj, Status@ status, any@ data, Region@ fromRegion, Region@ toRegion) const {
		IfData@ info;
		data.retrieve(@info);

		if(info.enabled)
			hook.onRegionChange(obj, status, info.data, fromRegion, toRegion);
	}

	void save(Status@ status, any@ data, SaveFile& file) const {
		IfData@ info;
		data.retrieve(@info);

		if(info is null) {
			bool enabled = false;
			file << enabled;
		}
		else {
			file << info.enabled;
			if(info.enabled)
				hook.save(status, info.data, file);
		}
	}

	void load(Status@ status, any@ data, SaveFile& file) const {
		IfData info;
		data.store(@info);

		file >> info.enabled;
		if(info.enabled)
			hook.load(status, info.data, file);
	}
#section all
};


class IfAlliedWithOriginEmpire : IfStatusHook {
	Document doc("Only apply the inner hook if the owner of this object is allied to the status' origin empire.");
	Argument hookID(AT_Hook);
	Argument allow_null(AT_Boolean, "True", doc="Whether the hook executes if the status has no origin empire.");
	Argument allow_self(AT_Boolean, "True", doc="Whether the hook executes if the object owner is the origin empire.");
	
	bool instantiate() override {
		if(!withHook(hookID.str))
			return false;
		return StatusHook::instantiate();
	}
	
#section server
	bool condition(Object& obj, Status@ status) {
		Empire@ owner = obj.owner;
		if(owner is null)
			return false;
		Empire@ origin = status.originEmpire;
		if(origin is null)
			return allow_null.boolean;
		if(origin is owner)
			return allow_self.boolean;
		return (origin.ForcedPeaceMask & owner.mask != 0) && (owner.ForcedPeaceMask & origin.mask != 0); 
	}
#section all
}

class ProtectPlanet : GenericEffect {
	Document doc("Planets affected by this status cannot be captured.");
	
#section server
	void disable(Object& obj, any@ data) const {
		if(obj.hasSurfaceComponent)
			obj.clearProtectedFrom();
	}

	void tick(Object& obj, any@ data, double time) const {
		uint mask = ~0;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i)
			mask &= getEmpire(i).mask;
		if(obj.hasSurfaceComponent)
			obj.protectFrom(mask);
	}
#section all
}

class TargetFilterNotRace : TargetFilter {
	Document doc("Only allow targets that have an empire that is of a particular race.");
	Argument targID(TT_Any);
	Argument trait(AT_Trait, doc="Trait to select for on human empires.");
	Argument name(AT_Locale, doc="Race name to require for AI empires.");

	string getFailReason(Empire@ emp, uint index, const Target@ targ) const override {
		return format(locale::NTRG_REQUIRE, getTrait(trait.integer).name);
	}

	bool isValidTarget(Empire@ emp, uint index, const Target@ targ) const override {
		if(index != uint(targID.integer))
			return true;
		Empire@ check;
		if(targ.type == TT_Empire) {
			@check = targ.emp;
		}
		else if(targ.type == TT_Object) {
			if(targ.obj is null)
				return false;
			@check = targ.obj.owner;
		}
		if(check is null)
			return false;
		if(check.isAI)
			return check.RaceName != name.str;
		else
			return !check.hasTrait(trait.integer);
	}
};

class IfRace : IfHook {
	Document doc("Only apply the inner hook if the owner of this object is of a particular race.");
	Argument hookID(AT_Hook, "generic_effects::GenericEffect");
	Argument trait(AT_Trait, doc="Trait to search for on human empires.");
	Argument name(AT_Locale, doc="Race name to require for AI empires.");

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
		if(owner.isAI)
			return owner.RaceName == name.str;
		else
			return owner.hasTrait(trait.integer);
	}
#section all
}

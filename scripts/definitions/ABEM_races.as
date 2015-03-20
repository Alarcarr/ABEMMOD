import statuses;
import abilities;
import hooks;
import bonus_effects;
import generic_effects;

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
}

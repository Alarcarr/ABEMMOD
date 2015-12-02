import hooks;
import buildings;
from buildings import IBuildingHook;
import abilities;
from abilities import IAbilityHook;
import statuses;
from statuses import IStatusHook;
import util.formatting;
import icons;
import ABEM_icons;
import constructions;
import listed_values;
from constructions import IConstructionHook;

#section server
from construction.Constructible import Constructible;
#section all

class ShowFTLCrystalValue : ListedValue {
	Document doc("Show an FTL crystal value in the tooltip.");
	Argument amount(AT_Decimal, doc="Amount of the value.");
	Argument name(AT_Locale, "#RESOURCE_FTL", doc="Name of the value.");
	Argument suffix(AT_Locale, EMPTY_DEFAULT, doc="Suffix behind the value.");

	bool getVariable(Object@ obj, Empire@ emp, Sprite& sprt, string& name, string& value, Color& color) const {
		double v = amount.decimal;
		Empire@ owner = emp;
		if(obj !is null && owner is null)
			@owner = obj.owner;

		sprt = ABEM_icons::FTLCrystal;
		color = colors::FTLResource;
		name = this.name.str;
		value = standardize(v, true);
		if(suffix.str.length != 0)
			value += " "+suffix.str;
		return true;
	}
};

class TransferPowerFromSubsystem : AbilityHook {
	Document doc("Gives Power to its target while draining its own Power, with a rate determined by a subsystem value. If the caster is not a ship, the default transfer rate is used instead, and the Power rate is irrelevant.");
	Argument objTarg(TT_Object);
	Argument value("Subsystem Value", AT_SysVar, doc="The subsystem value you wish to use to regulate the transfer. For example, HyperdriveSpeed would be Sys.HyperdriveSpeed - the transfer rate is 1 unit of Power per unit of HyperdriveSpeed in such a case.");
	Argument preset("Default Rate", AT_Decimal, "500.0", doc="The default transfer rate, used if the subsystem value could not be found (or is less than 0). Defaults to 500.");

	bool canActivate(const Ability@ abl, const Targets@ targs, bool ignoreCost) const override {
		Ship@ caster = cast<Ship>(abl.obj);
		if(caster !is null && caster.Energy == 0)
			return false;
		return true;
	}

	bool isValidTarget(const Ability@ abl, uint index, const Target@ targ) const override {
		if(index != uint(objTarg.integer))
			return true;
		if(targ.obj is null)
			return false;
		if(targ.obj.isShip) {
			Ship@ target = cast<Ship>(targ.obj);
			return target.Energy < target.MaxEnergy;
		}
		return false;
	}		

#section server
	void tick(Ability@ abl, any@ data, double time) const override {
		if(abl.obj is null)
			return;
		Target@ storeTarg = objTarg.fromTarget(abl.targets);
		if(storeTarg is null)
			return; 

		Object@ target = storeTarg.obj;
		if(target is null)
			return; 

		Ship@ targetShip = cast<Ship>(target);
		if(targetShip is null || targetShip.Energy == targetShip.MaxEnergy)
			return;

		Ship@ caster = cast<Ship>(abl.obj);
		bool castedByShip = caster !is null; 
		if(castedByShip && caster.Energy == 0) 
			return;

		float resupply = targetShip.MaxEnergy - targetShip.Energy; 
		float resupplyCap = 0; 
		
		
		if(castedByShip && value.fromSys(abl.subsystem, efficiencyObj=abl.obj) > 0) { 
			resupplyCap = value.fromSys(abl.subsystem, efficiencyObj=abl.obj) * time;
		}
		else {
			resupplyCap = preset.decimal * time; // The 'default' value is now only called if whoever wrote the ability didn't set a default value for 'value'. Still, better safe than sorry.
		}
		if(resupplyCap < resupply)
			resupply = resupplyCap;

		if(castedByShip && caster.Energy < resupply)
			resupply = caster.Energy;
		
		if(castedByShip)
			caster.consumeEnergy(resupply);
		targetShip.refundEnergy(resupply);
	}
#section all
};
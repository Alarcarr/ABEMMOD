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
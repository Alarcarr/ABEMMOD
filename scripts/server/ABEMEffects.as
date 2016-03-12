void LeakCrystals(Event& evt, double LeakPctPerSec) {
	if(evt.workingPercent >= 0.9999f)
		return;
	Ship@ ship = cast<Ship>(evt.obj);
	if(ship is null || ship.Crystals <= 0.0001f)
		return;

	ship.consumeCrystalPct(LeakPctPerSec * (1.0 - sqr(evt.workingPercent)) * evt.time);
}

void StartLocalFTLUpkeep(Event& evt, double amount) {
	if(evt.obj.isShip) {
		cast<Ship>(evt.obj).modFTLUse(+amount);
	}
}

void EndLocalFTLUpkeep(Event& evt, double amount) {
	if(evt.obj.isShip) {
		cast<Ship>(evt.obj).modFTLUse(+amount);
	}
}

enum WeaponResponse {
	// This stuff is important, as it defines how effectors (weapons) interact with the new Power mechanic.
	
	// If an effector calls ABEMWeaponFire with a Response of WR_AlwaysFire,
	// then the weapon will always fire regardless of whether it has enough Supply and Power.
	WR_AlwaysFire = 1, 
	
	// If it uses a Response of WR_FireIfEnergy,
	// then the weapon will fire only if it has enough Power.
	WR_FireIfEnergy = 2, 
	
	// If it uses a Response of WR_FireIfSupply,
	// then the weapon will fire only if it has enough Supply.
	WR_FireIfSupply = 3, 
	
	// And if it uses a Response of WR_FireIfEnergyAndSupply, or uses an invalid Response,
	// it will fire only if it has enough Supply and Power.
	WR_FireIfEnergyAndSupply = 4 
}

bool ABEMWeaponFire(const Effector& efftr, Object& obj, Object& target, float& efficiency, double supply, double energy, double Response) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return true;

	bool valid = true;

	if(Response != WR_AlwaysFire) {
		if(ship.Energy < energy) 
			valid = Response == WR_FireIfSupply;
		if(!ship.canConsumeSupply(supply))
			valid = Response == WR_FireIfEnergy;			
	}
	if(!valid)
		return false;
	
	ship.consumeEnergy(energy);
	ship.consumeSupply(supply);
	return true;
}
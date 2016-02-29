import combat;
import generic_effects;
import ABEM_data;
import ABEMCombat;

// Specialized effect script for the Powered Armor subsystem.
DamageEventStatus PoweredArmor(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double Resist, double PowerUse, double MinPct)
{
	// Traditional DR response flags.
	if(evt.flags & DF_IgnoreDR != 0)
		return DE_Continue;
	if(evt.flags & DF_FullDR != 0)
		MinPct = 0.01;
		
	// Checking if the target can provide enough Power, followed by consuming it.
	// If the object is a ship, and doesn't have enough Power, then we'll drain what we can and lower the damage resistance.
	double ratio = 1;
	if(evt.target.isShip) {
		Ship@ ship = cast<Ship>(evt.target);
		if(ship.Energy < PowerUse) {
			ratio = ship.Energy / PowerUse;
		}
		ship.consumeEnergy(PowerUse);
	}

	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

	// Perform ReduceDamagePercentile's damage calculations.
	double dmg = evt.damage;
	double dr;
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			dr = ProjResist; break;
		case DT_Energy:
			dr = EnergyResist; break;
		case DT_Explosive:
			dr = ExplResist; break;
		case DT_Generic:
		default:
			dr = (ProjResist + EnergyResist + ExplResist) / 3.0; break;
	}
	
	dr *= dmg;
	
	dmg -= dr * evt.partiality * ratio;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg; // Storing the results of ReduceDamagePercentile.

	// Applying DamageResist.
	dmg = evt.damage - (Resist * evt.partiality * ratio);
	minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	return DE_Continue; // And we're done.
}
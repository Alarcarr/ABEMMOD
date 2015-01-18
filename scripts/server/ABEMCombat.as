import statuses;
import combat;
import generic_effects;
import components.Statuses;
import ABEM_data;

int getDamageType(double type) {
	int iType = int(type);
	switch(iType) {
		case 1: 
			return DT_Projectile;
		case 2: 
			return DT_Energy;
		case 3:
			return DT_Explosive;
		default: return DT_Generic;
	}
	return DT_Generic;
}

DamageEventStatus ChannelDamage(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct, double RechargePercent)
{
	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

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
	
	if(evt.flags & QuadDRPenalty == 0)
		dr *= 4.0;
	
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null) {
		double Recharge = dr * RechargePercent;
		if((ship.Shield + Recharge) > ship.MaxShield) {
			ship.Shield = ship.MaxShield;
		}
		else {
			ship.Shield += Recharge;
		}
	}
	return DE_Continue;
}

DamageEventStatus ChannelDamagePercentile(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct, double RechargePercent)
{
	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

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

	if(evt.flags & QuadDRPenalty == 0)
		dr *= 4.0;
	
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	Ship@ ship = cast<Ship>(evt.target);
	if(ship !is null) {
		double Recharge = dr * RechargePercent;
		if((ship.Shield + Recharge) > ship.MaxShield) {
			ship.Shield = ship.MaxShield;
		}
		else {
			ship.Shield += Recharge;
		}
	}
	return DE_Continue;
}

DamageEventStatus ReduceDamagePercentile(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct)
{
	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

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
	
	if(evt.flags & QuadDRPenalty == 0)
		dr *= 4.0;
	
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	return DE_Continue;
}

void ReactorOverload(Object& obj, double PowerAmountMult, double PowerRadiusMult, double BaseAmount, double BaseRadius) {
	Ship@ ship = cast<Ship>(obj);
	if(ship !is null) {
		double power = ship.blueprint.getEfficiencySum(SV_Power);
		double amount = BaseAmount + sqrt(power * PowerAmountMult);
		double radius = BaseRadius + sqrt(power * PowerRadiusMult);
		ObjectAreaExplDamage(obj, amount, radius, 4);
		obj.destroy();
	}
}

void ObjectAreaExplDamage(Object& obj, double Amount, double Radius, double Hits) {
	vec3d center = obj.position;
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), obj.owner.hostileMask);

	playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, obj.visibleMask);

	uint hits = round(Hits);
	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Amount;
		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);
		
		//Rock the boat
		if(target.hasMover) {
			double amplitude = deal * 0.2 / (target.radius * target.radius);
			target.impulse(off.normalize(min(amplitude,8.0)));
			target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		}
		
		DamageEvent dmg;
		@dmg.obj = obj;
		@dmg.target = target;
		dmg.flags |= DT_Projectile;
		dmg.impact = off.normalized(target.radius);
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = 1 / double(hits);
			dmg.damage = deal * double(1) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
}

void IncreasingDamage(Event& evt, double Amount, double Status, double StatusMultiplier, double StatusAmount, double StatusIncrement, double DamageType) {
	DamageEvent dmg;
	int i;
	int StatusInt = int(Status);
	double Increment = StatusIncrement * double(evt.partiality) * double(evt.efficiency);
	int IncrementCount = int(Increment);
	Increment -= IncrementCount;
	if(Increment > 0.00001 && randomd() < Increment)
		IncrementCount += 1; 
	Empire@ dummyEmp = null;
	Region@ dummyReg = null;
	const StatusType@ type = getABEMStatus(StatusInt);
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;
	int dmgType = getDamageType(DamageType);

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= dmgType | ReachedInternals;

	// If there was an invalid Status, then we need to detect it before we try to do anything else.
	if(evt.target.hasStatuses && type !is null) {
		// If it already has the status, find the status and check its stack count to apply some math.
		uint stacks = 0;
		stacks = evt.target.getStatusStackCount(type.id, evt.obj, evt.obj.owner);
		dmg.damage += (dmg.damage * stacks * StatusMultiplier) + (stacks * StatusAmount * double(evt.efficiency) * double(evt.partiality));
		print("Stacks: "+stacks);
		for(i = 0; i < IncrementCount; ++i) {
			evt.target.addStatus(-1, type.id, dummyEmp, dummyReg, evt.obj.owner, evt.obj);
		}
	}
	evt.target.damage(dmg, -1.0, evt.direction);
}
					
void DamageFromRelativeSize(Event& evt, double Amount, double SizeMultiplier, double AmountPerSize, double MinRatio, double MaxRatio, double DamageType) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;
	int dmgType = getDamageType(DamageType);

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= dmgType | ReachedInternals;

	if(evt.obj !is null) { // This particular bit of code is probably unneeded, but better safe than sorry.
		// This whole section is just copy-pasted with renamed variables from RelativeSizeEnergyCost, the AbilityHook.
		double myScale = sqr(evt.obj.radius);
		if(evt.obj.isShip)
			myScale = cast<Ship>(evt.obj).blueprint.design.size;
		double theirScale = sqr(evt.target.radius);
		if(evt.target.isShip)
			theirScale = cast<Ship>(evt.target).blueprint.design.size;

		double ratio = theirScale / myScale; // Just to wrap my mind around it: If they're size 200, and we're size 100, then this will yield a ratio of 2, which is 200%. Good.
		dmg.damage *= clamp(ratio, MinRatio, MaxRatio) * SizeMultiplier;
		dmg.damage += AmountPerSize * clamp(ratio, MinRatio, MaxRatio) * double(evt.efficiency) * double(evt.partiality);
	}
	evt.target.damage(dmg, -1.0, evt.direction);
}

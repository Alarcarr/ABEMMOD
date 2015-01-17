import statuses;
import combat;

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
			dmg.partiality = 0.5 / double(hits);
			dmg.damage = deal * double(0.5) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
}

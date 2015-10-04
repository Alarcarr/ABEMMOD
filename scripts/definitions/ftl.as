#section server-side
from regions.regions import getRegion;
#section all
import orbitals;

const double HYPERDRIVE_COST = 0.08;
const double HYPERDRIVE_START_COST = 25.0;
const double HYPERDRIVE_CHARGE_TIME = 15.0;

bool canHyperdrive(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null || !ship.hasLeaderAI)
		return false;
	if(isFTLBlocked(ship))
		return false;
	return ship.blueprint.hasTagActive(ST_Hyperdrive);
}

double hyperdriveSpeed(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.getEfficiencySum(SV_HyperdriveSpeed);
}

int hyperdriveCost(Object& obj, vec3d position) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0;
	auto@ dsg = ship.blueprint.design;
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0;
	return ceil(log(dsg.size) * (dsg.total(HV_Mass)*0.5/dsg.size) * sqrt(position.distanceTo(obj.position)) * HYPERDRIVE_COST + HYPERDRIVE_START_COST);
}

int hyperdriveCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i) {
		if(!canHyperdrive(objects[i]))
			continue;
		cost += hyperdriveCost(objects[i], destination);
	}
	return cost;
}

double hyperdriveRange(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return 0.0;
	int scale = ship.blueprint.design.size;
	return hyperdriveRange(obj, scale, playerEmpire.FTLStored);
}

double hyperdriveRange(Object& obj, int scale, int stored) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return INFINITY;
	return sqr(max(double(stored) - HYPERDRIVE_START_COST, 0.0) / (log(double(scale)) * HYPERDRIVE_COST));
}

bool canHyperdriveTo(Object& obj, const vec3d& pos) {
	return !isFTLBlocked(obj, pos);
}

const double FLING_BEACON_RANGE = 10000.0;
const double FLING_BEACON_RANGE_SQ = sqr(FLING_BEACON_RANGE);
const double FLING_COST = 8.0;
const double FLING_CHARGE_TIME = 15.0;
const double FLING_TIME = 10.0;

bool canFling(Object& obj) {
	if(isFTLBlocked(obj))
		return false;
	if(!obj.hasLeaderAI)
		return false;
	if(obj.isShip) {
		return true;
	}
	else {
		if(obj.isOrbital) {
			if(obj.owner.isFlingBeacon(obj))
				return false;
			Orbital@ orb = cast<Orbital>(obj);
			auto@ core = getOrbitalModule(orb.coreModule);
			return core is null || core.canFling;
		}
		if(obj.isPlanet)
			return true;
		return false;
	}
}

bool canFlingTo(Object& obj, const vec3d& pos) {
	return !isFTLBlocked(obj, pos);
}

double flingSpeed(Object& obj, const vec3d& pos) {
	return obj.position.distanceTo(pos) / FLING_TIME;
}

int flingCost(Object& obj, vec3d position) {
	Region@ reg = obj.region;
	Empire@ owner = obj.owner;
	if(reg !is null && owner !is null && reg.FreeFTLMask & owner.mask != 0)
		return 0;
	if(obj.isShip) {
		Ship@ ship = cast<Ship>(obj);
		auto@ dsg = ship.blueprint.design;
		int scale = dsg.size;
		double massFactor = dsg.total(HV_Mass) * 0.3/dsg.size;
		return ceil(FLING_COST * sqrt(double(scale)) * massFactor);
	}
	else {
		if(obj.isOrbital)
			return ceil(FLING_COST * obj.radius * 3.0);
		else if(obj.isPlanet)
			return ceil(FLING_COST * obj.radius * 30.0);
		return INFINITY;
	}
}

int flingCost(array<Object@>& objects, const vec3d& destination) {
	int cost = 0;
	for(uint i = 0, cnt = objects.length; i < cnt; ++i)
		cost += flingCost(objects[i], destination);
	return cost;
}

double flingRange(Object& obj) {
	if(flingCost(obj, obj.position) > obj.owner.FTLStored)
		return 0.0;
	return INFINITY;
}

const double SLIPSTREAM_CHARGE_TIME = 15.0;
const double SLIPSTREAM_LIFETIME = 10.0 * 60.0;

bool canSlipstream(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null || !ship.hasLeaderAI)
		return false;
	if(isFTLBlocked(ship))
		return false;
	return ship.blueprint.hasTagActive(ST_Slipstream);
}

int slipstreamCost(Object& obj, int scale, double distance) {
	Ship@ ship = cast<Ship>(obj);
	double overhead = ship.blueprint.design.total(SV_SlipstreamOverhead);
	double distCost = ship.blueprint.design.total(SV_SlipstreamDistCost);
	return ceil(distance * distCost / 1000.0 + overhead);
}

double slipstreamRange(Object& obj, int scale, int stored) {
	Ship@ ship = cast<Ship>(obj);
	double overhead = ship.blueprint.design.total(SV_SlipstreamOverhead);
	double distCost = ship.blueprint.design.total(SV_SlipstreamDistCost);
	return max(double(stored) - overhead, 0.0) / (distCost / 1000.0);
}

double slipstreamLifetime(Object& obj) {
	Ship@ ship = cast<Ship>(obj);
	return ship.blueprint.getEfficiencySum(SV_SlipstreamDuration);
}

void slipstreamModifyPosition(Object& obj, vec3d& position) {
	double radius = slipstreamInaccuracy(obj, position);

	vec2d offset = random2d(radius);
	position += vec3d(offset.x, randomd(-radius * 0.2, radius * 0.2), offset.y);
}

double slipstreamInaccuracy(Object& obj, const vec3d& position) {
	double dist = obj.position.distanceTo(position);
	return dist * 0.01;
}

bool canSlipstreamTo(Object& obj, const vec3d& point) {
	auto@ reg = obj.region;
	if(reg !is null) {
		if(reg.BlockFTLMask & obj.owner.mask != 0)
			return false;
	}
	@reg = getRegion(point);
	if(reg !is null) {
		if(reg.BlockFTLMask & obj.owner.mask != 0)
			return false;
	}
	return true;
}

bool isFTLBlocked(Object& obj, const vec3d& point) {
	auto@ reg = getRegion(point);
	if(reg is null)
		return false;
	if(reg.BlockFTLMask & obj.owner.mask != 0)
		return true;
	return false;
}

bool isFTLBlocked(Object& obj) {
	auto@ reg = obj.region;
	if(reg is null)
		return false;
	if(reg.BlockFTLMask & obj.owner.mask != 0)
		return true;
	return false;
}

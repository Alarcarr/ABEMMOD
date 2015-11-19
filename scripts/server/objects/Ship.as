import resources;
import util.target_search;
import regions.regions;
import saving;
from generic_effects import RegionChangeable, LeaderChangeable;
from influence_global import giveRandomReward, DiplomacyEdictType;
from designs import getDesignMesh;

MeshDesc shipMesh;

//Amount of points per unit of size of a ship
const double SHIP_SIZE_POINTS = 0.0;

//Rate of repair in combat
const double COMBAT_REPAIR_MOD = 1.0 / 4.0;

//Amount of effectiveness gained from energy = size
const float ENERGY_EFFECTIVENESS = 1.25f;

//Threshold at which lack of supply starts causing efficiency loss
const float SUPPLY_THRESHOLD = 0.5f;

//Lowest efficiency supply can make a fleet go down to
const float SUPPLY_EFFICIENCY = 0.25f;

//Supply rate in trade border systems
const float SUPPLY_TRADE_RATE = 0.26f;

//Supply rate in unowned systems
const float SUPPLY_UNOWNED_RATE = 0.12f;

//Rate at which supression recovers
const float SUPPRESSION_REGEN = 0.05f;

//Chance of extinguishing fire per second
const float EXTINGUISH_CHANCE = 0.2f;

//Fire damage-per-second per size
const float FIRE_DPS = 0.25;

class ShipScript {
	Object@ lastHitBy;
	Empire@ killCredit;
	uint bpStatusID = 0;
	bool barDelta = false, onFire = false, needRepair = true, shieldDelta = false;
	int prevSupply = 0;
	int currentMaintenance = 0;
	float mass = 0.f;
	float massBonus = 0.f;
	float currentRepair = 0.f;
	float currentRepairCost = 0.f;
	float shipEffectiveness = 0.f;
	float suppression = 0.f;
	float wreckage = 0.f;
	float shieldRegen = 0.f;
	float ftlRegen = 0.f;
	float crystalConsumption = 0.f;
	float emergencyFTLRegen = 0.f;
	float energyRegen = 0.f;
	Object@ cachedLeader;
	const Design@ retrofitTo;
	const Design@ queuedRetrofit;
	float timer = 0.f, bpTimer = 0.f;
	float supplyBonus = 0.f;
	float crystalBonus = 0.f;
	float shieldRegenBonus = 0.f;
	float shieldRegenMod = 1;
	float shieldBonus = 0.f;
	float ftlRegenMod = 1;
	float energyUse = 0.f;
	float energyRegenMod = 1;
	float repairMod = 1;
	float ftlUse = 0.f;
	int disableRegionVision = 0;
	int holdFire = 0;
	float movementAccel = 0;

	ShipScript() {
	}

	void save(Ship& ship, SaveFile& file) {
		saveObjectStates(ship, file);
		file << cast<Savable>(ship.Mover);

		if(ship.hasLeaderAI) {
			file << true;
			file << cast<Savable>(ship.LeaderAI);
		}
		else {
			file << false;
		}

		if(ship.hasSupportAI) {
			file << true;
			file << cast<Savable>(ship.SupportAI);
		}
		else {
			file << false;
		}

		if(ship.hasAbilities) {
			file << true;
			file << cast<Savable>(ship.Abilities);
		}
		else {
			file << false;
		}

		if(ship.hasStatuses) {
			file << true;
			file << cast<Savable>(ship.Statuses);
		}
		else {
			file << false;
		}

		if(ship.hasCargo) {
			file << true;
			file << cast<Savable>(ship.Cargo);
		}
		else {
			file << false;
		}

		if(ship.hasConstruction) {
			file << true;
			file << cast<Savable>(ship.Construction);
		}
		else {
			file << false;
		}

		if(ship.hasOrbit) {
			file << true;
			file << cast<Savable>(ship.Orbit);
		}
		else {
			file << false;
		}

		file << currentMaintenance;
		file << ship.isFree;
		file << ship.isFTLing;
		file << ship.delayFTL;

		file << prevSupply;
		file << ship.Energy;
		file << ship.MaxEnergy;
		file << ship.Supply;
		file << ship.MaxSupply;
		file << ship.formationDest;
		ship.blueprint.save(ship, file);
		file << ship.Leader;
		file << ship.RetrofittingAt;
		file << retrofitTo;
		file << queuedRetrofit;
		file << suppression;
		file << wreckage;
		file << onFire;
		file << supplyBonus;
		file << massBonus;
		file << ship.Shield;
		file << ship.MaxShield;
		file << shieldRegen;
		file << disableRegionVision;
		file << holdFire;
		file << movementAccel;
		file << ship.FTL;
		file << ship.MaxFTL;
		file << ship.Crystals;
		file << ship.MaxCrystals;
		file << crystalBonus;
		file << ftlUse;
		file << shieldRegenBonus;
		file << shieldRegenMod;
		file << ftlRegenMod;
		file << energyUse;
		file << energyRegenMod;
		file << repairMod;
		file << shieldBonus;
	}
	
	void load(Ship& ship, SaveFile& file) {
		timer = -float(uint8(ship.id)) / 255.f;
		bpTimer = timer - 0.5f;
		
		loadObjectStates(ship, file);
		file >> cast<Savable>(ship.Mover);

		bool has = false;
		file >> has;
		if(has) {
			ship.activateLeaderAI();
			file >> cast<Savable>(ship.LeaderAI);
		}

		file >> has;
		if(has) {
			ship.activateSupportAI();
			file >> cast<Savable>(ship.SupportAI);
		}

		file >> has;
		if(has) {
			ship.activateAbilities();
			file >> cast<Savable>(ship.Abilities);
		}

		file >> has;
		if(has) {
			ship.activateStatuses();
			file >> cast<Savable>(ship.Statuses);
		}

		if(file >= SV_0122) {
			file >> has;
			if(has) {
				ship.activateCargo();
				file >> cast<Savable>(ship.Cargo);
			}
		}

		if(file >= SV_0108) {
			file >> has;
			if(has) {
				ship.activateConstruction();
				file >> cast<Savable>(ship.Construction);
			}
		}

		if(file >= SV_0060) {
			file >> has;
			if(has) {
				ship.activateOrbit();
				file >> cast<Savable>(ship.Orbit);
			}
		}

		file >> currentMaintenance;
		file >> ship.isFree;
		file >> ship.isFTLing;
		file >> ship.delayFTL;

		file >> prevSupply;
		file >> ship.Energy;
		file >> ship.MaxEnergy;
		file >> ship.Supply;
		file >> ship.MaxSupply;
		file >> ship.formationDest;
		ship.blueprint.load(ship, file);
		@ship.Leader = file.readObject();
		file >> ship.RetrofittingAt;
		file >> retrofitTo;
		file >> queuedRetrofit;
		file >> suppression;
		file >> wreckage;
		file >> onFire;
		if(file >= SV_0077)
			file >> supplyBonus;
		if(file >= SV_0081)
			file >> massBonus;
		if(file >= SV_0092) {
			file >> ship.Shield;
			file >> ship.MaxShield;
			file >> shieldRegen;
		}
		if(file >= SV_0104) {
			file >> disableRegionVision;
			file >> holdFire;
		}
		if(file >= SV_0117)
			file >> movementAccel;
		
		file >> ship.FTL;
		file >> ship.MaxFTL;
		file >> ship.Crystals;
		file >> ship.MaxCrystals;
		file >> crystalBonus;
		file >> ftlUse;
		file >> shieldRegenBonus;
		file >> shieldRegenMod;
		file >> ftlRegenMod;
		file >> energyUse;
		file >> energyRegenMod;
		file >> repairMod;
		file >> shieldBonus;

		getDesignMesh(ship.blueprint.design, shipMesh);
		bindMesh(ship, shipMesh);
	}

	bool get_isStation(Ship& ship) {
		return ship.blueprint.design.hasTag(ST_Station);
	}

	void setHoldFire(bool value) {
		if(value)
			holdFire += 1;
		else
			holdFire -= 1;
	}

	bool getHoldFire() {
		return holdFire > 0 || inFTL;
	}

	void setDisableRegionVision(bool value) {
		if(value)
			disableRegionVision += 1;
		else
			disableRegionVision -= 1;
	}

	bool getDisableRegionVision() {
		return disableRegionVision > 0;
	}

	void modMass(Ship& ship, float amount) {
		massBonus += amount;
		ship.blueprint.statusID++;
	}

	float getMass() {
		return max(mass + massBonus, 0.01f);
	}

	float getBaseMass() {
		return max(mass, 0.01f);
	}

	void postLoad(Ship& ship) {
		if(ship.hasLeaderAI) {
			ship.leaderPostLoad();
			Node@ node = ship.getNode();
			if(node !is null)
				node.animInvis = true;
		}
		
		cacheStats(ship);
		updateStats(ship, true);
		
		if(ship.region !is null) {
			Node@ node = ship.getNode();
			if(node !is null)
				node.hintParentObject(ship.region, false);
		}
	}
	
	void init(Ship& ship) {
		timer = -float(uint8(ship.id)) / 255.f;
		bpTimer = timer - 0.5f;
	}

	uint moneyType(Ship& ship) {
		const Design@ dsg = ship.blueprint.design;
		if(dsg !is null && dsg.hasTag(ST_Station))
			return MoT_Orbitals;
		return MoT_Ships;
	}

	stat::EmpireStat statType(Ship& ship) {
		const Design@ dsg = ship.blueprint.design;
		if(dsg !is null && dsg.hasTag(ST_Station))
			return stat::Stations;
		return stat::Ships;
	}

	void postInit(Ship& ship) {
		cacheStats(ship);
		updateStats(ship, true);
		if(ship.hasLeaderAI) {
			ship.Supply = ship.MaxSupply;
			ship.FTL = ship.MaxFTL;
			ship.Crystals = ship.MaxCrystals;
		}
		else {
			ship.Supply = 0;
			ship.FTL = 0;
			ship.Crystals = 0;
		}


		if(ship.hasLeaderAI) {
			ship.leaderInit();
			ship.activateStatuses();
			ship.activateAbilities();

			if(ship.owner.valid)
				ship.owner.recordStatDelta(statType(ship), 1);
			auto@ node = ship.getNode();
			if(node !is null)
				node.animInvis = true;
		}
		else{
			ship.supportInit();
		}

		if(ship.owner !is null && ship.owner.valid) {
			if(ship.hasLeaderAI)
				ship.owner.points += int(double(ship.blueprint.design.size) * SHIP_SIZE_POINTS);

			if(ship.hasLeaderAI) {
				ship.owner.TotalFlagshipsBuilt += 1;
				ship.owner.TotalFlagshipsActive += 1;
			}
			else {
				ship.owner.TotalSupportsBuilt += 1;
				ship.owner.TotalSupportsActive += 1;
			}
		}

		ship.startEffects();
	}

	void startEffects(Ship& ship) {
		if(ship.blueprint.design.hasTag(ST_Ability)) {
			if(!ship.hasAbilities)
				ship.activateAbilities();
			ship.initAbilities(ship.blueprint.design);
		}

		ship.blueprint.start(ship);
	}

	int get_maintenanceCost() {
		return currentMaintenance;
	}

	void setHealthPct(Ship& obj, float pct) {
		if(pct >= 0.999f)
			return;
		auto@ bp = obj.blueprint;
		vec2i size = bp.design.hull.gridSize;

		DamageEvent evt;
		evt.pierce = 0.f;
		@evt.obj = obj;
		@evt.target = obj;
		for(int x = 0; x < size.x; ++x) {
			for(int y = 0; y < size.y; ++y) {
				auto@ status = bp.getHexStatus(x, y);
				if(status !is null && status.hp != 0) {
					evt.damage = bp.design.variable(vec2u(x,y), HV_HP) * (1.f - pct);
					if(evt.damage > 0.001f)
						bp.damage(obj, evt, vec2u(x, y));
				}
			}
		}
		needRepair = true;
		bp.delta = true;
	}

	void makeNotFree(Ship& ship) {
		if(ship.isFree) {
			if(ship.owner !is null && ship.owner.valid) {
				currentMaintenance = ship.blueprint.design.total(HV_MaintainCost);
				ship.owner.modMaintenance(currentMaintenance, moneyType(ship));
			}
			else {
				currentMaintenance = 0;
			}
			ship.isFree = false;
		}
	}

	void startRetrofit(Ship& ship, Object@ from, const Design@ to) {
		if(ship.RetrofittingAt !is null)
			return;
		@ship.RetrofittingAt = from;
		@retrofitTo = to;
	}

	void stopRetrofit(Ship& ship, Object@ from) {
		if(ship.RetrofittingAt is from) {
			@ship.RetrofittingAt = null;
			@retrofitTo = null;
		}
	}

	void completeRetrofit(Ship& ship, Object@ from) {
		if(ship.RetrofittingAt is from) {
			makeNotFree(ship);
			@queuedRetrofit = retrofitTo;
			@ship.RetrofittingAt = null;
			@retrofitTo = null;
		}
	}

	void cacheStats(Ship& ship) {
		ship.MaxDPS = ship.blueprint.design.total(SV_DPS);
		if(ship.hasLeaderAI) {
			ship.MaxSupply = ship.blueprint.design.total(SV_SupplyCapacity) + supplyBonus;
			ship.MaxCrystals = ship.blueprint.design.total(SV_CrystalCapacity) + crystalBonus;
		}
		else
			ship.MaxSupply = ship.blueprint.design.total(SV_SupportSupplyCapacity) + supplyBonus;
		mass = ship.blueprint.design.total(HV_Mass);
		//ship.MaxEnergy = 0;

		const Design@ dsg = ship.blueprint.design;
		ship.hasVectorMovement = ship.isStation || (dsg.hasTag(ST_VectorThrust) && !dsg.hasTag(ST_TurnToThrust));
	}

	void modSupplyBonus(Ship& ship, float amount) {
		supplyBonus += amount;
		if(ship.hasLeaderAI)
			ship.MaxSupply = ship.blueprint.design.total(SV_SupplyCapacity) + supplyBonus;
		else
			ship.MaxSupply = ship.blueprint.design.total(SV_SupportSupplyCapacity) + supplyBonus;
		if(ship.MaxSupply > 0 && amount < 0)
			ship.Supply += (ship.Supply / ship.MaxSupply) * amount;
	}

	void modCrystalBonus(Ship& ship, float amount) {
		crystalBonus += amount;
		if(ship.hasLeaderAI)
			ship.MaxCrystals = ship.blueprint.design.total(SV_CrystalCapacity) + crystalBonus;
		if(ship.MaxCrystals > 0 && amount < 0)
			ship.Crystals += (ship.Crystals / ship.MaxCrystals) * amount;
	}
	
	void modFTLUse(Ship& ship, float amount) {
		ftlUse += amount;
	}
	
	void modEnergyUse(Ship& ship, float amount) {
		energyUse += amount;
	}
	
	void modShieldRegenBonus(Ship& ship, float amount) {
		shieldRegenBonus += amount;
	}
	
	void modShieldRegenMod(Ship& ship, float amount) {
		shieldRegenMod += amount;
	}
	
	void modFTLRegenMod(Ship& ship, float amount) {
		ftlRegenMod += amount;
	}
	
	void modEnergyRegenMod(Ship& ship, float amount) {
		energyRegenMod += amount;
	}
	
	void modRepairMod(Ship& ship, float amount) {
		repairMod += amount;
	}
	
	void modShieldBonus(Ship& ship, float amount) {
		shieldBonus += amount;
	}

	void updateAccel(Ship& ship) {
		float leaderAccel = ship.blueprint.getEfficiencySum(SV_Thrust) / max(mass + massBonus, 0.01f);
		float supportAccel = ship.slowestSupportAccel;
		float resultAccel = leaderAccel;
		if(supportAccel > 0.0f && supportAccel * 0.75f < leaderAccel)
			resultAccel = supportAccel * 0.75f;
		if(resultAccel > movementAccel || leaderAccel < movementAccel || !ship.isMoving) {
			ship.maxAcceleration = resultAccel;
			movementAccel = resultAccel;
		}

		double turnThrust = ship.blueprint.getEfficiencySum(SV_TurnThrust);
		if(turnThrust != 0)
			ship.rotationSpeed = max(turnThrust / max(mass + massBonus, 0.01f), 0.005f);
	}

	void updateStats(Ship& ship, bool init = false) {
		const Design@ dsg = ship.blueprint.design;

		//Set the mover's maximum acceleration based on thrust
		if(init) {
			ship.maxAcceleration = ship.blueprint.getEfficiencySum(SV_Thrust) / max(mass + massBonus, 0.01f);

			double turnThrust = ship.blueprint.getEfficiencySum(SV_TurnThrust);
			if(turnThrust != 0)
				ship.rotationSpeed = max(turnThrust / max(mass + massBonus, 0.01f), 0.005f);
		}
		else
			updateAccel(ship);

		//Record the used command
		float commandUsed = dsg.variable(ShV_REQUIRES_Command);
		float powerUsed = dsg.variable(ShV_REQUIRES_Power) + energyUse;

		//Record DPS
		ship.DPS = ship.blueprint.getEfficiencySum(SV_DPS);
		
		//Update shield stats
		double maxShield = ship.blueprint.getEfficiencySum(SV_ShieldCapacity) + shieldBonus;
		if(maxShield != ship.MaxShield) {
			if(maxShield == 0) {
				ship.Shield = 0;
				ship.MaxShield = 0;
				shieldRegen = 0;
			}
			else if(ship.MaxShield > 0) {
				ship.Shield = maxShield * (ship.Shield / ship.MaxShield);
				ship.MaxShield = maxShield;
				shieldRegen = ship.blueprint.getEfficiencySum(SV_ShieldRegen);
			}
			else {
				ship.MaxShield = maxShield;
				shieldRegen = ship.blueprint.getEfficiencySum(SV_ShieldRegen);
			}
			shieldRegen =(shieldRegen * shieldRegenMod) + shieldRegenBonus;
			shieldDelta = true;
		}
		
		// Update FTL stats
		double maxFTL = ship.blueprint.getEfficiencySum(SV_FTLCapacity);
		if(maxFTL != ship.MaxFTL) {
			if(maxFTL == 0) {
				ship.FTL = 0;
			}
			else if(ship.MaxFTL > 0) {
				ship.FTL = maxFTL * (ship.FTL / ship.MaxFTL);
			}
			ship.MaxFTL = maxFTL;
			barDelta = true;
		}

		ftlRegen = ship.blueprint.getEfficiencySum(SV_FTLRegen) * ftlRegenMod;
		crystalConsumption = ship.blueprint.getEfficiencySum(SV_CrystalConsumption) * ftlRegenMod;
		emergencyFTLRegen = (ship.blueprint.getEfficiencySum(SV_Power) * energyRegenMod - powerUsed) / 100;
		
		energyRegen = ship.blueprint.getEfficiencySum(SV_Power) * energyRegenMod - powerUsed;
				
		double maxEnergy = ship.blueprint.getEfficiencySum(SV_EnergyCapacity);
		if(maxEnergy != ship.MaxEnergy) {
			if(maxEnergy == 0) {
				ship.Energy = 0;
			}
			else if(ship.MaxEnergy > 0) {
				ship.Energy = maxEnergy * (ship.Energy / ship.MaxEnergy);
			}
			ship.MaxEnergy = maxEnergy;
			barDelta = true;
		}

		//Set the supply capacity of the ship
		int supply = ship.blueprint.getEfficiencySum(SV_SupportCapacity);
		if(supply != prevSupply) {
			ship.modSupplyCapacity(supply - prevSupply);
			prevSupply = supply;
		}

		//Modify ship efficiency based on available command
		float commandAvail = ship.blueprint.getEfficiencySum(SV_Command);
		if(commandAvail >= commandUsed || commandUsed <= 0.0)
			shipEffectiveness = 1.f;
		else if(commandAvail == 0.f && dsg.total(SV_Command) == 0.f)
			shipEffectiveness = 1.f;
		else
			shipEffectiveness = float(commandAvail) / commandUsed;

		//Low power also decreases effectiveness
		if(powerUsed > 0) {
			float powerAvail = ship.blueprint.getEfficiencySum(SV_Power) * energyRegenMod;
			if(powerAvail < powerUsed)
				shipEffectiveness *= sqr(powerAvail / powerUsed);
		}
		
		float effectiveness = shipEffectiveness;
		if(suppression > 0.f)
			effectiveness /= 1.f + suppression;

		{
			double minRange = INFINITY, maxRange = -INFINITY;
			for(uint i = 0, cnt = dsg.subsystemCount; i < cnt; ++i) {
				auto subsys = dsg.subsystems[i];
				
				for(uint j = 0, jcnt = subsys.effectorCount; j < jcnt; ++j) {
					double range = subsys.effectors[j].range;
					if(range < minRange)
						minRange = range;
					if(range > maxRange)
						maxRange = range;
				}
			}
			
			if(!ship.hasLeaderAI)
				ship.supportEngageRange = minRange;
			ship.minEngagementRange = minRange;
			ship.maxEngagementRange = maxRange;
		}
		

		if(!ship.hasLeaderAI) {
			Object@ leader = ship.Leader;
			if(leader !is null)
				effectiveness *= leader.getFleetEffectiveness();
			else
				effectiveness *= SUPPLY_EFFICIENCY;
			ship.blueprint.shipEffectiveness = effectiveness;
		}
		else {
			ship.blueprint.shipEffectiveness = double(effectiveness) * double(ship.getFleetEffectiveness());
		}

		//Store the amount of repair we have available
		currentRepair = ship.blueprint.getEfficiencySum(SV_Repair) * repairMod;
		currentRepairCost = ship.blueprint.getEfficiencySum(SV_RepairSupplyCost) * repairMod;

		//Check if we should update our maintenance
		if(!ship.isFree && ship.owner !is null && ship.owner.valid) {
			int maint = ship.blueprint.design.total(HV_MaintainCost);
			if(maint != currentMaintenance) {
				ship.owner.modMaintenance(maint - currentMaintenance, moneyType(ship));
				currentMaintenance = maint;
			}
		}

		bpStatusID = ship.blueprint.statusID;
	}
	
	void scuttle(Ship& ship) {
		ship.destroy();
	}
	
	void destroy(Ship& ship) {
		if(ship.owner !is null && ship.owner.valid && currentMaintenance != 0)
			ship.owner.modMaintenance(-currentMaintenance, moneyType(ship));

		//Assuming we've been hit recently, the likely cause of death is explosion
		if(killCredit !is null && !game_ending) {
			auto size = ship.blueprint.design.size;			
			if(size < 16)
				playParticleSystem("ShipExplosionLight", ship.position, ship.rotation, ship.radius, ship.visibleMask);
			else
				playParticleSystem("ShipExplosion", ship.position, ship.rotation, ship.radius, ship.visibleMask);
			if(size > 64)
				playParticleSystem("ShipExplosionExtra", ship.position, ship.rotation, ship.radius, ship.visibleMask);
			if(size >= 200)
				playParticleSystem("ShipExplosionLong", ship.position, ship.rotation, ship.radius, ship.visibleMask);
			
			auto@ region = ship.region;
			if(region !is null) {
				uint debris = uint(log(size) / log(2.0));
				if(debris > 0)
					region.addShipDebris(ship.position, debris);
			}
			

			if(ship.hasLeaderAI && currentMaintenance != 0) {
				Empire@ master = killCredit.SubjugatedBy;
				if(master !is null && master.getEdictType() == DET_Conquer) {
					if(master.getEdictEmpire() is ship.owner) {
						giveRandomReward(killCredit, double(currentMaintenance) / 100.0);
					}
				}
			}
		}
	
		if(ship.owner !is null && ship.owner.valid) {
			if(ship.hasLeaderAI) {
				ship.owner.points -= int(double(ship.blueprint.design.size) * SHIP_SIZE_POINTS);
				ship.owner.recordStatDelta(statType(ship), -1);
			}
			if(killCredit !is ship.owner)
				ship.owner.recordStatDelta(stat::ShipsLost, 1);
		}

		if(ship.hasSupportAI) {
			ship.supportDestroy();

			if(ship.owner !is null)
				ship.owner.TotalSupportsActive -= 1;
		}
		else if(ship.hasLeaderAI) {
			ship.leaderDestroy();

			if(ship.owner !is null)
				ship.owner.TotalFlagshipsActive -= 1;
		}

		leaveRegion(ship);
		ship.blueprint.destroy(ship);
		if(ship.hasStatuses)
			ship.destroyStatus();
		if(ship.hasConstruction)
			ship.destroyConstruction();
		if(ship.hasAbilities)
			ship.destroyAbilities();
			
		if(killCredit !is null && killCredit !is ship.owner && killCredit.valid)
			killCredit.recordStatDelta(stat::ShipsDestroyed, 1);
	}
	
	bool onOwnerChange(Ship& ship, Empire@ prevOwner) {
		if(prevOwner !is null && prevOwner.valid) {
			if(currentMaintenance != 0)
				prevOwner.modMaintenance(-currentMaintenance, moneyType(ship));

			if(ship.hasLeaderAI) {
				prevOwner.TotalFlagshipsActive -= 1;
				prevOwner.recordStatDelta(statType(ship), -1);
				prevOwner.points -= int(double(ship.blueprint.design.size) * SHIP_SIZE_POINTS);
			}
			else
				prevOwner.TotalSupportsActive -= 1;
		}
		
		if(ship.owner !is null && ship.owner.valid) {
			if(currentMaintenance != 0)
				ship.owner.modMaintenance(currentMaintenance, moneyType(ship));

			if(ship.hasLeaderAI) {
				ship.owner.TotalFlagshipsActive += 1;
				ship.owner.recordStatDelta(statType(ship), 1);
				ship.owner.points += int(double(ship.blueprint.design.size) * SHIP_SIZE_POINTS);
			}
			else
				ship.owner.TotalSupportsActive += 1;
		}
		if(ship.hasAbilities)
			ship.abilityOwnerChange(prevOwner, ship.owner);
		if(ship.hasStatuses)
			ship.changeStatusOwner(prevOwner, ship.owner);
		regionOwnerChange(ship, prevOwner);
		if(ship.hasLeaderAI)
			ship.leaderChangeOwner(prevOwner, ship.owner);
		ship.blueprint.ownerChange(ship, prevOwner, ship.owner);
		return false;
	}

	bool consumeMinEnergy(Ship& ship, double amount) {
		if(ship.Energy < amount)
			return false;
		ship.Energy -= amount;
		barDelta = true;
		return true;
	}

	void consumeEnergy(Ship& ship, double amount) {
		ship.Energy = max(0.0, ship.Energy - amount);
		barDelta = true;
	}
	
	bool consumeMinSupply(Ship& ship, double amount) {
		if(ship.Supply >= amount) {
			ship.Supply = max(0.0, ship.Supply - amount);
			barDelta = true;
			return true;
		}
		else {
			return false;
		}
	}

	bool consumeMinFTL(Ship& ship, double amount) {
		if(ship.FTL >= amount) {
			ship.FTL = max(0.0, ship.FTL - amount);
			barDelta = true;
			return true;
		}
		else {
			return false;
		}
	}

	void consumeFTL(Ship& ship, double amount) {
		ship.FTL = max(0.0, ship.FTL - amount);
		barDelta = true;
	}

	void consumeSupply(Ship& ship, double amount) {
		if(ship.hasLeaderAI) {
			ship.Supply = max(0.0, ship.Supply - amount);
			barDelta = true;
		}
		else {
			if(ship.isDetached) {
				ship.Supply = max(0.0, ship.Supply - amount);
				barDelta = true;
			}
			else {
				Ship@ lead = cast<Ship>(cachedLeader);
				if(lead !is null) {
					lead.consumeSupply(amount);
					return;
				}
			}
		}
	}

	void consumeSupplyPct(Ship& ship, double pct) {
		ship.Supply = max(0.0, ship.Supply - pct * ship.MaxSupply);
		barDelta = true;
	}
	
	void consumeEnergyPct(Ship& ship, double pct) {
		ship.Energy = max(0.0, ship.Energy - pct * ship.MaxEnergy);
		barDelta = true;
	}
	
	void consumeCrystalPct(Ship& ship, double pct) {
		ship.Crystals = max(0.0, ship.Crystals - pct * ship.MaxCrystals);
		barDelta = true;
	}

	void refundEnergy(Ship& ship, double amount) {
		ship.Energy = min(ship.MaxEnergy, ship.Energy + amount);
		barDelta = true;
	}

	void refundSupply(Ship& ship, double amount) {
		ship.Supply = min(ship.MaxSupply, ship.Supply + amount);
		barDelta = true;
	}

	void refundFTL(Ship& ship, double amount) {
		double refund = ship.FTL + amount;
		double crystalRefund = 0;
		if(refund > ship.MaxFTL) {
			crystalRefund = (refund - ship.MaxFTL) * (ftlRegen / crystalConsumption);
			refund = ship.MaxFTL - ship.FTL;
			ship.Crystals = min(ship.MaxCrystals, ship.Crystals + crystalRefund);
		}
		ship.FTL = refund;
		barDelta = true;
	}

	void repairShip(Ship& ship, double amount) {
		ship.blueprint.repair(ship, amount);
	}
	
	void mangle(double amount) {
		wreckage += amount;
	}
	
	void suppress(double amount) {
		suppression += amount;
	}
	
	void startFire() {
		onFire = true;
	}

	void triggerLeaderChange(Ship& ship, Object@ prevLeader, Object@ newLeader) {
		if(ship.blueprint.design.dataCount != 0) {
			uint hookN = 0;
			SubsystemEvent evt;
			@evt.obj = ship;
			@evt.design = ship.blueprint.design;
			@evt.blueprint = ship.blueprint;
			for(uint i = 0, cnt = ship.blueprint.design.subsystemCount; i < cnt; ++i) {
				auto@ subsys = ship.blueprint.design.subsystems[i];
				for(uint n = 0, ncnt = subsys.hookCount; n < ncnt; ++n) {
					auto@ cls = cast<LeaderChangeable>(subsys.hooks[n]);
					if(cls !is null) {
						@evt.subsystem = subsys;
						@evt.data = ship.blueprint.getHookData(hookN);
						cls.leaderChange(evt, prevLeader, newLeader);
					}
					hookN += 1;
				}
			}
		}
	}

	float combatTimer = 0.f;
	bool prevEngaged = false;
	bool inFTL = false;
	void occasional_tick(Ship& ship, float time) {
		Empire@ owner = ship.owner;
		Region@ reg = ship.region;
		Ship@ shipLeader = cast<Ship>(cachedLeader);
		bool regionChanged = updateRegion(ship, takeVision=false);
		inFTL = ship.inFTL;
		if(regionChanged) {
			if(ship.hasLeaderAI) {
				ship.leaderRegionChanged();
				if(ship.hasStatuses)
					ship.changeStatusRegion(reg, ship.region);
			}
			else {
				Node@ node = ship.getNode();
				if(node !is null)
					node.hintParentObject(ship.region, false);
			}

			if(ship.blueprint.design.dataCount != 0) {
				uint hookN = 0;
				SubsystemEvent evt;
				@evt.obj = ship;
				@evt.design = ship.blueprint.design;
				@evt.blueprint = ship.blueprint;
				for(uint i = 0, cnt = ship.blueprint.design.subsystemCount; i < cnt; ++i) {
					auto@ subsys = ship.blueprint.design.subsystems[i];
					for(uint n = 0, ncnt = subsys.hookCount; n < ncnt; ++n) {
						auto@ cls = cast<RegionChangeable>(subsys.hooks[n]);
						if(cls !is null) {
							@evt.subsystem = subsys;
							@evt.data = ship.blueprint.getHookData(hookN);
							cls.regionChange(evt, reg, ship.region);
						}
						hookN += 1;
					}
				}
			}
			
			@reg = ship.region;
		}

		//Take vision from region
		if(reg !is null) {
			if(disableRegionVision <= 0 && (shipLeader is null|| !shipLeader.getDisableRegionVision()))
				ship.donatedVision |= reg.DonateVisionMask;
		}

		//Update in combat flags
		bool engaged = ship.engaged;
		if(cachedLeader !is null) {
			if(engaged)
				cachedLeader.engaged = true;
			if(cachedLeader.inCombat)
				engaged = true;
		}

		if(holdFire > 0 || inFTL || (shipLeader !is null && (shipLeader.getHoldFire() || (ship.isDetached && ship.Supply <= 0.001))))
			ship.blueprint.holdFire = true;
		else
			ship.blueprint.holdFire = false;
		
		if(engaged)
			combatTimer = 5.f;
		else
			combatTimer -= time;
		
		{
			bool nowCombat = combatTimer > 0.f;
			if(ship.inCombat != nowCombat) {
				ship.inCombat = nowCombat;
				barDelta = true;
			}
		}
		ship.engaged = false;

		//Deal with combat facing
		if(engaged) {
			Object@ target = ship.blueprint.getCombatTarget();
			if(target is null)
				@target = findEnemy(ship, ship, owner, ship.position, 500.0);
			if(target !is null) {
				//Always face the fleet as a whole
				{
					Ship@ othership = cast<Ship>(target);
					if(othership !is null) {
						Object@ leader = othership.Leader;
						if(leader !is null)
							@target = leader;
					}
				}

				//Find optimal facing
				vec3d facing = ship.blueprint.getOptimalFacing(SV_DPS);
				vec3d diff = target.position - ship.position;
				diff.normalize();

				//Rotate so that target rotation * facing = diff
				quaterniond rot = quaterniond_fromVecToVec(facing, diff);
				ship.setCombatFacing(rot);
				
				if(ship.hasLeaderAI) {
					//Order a random support to assist
					uint cnt = ship.supportCount;
					if(cnt > 0) {
						uint attackWith = max(1, cnt / 8);
						for(uint i = 0, off = randomi(0,cnt-1); i < attackWith; ++i) {
							Object@ sup = ship.supportShip[(i+off) % cnt];
							if(sup !is null)
								sup.supportAttack(target);
						}
					}
				}
			}
			else
				ship.clearCombatFacing();
			if(reg !is null)
				reg.EngagedMask |= owner.mask;
		}
		else if(prevEngaged) {
			ship.clearCombatFacing();
		}
		
		prevEngaged = engaged;

		bool isContested = engaged || (reg !is null && reg.ContestedMask & owner.mask != 0);

		//Deal with energy charge
		float fleetEffectiveness = 1.f;
//		if(ship.MaxEnergy > 0 && ship.Energy < ship.MaxEnergy) {
//			if((reg !is null && reg.TradeMask & owner.TradeMask.value != 0 && !engaged)
//					|| owner.GlobalCharge) {
//				/*float chargeRate = ship.blueprint.getEfficiencySum(SV_ChargeRate);*/
//				float chargeRate = 0.f;
//				float amt = min(chargeRate * time, ship.MaxEnergy - ship.Energy);
//				amt = owner.consumeEnergy(amt);
//				if(amt > 0.f) {
//					ship.Energy = min(ship.Energy + amt, ship.MaxEnergy);
//					barDelta = true;
//				}
//			}
//		}

		if(ship.hasSupportAI) {
			ship.supportTick(time);
			if(cachedLeader !is null)
				ship.seeableRange = cachedLeader.seeableRange;
			else
				ship.seeableRange = FLOAT_INFINITY;
		}
		else if(ship.hasLeaderAI) {
			ship.commandTick();
		//	if(ship.Energy > 0) {
		//		//Calculate extra fleet effectiveness based on energy
		//		//relative to ship size and supply.
		//		float size = ship.blueprint.design.size;
		//		fleetEffectiveness *= 1.f + ENERGY_EFFECTIVENESS * (ship.Energy / size);
		//	}

			if(ship.MaxSupply > 0) {
				//Supply recharge
				if(ship.Supply < ship.MaxSupply) {
					float chargeRate = ship.blueprint.getEfficiencySum(SV_SupplyRate);
					float amt = chargeRate * time;

					if(isContested || reg is null) {
						amt = 0.f;
					}
					else if(reg.TradeMask & owner.TradeMask.value == 0) {
						if(reg.isTradableRegion(owner))
							amt *= SUPPLY_TRADE_RATE;
						else
							amt *= SUPPLY_UNOWNED_RATE;
					}

					if(amt > 0) {
						ship.Supply = min(ship.MaxSupply, ship.Supply + amt);
						barDelta = true;
					}
				}

				//Supply effectiveness
				float sup = ship.Supply / ship.MaxSupply;
				if(sup < SUPPLY_THRESHOLD)
					fleetEffectiveness *= SUPPLY_EFFICIENCY + sup * ((1.f - SUPPLY_EFFICIENCY) / SUPPLY_THRESHOLD);
			}
			else {
				fleetEffectiveness *= SUPPLY_EFFICIENCY;
			}
			if(ship.MaxCrystals > 0) {
				// FTL crystal resupply
				if(ship.Crystals < ship.MaxCrystals) {
					float chargeRate = ship.blueprint.getEfficiencySum(SV_CrystalRate);
					float amt = chargeRate * time;

					if(isContested || reg is null || reg.PlanetsMask & ship.owner.mask == 0) {
						amt = 0.f;
					}

					amt = min(ship.MaxCrystals - ship.Crystals, amt);
					amt = ship.owner.consumeFTL(amt);
					
					if(amt > 0) {
						ship.Crystals = min(ship.MaxCrystals, ship.Crystals + amt);
						barDelta = true;
					}
				}
			}

			//Efficiency decrease due to debt
			float debtFactor = ship.owner.DebtFactor;
			if(debtFactor > 1.f)
				fleetEffectiveness *= pow(0.5f, debtFactor-1.f);

			fleetEffectiveness *= owner.FleetEfficiencyFactor;
			ship.setFleetEffectiveness(fleetEffectiveness);
			
			updateAccel(ship);
		}
		
		float effectiveness = shipEffectiveness;
		float prevEffectiveness = ship.blueprint.shipEffectiveness;
		//Deal with fleet effectiveness
		if(ship.hasLeaderAI) {
			effectiveness *= ship.getFleetEffectiveness();
			ship.blueprint.shipEffectiveness = effectiveness;
			ship.updateFleetStrength();
		}
		else {
			Object@ leader = ship.Leader;
			if(leader !is null)
				effectiveness *= leader.getFleetEffectiveness();
			else
				effectiveness *= SUPPLY_EFFICIENCY;
			ship.blueprint.shipEffectiveness = effectiveness;
		}
		if(prevEffectiveness != ship.blueprint.shipEffectiveness)
			ship.blueprint.delta = true;

		if(suppression > 0.f) {
			//Apply suppression before recovery, or small suppression will never do anything
			effectiveness /= 1.f + suppression;
			suppression -= (1.f + suppression) * SUPPRESSION_REGEN * time;
			if(suppression < 0.f)
				suppression = 0.f;
		}
		
		if(onFire && time > 0) {
			double fireDamage = ship.blueprint.design.size * FIRE_DPS * time * owner.FireDamageTakenFactor;
			internalDamage(ship, fireDamage);
			if(effectiveness > 0 && randomd() < pow(EXTINGUISH_CHANCE, 1.0 / (time * effectiveness)))
				onFire = false;
		}
		
		//Clear kill credits after short spans of time
		if(killCredit !is null && !ship.inCombat) {
			@killCredit = null;
			@lastHitBy = null;
		}

		//Check if we can retrofit
		if(queuedRetrofit !is null && !isContested) {
			retrofit(ship, queuedRetrofit);
			@queuedRetrofit = null;
		}
		
		@cachedLeader = ship.Leader;
	}
	
	double tick(Ship& ship, double time) {
		auto@ bp = ship.blueprint;
		if(bp.statusID != bpStatusID)
			updateStats(ship);
		
		bool inCombat = ship.inCombat;
			
		//Keep a timer for some occasional checks
		timer += float(time);
		if(timer >= 1.f) {
			occasional_tick(ship, timer);
			timer = 0.f;
		}

		double delay = 0.2;
		double d = 0.2;
		
		if(inCombat) {
			bpTimer += time;
			if(bpTimer > 0.2f) {
				d = bp.tick(ship, bpTimer);
				bpTimer = 0.f;
			}
		}
		else {
			bpTimer += time;
			if(bpTimer >= 1.f) {
				d = bp.tick(ship, bpTimer);
				bpTimer = 0.f;
			}
		}

		if(!ship.hasSupportAI) {
			if(ship.hasLeaderAI) {
				ship.orderTick(time);
				ship.leaderTick(time);
			}
			if(ship.hasAbilities)
				ship.abilityTick(time);
			if(ship.hasStatuses)
				ship.statusTick(time);
			if(ship.hasConstruction)
				ship.constructionTick(time);
		}

		if(d < delay)
			delay = d;
		d = ship.moverTick(time);
		if(d < delay)
			delay = d;
		
		double amt;
		double consumed;
		double ratio;
		if(ship.Shield < ship.MaxShield) {
			amt = shieldRegen * time;
			consumed = ship.blueprint.getEfficiencySum(SV_PowerUse, ST_IsShield) * time;
			consumed *= ship.blueprint.getEfficiencyFactor(SV_PowerUse, ST_IsShield);
			if(amt > ship.MaxShield - ship.Shield) {
				ratio = (ship.MaxShield - ship.Shield) / amt;
				amt *= ratio;
				consumed *= ratio;
			}
			if(consumed > ship.Energy) {
				ratio = (ship.Energy / consumed);
				amt *= ratio;
				consumed *= ratio;
			}
			ship.Shield += amt;
			ship.Energy -= consumed;
			shieldDelta = true;
		}
		if(ship.FTL < ship.MaxFTL) {
			amt = ftlRegen * time;
			consumed = crystalConsumption * time;
			if(amt > ship.MaxFTL - ship.FTL) {
				ratio = (ship.MaxFTL - ship.FTL) / amt;
				amt *= ratio;
				consumed *= ratio;
			}
			if(consumed > ship.Crystals) {
				ratio = (ship.Crystals / consumed);
				amt *= ratio;
				consumed = ship.Crystals;
				amt += emergencyFTLRegen * (1 - ratio) * time; // The percentage of missing crystals is also the percentage of emergency regeneration used.
			}
			amt -= ftlUse;
			ship.FTL += amt;
			ship.Crystals -= consumed;
			barDelta = true;
		}
		if(ship.Energy < ship.MaxEnergy) {
			ship.Energy = min(ship.MaxEnergy, ship.Energy + energyRegen * time);
			barDelta = true;
		}

		//Repair out of combat
		if(needRepair) {
			double damage = bp.design.totalHP - bp.currentHP;
			if(currentRepair > 0.f && (damage > 0.f || wreckage > 0.f)) {
				double repairFact = 1.0;
				bool inCombat = ship.inCombat;
				if(inCombat) {
					repairFact *= COMBAT_REPAIR_MOD;
					repairFact *= min(bp.shipEffectiveness, 1.0);
				}
				if(repairFact != 0) {
					double repairAmt = currentRepair * repairFact * time;
					double repairCost = currentRepairCost * repairFact * time;
					if(inCombat) {
						if(repairCost < 0) {
							repairAmt = 0;
						}
						else if(cachedLeader !is null) {
							Ship@ shipLeader = cast<Ship>(cachedLeader);
							if(shipLeader !is null) {
								if(shipLeader.Supply < repairCost)
									repairAmt = 0.0;
								else
									shipLeader.consumeSupply(repairCost);
							}
						}
						else {
							if(ship.Supply < repairCost)
								repairAmt = 0.0;
							else
								consumeSupply(ship, repairCost);
						}
					}
					if(repairAmt != 0) {
						if(wreckage > 0.f) {
							double repWreckage = repairAmt * wreckage / (wreckage + damage);
							repairAmt -= repWreckage;
							wreckage -= repWreckage;
						}
						bp.repair(ship, repairAmt);
					}
				}
			}
			else {
				bp.repairingHex.x = -1;
				bp.repairingHex.y = -1;
				needRepair = false;
			}
		}

		return delay;
	}
	
	void internalDamage(Ship& ship, double amount) {
		Blueprint@ bp = ship.blueprint;
		const Design@ dsg = bp.design;
		vec2i gridSize = dsg.hull.gridSize;
		
		vec2i base = vec2i(randomi(0, gridSize.x-1), randomi(0, gridSize.y-1));
		for(int x = 0; x < gridSize.x; ++x) {
			for(int y = 0; y < gridSize.y; ++y) {
				vec2u pos = vec2u((base.x + x) % gridSize.x, (base.y + y) % gridSize.y);
				auto status = bp.getHexStatus(pos.x,pos.y);
				if(status is null || status.hp == 0)
					continue;
				
				DamageEvent evt;
				evt.damage = amount;
				
				bp.damage(ship, evt, pos);
				needRepair = true;
				return;
			}
		}
	}

	void damage(Ship& ship, DamageEvent& evt, double position, const vec2d& direction) {
		//Score kills to the last aggressor
		double prevShield = ship.Shield;
		if(evt.obj !is null) {
			if(lastHitBy !is evt.obj && ship.hasLeaderAI) {
				//Order a random support to block, and another to attack
				uint cnt = ship.supportCount;
				if(cnt > 0) {
					uint ind = randomi(0,cnt-1);
					
					Object@ sup = ship.supportShip[ind];
					if(sup !is null)
						sup.supportInterfere(lastHitBy, ship);
					
					if(cnt > 1) {
						@sup = ship.supportShip[ind+1];
						if(sup !is null)
							sup.supportAttack(lastHitBy);
					}
				}
			}
			
			@lastHitBy = evt.obj;
			@killCredit = evt.obj.owner;
		}
		ship.engaged = true;
		ship.blueprint.damage(ship, evt, direction);
		needRepair = true;
		if(prevShield != ship.Shield)
			shieldDelta = true;
	}

	void restoreShield(Ship& ship, double value) {
		double prevShield = ship.Shield;
		ship.Shield = clamp(ship.Shield + value, 0, ship.MaxShield);
		if(ship.Shield != prevShield)
			shieldDelta = true;
	}
	
	Empire@ getKillCredit() {
		return killCredit;
	}

	void syncInitial(const Ship& ship, Message& msg) {
		msg.writeSmall(ship.blueprint.design.hull.id);
		ship.blueprint.sendDetails(ship, msg);

		if(ship.hasLeaderAI) {
			msg.write1();
			ship.writeLeaderAI(msg);
		}
		else {
			msg.write0();
			ship.writeSupportAI(msg);
		}
		ship.writeMover(msg);
		if(ship.MaxEnergy > 0) {
			msg.write1();
			msg << ship.MaxEnergy;
			msg.writeFixed(ship.Energy, 0.f, ship.MaxEnergy, 16);
		}
		else {
			msg.write0();
		}
		
		if(ship.MaxSupply > 0) {
			msg.write1();
			msg << ship.MaxSupply;
			msg.writeFixed(ship.Supply, 0.f, ship.MaxSupply, 16);
		}
		else {
			msg.write0();
		}
		
		if(ship.MaxShield > 0) {
			msg.write1();
			msg << ship.MaxShield;
			msg.writeFixed(ship.Shield, 0.f, ship.MaxShield, 16);
		}
		else {
			msg.write0();
		}

		if(ship.MaxFTL > 0) {
			msg.write1();
			msg << ship.MaxFTL;
			msg.writeFixed(ship.FTL, 0.f, ship.MaxFTL, 16);
		}
		else {
			msg.write0();
		}
		
		if(ship.MaxCrystals > 0) {
			msg.write1();
			msg << ship.MaxCrystals;
			msg.writeFixed(ship.Crystals, 0.f, ship.MaxCrystals, 16);
		}
		else {
			msg.write0();
		}

		if(ship.hasAbilities) {
			msg.write1();
			ship.writeAbilities(msg);
		}
		else {
			msg.write0();
		}
		
		if(ship.hasStatuses) {
			msg.write1();
			ship.writeStatuses(msg);
		}
		else {
			msg.write0();
		}

		if(ship.hasCargo) {
			msg.write1();
			ship.writeCargo(msg);
		}
		else {
			msg.write0();
		}

		if(ship.hasConstruction) {
			msg.write1();
			ship.writeConstruction(msg);
		}
		else {
			msg.write0();
		}

		if(ship.hasOrbit) {
			msg.write1();
			ship.writeOrbit(msg);
		}
		else {
			msg.write0();
		}
	}

	void retrofit(Ship& ship, const Design@ newDesign) {
		const Design@ prevDesign = ship.blueprint.design;
		ship.blueprint.retrofit(ship, newDesign);
		cacheStats(ship);
		ship.Energy = min(ship.Energy, ship.MaxEnergy);
		if(ship.hasAbilities)
			ship.initAbilities(ship.blueprint.design);
		if(ship.hasSupportAI && newDesign.base() !is prevDesign.base()) {
			Object@ leader = ship.Leader;
			if(leader !is null)
				leader.postSupportRetrofit(ship, prevDesign, newDesign);
		}
	}

	void syncDetailed(const Ship& ship, Message& msg) {
		ship.writeMover(msg);
		if(ship.hasLeaderAI)
			ship.writeLeaderAI(msg);
		else
			ship.writeSupportAI(msg);
		ship.blueprint.sendDetails(ship, msg);
		msg << ship.Energy;
		msg << ship.MaxEnergy;
		msg << ship.Supply;
		msg << ship.MaxSupply;
		msg << ship.Shield;
		msg << ship.MaxShield;
		msg << ship.FTL;
		msg << ship.MaxFTL;
		msg << ship.Crystals;
		msg << ship.MaxCrystals;
		msg.writeBit(ship.isFTLing);
		msg.writeBit(ship.inCombat);
		if(ship.hasAbilities)
			ship.writeAbilities(msg);
		if(ship.hasStatuses)
			ship.writeStatuses(msg);
		if(ship.hasCargo) {
			msg.write1();
			ship.writeCargo(msg);
		}
		else {
			msg.write0();
		}
		if(ship.hasOrbit) {
			msg.write1();
			ship.writeOrbit(msg);
		}
		else {
			msg.write0();
		}
		if(ship.hasConstruction) {
			msg.write1();
			ship.writeConstruction(msg);
		}
		else {
			msg.write0();
		}
	}

	bool prevFTL = false, prevCombat = false;
	bool syncDelta(const Ship& ship, Message& msg) {
		bool used = false;
		if(ship.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();

		if(ship.blueprint.sendDelta(ship, msg))
			used = true;
		else
			msg.write0();
		
		msg.writeBit(shieldDelta);
		if(shieldDelta) {
			used = true;
			shieldDelta = false;
			msg.writeFixed(ship.Shield, 0.f, ship.MaxShield, 16);
		}

		if(ship.hasLeaderAI) {
			if(ship.writeLeaderAIDelta(msg))
				used = true;
			else
				msg.write0();
		}
		else {
			if(ship.writeSupportAIDelta(msg))
				used = true;
			else
				msg.write0();
		}

		if(ship.hasAbilities) {
			if(ship.writeAbilityDelta(msg))
				used = true;
			else
				msg.write0();
		}

		if(ship.hasStatuses) {
			if(ship.writeStatusDelta(msg))
				used = true;
			else
				msg.write0();
		}

		if(ship.hasLeaderAI) {
			if(ship.hasCargo) {
				if(ship.writeCargoDelta(msg))
					used = true;
				else
					msg.write0();
			}
			else {
				msg.write0();
			}
		}

		if(barDelta || prevFTL != ship.isFTLing
			|| prevCombat != ship.inCombat) {
			msg.write1();
			used = true;
			msg.writeBit(ship.Energy > 0);
			if(ship.Energy > 0)
				msg << ship.Energy;
				
			msg.writeBit(ship.Supply > 0);
			if(ship.Supply > 0)
				msg << ship.Supply;

			msg.writeBit(ship.FTL > 0);
			if(ship.FTL > 0)
				msg << ship.FTL;

			msg.writeBit(ship.Crystals > 0);
			if(ship.Crystals > 0)
				msg << ship.Crystals;
			
			msg.writeBit(ship.isFTLing);
			msg.writeBit(ship.inCombat);
			barDelta = false;
			prevFTL = ship.isFTLing;
			prevCombat = ship.inCombat;
		}
		else {
			msg.write0();
		}

		if(ship.hasOrbit) {
			if(ship.writeOrbitDelta(msg))
				used = true;
			else
				msg.write0();
		}
		else {
			msg.write0();
		}

		if(ship.hasLeaderAI && ship.hasConstruction) {
			if(ship.writeConstructionDelta(msg))
				used = true;
			else
				msg.write0();
		}
		else {
			msg.write0();
		}

		return used;
	}
};

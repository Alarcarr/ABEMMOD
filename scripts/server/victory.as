import saving;
from empire import majorEmpireCount;
import bool getCheatsEverOn() from "cheats";
import systems;

bool hasGameEnded = false;

void save(SaveFile& file) {
	file << hasGameEnded;
}

void load(SaveFile& file) {
	if(file >= SV_0078)
		file >> hasGameEnded;
}

bool hasGameEnded_client() {
	return hasGameEnded;
}

void declareVictor(Empire@ emp) {
	hasGameEnded = true;
	gameSpeed = 0.0;
	serverEndGame(ALL_PLAYERS);

	if(emp !is null) {
		if(emp.Victory <= 0)
			emp.Victory = emp.VictoryType;

		int maxDiff = -1;
		bool achieve = systemCount >= 10 && !getCheatsEverOn() && config::GAME_TIME_LIMIT <= 0.01;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(other.major && (emp.team < 0 || emp.team != other.team))
				maxDiff = max(maxDiff, other.difficulty);
			if(other.major && emp.team != -1 && emp.team == other.team) {
				if(other.Victory >= 0 && other.VictoryType <= emp.VictoryType)
					other.Victory = emp.VictoryType;
			}	
		}
		if(emp.player !is null) {
			if(achieve) {
				if(maxDiff >= 1)
					clientAchievement(emp.player, "ACH_WIN_EASY");
				if(maxDiff >= 2)
					clientAchievement(emp.player, "ACH_WIN_MEDIUM");
				if(maxDiff >= 3)
					clientAchievement(emp.player, "ACH_WIN_HARD");
				if(maxDiff >= 5)
					clientAchievement(emp.player, "ACH_WIN_SAVAGE");
			}
		}
		if(emp is playerEmpire) {
			if(achieve) {
				if(maxDiff >= 1)
					unlockAchievement("ACH_WIN_EASY");
				if(maxDiff >= 2)
					unlockAchievement("ACH_WIN_MEDIUM");
				if(maxDiff >= 3)
					unlockAchievement("ACH_WIN_HARD");
				if(maxDiff >= 5)
					unlockAchievement("ACH_WIN_SAVAGE");
			}
		}
	}
}

void tick(double time) {
	if(hasGameEnded) {
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ emp = getEmpire(i);
			emp.visionMask = ~0;
		}
		return;
	}

	checkStandardVictory();
	checkVanguardVictory();
}

void checkStandardVictory() {
	if((!mpServer && playerEmpire.Victory == -1)
			|| (config::GAME_TIME_LIMIT > 0.01 && gameTime >= config::GAME_TIME_LIMIT*60.0)) {
		Empire@ winner;
		int bestPts = INT_MIN;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ emp = getEmpire(i);
			if(emp.major && emp.SubjugatedBy is null && emp.Victory == 0) {
				int pts = emp.points.value;
				if(pts > bestPts) {
					bestPts = pts;
					@winner = emp;
				}
			}
		}
		declareVictor(winner);
		return;
	}

	uint aliveAlone = 0;
	set_int aliveTeams;
	int aliveTeam = -1;
	
	uint players = 0;
	set_int teams;
	
	bool foundVictor = false;
	for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
		Empire@ other = getEmpire(i);
		if(!other.major)
			continue;
		if(other.team < 0)
			players += 1;
		else
			teams.insert(other.team);

		if(other.Victory == 0) {
			if(other.TotalPlanets.value == 0)
				other.Victory = -1;
			else if(other.SubjugatedBy !is null)
				other.Victory = -2;
		}
			
		if(other.Victory >= 0) {
			if(other.SubjugatedBy is null) {
				if(other.team < 0)
					aliveAlone += 1;
				else {
					aliveTeams.insert(other.team);
					aliveTeam = other.team;
				}
			}
		}
		
		if(other.Victory >= 1)
			foundVictor = true;
	}
	
	if(players + teams.size() > 1 && !foundVictor && aliveAlone + aliveTeams.size() == 1) {
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.major)
				continue;
			if(other.Victory >= 0)
				declareVictor(other);
		}
	}
}

void checkVanguardVictory() {
	for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
		Empire@ other = getEmpire(i);
		if(!other.major)
			continue;
		else if(other.VanguardVictoryRequirement <= 0 && other.VictoryType == 2) {
			declareVictor(other);
			return;
		}
	}
}

void syncInitial(Message& msg) {
	msg << hasGameEnded;
}

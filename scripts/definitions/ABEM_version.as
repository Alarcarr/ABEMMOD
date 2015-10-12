import version;

const string MOD_REVISION = "574";
const array<string> VERSIONS = {
	"v1.0.2",
	"v1.0.3"
};

const array<string> REVISIONS = {
	"4740",
	"4744", 
	"4746"
};
const string MOD_NAME = "ABEM 0.4.0";
const string MOD_VERSION = MOD_NAME + " (revision " + MOD_REVISION + ") for Star Ruler 2 " + VERSIONS[0] + " (revision " + REVISIONS[0] + ", currently using " + GAME_VERSION + " " + SCRIPT_VERSION + ")";

string getLowestSupported(string input) {
	print(input.split("; ")[0]);
	return input.split("; ")[0];
};

bool checkSupported() {
	bool resultA = false;
	bool resultB = false;
	for(uint i = 0; i < VERSIONS.length; ++i) {
		if(VERSIONS[i].equals_nocase(GAME_VERSION)) {
			resultA = true;
			break;
		}
	}
	if(resultA) {
		for(uint i = 0; i < REVISIONS.length; ++i) {
			if(("r" + REVISIONS[i]).equals_nocase(SCRIPT_VERSION)) {
				resultB = true;
				break;
			}
		}
	}
	if(resultA && resultB)
		return true;
	else {
		error("Mod " + MOD_NAME + " does not support current game version " + GAME_VERSION + "(" + SCRIPT_VERSION + "), use with caution!");
		return false;
	}
}

//bool MOD_SUPPORTS_VERSION = checkSupported();
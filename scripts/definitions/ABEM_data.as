import statuses;

// For use in effects using statuses.
// DO NOT CHANGE THIS UNLESS YOU KNOW WHAT YOU'RE DOING.
enum ABEMStatusTypes {
	SType_VoidRay = 1
};

const StatusType@ getABEMStatus(int index) {
	switch(index) {
		case SType_VoidRay:
			return getStatusType("VoidRay");
		default:
			error("Invalid status index in function getABEMStatus: "+index); return null;
	}
	error("Unknown error has occurred in getABEMStatus.");
	return null;
}

// Data entries for baseline sight ranges for ships, stations (multiplies SHIP_BASESIGHTRANGE), orbitals and planets.
const double SHIP_BASESIGHTRANGE = 250;
const double STATION_SIGHTMULTIPLIER = 2;
const double ORBITAL_BASESIGHTRANGE = 1000;
const double PLANET_BASESIGHTRANGE = 1500;
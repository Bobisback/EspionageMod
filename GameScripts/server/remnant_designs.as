import util.design_designer;
import ship_groups;
import object_creation;
from empire import Creeps;

export getRemnantDesign;
export spawnRemnantFleet;

array<const Design@> flagships;
array<const Design@> supportShips;

const Design@ getRemnantDesign(uint type, int size) {
	auto@ remnants = flagships;
	if(type == DT_Support)
		@remnants = supportShips;

	//Find existing designs at this size
	array<const Design@> designs;
	for(uint i = 0, cnt = remnants.length; i < cnt; ++i) {
		if(int(remnants[i].size) == size)
			designs.insertLast(remnants[i]);
	}

	if(designs.length == 0 || randomd() < 1.0/double(designs.length)) {
		//Create a new design of this type
		Designer designer;
		
		if(type == DT_Flagship && randomd() < 0.05) {
			designer.prepare(DesignType(type), size * 3, Creeps, "Defense");
			designer.weaponCount = 8;
			designer.support = false;
		}
		else {
			designer.prepare(DesignType(type), size, Creeps, "Defense");
		}
		
		auto@ dsg = designer.design(128);
		if(dsg !is null) {
			string name = "Remnant "+dsg.name;
			uint try = 0;
			while(Creeps.getDesign(name) !is null) {
				name = "Remnant "+dsg.name + " ";
				appendRoman(++try, name);
			}
			dsg.rename(name);

			Creeps.addDesign(Creeps.getDesignClass("Defense"), dsg);
			remnants.insertLast(dsg);
		}
		return dsg;
	}
	else {
		return designs[randomi(0, designs.length-1)];
	}
}

Ship@ spawnRemnantFleet(const vec3d& position, int size, double occupation = 1.0) {
	const Design@ dsg = getRemnantDesign(DT_Flagship, size);
	if(dsg is null)
		return null;

	Ship@ leader = createShip(position, dsg, Creeps, free=true, memorable=true);
	leader.setAutoMode(AM_RegionBound);
	leader.sightRange = 0;
	leader.setRotation(quaterniond_fromAxisAngle(vec3d_up(), randomd(-pi, pi)));

	uint supports = dsg.total(SV_SupportCapacity) * occupation;
	if(supports != 0) {
		uint supportTypes = randomd(1, 4);
		for(uint n = 0; n < supportTypes; ++n) {
			uint supportCount = randomd(5,50);
			int supportSize = floor(double(supports) / double(supportTypes) / double(supportCount));
			if(supportSize > 5)
				supportSize = floor(double(supportSize) / 5.0) * 5;
			const Design@ sup = getRemnantDesign(DT_Support, supportSize);
			if(sup !is null) {
				for(uint i = 0; i < supportCount; ++i)
					createShip(leader.position, sup, Creeps, leader, free=true);
			}
		}
	}
	return leader;
}

void save(SaveFile& file) {
	uint cnt = flagships.length;
	file << cnt;
	for(uint i = 0; i < cnt; ++i)
		file << flagships[i].id;

	cnt = supportShips.length;
	file << cnt;
	for(uint i = 0; i < cnt; ++i)
		file << supportShips[i].id;
}

void loadRemnantDesigns(SaveFile& file) {
	uint cnt = 0;
	file >> cnt;
	flagships.length = cnt;
	for(uint i = 0; i < cnt; ++i) {
		int id = 0;
		file >> id;
		@flagships[i] = Creeps.getDesign(id);
	}

	file >> cnt;
	supportShips.length = cnt;
	for(uint i = 0; i < cnt; ++i) {
		int id = 0;
		file >> id;
		@supportShips[i] = Creeps.getDesign(id);
	}
}

void load(SaveFile& file) {
	loadRemnantDesigns(file);
}

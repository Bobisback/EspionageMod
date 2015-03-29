#priority init 2500
from resources import ResourceRequirements;

class PlanetLevel {
	uint level = 0;
	string name;
	ResourceRequirements reqs;
	uint population = 1;
	double popGrowth = 0.3;
	double requiredPop = 0.0;
	int baseIncome = 100;
	int resourceIncome = 0;
	int baseLoyalty = 10;
	uint basePressure = 0;
	uint exportPressurePenalty = 0;
	double neighbourLoyalty = 0.0;
	int points = 10;
	Sprite icon;
};

PlanetLevel@[] _planetLevels;

uint get_MAX_PLANET_LEVEL() {
	return _planetLevels.length - 1;
}

const PlanetLevel@ getPlanetLevel(uint level) {
	if(level >= _planetLevels.length)
		return null;
	return _planetLevels[level];
}

double getPlanetLevelRequiredPop(uint level) {
	if(level >= _planetLevels.length)
		return 0.0;
	return _planetLevels[level].requiredPop;
}

void init() {
	ReadFile file(resolve("data/planet_levels.txt"));
	PlanetLevel@ lvl;
	ResourceRequirements@ reqs;
	
	string key, value;
	while(file++) {
		key = file.key;
		value = file.value;

		if(key == "Level") {
			@lvl = PlanetLevel();
			lvl.level = _planetLevels.length;
			@reqs = lvl.reqs;

			_planetLevels.insertLast(lvl);
		}
		else if(key == "Required") {
			if(reqs !is null)
				reqs.parse(value);
		}
		else if(key == "Population") {
			if(lvl !is null)
				lvl.population = toUInt(value);
		}
		else if(key == "PopGrowth") {
			if(lvl !is null)
				lvl.popGrowth = toDouble(value);
		}
		else if(key == "RequiredPop") {
			if(lvl !is null)
				lvl.requiredPop = toDouble(value);
		}
		else if(key == "BaseIncome") {
			if(lvl !is null)
				lvl.baseIncome = toInt(value);
		}
		else if(key == "ResourceIncome") {
			if(lvl !is null)
				lvl.resourceIncome = toInt(value);
		}
		else if(key == "BasePressure") {
			if(lvl !is null)
				lvl.basePressure = toUInt(value);
		}
		else if(key == "BaseLoyalty") {
			if(lvl !is null)
				lvl.baseLoyalty = toInt(value);
		}
		else if(key == "NeighbourLoyalty") {
			if(lvl !is null)
				lvl.neighbourLoyalty = toDouble(value);
		}
		else if(key == "ExportPressurePenalty") {
			if(lvl !is null)
				lvl.exportPressurePenalty = toUInt(value);
		}
		else if(key == "Name") {
			if(lvl !is null)
				lvl.name = localize(value);
		}
		else if(key == "Icon") {
			lvl.icon = getSprite(value);
		}
		else if(key == "Points") {
			lvl.points = toInt(value);
		}
	}
}

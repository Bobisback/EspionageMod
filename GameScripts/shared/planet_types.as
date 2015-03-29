#priority init 2000
from biomes import Biome, getBiome;
from saving import SaveIdentifier;

final class PlanetType {
	string ident;
	int id;
	//Material used for empty planets
	const Material@ emptyMat;
	//Material used for colonized planets
	const Material@ colonyMat;
	//Material used for planets undergoing imminent death
	const Material@ dyingMat;
	//Has an atmosphere?
	const Material@ atmosMat;
	//Small icon sprite
	Sprite icon;
	//Distant icon sprite
	Sprite distantIcon;
	
	map biomeWeights;
	
	int getBiomeWeight(int biomeID) const {
		int64 weight = 0;
		biomeWeights.get(biomeID, weight);
		return weight;
	}
};

array<PlanetType@> _planetTypes;

uint getPlanetTypeCount() {
	return _planetTypes.length;
}

const PlanetType@ getPlanetType(int id) {
	return _planetTypes[id];
}

const PlanetType@ getPlanetType(Planet& pl) {
	return _planetTypes[pl.PlanetType];
}

const PlanetType@ getPlanetType(const string& ident) {
	for(uint i = 0, cnt = _planetTypes.length; i < cnt; ++i)
		if(_planetTypes[i].ident == ident)
			return _planetTypes[i];
	return null;
}

const PlanetType@ getBestPlanetType(const Biome@ biome1, const Biome@ biome2, const Biome@ biome3) {
	array<const PlanetType@> choices;
	int bestWeight = -10000;
	
	for(uint i = 0, cnt = _planetTypes.length; i < cnt; ++i) {
		const PlanetType@ type = _planetTypes[i];
		int totalWeight = type.getBiomeWeight(biome1.id) + type.getBiomeWeight(biome2.id) + type.getBiomeWeight(biome3.id);
		
		if(totalWeight > bestWeight) {
			choices.length = 1;
			@choices[0] = type;
			bestWeight = totalWeight;
		}
		else if(totalWeight == bestWeight) {
			choices.insertLast(type);
		}
	}
	
	if(choices.length == 1)
		return choices[0];
	else
		return choices[randomi(0,choices.length-1)];
}

void loadPlanetType(ReadFile& file) {
	PlanetType@ type;
	
	int biomeIndent = -1;
	
	string key, value;
	while(file++) {
		key = file.key;
		value = file.value;
		
		if(file.indent != biomeIndent)
			biomeIndent = -1;
		
		if(key == "PlanetType") {
			@type = PlanetType();
			type.id = _planetTypes.length;
			type.ident = value;
			_planetTypes.insertLast(type);
		}
		else if(type !is null) {
			if(biomeIndent != -1) {
				const Biome@ biome = getBiome(key);
				if(biome !is null) {
					int64 weight = toInt(value);
					type.biomeWeights.set(biome.id, weight);
				}
				else {
					error(format("'$1' is not a biome", key));
				}
			}
			else {
				if(key == "EmptyMat") {
					@type.emptyMat = getMaterial(value);
				}
				else if(key == "ColonyMat") {
					@type.colonyMat = getMaterial(value);
				}
				else if(key == "DyingMat") {
					@type.dyingMat = getMaterial(value);
				}
				else if(key == "BiomeWeights") {
					biomeIndent = file.indent + 1;
				}
				else if(key == "Atmosphere") {
					@type.atmosMat = getMaterial(value);
				}
				else if(key == "Icon") {
					type.icon = getSprite(value);
				}
				else if(key == "DistantIcon") {
					type.distantIcon = getSprite(value);
				}
			}
		}
		else {
			error("Missing 'PlanetType: Name' line");
		}
	}
}

void preInit() {
	FileList list("data/planet_types", "*.txt");
	for(uint i = 0, cnt = list.length; i < cnt; ++i)
		loadPlanetType(ReadFile(list.path[i]));
}

void saveIdentifiers(SaveFile& file) {
	for(uint i = 0, cnt = _planetTypes.length; i < cnt; ++i) {
		PlanetType@ type = _planetTypes[i];
		file.addIdentifier(SI_PlanetType, type.id, type.ident);
	}
}

enum CargoType {
	CT_Resource,
	CT_Goods,
};

enum CivilianType {
	CiT_Freighter,
	CiT_Station,
};

array<const Model@> CivilianModels = {
	model::Fighter,
	model::Research_Station,
};

array<const Material@> CivilianMaterials = {
	material::Ship10,
	material::ResearchStation,
};

array<Sprite> CivilianIcons = {
	Sprite(spritesheet::HullIcons, 2),
	Sprite(spritesheet::OrbitalIcons, 0),
};

const double CIV_SIZE_MIN = 2.0;
const double CIV_SIZE_MAX = 5.4;
const double CIV_SIZE_FREIGHTER = 2.7;
const double CIV_SIZE_CARAVAN = 5.0;

const double CIV_RADIUS_WORTH = 1.0;

const int CIV_CARAVAN_INCOME = 15;
const int CIV_STATION_INCOME = 20;

const Model@ getCivilianModel(uint type, double radius) {
	return CivilianModels[type];
}

const Material@ getCivilianMaterial(uint type, double radius) {
	return CivilianMaterials[type];
}

double randomCivilianFreighterSize() {
	return sqr(randomd()) * (CIV_SIZE_MAX - CIV_SIZE_MIN) + CIV_SIZE_MIN;
}

string getCivilianName(uint type, double radius) {
	if(type == CiT_Freighter) {
		if(radius >= CIV_SIZE_CARAVAN)
			return locale::CIVILIAN_CARAVAN;
		else if(radius >= CIV_SIZE_FREIGHTER)
			return locale::CIVILIAN_FREIGHTER;
		return locale::CIVILIAN_MERCHANT;
	}
	else if(type == CiT_Station) {
		return locale::CIVILIAN_STATION;
	}
	return locale::CIVILIAN;
}

Sprite getCivilianIcon(uint type, double radius) {
	if(type == CiT_Freighter) {
		if(radius >= CIV_SIZE_CARAVAN)
			return Sprite(spritesheet::HullIcons, 4);
		else if(radius >= CIV_SIZE_FREIGHTER)
			return Sprite(spritesheet::HullIcons, 3);
	}
	return CivilianIcons[type];
}

const double STATION_MIN_RAD = 5.0;
const double STATION_MAX_RAD = 10.0;

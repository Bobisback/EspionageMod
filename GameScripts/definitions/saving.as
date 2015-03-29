enum SaveIdentifier {
	SI_InfluenceCard = SAVE_IDENTIFIER_START,
	SI_InfluenceVote,
	SI_Biome,
	SI_Orbital,
	SI_Pickup,
	SI_Resource,
	SI_Building,
	SI_PlanetType,
	SI_ResearchField,
	SI_ResearchProject,
	SI_RegionEffect,
	SI_AbilityType,
	SI_PlanetDesignation,
	SI_AnomalyType,
	SI_InfluenceEffect,
	SI_Trait,
	SI_Status,
	SI_Artifact,
	SI_Global,
	SI_InfluenceClause,
	SI_Technology,
	SI_UnlockTag,
	SI_SystemFlag,
	SI_CreepCamp,
	SI_EmpAttribute,
	SI_ConstructionType,
};

enum SaveVersion {
	SV_0001,
	SV_0002,
	SV_0003,
	SV_0004,
	SV_0005,
	SV_0006,
	SV_0007,
	SV_0008,
	SV_0009,
	SV_0010,
	SV_0011,
	SV_0012,
	SV_0013,
	SV_0014,
	SV_0015,
	SV_0016,
	SV_0017,
	SV_0018,
	SV_0019,
	SV_0020,
	SV_0021,
	SV_0022,
	SV_0023,
	SV_0024,
	SV_0025,
	SV_0026,
	SV_0027,
	SV_0028,
	SV_0029,
	SV_0030,
	SV_0031,
	SV_0032,
	SV_0033,
	SV_0034,
	SV_0035,
	SV_0036,
	SV_0037,
	SV_0038,
	SV_0039,
	SV_0040,
	SV_0041,
	SV_0042,
	SV_0043,
	SV_0044,
	SV_0045,
	SV_0046,
	SV_0047,
	SV_0048,
	SV_0049,
	SV_0050,
	SV_0051,
	SV_0052,
	SV_0053,
	SV_0054,
	SV_0055,
	SV_0056,
	SV_0057,
	SV_0058,
	SV_0059,
	SV_0060,
	SV_0061,
	SV_0062,
	SV_0063,
	SV_0064,
	SV_0065,
	SV_0066,
	SV_0067,
	SV_0068,
	SV_0069,
	SV_0070,
	SV_0071,
	SV_0072,
	SV_0073,
	SV_0074,

	SV_0075,

	SV_0076,
	SV_0077,
	SV_0078,
	SV_0079,
	SV_0080,
	SV_0081,
	SV_0082,
	SV_0083,
	SV_0084,
	SV_0085,
	SV_0086,
	SV_0087,
	SV_0088,
	SV_0089,
	SV_0090,
	SV_0091,
	SV_0092,
	SV_0093,
	SV_0094,
	SV_0095,
	SV_0096,
	SV_0097,
	SV_0098,
	SV_0099,
	SV_0100,
	SV_0101,
	SV_0102,
	SV_0103,
	SV_0104,
	SV_0105,
	SV_0106,
	SV_0107,
	SV_0108,
	SV_0109,
	SV_0110,
	SV_0111,
	SV_0112,
	SV_0113,
	SV_0114,
	SV_0115,

	SV_0116,
	SV_LOWEST_COMPATIBLE = SV_0116,
	SV_0117,
	SV_0118,
	SV_0119,

	SV_NEXT,
	SV_CURRENT = SV_NEXT - 1,
};

array<uint> COMPATIBILITY_MODS = {
	SV_0032, /* -- r3444 --> */ SV_0074,
	SV_0074, /* -- r4257 --> */ SV_0115,
};

bool isSaveCompatible(uint version) {
	if(version == uint(-1))
		return false;
	if(version >= SV_LOWEST_COMPATIBLE)
		return true;
	for(uint i = 0, cnt = COMPATIBILITY_MODS.length; i+1 < cnt; i += 2) {
		if(version >= COMPATIBILITY_MODS[i] && version <= COMPATIBILITY_MODS[i+1])
			return true;
	}
	return false;
}

void saveIdentifiers(SaveFile& file) {
	file.scriptVersion = SV_CURRENT;
	if(!isLoadedSave)
		file.startVersion = SV_CURRENT;
	else
		file.startVersion = START_VERSION;
}

void saveObjectStates(Object& obj, SaveFile& file) {
	file << obj.region;
}

void loadObjectStates(Object& obj, SaveFile& file) {
	file >> obj.region;
}

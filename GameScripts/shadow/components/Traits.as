import traits;

class Traits : Component_Traits {
	array<const Trait@> traits;
	array<bool> hasTraits(getTraitCount(), false);

	bool hasTrait(uint id) {
		if(id >= hasTraits.length)
			return false;
		return hasTraits[id];
	}

	uint get_traitCount() const {
		return traits.length;
	}

	uint getTraitType(uint index) const {
		if(index >= traits.length)
			return uint(-1);
		return traits[index].id;
	}

	void readTraits(Message& msg) {
		uint cnt = msg.readSmall();
		traits.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			int id = msg.readSmall();
			@traits[i] = getTrait(id);
			hasTraits[id] = true;
		}
	}
};


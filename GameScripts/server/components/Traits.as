import traits;
import saving;

class TraitData {
	const Trait@ trait;
	array<any> data;
};

class Traits : Component_Traits, Savable {
	array<TraitData@> traits;
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
		return traits[index].trait.id;
	}

	void addTrait(Empire& emp, uint id, bool doPreInit = false) {
		auto@ trait = getTrait(id);
		if(trait is null)
			throw("Invalid trait.");

		TraitData dat;
		@dat.trait = trait;
		traits.insertLast(dat);
		hasTraits[trait.id] = true;
		if(doPreInit)
			dat.trait.preInit(emp, dat.data);
	}

	void replaceTrait(Empire& emp, uint fromId, uint toId, bool doPreInit = true) {
		auto@ fromType = getTrait(fromId);
		auto@ toType = getTrait(toId);
		if(fromType is null || toType is null)
			return;

		for(uint i = 0, cnt = traits.length; i < cnt; ++i) {
			if(traits[i].trait is fromType) {
				@traits[i].trait = toType;
				if(doPreInit)
					toType.preInit(emp, traits[i].data);
				hasTraits[fromType.id] = false;
				hasTraits[toType.id] = true;
				break;
			}
		}
	}

	void preInitTraits(Empire& emp) {
		for(uint i = 0, cnt = traits.length; i < cnt; ++i)
			traits[i].trait.preInit(emp, traits[i].data);
	}

	void initTraits(Empire& emp) {
		for(uint i = 0, cnt = traits.length; i < cnt; ++i)
			traits[i].trait.init(emp, traits[i].data);
	}

	void postInitTraits(Empire& emp) {
		for(uint i = 0, cnt = traits.length; i < cnt; ++i)
			traits[i].trait.postInit(emp, traits[i].data);
	}

	void traitsTick(Empire& emp, double time) {
		for(uint i = 0, cnt = traits.length; i < cnt; ++i)
			traits[i].trait.tick(emp, traits[i].data, time);
	}

	void save(SaveFile& file) {
		uint cnt = traits.length;
		file << cnt;
		for(uint i = 0; i < cnt; ++i) {
			file.writeIdentifier(SI_Trait, traits[i].trait.id);
			traits[i].trait.save(traits[i].data, file);
		}
	}

	void load(SaveFile& file) {
		uint cnt = 0;
		file >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			auto@ trait = getTrait(file.readIdentifier(SI_Trait));
			if(trait !is null) {
				TraitData dat;
				@dat.trait = trait;
				trait.load(dat.data, file);
				hasTraits[trait.id] = true;

				traits.insertLast(dat);
			}
		}
	}

	void writeTraits(Message& msg) {
		uint cnt = traits.length;
		msg.writeSmall(cnt);
		for(uint i = 0; i < cnt; ++i)
			msg.writeSmall(traits[i].trait.id);
	}
};

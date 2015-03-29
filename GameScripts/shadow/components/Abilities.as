import abilities;
import saving;

class Abilities : Component_Abilities {
	array<Ability> abilities;

	Ability@ getAbility(int id) {
		for(uint i = 0, cnt = abilities.length; i < cnt; ++i) {
			if(abilities[i].id == id)
				return abilities[i];
		}
		return null;
	}

	uint get_abilityCount() const {
		return abilities.length;
	}

	void abilityTick(Object& obj, double time) {
		for(uint i = 0, cnt = abilities.length; i < cnt; ++i) {
			if(!abilities[i].disabled)
				abilities[i].cooldown = max(0.0, abilities[i].cooldown - time);
		}
	}

	void getAbilities() const {
		for(uint i = 0, cnt = abilities.length; i < cnt; ++i)
			yield(abilities[i]);
	}

	uint get_abilityTypes(int id) {
		Ability@ abl = getAbility(id);
		if(abl is null)
			return uint(-1);
		return abl.type.id;
	}

	void readAbilities(Message& msg) {
		uint cnt = msg.read_uint();
		abilities.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			msg >> abilities[i];
	}

	void readAbilityDelta(Message& msg) {
		readAbilities(msg);
	}
};


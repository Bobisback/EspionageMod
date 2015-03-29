import construction.Constructible;
import buildings;
import saving;

class BuildingConstructible : Constructible {
	vec2i position;
	const BuildingType@ building;

	BuildingConstructible(vec2i pos, const BuildingType@ type) {
		position = pos;
		@building = type;

		totalLabor = type.laborCost;
	}

	BuildingConstructible(SaveFile& file) {
		Constructible::load(file);
		uint id = file.readIdentifier(SI_Building);
		@building = getBuildingType(id);
		file >> position;
	}

	void save(SaveFile& file) {
		Constructible::save(file);
		file.writeIdentifier(SI_Building, building.id);
		file << position;
	}

	ConstructibleType get_type() {
		return CT_Building;
	}

	string get_name() {
		return building.name;
	}

	bool tick(Object& obj, double time) {
		double progress = curLabor / max(totalLabor, 0.001);
		obj.setBuildingCompletion(position.x, position.y, progress);
		return true;
	}

	void cancel(Object& obj) {
		Constructible::cancel(obj);
		vec2i pos = position;
		position = vec2i(-1, -1);
		obj.destroyBuilding(pos);
	}

	void complete(Object& obj) {
		obj.setBuildingCompletion(position.x, position.y, 1.f);
	}

	void write(Message& msg) {
		Constructible::write(msg);
		msg << building.id;
	}

	bool repeat(Object& obj) {
		return false;
	}
};

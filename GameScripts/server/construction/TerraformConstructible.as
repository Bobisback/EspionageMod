import construction.Constructible;
import resources;

class TerraformConstructible : Constructible {
	Planet@ planet;
	const ResourceType@ resource;

	TerraformConstructible(Object& obj, Planet@ p, const ResourceType@ r, double cost, double labor) {
		@planet = p;
		@resource = r;
		buildCost = cost;
		totalLabor = labor;
	}

	TerraformConstructible(SaveFile& file) {
		Constructible::load(file);
		uint rid = file.readIdentifier(SI_Resource);
		@resource = getResource(rid);
		file >> planet;
	}

	bool repeat(Object& obj) {
		return false;
	}

	void save(SaveFile& file) {
		Constructible::save(file);
		file.writeIdentifier(SI_Resource, resource.id);
		file << planet;
	}

	ConstructibleType get_type() {
		return CT_Terraform;
	}

	string get_name() {
		return format(locale::BUILD_ASTEROID, resource.name);
	}
	
	bool start(Object& obj) {
		if(!started)
			planet.startTerraform();
		return Constructible::start(obj);
	}

	void cancel(Object& obj) {
		planet.stopTerraform();
		Constructible::cancel(obj);
	}

	bool tick(Object& obj, double time) {
		if(obj.owner !is planet.owner || !planet.isTerraforming()) {
			cancel(obj);
			return false;
		}
		return true;
	}

	void complete(Object& obj) {
		planet.terraformTo(resource.id);
	}

	void write(Message& msg) {
		Constructible::write(msg);
		msg << resource.id;
		msg << planet;
	}
};

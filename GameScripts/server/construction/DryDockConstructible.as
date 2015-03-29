import construction.Constructible;
import orbitals;
import resources;

class DryDockConstructible : Constructible {
	Orbital@ orbital;
	double givenLabor = 0.0;

	DryDockConstructible(Object& obj, Orbital& orb) {
		@orbital = orb;
		totalLabor = INT_MAX;
	}

	DryDockConstructible(SaveFile& file) {
		Constructible::load(file);
		file >> orbital;
		file >> givenLabor;
	}

	void save(SaveFile& file) {
		Constructible::save(file);
		file << orbital;
		file << givenLabor;
	}

	bool repeat(Object& obj) {
		return false;
	}

	ConstructibleType get_type() {
		return CT_DryDock;
	}

	string get_name() {
		return format(locale::BUILD_DRY_DOCK, "-");
	}

	bool start(Object& obj) {
		if(started)
			return true;
		if(!Constructible::start(obj))
			return false;
		givenLabor = obj.laborIncome;
		orbital.sendValue(OV_DRY_ModLabor, +givenLabor);
		return true;
	}

	void remove(Object& obj) {
		Constructible::remove(obj);
		if(givenLabor != 0)
			orbital.sendValue(OV_DRY_ModLabor, -givenLabor);
	}

	bool tick(Object& obj, double time) {
		if(!orbital.valid)
			return false;
		double income = max(obj.laborIncome, curLabor / max(time, 0.001));
		curLabor = 0;
		if(income != givenLabor) {
			orbital.sendValue(OV_DRY_ModLabor, income - givenLabor);
			givenLabor = income;
		}
		return true;
	}

	bool isUsingLabor(Object& obj) {
		return orbital.usingLabor;
	}

	bool useLabor(Object& obj, double& tickLabor) {
		if(!orbital.valid)
			return true;
		if(!orbital.usingLabor)
			return false;
		return true;
	}

	void write(Message& msg) {
		Constructible::write(msg);
		msg << orbital;
	}
};

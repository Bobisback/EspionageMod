import construction.Constructible;
import resources;

class ExportConstructible : Constructible {
	Object@ exportTo;
	double givenLabor = 0.0;

	ExportConstructible(Object& obj, Object& exportTo) {
		@this.exportTo = exportTo;
		totalLabor = INT_MAX;
	}

	ExportConstructible(SaveFile& file) {
		Constructible::load(file);
		file >> exportTo;
		file >> givenLabor;
	}

	bool repeat(Object& obj) {
		return false;
	}

	void save(SaveFile& file) {
		Constructible::save(file);
		file << exportTo;
		file << givenLabor;
	}

	ConstructibleType get_type() {
		return CT_Export;
	}

	string get_name() {
		return format(locale::EXPORT_LABOR, exportTo.name);
	}

	bool start(Object& obj) {
		if(started)
			return true;
		if(!Constructible::start(obj))
			return false;
		givenLabor = obj.laborIncome;
		exportTo.modLaborIncome(+givenLabor);
		return true;
	}

	void remove(Object& obj) {
		Constructible::remove(obj);
		if(givenLabor != 0)
			exportTo.modLaborIncome(-givenLabor);
	}

	bool tick(Object& obj, double time) {
		if(!exportTo.valid || !obj.canExportLabor || !exportTo.canImportLabor || exportTo.owner !is obj.owner)
			return false;
		double income = max(obj.laborIncome, curLabor / max(time, 0.001));
		curLabor = 0;
		if(income != givenLabor) {
			exportTo.modLaborIncome(income - givenLabor);
			givenLabor = income;
		}
		return true;
	}

	bool isUsingLabor(Object& obj) {
		return exportTo.isUsingLabor;
	}

	bool useLabor(Object& obj, double& tickLabor) {
		if(exportTo is null || !exportTo.valid || exportTo.owner !is obj.owner || !obj.canExportLabor || !exportTo.canImportLabor)
			return true;
		if(!exportTo.isUsingLabor)
			return false;
		return true;
	}

	void write(Message& msg) {
		Constructible::write(msg);
		msg << exportTo;
	}
};

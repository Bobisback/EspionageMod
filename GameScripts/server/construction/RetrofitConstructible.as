import construction.Constructible;
import resources;

class RetrofitConstructible : Constructible {
	Object@ fleet;

	RetrofitConstructible(Object& obj, Object@ Fleet, int cost, double labor, int extraMaint) {
		@fleet = Fleet;
		buildCost = cost;
		maintainCost = extraMaint;
		totalLabor = labor;
	}

	RetrofitConstructible(SaveFile& file) {
		Constructible::load(file);
		file >> fleet;
	}

	void save(SaveFile& file) {
		Constructible::save(file);
		file << fleet;
	}

	bool repeat(Object& obj) {
		return false;
	}

	ConstructibleType get_type() {
		return CT_Retrofit;
	}

	string get_name() {
		return format(locale::BUILD_RETROFIT, fleet.name);
	}

	void cancel(Object& obj) {
		fleet.stopFleetRetrofit(obj);
		Constructible::cancel(obj);
	}

	void complete(Object& obj) {
		fleet.finishFleetRetrofit(obj);
	}

	bool tick(Object& obj, double time) {
		if(obj.owner !is fleet.owner
				|| obj.region is null
				|| obj.region !is fleet.region) {
			cancel(obj);
			return false;
		}
		return true;
	}

	void write(Message& msg) {
		Constructible::write(msg);
		msg << fleet;
	}
};

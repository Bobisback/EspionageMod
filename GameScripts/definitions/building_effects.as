import buildings;
from buildings import BuildingHook;
from bonus_effects import BonusEffect;
import planet_effects;
import listed_values;
import requirement_effects;

class TriggerStartConstruction : BuildingHook {
	Document doc("Triggers another hook when construction of a building starts.");
	Argument hook("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ eff;

	bool instantiate() override {
		@eff = cast<BonusEffect>(parseHook(hook.str, "bonus_effects::", required=false));
		if(eff is null) {
			error("TriggerStartConstruction(): could not find inner hook: "+escape(hook.str));
			return false;
		}
		return BuildingHook::instantiate();
	}

#section server
	void startConstruction(Object& obj, SurfaceBuilding@ bld) const {
		if(eff !is null)
			eff.activate(obj, obj.owner);
	}
#section all
};

class TriggerCancelConstruction : BuildingHook {
	Document doc("Triggers another hook when construction of a building is cancelled.");
	Argument hook("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ eff;

	bool instantiate() override {
		@eff = cast<BonusEffect>(parseHook(hook.str, "bonus_effects::", required=false));
		if(eff is null) {
			error("TriggerCancelConstruction(): could not find inner hook: "+escape(hook.str));
			return false;
		}
		return BuildingHook::instantiate();
	}

#section server
	void cancelConstruction(Object& obj, SurfaceBuilding@ bld) const {
		if(eff !is null)
			eff.activate(obj, obj.owner);
	}
#section all
};

class TriggerConstructed : BuildingHook {
	Document doc("Triggers another hook when construction of a building is finished.");
	Argument hook("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ eff;

	bool instantiate() override {
		@eff = cast<BonusEffect>(parseHook(hook.str, "bonus_effects::", required=false));
		if(eff is null) {
			error("TriggerConstructed(): could not find inner hook: "+escape(hook.str));
			return false;
		}
		return BuildingHook::instantiate();
	}

#section server
	void complete(Object& obj, SurfaceBuilding@ bld) const {
		if(eff !is null)
			eff.activate(obj, obj.owner);
	}
#section all
};

class ConstructibleIfAttributeGTE : BuildingHook {
	Document doc("Only constructible if an empire attribute is greater than or equal to the specified value.");
	Argument attribute("Attribute", AT_EmpAttribute, doc="Attribute to test, can be set to any arbitrary name to be created as a new attribute with starting value 0.");
	Argument value("Value", AT_Decimal, doc="Value to test against.");

	bool canBuildOn(Object& obj, bool ignoreState = false) const override {
		Empire@ emp = obj.owner;
		if(emp is null)
			return false;
		if(emp.getAttribute(attribute.integer) < value.decimal)
			return false;
		return true;
	}
};

class ConstructibleIfAttribute : BuildingHook {
	Document doc("Only constructible if an empire attribute is equal to the specified value.");
	Argument attribute("Attribute", AT_EmpAttribute, doc="Attribute to test, can be set to any arbitrary name to be created as a new attribute with starting value 0.");
	Argument value("Value", AT_Decimal, doc="Value to test against.");

	bool canBuildOn(Object& obj, bool ignoreState = false) const override {
		Empire@ emp = obj.owner;
		if(emp is null)
			return false;
		if(abs(emp.getAttribute(attribute.integer) - value.decimal) >= 0.001)
			return false;
		return true;
	}
};

class CannotBuildManually : BuildingHook {
	Document doc("Indicates that the building cannot be manually constructed.");

	bool canBuildOn(Object& obj, bool ignoreState = false) const override {
		return false;
	}
};

class CannotRemove : BuildingHook {
	Document doc("Indicates that the building cannot be removed by the player.");

	bool canRemove(Object& obj) const override {
		return false;
	}
};

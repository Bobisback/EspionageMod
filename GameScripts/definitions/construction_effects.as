import constructions;
from constructions import ConstructionHook;
import generic_hooks;
import requirement_effects;
import bonus_effects;
import target_filters;
import listed_values;

#section server
from constructions import Constructible;
#section all

class AddBuildCostAttribute : ConstructionHook {
	Document doc("Add build cost based on an empire attribute value.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to use.");
	Argument multiply(AT_Decimal, "1", doc="Multiply attribute value by this much.");
	Argument multiply_sqrt(AT_Decimal, "0", doc="Add cost based on the square root of the attribute multiplied by this.");

	void getBuildCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, int& cost) const override {
		cost += obj.owner.getAttribute(attribute.integer) * multiply.decimal;
		if(multiply_sqrt.decimal != 0)
			cost += sqrt(obj.owner.getAttribute(attribute.integer)) * multiply_sqrt.decimal;
	}
};

class AddMaintainCostAttribute : ConstructionHook {
	Document doc("Add maintenance cost based on an empire attribute value.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to use.");
	Argument multiply(AT_Decimal, "1", doc="Multiply attribute value by this much.");
	Argument multiply_sqrt(AT_Decimal, "0", doc="Add cost based on the square root of the attribute multiplied by this.");

	void getMaintainCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, int& cost) const override {
		cost += obj.owner.getAttribute(attribute.integer) * multiply.decimal;
		if(multiply_sqrt.decimal != 0)
			cost += sqrt(obj.owner.getAttribute(attribute.integer)) * multiply_sqrt.decimal;
	}
};

class AddLaborCostAttribute : ConstructionHook {
	Document doc("Add labor cost based on an empire attribute value.");
	Argument attribute(AT_EmpAttribute, doc="Attribute to use.");
	Argument multiply(AT_Decimal, "1", doc="Multiply attribute value by this much.");
	Argument multiply_sqrt(AT_Decimal, "0", doc="Add cost based on the square root of the attribute multiplied by this.");

	void getLaborCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, double& cost) const override {
		cost += obj.owner.getAttribute(attribute.integer) * multiply.decimal;
		if(multiply_sqrt.decimal != 0)
			cost += sqrt(obj.owner.getAttribute(attribute.integer)) * multiply_sqrt.decimal;
	}
};

class OnStart : ConstructionHook {
	Document doc("Trigger a hook whenever the construction is started.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("OnStart(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return ConstructionHook::instantiate();
	}

#section server
	void start(Construction@ cons, Constructible@ qitem, any@ data) const override {
		if(hook !is null)
			hook.activate(cons.obj, cons.obj.owner);
	}
#section all
};

class OnCancel : ConstructionHook {
	Document doc("Trigger a hook whenever the construction is canceled.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::", required=false));
		if(hook is null) {
			error("OnStart(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return ConstructionHook::instantiate();
	}

#section server
	void cancel(Construction@ cons, Constructible@ qitem, any@ data) const override {
		if(hook !is null)
			hook.activate(cons.obj, cons.obj.owner);
	}
#section all
};

class Trigger : ConstructionHook {
	Document doc("Runs a triggered hook on the target when the construction completes.");
	Argument targ(TT_Object);
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to run.");
	BonusEffect@ hook;
	GenericEffect@ eff;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::", required=false));
		if(hook is null)
			@eff = cast<GenericEffect>(parseHook(hookID.str, "planet_effects::", required=false));
		if(hook is null && eff is null) {
			error("Trigger(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return ConstructionHook::instantiate();
	}

#section server
	void finish(Construction@ cons, Constructible@ qitem, any@ data) const {
		auto@ objTarg = targ.fromConstTarget(cons.targets);
		if(objTarg is null || objTarg.obj is null)
			return;
		if(hook !is null)
			hook.activate(objTarg.obj, cons.obj.owner);
		else if(eff !is null)
			eff.enable(objTarg.obj, null);
	}
#section all
};

class ConsumeFTL : ConstructionHook {
	Document doc("Requires a payment of FTL to build this construction.");
	Argument cost("Amount", AT_Decimal, doc="FTL Cost.");

	bool canBuild(Object& obj, const ConstructionType@ cons, const Targets@ targs, bool ignoreCost) const {
		if(ignoreCost)
			return true;
		return obj.owner.FTLStored >= cost.decimal;
	}

	bool formatCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, string& value) const {
		value = format(locale::FTL_COST, toString(cost.decimal, 0));
		return true;
	}

#section server
	bool consume(Construction@ cons, any@ data, const Targets@ targs) const override {
		if(cons.obj.owner.consumeFTL(cost.decimal, partial=false) == 0.0)
			return false;
		return true;
	}

	void reverse(Construction@ cons, any@ data, const Targets@ targs) const override {
		cons.obj.owner.modFTLStored(cost.decimal);
	}
#section all
};

class ConsumeEnergy : ConstructionHook {
	Document doc("Requires a payment of Energy to build this construction.");
	Argument cost("Amount", AT_Decimal, doc="Energy Cost.");

	bool canBuild(Object& obj, const ConstructionType@ cons, const Targets@ targs, bool ignoreCost) const {
		if(ignoreCost)
			return true;
		return obj.owner.EnergyStored >= cost.decimal;
	}

	bool formatCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, string& value) const {
		value = toString(cost.decimal, 0)+" "+locale::RESOURCE_ENERGY;
		return true;
	}

#section server
	bool consume(Construction@ cons, any@ data, const Targets@ targs) const override {
		if(cons.obj.owner.consumeEnergy(cost.decimal, false) == 0.0)
			return false;
		return true;
	}

	void reverse(Construction@ cons, any@ data, const Targets@ targs) const override {
		cons.obj.owner.modEnergyStored(cost.decimal);
	}
#section all
};

class ConsumePopulation : ConstructionHook {
	Document doc("Requires a payment of Population to build this construction.");
	Argument cost("Amount", AT_Decimal, doc="Population Cost.");
	Argument allow_abandon(AT_Boolean, "False", doc="Whether to allow the planet to build this so it would go below 1 population and abandon.");

	bool canBuild(Object& obj, const ConstructionType@ cons, const Targets@ targs, bool ignoreCost) const {
		if(!obj.hasSurfaceComponent)
			return false;
		if(ignoreCost)
			return true;
		if(!allow_abandon.boolean)
			return obj.population - 1.0 > cost.decimal;
		return obj.population > cost.decimal;
	}

	bool formatCost(Object& obj, const ConstructionType@ cons, const Targets@ targs, string& value) const {
		value = toString(cost.decimal, 0)+" "+locale::POPULATION;
		return true;
	}

#section server
	bool consume(Construction@ cons, any@ data, const Targets@ targs) const override {
		if(!cons.obj.hasSurfaceComponent)
			return false;
		double avail = cons.obj.population;
		if(!allow_abandon.boolean)
			avail -= 1.0;
		if(avail < cost.decimal)
			return false;
		cons.obj.addPopulation(-cost.decimal);
		return true;
	}

	void reverse(Construction@ cons, any@ data, const Targets@ targs) const override {
		cons.obj.addPopulation(cost.decimal);
	}

	void tick(Construction@ cons, Constructible@ qitem, any@ data, double time) const {
		if(allow_abandon.boolean && cons.obj.population <= 0.1)
			cons.obj.forceAbandon();
	}
#section all
};

class SlowDownDebtGrowthFactor : ConstructionHook {
	Document doc("This constructible gets slowed down depending on the current debt factor.");

#section server
	void start(Construction@ cons, Constructible@ qitem, any@ data) const override {
		double lab = qitem.totalLabor;
		data.store(lab);
	}

	void tick(Construction@ cons, Constructible@ qitem, any@ data, double time) const {
		double lab = 0;
		data.retrieve(lab);

		float growthFactor = 1.f;
		float debtFactor = cons.obj.owner.DebtFactor;
		for(; debtFactor > 0; debtFactor -= 1.f)
			growthFactor *= 0.33f + 0.67f * (1.f - min(debtFactor, 1.f));

		qitem.totalLabor = (lab - qitem.curLabor) / max(growthFactor, 0.01f) + qitem.curLabor;
	}

	void save(Construction@ cons, any@ data, SaveFile& file) const {
		double lab = 0;
		data.retrieve(lab);
		file << lab;
	}

	void load(Construction@ cons, any@ data, SaveFile& file) const {
		double lab = 0;
		file >> lab;
		data.store(lab);
	}
#section all
};

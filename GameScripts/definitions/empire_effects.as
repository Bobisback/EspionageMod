#include "include/resource_constants.as"
import generic_hooks;
import repeat_hooks;
#section server
import bool getCheatsEverOn() from "cheats";
#section all

class GiveAchievement : EmpireEffect, TriggerableGeneric {
	Document doc("Unlocks an achievement when the effect is enabled.");
	Argument achievement(AT_Custom, doc="ID of the achievement to achieve.");

#section server
	void enable(Empire& owner, any@ data) const override {
		if(!owner.valid || getCheatsEverOn())
			return;
		if(owner is playerEmpire)
			unlockAchievement(achievement.str);
		if(mpServer && owner.player !is null)
			clientAchievement(owner.player, achievement.str);
	}
#section all
};

class GivePoints : EmpireEffect, TriggerableGeneric {
	Document doc("When the effect is first activated, permanently increase the empire's points.");
	Argument points(AT_Integer, doc="Amount of points.");
	
#section server
	void enable(Empire& owner, any@ data) const override {
		owner.points += arguments[0].integer;
	}
#section all
};

class WorthPoints : EmpireEffect {
	Document doc("While this effect is active, the empire's points are increased.");
	Argument points(AT_Integer, doc="Amount of points.");
	
#section server
	void enable(Empire& owner, any@ data) const override {
		owner.points += arguments[0].integer;
	}
	
	void disable(Empire& owner, any@ data) const override {
		owner.points -= arguments[0].integer;
	}
#section all
};

class GiveGlobalVision : EmpireEffect, TriggerableGeneric {
	Document doc("Grants vision over every object in the universe while active.");

#section server
	void tick(Empire& owner, any@ data, double time) const override {
		owner.visionMask = ~0;
	}

	void disable(Empire& owner, any@ data) const override {
		owner.visionMask = owner.mask;
	}
#section all
};

class GiveGlobalTrade : EmpireEffect, TriggerableGeneric {
	Document doc("Allows planetary resource trade from anywhere to anywhere while active.");

#section server
	void tick(Empire& owner, any@ data, double time) const override {
		owner.GlobalTrade = true;
	}
	
	void disable(Empire& owner, any@ data) {
		owner.GlobalTrade = false;
	}
#section all
};

class ModGlobalLoyalty : EmpireEffect, TriggerableGeneric {
	Document doc("Modifies the loyalty of all planets owned by this effect's owner.");
	Argument amount(AT_Integer, doc="How much to add or subtract from the loyalty value.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.GlobalLoyalty += arguments[0].integer;
	}

	void disable(Empire& owner, any@ data) const override {
		owner.GlobalLoyalty -= arguments[0].integer;
	}
#section all
};

class AddFTLIncome : EmpireEffect, TriggerableGeneric {
	Document doc("Increase FTL income per second.");
	Argument rate(AT_Decimal, doc="Rate per second to add.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modFTLIncome(+arguments[0].decimal);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modFTLIncome(-arguments[0].decimal);
	}
#section all
};

class AddFTLStorage : EmpireEffect, TriggerableGeneric {
	Document doc("Increase FTL storage cap.");
	Argument amount(AT_Integer, doc="Amount of extra storage to add.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modFTLCapacity(+arguments[0].integer);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modFTLCapacity(-arguments[0].integer);
	}
#section all
};

class AddEnergyIncome : EmpireEffect, TriggerableGeneric {
	Document doc("Increase energy income per second.");
	Argument amount(AT_Decimal, doc="Amount of energy per second to add, before storage penalty.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modEnergyIncome(+amount.decimal);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modEnergyIncome(-amount.decimal);
	}
#section all
};

class AddResearchIncome : EmpireEffect, TriggerableGeneric {
	Document doc("Increase research income per second.");
	Argument amount(AT_Decimal, doc="Amount of research generation per second to add, before generation penalties.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modResearchRate(+amount.decimal);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modResearchRate(-amount.decimal);
	}
#section all
};

class AddMoneyIncome : EmpireEffect, TriggerableGeneric {
	Document doc("Increase money income per cycle.");
	Argument amount(AT_Integer, doc="Amount of income per cycle to add.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modTotalBudget(amount.integer, MoT_Misc);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modTotalBudget(-amount.integer, MoT_Misc);
	}
#section all
};

class AddInfluenceStake : EmpireEffect, TriggerableGeneric {
	Document doc("Increase the empire's influence stake, increasing its influence generation.");
	Argument amount(AT_Integer, doc="Amount of pressure-equivalent influence stake to gain while this is active.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modInfluenceIncome(+amount.integer);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modInfluenceIncome(-amount.integer);
	}
#section all
};

class ModInfluenceFactor : EmpireEffect, TriggerableGeneric {
	Document doc("Change the influence generation rate factor by a certain amount.");
	Argument amount(AT_Decimal, doc="Amount added to percentage influence generation. For example, 0.25 increases influence generation by 25% of base.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modInfluenceFactor(+amount.decimal);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modInfluenceFactor(-amount.decimal);
	}
#section all
};

class PeriodicInfluenceCard : EmpireEffect {
	Document doc("Grant one of the specified influence cards every specified interval.");
	Argument cardIDs("Cards", AT_Custom, doc="A list of possible influence cards to grant, separated by :.");
	Argument timer(AT_Decimal, "60", doc="Amount of seconds between influence card generation.");
	Argument quality(AT_Integer, "0", doc="Extra quality to add to the generated cards.");

#section server
	array<const InfluenceCardType@> cards;

	bool instantiate() override {
		array<string>@ args = arguments[0].str.split(":");
		for(uint i = 0, cnt = args.length; i < cnt; ++i) {
			auto@ card = getInfluenceCardType(args[i]);
			if(card is null) {
				error("PeriodicInfluenceCrad() Error: could not find influence card "+args[i]);
			}
			else {
				cards.insertLast(card);
			}
		}
		return EmpireEffect::instantiate();
	}

	void enable(Empire& owner, any@ data) const override {
		double timer = 0.0;
		data.store(timer);
	}

	void tick(Empire& owner, any@ data, double tick) const override {
		double timer = 0.0;
		data.retrieve(timer);

		timer += tick;
		if(timer >= arguments[1].decimal) {
			auto@ type = cards[randomi(0, cards.length-1)];
			auto@ newCard = type.generate();
			newCard.quality = clamp(arguments[2].integer, type.minQuality, type.maxQuality);
			cast<InfluenceStore>(owner.InfluenceManager).addCard(owner, newCard);

			timer -= arguments[1].decimal;
		}

		data.store(timer);
	}

	void save(any@ data, SaveFile& file) const override {
		double timer = 0.0;
		data.retrieve(timer);
		file << timer;
	}

	void load(any@ data, SaveFile& file) const override {
		double timer = 0.0;
		file >> timer;
		data.store(timer);
	}
#section all
};

class ModEmpireAttribute : EmpireEffect, TriggerableGeneric {
	Document doc("Modify the value of an empire attribute while this effect is active.");
	Argument attribute(AT_EmpAttribute, doc="Which attribute to alter.");
	Argument mode(AT_AttributeMode, doc="How to modify the attribute.");
	Argument value(AT_Decimal, doc="Value to modify the attribute by.");

#section server
	void enable(Empire& emp, any@ data) const override {
		if(emp !is null && emp.valid)
			emp.modAttribute(uint(arguments[0].integer), arguments[1].integer, arguments[2].decimal);
	}

	void disable(Empire& emp, any@ data) const override {
		if(emp !is null && emp.valid) {
			if(arguments[1].integer == AC_Multiply)
				emp.modAttribute(uint(arguments[0].integer), arguments[1].integer, 1.0/arguments[2].decimal);
			else
				emp.modAttribute(uint(arguments[0].integer), arguments[1].integer, -1.0*arguments[2].decimal);
		}
	}
#section all
};

class UnlockTagWhileActive : EmpireEffect {
	Document doc("While this effect is active, the specified unlock tag is marked as unlocked on the empire. When the effect stops, the unlocking is revoked.");
	Argument tag(AT_UnlockTag, doc="The unlock tag to unlock. Unlock tags can be named any arbitrary thing, and will be created as specified. Use the same tag value in any RequireUnlockTag() or similar hooks that check for it.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.setTagUnlocked(tag.integer, true);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.setTagUnlocked(tag.integer, false);
	}
#section all
};

class AddGlobalDefense : EmpireEffect, TriggerableGeneric {
	Document doc("Add an amount of pressure-equivalent defense generation to the empire's global defense pool.");
	Argument amount(AT_Decimal, doc="Amount of defense generation to add to the global pool.");

#section server
	void enable(Empire& owner, any@ data) const override {
		owner.modDefenseRate(+amount.decimal * DEFENSE_LABOR_PM / 60.0);
	}

	void disable(Empire& owner, any@ data) const override {
		owner.modDefenseRate(-amount.decimal * DEFENSE_LABOR_PM / 60.0);
	}
#section all
};

class ReduceEmpireInfluencePerFlagshipSize : EmpireEffect {
	Document doc("While this is active, the empire's influence stake is reduced by 1 for every specified amount of size worth of flagships.");
	Argument per_size(AT_Decimal, "100", doc="Reduces influence generation by 1 stake for every flagship size multiple of this.");
	Argument count_orbitals(AT_Boolean, "False", doc="Whether to count orbital size.");

#section server
	void enable(Empire& owner, any@ data) const override {
		int amount = 0;
		data.store(amount);
	}

	void disable(Empire& owner, any@ data) const override {
		int amount = 0;
		data.retrieve(amount);

		owner.modInfluenceIncome(+amount);
	}

	void tick(Empire& owner, any@ data, double time) const override {
		int amount = 0;
		data.retrieve(amount);

		double totalSize = 0;
		for(uint i = 0, cnt = owner.fleetCount; i < cnt; ++i) {
			Ship@ obj = cast<Ship>(owner.fleets[i]);
			if(obj is null)
				continue;
			auto@ bp = obj.blueprint;
			if(bp is null)
				continue;
			auto@ dsg = bp.design;
			if(dsg is null)
				continue;
			if(!count_orbitals.boolean && dsg.hasTag(ST_Station))
				continue;
			totalSize += dsg.size;
		}

		int newAmount = floor(totalSize / per_size.decimal);
		if(amount != newAmount) {
			owner.modInfluenceIncome(amount - newAmount);
			data.store(newAmount);
		}
	}

	void save(any@ data, SaveFile& file) const override {
		int amount = 0;
		data.retrieve(amount);
		file << amount;
	}

	void load(any@ data, SaveFile& file) const override {
		int amount = 0;
		file >> amount;
		data.store(amount);
	}
#section all
};

class ModEmpireInfluenceGenMilitaryRank : EmpireEffect {
	Document doc("Modify influence generation percent of the empire based on their military rank.");
	Argument min_pct(AT_Decimal, "The empire with the lowest military gets this modification on their influence generation. Empires in between are interpolated.");
	Argument max_pct(AT_Decimal, "The empire with the highest military gets this modification on their influence generation. Empires in between are interpolated.");

#section server
	void enable(Empire& owner, any@ data) const override {
		double amount = 0;
		data.store(amount);
	}

	void disable(Empire& owner, any@ data) const override {
		double amount = 0;
		data.retrieve(amount);

		owner.modInfluenceFactor(-amount);
	}

	void tick(Empire& owner, any@ data, double time) const override {
		double amount = 0;
		data.retrieve(amount);

		uint total = 0;
		uint rank = 0;
		double myMil = owner.TotalMilitary;

		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.major)
				continue;
			if(other is owner)
				continue;

			++total;
			if(other.TotalMilitary > myMil)
				++rank;
		}
		if(total == 0)
			total = 1;

		double newAmount = (1.0 - (double(rank) / double(total))) * (max_pct.decimal - min_pct.decimal) + min_pct.decimal;
		if(newAmount != amount) {
			owner.modInfluenceFactor(newAmount - amount);
			data.store(newAmount);
		}
	}

	void save(any@ data, SaveFile& file) const override {
		double amount = 0;
		data.retrieve(amount);
		file << amount;
	}

	void load(any@ data, SaveFile& file) const override {
		double amount = 0;
		file >> amount;
		data.store(amount);
	}
#section all
};

class GiveVisionOverPeaceful : EmpireEffect {
	Document doc("Give the empire vision over all empires that it is not currently at war with, even if they are not allies.");
	Argument limit_contact(AT_Boolean, "True", doc="Whether to only give vision over empires we have contact with.");

#section server
	void disable(Empire& owner, any@ data) const override {
		owner.visionMask = owner.mask;
	}

	void tick(Empire& owner, any@ data, double time) const override {
		uint mask = 0;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(!other.valid || !other.major)
				continue;
			if(other.isHostile(owner))
				continue;
			if(limit_contact.boolean && owner.ContactMask.value & other.mask == 0)
				continue;
			mask |= other.mask;
		}
		owner.visionMask |= mask;
	}
#section all
};

class ObjectStatusList {
	double timer;
	set_int set;
	array<Object@> list;
	uint prevCount = 0;
};

class AddStatusOwnedPlanets : EmpireEffect {
	Document doc("Add a status effect to all owned planets.");
	Argument status(AT_Status, doc="Type of status to add to planets.");
	Argument level_requirement(AT_Integer, "0", doc="Minimum level of planets that get the status.");

#section server
	void enable(Empire& emp, any@ data) const override {
		ObjectStatusList list;
		data.store(@list);
	}

	void tick(Empire& emp, any@ data, double time) const override {
		ObjectStatusList@ list;
		data.retrieve(@list);
		if(list is null)
			return;

		list.timer -= time;
		if(list.timer >= 0 && emp.planetCount == list.prevCount)
			return;
		uint minLevel = level_requirement.integer;
		list.timer = 5.0;
		list.prevCount = emp.planetCount;

		int maxMods = 25;

		//Check old
		for(int i = list.list.length - 1; i >= 0 && maxMods > 0; --i) {
			Object@ pl = list.list[i];
			if(pl.level < minLevel || pl.owner !is emp || !pl.valid) {
				pl.removeStatusInstanceOfType(status.integer);
				list.list.removeAt(uint(i));
				list.set.erase(pl.id);
				--maxMods;
			}
		}

		//Check new
		if(maxMods > 0) {
			DataList@ objs = emp.getPlanets();
			Object@ obj;
			while(receive(objs, obj)) {
				if(maxMods <= 0)
					continue;
				Planet@ pl = cast<Planet>(obj);
				if(!list.set.contains(pl.id) && pl.level >= minLevel) {
					pl.addStatus(status.integer);
					list.list.insertLast(pl);
					list.set.insert(pl.id);
					--maxMods;
				}
			}
		}
	}

	void disable(Empire& emp, any@ data) const override {
		ObjectStatusList@ list;
		data.retrieve(@list);
		if(list is null)
			return;

		for(int i = list.list.length - 1; i >= 0; --i) {
			Object@ pl = list.list[i];
			pl.removeStatusInstanceOfType(status.integer);
		}

		list.list.length = 0;
		@list = null;
		data.store(@list);
	}

	void save(any@ data, SaveFile& file) const override {
		ObjectStatusList@ list;
		data.retrieve(@list);
		if(list is null) {
			file.write0();
			return;
		}
		file.write1();
		file << list.timer;
		file << list.list.length;
		for(uint i = 0, cnt = list.list.length; i < cnt; ++i)
			file << list.list[i];
	}

	void load(any@ data, SaveFile& file) const override {
		if(file.readBit()) {
			ObjectStatusList list;
			data.store(@list);
			file >> list.timer;
			uint cnt = 0;
			file >> cnt;
			list.list.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				file >> list.list[i];
				list.set.insert(list.list[i].id);
			}
		}
	}
#section all
};

class AddStatusOwnedFleets : EmpireEffect {
	Document doc("Add a status effect to all owned fleets.");
	Argument status(AT_Status, doc="Type of status to add to fleets.");
	Argument give_to_stations(AT_Boolean, "True", doc="Whether to also give the status to designed stations.");
	Argument give_to_ships(AT_Boolean, "True", doc="Whether to give the status to movable flagships.");

#section server
	void enable(Empire& emp, any@ data) const override {
		ObjectStatusList list;
		data.store(@list);
	}

	void tick(Empire& emp, any@ data, double time) const override {
		ObjectStatusList@ list;
		data.retrieve(@list);
		if(list is null)
			return;

		list.timer -= time;
		if(list.timer >= 0 && emp.fleetCount == list.prevCount)
			return;
		list.timer = 5.0;
		list.prevCount = emp.fleetCount;

		int maxMods = 25;

		//Check old
		for(int i = list.list.length - 1; i >= 0 && maxMods > 0; --i) {
			Object@ flt = list.list[i];
			if(flt.owner !is emp || !flt.valid) {
				flt.removeStatusInstanceOfType(status.integer);
				list.list.removeAt(uint(i));
				list.set.erase(flt.id);
				--maxMods;
			}
		}

		//Check new
		if(maxMods > 0) {
			if(give_to_ships.boolean) {
				DataList@ objs = emp.getFlagships();
				Object@ obj;
				while(receive(objs, obj)) {
					if(maxMods <= 0)
						continue;
					if(!list.set.contains(obj.id)) {
						obj.addStatus(status.integer);
						list.list.insertLast(obj);
						list.set.insert(obj.id);
						--maxMods;
					}
				}
			}

			if(give_to_stations.boolean) {
				DataList@ objs = emp.getStations();
				Object@ obj;
				while(receive(objs, obj)) {
					if(maxMods <= 0)
						continue;
					if(!list.set.contains(obj.id)) {
						obj.addStatus(status.integer);
						list.list.insertLast(obj);
						list.set.insert(obj.id);
						--maxMods;
					}
				}
			}
		}
	}

	void disable(Empire& emp, any@ data) const override {
		ObjectStatusList@ list;
		data.retrieve(@list);
		if(list is null)
			return;

		for(int i = list.list.length - 1; i >= 0; --i) {
			Object@ obj = list.list[i];
			obj.removeStatusInstanceOfType(status.integer);
		}

		list.list.length = 0;
		@list = null;
		data.store(@list);
	}

	void save(any@ data, SaveFile& file) const override {
		ObjectStatusList@ list;
		data.retrieve(@list);
		if(list is null) {
			file.write0();
			return;
		}
		file.write1();
		file << list.timer;
		file << list.list.length;
		for(uint i = 0, cnt = list.list.length; i < cnt; ++i)
			file << list.list[i];
	}

	void load(any@ data, SaveFile& file) const override {
		if(file.readBit()) {
			ObjectStatusList list;
			data.store(@list);
			file >> list.timer;
			uint cnt = 0;
			file >> cnt;
			list.list.length = cnt;
			for(uint i = 0; i < cnt; ++i) {
				file >> list.list[i];
				list.set.insert(list.list[i].id);
			}
		}
	}
#section all
};

class SystemData {
	uint index = 0;
	set_int set;
};

class AddRegionStatusOwnedSystems : EmpireEffect {
	Document doc("Add a region status to all owned systems.");
	Argument status(AT_Status, doc="Type of status to add to regions.");
	Argument allow_neutral(AT_Boolean, "True", doc="Whether to count systems that also have planets from neutral empires as owned.");
	Argument allow_enemy(AT_Boolean, "False", doc="Whether to count systems that also have planets from enemy empires as owned.");
	Argument bind_empire(AT_Boolean, "True", doc="Whether to only add to objects of this empire, or of all empires.");

#section server
	void enable(Empire& emp, any@ data) const override {
		SystemData list;
		data.store(@list);
	}

	void tick(Empire& emp, any@ data, double time) const override {
		SystemData@ list;
		data.retrieve(@list);
		if(list is null)
			return;

		list.index = (list.index+1) % systemCount;
		auto@ sys = getSystem(list.index);

		Empire@ bindEmp;
		if(bind_empire.boolean)
			@bindEmp = emp;

		bool applicable = false;
		uint plMask = sys.object.PlanetsMask;
		if(plMask & emp.mask != 0) {
			applicable = true;
			if(plMask != emp.mask && !allow_neutral.boolean)
				applicable = false;
			else if(plMask & emp.hostileMask != 0 && !allow_enemy.boolean)
				applicable = false;
		}

		if(list.set.contains(sys.object.id)) {
			if(!applicable) {
				sys.object.removeRegionStatus(bindEmp, status.integer);
				list.set.erase(sys.object.id);
			}
		}
		else {
			if(applicable) {
				sys.object.addRegionStatus(bindEmp, status.integer);
				list.set.insert(sys.object.id);
			}
		}
	}

	void disable(Empire& emp, any@ data) const override {
		SystemData@ list;
		data.retrieve(@list);
		if(list is null)
			return;

		Empire@ bindEmp;
		if(bind_empire.boolean)
			@bindEmp = emp;

		for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
			auto@ sys = getSystem(i);
			if(list.set.contains(sys.object.id))
				sys.object.removeRegionStatus(bindEmp, status.integer);
		}

		@list = null;
		data.store(@list);
	}

	void save(any@ data, SaveFile& file) const override {
		SystemData@ list;
		data.retrieve(@list);
		if(list is null) {
			file.write0();
			return;
		}
		file.write1();
		uint cnt = list.set.size();
		file << cnt;
		for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
			auto@ sys = getSystem(i);
			if(list.set.contains(sys.object.id))
				file << sys.object.id;
		}
	}

	void load(any@ data, SaveFile& file) const override {
		if(file.readBit()) {
			SystemData list;
			data.store(@list);

			if(file >= SV_0111) {
				uint cnt = 0;
				file >> cnt;
				for(uint i = 0; i < cnt; ++i) {
					int id = 0;
					file >> id;
					list.set.insert(id);
				}
			}
			else {
				for(uint i = 0, cnt = 100; i < cnt; ++i)
					file.readBit();
			}
		}
	}
#section all
};

class GrantAllFleetVision : EmpireEffect {
	Document doc("Grant vision of all fleets anywhere.");
	Argument normal_space(AT_Boolean, "True", doc="Grant vision over fleets currently in normal space.");
	Argument in_ftl(AT_Boolean, "True", doc="Grant vision over fleets currently in FTL.");
	Argument stations(AT_Boolean, "False", doc="Count stations as fleets.");

#section server
	void tick(Empire& emp, any@ data, double time) const override {
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			Empire@ other = getEmpire(i);
			if(emp.visionMask & other.mask != 0)
				continue;
			other.giveFleetVisionTo(emp, normal_space.boolean, in_ftl.boolean, stations.boolean);
		}
	}
#section all
};

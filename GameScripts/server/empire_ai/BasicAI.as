import settings.game_settings;
from empire_ai.EmpireAI import AIController;
from saving import SaveVersion;
import biomes;
import orbitals;
import attributes;
import util.convar;
import notifications;
import regions.regions;
import util.design_designer;
import int getAbilityID(const string& ident) from "abilities";
import int getTraitID(const string&) from "traits";

const double maxAIFrame = 0.001;

const float gotPlanetWill = 1.25f;
const float lostPlanetWill = 1.f;
//Per size of flagship
const float gotFleetWill = 0.05f;
const float lostFleetWill = 0.02f;

//Percent of willpower remaining after 3 minute cycle
const double willDecayPerBudget = 0.55;

ConVar profile_ai("profile_ai", 0.0);

#include "empire_ai/include/bai_act_colonize.as"
#include "empire_ai/include/bai_act_resources.as"
#include "empire_ai/include/bai_act_fleets.as"
#include "empire_ai/include/bai_act_strategy.as"
#include "empire_ai/include/bai_act_influence.as"
#include "include/resource_constants.as"

from influence_global import sendPeaceOffer;

const uint unownedMask = 1;

enum ActionType {
	ACT_Plan,
	ACT_FindIdle,
	ACT_Colonize,
	ACT_ColonizeRes,
	ACT_Explore,
	ACT_Build,
	ACT_Improve,
	ACT_Trade,
	ACT_Expend,
	ACT_Budget,
	ACT_Vote,
	ACT_Combat,
	ACT_War,
	ACT_Defend,
	ACT_Expand,
	ACT_Building,
	ACT_BuildOrbital,
	ACT_Design,
	ACT_Populate, //18
	
	STRAT_Military = 32,
	STRAT_Influence,
	
	ACT_BIT_OFFSET = 58,
};

enum AIDifficulty {
	DIFF_Trivial = 0,
	DIFF_Easy = 1,
	DIFF_Medium = 2,
	DIFF_Hard = 3,
	DIFF_Max = 4,
};

enum AIBehavior {
	AIB_IgnorePlayer = 0x1,
	AIB_IgnoreAI = 0x2,
	AIB_QuickToWar = 0x4,
};

enum AICheats {
	AIC_Vision = 0x1,
	AIC_Resources = 0x2,
};

enum FleetType {
	FT_Scout,
	FT_Combat,
	FT_Carrier,
	FT_Titan,
	
	FT_Mothership,

	FT_INVALID
};

enum SpendFlags {
	SF_Borrow = 1
};

interface Action {
	int64 get_hash() const;
	ActionType get_actionType() const;
	string get_state() const;
	//Returns true if the action is finished
	bool perform(BasicAI@);
	void save(BasicAI@, SaveFile& msg);
	void postLoad(BasicAI@);
}

interface ObjectReceiver : Action {
	bool giveObject(BasicAI@ ai, Object@);
}

final class PlanRegion {
	Region@ region;
	vec3d center;
	double radius = 900.0;
	
	double lastSeen = -1e3;
	uint planetMask = 0;
	
	array<Planet@> planets, plRecord;
	array<int> planetResources;
	array<Asteroid@> asteroids;
	array<Artifact@> artifacts;
	array<Orbital@> orbitals;
	array<Anomaly@> anomalies;
	//Ship strength per-empire (sqrt space)
	array<double> strengths(getEmpireCount());
	
	const SystemDesc@ cachedSystem;
	
	const SystemDesc@ get_system() {
		if(cachedSystem !is null)
			return cachedSystem;
		if(region is null)
			return null;
		@cachedSystem = getSystem(region);
		return cachedSystem;
	}
	
	PlanRegion(Object@ Focus) {
		while(Focus.region !is null)
			@Focus = Focus.region;
		@region = cast<Region>(Focus);
		center = region.position;
		radius = region.radius;
	}

	PlanRegion(SaveFile& file) {
		file >> region;
		file >> center;
		if(file >= SV_0037)
			file >> lastSeen;
		
		file >> planetMask;
		
		uint count = 0;
		
		file >> count;
		planets.length = count;
		planetResources.length = count;
		for(uint i = 0; i < count; ++i) {
			file >> planets[i];
			planetResources[i] = planets[i].primaryResourceType;
		}
		
		plRecord = planets;
		
		file >> count;
		asteroids.length = count;
		for(uint i = 0; i < count; ++i)
			file >> asteroids[i];
		
		if(file >= SV_0030) {
			file >> count;
			artifacts.length = count;
			for(uint i = 0; i < count; ++i)
				file >> artifacts[i];
		}
			
		for(uint i = 0; i < strengths.length; ++i)
			file >> strengths[i];
	}

	void save(SaveFile& file) {
		file << region;
		file << center;
		file << lastSeen;
		
		file << planetMask;
		file << uint(planets.length);
			for(uint i = 0; i < planets.length; ++i)
				file << planets[i];
		
		file << uint(asteroids.length);
			for(uint i = 0; i < asteroids.length; ++i)
				file << asteroids[i];
		
		file << uint(artifacts.length);
			for(uint i = 0; i < artifacts.length; ++i)
				file << artifacts[i];
		
		for(uint i = 0; i < strengths.length; ++i)
			file << strengths[i];
	}
	
	double get_age() const {
		return gameTime - lastSeen;
	}
	
	//Checks for various changes to remembered planet states
	//	Returns true if all planets were in memory
	bool useMemory(BasicAI@ ai) {
		bool anyMemory = false, allInMemory = true;
		uint plOwnerMask = 0;
		
		//TODO: Have regions track when their planet list changes
		uint plCount = region.planetCount;
		if(plRecord.length != plCount) {
			plRecord.length = 0;
			for(uint i = 0, cnt = plCount; i < cnt; ++i) {
				Planet@ pl = region.planets[i];
				if(pl !is null && pl.valid)
					plRecord.insertLast(pl);
			}
		}
		
		for(uint i = 0, cnt = plRecord.length; i < cnt; ++i) {
			Planet@ pl = plRecord[i];
			if(pl is null || !pl.valid)
				break;
			
			if(!pl.isKnownTo(ai.empire)) {
				allInMemory = false;
				continue;
			}
			
			Empire@ owner = pl.visibleOwnerToEmp(ai.empire);
			if(owner is null)
				continue;
			
			if(!anyMemory) {
				planets.length = 0;
				planetResources.length = 0;
			}
			
			anyMemory = true;
			plOwnerMask |= owner.mask;
			planets.insertLast(pl);
			planetResources.insertLast(pl.primaryResourceType);
		}
		
		if(anyMemory)
			planetMask = plOwnerMask;
		return allInMemory;
	}
	
	//Search the system for all objects we can track and remember, and update strength ratings
	array<Object@>@ scout(BasicAI@ ai, bool verbose = false) {
		ai.didTickScan = true;
	
		array<Object@>@ objs = search();
		lastSeen = gameTime;
		
		plRecord.length = 0;
		planets.length = 0;
		planetResources.length = 0;
		asteroids.length = 0;
		artifacts.length = 0;
		orbitals.length = 0;
		anomalies.length = 0;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i)
			strengths[i] = 0.0;
		
		planetMask = 0;
		
		for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
			Object@ obj = objs[i];
			if(obj.region !is region)
				continue;
			
			//if(verbose)
			//	error(obj.name);
			
			switch(obj.type) {
				case OT_Planet:
					{
						Planet@ pl = cast<Planet>(obj);
						plRecord.insertLast(pl);
						planets.insertLast(pl);
						planetResources.insertLast(pl.primaryResourceType);
						Empire@ owner = obj.owner;
						planetMask |= owner.mask;
						if(owner.valid)
							strengths[owner.index] += sqrt(pl.getFleetStrength());
						if(owner is ai.empire && !ai.knownPlanets.contains(pl.id)) {
							ai.addPlanet(pl);
							ai.markAsColony(region);
						}
					}
					break;
				case OT_Asteroid:
					asteroids.insertLast(cast<Asteroid>(obj));
					break;
				case OT_Ship:
					{
						Empire@ owner = obj.owner;
						if(owner.valid && obj.hasLeaderAI)
							strengths[owner.index] += sqrt(obj.getFleetStrength());
					} break;
				case OT_Artifact:
					artifacts.insertLast(cast<Artifact>(obj));
					break;
				case OT_Anomaly:
					anomalies.insertLast(cast<Anomaly>(obj));
					break;
				case OT_Orbital:
					{
						orbitals.insertLast(cast<Orbital>(obj));
						Empire@ owner = obj.owner;
						if(owner.valid) {
							Orbital@ orb = cast<Orbital>(obj);
							double hp = orb.maxHealth + orb.maxArmor;
							double dps = orb.dps * max(orb.efficiency, 0.75);
							if(orb.hasLeaderAI) {
								hp += obj.getFleetHP();
								dps += orb.getFleetDPS();
							}
							strengths[owner.index] += sqrt(hp * dps);
						}
					} break;
			}
		}
		
		return objs;
	}
	
	array<Object@>@ search(uint mask = 0) {
		vec3d bound(radius);
		return findInBox(center - bound, center + bound, mask);
	}
	
	bool hasEnemies(Empire& against) {
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			auto@ emp = getEmpire(i);
			if(!emp.valid)
				continue;
			if(against.isHostile(emp) && strengths[emp.index] > 0)
				return true;
		}
		return false;
	}
};

final class SysSearch {
	int start = -1;
	int index = 0;
	
	void reset() {
		start = -1;
		index = 0;
	}
	
	void save(SaveFile& msg) {
		msg << start;
		if(start != -1)
			msg << index;
	}
	
	void load(SaveFile& msg) {
		msg >> start;
		if(start != -1)
			msg >> index;
	}
	
	PlanRegion@ next(array<PlanRegion@>& sysList) {
		int count = sysList.length;
		if(start == -1)
			start = randomi(0,count-1);
		
		if(index >= count)
			return null;
		
		int ind = (start + index) % count;
		index += 1;
		
		return sysList[ind];
	}
	
	PlanRegion@ random(array<PlanRegion@>& sysList) {
		int count = sysList.length;
		if(count == 0)
			return null;
		else
			return sysList[randomi(0,count-1)];
	}
	
	//Searches the next region, returning null if none are remaining
	array<Object@>@ search(array<PlanRegion@>& sysList, uint mask = 0) {
		PlanRegion@ region = next(sysList);
		if(region !is null)
			return region.search(mask);
		else
			return null;
	}
	
	//Searches a random region
	array<Object@>@ searchRandom(array<PlanRegion@>& sysList, uint mask = 0) {
		PlanRegion@ region = random(sysList);
		if(region !is null)
			return region.search(mask);
		else
			return array<Object@>();
	}
};

final class PlanetList {
	array<Planet@> idle, used;
	array<Object@> purpose;
	
	bool markIdle(Planet@ pl, bool onlyIfMissing = false) {
		bool wasNew = true;
		if(idle.find(pl) < 0) {
			int ind = used.find(pl);
			if(ind >= 0) {
				if(onlyIfMissing)
					return false;
				
				wasNew = false;
				used.removeAt(ind);
				purpose.removeAt(ind);
			}
			idle.insertLast(pl);
		}
		
		return wasNew;
	}
	
	void markUsed(Planet@ pl, Object@ goal) {
		int ind = used.find(pl);
		if(ind < 0) {
			idle.remove(pl);
			used.insertLast(pl);
			purpose.insertLast(goal);
		}
		else {
			@purpose[ind] = goal;
		}
	}
	
	Object@ getPurpose(Planet@ pl) {
		int ind = used.find(pl);
		if(ind >= 0)
			return purpose[ind];
		else
			return null;
	}
	
	void remove(Planet@ pl) {
		int index = idle.find(pl);
		if(index >= 0) {
			idle.removeAt(index);
			return;
		}
		
		index = used.find(pl);
		if(index >= 0) {
			used.removeAt(index);
			purpose.removeAt(index);
			return;
		}
	}
	
	void validate(BasicAI@ ai, Empire@ owner, const ResourceType@ type) {
		uint resType = uint(-1);
		uint usedLevel = 0;
		if(type !is null) {
			usedLevel = type.level;
			resType = type.id;
		}
	
		for(int i = idle.length - 1; i >= 0; --i) {
			Planet@ pl = idle[i];
			if(pl.owner !is owner || !pl.valid) {
				ai.willpower -= lostPlanetWill;
				idle.removeAt(i);
				ai.knownPlanets.erase(pl.id);
			}
			else if(pl.Population < 1.0) {
				ai.addIdle(ai.requestColony(pl, execute=false));
			}
			else if(pl.primaryResourceType != resType) {
				idle.removeAt(i);
				ai.addPlanet(pl);
			}
		}
		
		for(int i = used.length - 1; i >= 0; --i) {
			Planet@ pl = used[i];
			if(pl.owner !is owner || !pl.valid) {
				ai.willpower -= lostPlanetWill;
				used.removeAt(i);
				purpose.removeAt(i);
				ai.knownPlanets.erase(pl.id);
			}
			else if(pl.resourceLevel < usedLevel) {
				if(purpose[i] !is pl) {
					pl.exportResource(owner, 0, null);
					used.removeAt(i);
					purpose.removeAt(i);
					idle.insertLast(pl);
					ai.freePlanetImports(pl);
				}
			}
			else if(pl.primaryResourceType != resType) {
				used.removeAt(i);
				auto@ use = purpose[i];
				purpose.removeAt(i);
				ai.addPlanet(pl, use);
			}
			else {
				Object@ goal = purpose[i];
				if(!goal.valid || goal.owner !is owner || goal.region.getTerritory(owner) !is pl.region.getTerritory(owner)) {
					pl.exportResource(owner, 0, null);
					used.removeAt(i);
					purpose.removeAt(i);
					idle.insertLast(pl);
					ai.freePlanetImports(pl);
				}
			}
		}
		
		if(used.length > 0) {
			uint index = randomi(0,used.length - 1);
			Planet@ pl = used[index];
			Object@ dest = purpose[index];
			
			if(pl !is dest && pl.level >= usedLevel && !pl.isPrimaryDestination(dest)) {
				pl.exportResource(owner, 0, null);
				used.removeAt(index);
				purpose.removeAt(index);
				idle.insertLast(pl);
				ai.freePlanetImports(pl);
			}
		}
	}
	
	void save(SaveFile& msg) {
		uint count = idle.length;
		msg << count;
		for(uint i = 0; i < count; ++i)
			msg << idle[i];
		
		count = used.length;
		msg << count;
		for(uint i = 0; i < count; ++i) {
			msg << used[i];
			msg << purpose[i];
		}
	}
	
	void load(BasicAI@ ai, SaveFile& msg) {
		Planet@ pl;
		uint count = 0;
		msg >> count;
		idle.reserve(count);
		for(uint i = 0; i < count; ++i) {
			msg >> pl;
			if(pl is null)
				continue;
			idle.insertLast(pl);
			ai.knownPlanets.insert(pl.id);
		}
		
		Object@ other;
		count = 0;
		msg >> count;
		used.reserve(count);
		purpose.reserve(count);
		for(uint i = 0; i < count; ++i) {
			msg >> pl; msg >> other;
			if(pl is null)
				continue;
			used.insertLast(pl);
			ai.knownPlanets.insert(pl.id);
			purpose.insertLast(other);
		}
	}
};

enum AIResourceType {
	RT_Water,
	RT_Food,
	RT_LevelZero,
	RT_LevelOne,
	RT_LevelTwo,
	RT_LevelThree,
	RT_LaborZero,
	
	RT_COUNT
};

final class Request {
	Region@ region;
	double time;
};

enum SupportTask {
	ST_Filler,
	ST_AntiSupport,
	ST_AntiFlagship,
	ST_Tank,
	ST_Supplies,
	
	ST_COUNT
};

enum FlagshipTask {
	FST_Scout,
	FST_Combat,
	FST_SuperHeavy,
	FST_Mothership,
	
	FST_COUNT,
	
	FST_COUNT_OLD1 = FST_Mothership
};

enum StationTask {
	STT_LightDefense,
	STT_HeavyDefense,
	
	STT_COUNT
};

final class BasicAI : AIController {
	Empire@ empire;
	Planet@ homeworld;
	
	bool isMachineRace = false, usesMotherships = false, needsStalks = false, needsAltars = false;
	
	PlanRegion@ protect;
	
	bool debug = false, profile = false, logWar = false;
	uint printDepth = 0;
	string dbgMsg;
	vec3d focus;
	WriteFile@ log;

	array<Empire@> enemies;
	uint allyMask = 0;
	
	//Start at a reasonable willpower
	float willpower = gotPlanetWill * 3.f;
	
	array<double> treatyWaits(getEmpireCount(), gameTime + randomd(20.0,60.0));
	
	double lastPing = gameTime - randomd(65.0,90.0);
	Mutex reqLock;
	array<Request> requests, queuedRequests;
	
	array<PlanRegion@> ourSystems, exploredSystems, otherSystems;
	array<PlanetList> planetsByResource(getResourceCount());
	set_int knownPlanets;
	
	array<Artifact@> artifacts(getArtifactTypeCount());
	array<Ship@> scoutFleets, combatFleets, motherships, untrackedFleets;
	set_int knownLeaders;
	map systems;
	set_int knownSystems;
	
	array<Orbital@> orbitals;
	array<Object@> factories;
	set_int knownFactories;
	
	array<const Design@> dsgSupports(ST_COUNT), dsgFlagships(FST_COUNT), dsgStations(STT_COUNT);
	
	array<Object@> revenantParts;
	
	//AI Skill at various mechanics
	int skillEconomy = DIFF_Medium;
	int skillCombat = DIFF_Medium;
	int skillDiplo = DIFF_Medium;
	int skillTech = DIFF_Medium;
	int skillScout = DIFF_Medium;
	
	uint behaviorFlags = 0;
	uint cheatFlags = 0;
	int cheatLevel = 0;
	
	int getDifficultyLevel() {
		if(skillEconomy <= DIFF_Easy)
			return behaviorFlags & AIB_IgnorePlayer != 0 ? 0 : 1;
		else if(skillEconomy == DIFF_Medium)
			return 2;
		else if(cheatLevel > 0)
			return 5;
		else if(behaviorFlags & AIB_IgnoreAI != 0)
			return 4;
		return 3;
	}
	
	map actions;
	Action@ head;
	array<Action@> idle;
	set_int idles;
	int thoughtCycle = 0;
	
	//Track when the AI has performed a scout of a system, to avoid too much per-tick load
	bool didTickScan = false;
	
	double timeSinceLastExpand = 0.0;
	
	uint nextNotification = 0;
	
	array<array<int>> resLists(RT_COUNT), resListsExportable(RT_COUNT);
	
	void buildCommonLists() {
		isMachineRace = empire.hasTrait(getTraitID("Mechanoid"));
		usesMotherships = empire.hasTrait(getTraitID("StarChildren"));
		needsStalks = empire.hasTrait(getTraitID("Verdant"));
		needsAltars = empire.hasTrait(getTraitID("Devout"));
	
		auto@ foods = getResourceClass("Food");
		auto@ waters = getResourceClass("WaterType");
		
		auto@ r = resLists, e = resListsExportable;
		
		for(uint i = 0, cnt = getResourceCount(); i < cnt; ++i) {
			auto@ res = getResource(i);
			if(res.mode == RM_NonRequirement)
				continue;
			
			switch(res.level) {
				case 0:
					if(res.cls is waters) {
						r[RT_Water].insertLast(res.id);
						if(res.exportable && !res.artificial)
							e[RT_Water].insertLast(res.id);
					}
					else if(res.cls is foods) {
						r[RT_Food].insertLast(res.id);
						if(res.exportable)
							e[RT_Food].insertLast(res.id);
					}
					else {
						bool isLabor = res.tilePressure[TR_Labor] > 0;
						
						r[RT_LevelZero].insertLast(res.id);
						if(isLabor)
							r[RT_LaborZero].insertLast(res.id);
						
						if(res.exportable) {
							e[RT_LevelZero].insertLast(res.id);
							if(isLabor)
								e[RT_LaborZero].insertLast(res.id);
						}
					}
					break;
				case 1:
					r[RT_LevelOne].insertLast(res.id);
					if(res.exportable)
						e[RT_LevelOne].insertLast(res.id);
					break;
				case 2:
					r[RT_LevelTwo].insertLast(res.id);
					if(res.exportable)
						e[RT_LevelTwo].insertLast(res.id);
					break;
				case 3:
					r[RT_LevelThree].insertLast(res.id);
					if(res.exportable)
						e[RT_LevelThree].insertLast(res.id);
					break;
			}
		}
	}
	
	array<int>@ getResourceList(AIResourceType type, bool onlyExportable = false) {
		if(uint(type) >= resLists.length)
			return null;
		
		if(onlyExportable)
			return resListsExportable[type];
		else
			return resLists[type];
	}
	
	array<PlanRegion@>@ getBorder() {
		array<PlanRegion@> border;
		set_int found;
		uint mask = empire.mask;
		
		auto@ ours = ourSystems;
		for(uint i = 0, cnt = ours.length; i < cnt; ++i) {
			auto@ sys = ours[i].system;
			for(uint j = 0, jcnt = sys.adjacent.length; j < jcnt; ++j) {
				auto@ r = findSystem(getSystem(sys.adjacent[j]).object);
				if(r !is null && r.planetMask & mask == 0 && !found.contains(r.region.id)) {
					found.insert(r.region.id);
					border.insertLast(r);
				}
			}
		}
		
		return border;
	}
	
	PlanRegion@ getBorderSystem(PlanRegion& region) {
		auto@ sys = region.system;
		uint mask = empire.mask;
		uint off = randomi();
		for(uint i = 0, cnt = sys.adjacent.length; i < cnt; ++i) {
			auto@ r = findSystem(getSystem(sys.adjacent[(off+i) % cnt]).object);
			if(r !is null && r.planetMask & mask == 0)
				return r;
		}
		
		return null;
	}
	
	bool isBorderSystem(PlanRegion& region) {
		auto@ sys = region.system;
		uint mask = empire.mask;
		for(uint i = 0, cnt = sys.adjacent.length; i < cnt; ++i) {
			auto@ r = findSystem(getSystem(sys.adjacent[i]).object);
			if(r !is null && r.planetMask & mask != 0)
				return true;
		}
		
		return false;
	}
	
	vec3d get_aiFocus() {
		return focus;
	}
	
	bool ignoreEmpire(Empire@ emp) const {
		if(emp is null)
			return true;
		auto aiType = emp.getAIType();
		if(behaviorFlags & AIB_IgnorePlayer != 0 && aiType == ET_Player)
			return true;
		else if(behaviorFlags & AIB_IgnoreAI != 0 && aiType != ET_Player)
			return true;
		return false;
	}
	
	PlanetList@ get_planets(uint resourceType) {
		return planetsByResource[resourceType];
	}
	
	void markPlanetIdle(Planet@ pl, bool onlyIfMissing = false) {
		knownPlanets.insert(pl.id);
		int resType = pl.primaryResourceType;
		if(resType < 0)
			return;
		bool wasNew = planetsByResource[resType].markIdle(pl, onlyIfMissing);
		if(wasNew)
			willpower += gotPlanetWill;
	}
	
	void markPlanetUsed(Planet@ pl, Object@ purpose) {
		knownPlanets.insert(pl.id);
		int typeID = pl.primaryResourceType;
		if(typeID < 0)
			return;
		planetsByResource[typeID].markUsed(pl, purpose);
		optimizePlanetImports(pl, getResource(typeID).level);
	}
	
	bool isKnownPlanet(Planet@ pl) {
		return knownPlanets.contains(pl.id);
	}
	
	void optimizePlanetImports(Planet@ pl, uint forLevel) {
		array<Resource> avail;
		avail.syncFrom(pl.getAllResources());
		
		bool needWater = forLevel > 0;
		uint needFood = forLevel;
		uint needLevel1 = 0;
		uint needLevel2 = 0;
		switch(forLevel) {
			case 2:
				needLevel1 = 1;
				break;
			case 3:
				needLevel1 = 2;
				needLevel2 = 1;
				break;
			case 4:
				needLevel1 = 4;
				needLevel2 = 2;
				break;
			case 5:
				needLevel1 = 6;
				needLevel2 = 4;
				break;
		}
		
		auto@ resFood = getResourceList(RT_Food);
		auto@ resWater = getResourceList(RT_Water);
		auto@ resLevelOne = getResourceList(RT_LevelOne);
		auto@ resLevelTwo = getResourceList(RT_LevelTwo);
		
		for(uint i = 0, cnt = avail.length; i < cnt; ++i) {
			auto@ res = avail[i];
			uint rid = res.type.id, rlevel = res.type.level;
			Planet@ source = cast<Planet>(res.origin);
			if(!res.usable || (source !is null && source.owner !is empire))
				continue;

			bool needed = true;
			
			if(rlevel == 0 && resFood.find(rid) >= 0) {
				if(needFood == 0)
					needed = false;
				else
					needFood -= 1;
			}
			else if(rlevel == 0 && resWater.find(rid) >= 0) {
				if(!needWater)
					needed = false;
				else
					needWater = false;
			}
			else if(rlevel == 1 && resLevelOne.find(rid) >= 0) {
				if(needLevel1 == 0)
					needed = false;
				else
					needLevel1 -= 1;
			}
			else if(rlevel == 2 && resLevelTwo.find(rid) >= 0) {
				if(needLevel2 == 0)
					needed = false;
				else
					needLevel2 -= 1;
			}
			
			if(source !is null && source !is pl) {
				if(needed)
					markPlanetUsed(source, pl);
				else {
					markPlanetIdle(source);
					source.exportResource(empire, 0, null);
				}
			}
		}
	}
	
	void usePlanetImports(Planet@ pl, int targetLevel = -1) {
		array<Resource> avail;
		avail.syncFrom(pl.getAllResources());
		
		uint plLevel = targetLevel == -1 ? pl.level : uint(targetLevel);
		
		bool needWater = plLevel > 0;
		uint needFood = plLevel;
		uint needLevel1 = 0;
		uint needLevel2 = 0;
		switch(plLevel) {
			case 2:
				needLevel1 = 1;
				break;
			case 3:
				needLevel1 = 2;
				needLevel2 = 1;
				break;
			case 4:
				needLevel1 = 4;
				needLevel2 = 2;
				break;
			case 5:
				needLevel1 = 6;
				needLevel2 = 4;
				break;
		}
		
		auto@ resFood = getResourceList(RT_Food);
		auto@ resWater = getResourceList(RT_Water);
		auto@ resLevelOne = getResourceList(RT_LevelOne);
		auto@ resLevelTwo = getResourceList(RT_LevelTwo);
		
		for(uint i = 0, cnt = avail.length; i < cnt; ++i) {
			auto@ res = avail[i];
			uint rid = res.type.id, rlevel = res.type.level;
			Planet@ source = cast<Planet>(res.origin);
			if(!res.usable || (source !is null && source.owner !is empire))
				continue;
			
			if(rlevel == 0 && resFood.find(rid) >= 0) {
				if(needFood == 0)
					continue;
				needFood -= 1;
			}
			else if(rlevel == 0 && resWater.find(rid) >= 0) {
				if(!needWater)
					continue;
				needWater = false;
			}
			else if(rlevel == 1 && resLevelOne.find(rid) >= 0) {
				if(needLevel1 == 0)
					continue;
				needLevel1 -= 1;
			}
			else if(rlevel == 2 && resLevelTwo.find(rid) >= 0) {
				if(needLevel2 == 0)
					continue;
				needLevel2 -= 1;
			}
			
			if(source !is null && source !is pl)
				markPlanetUsed(source, pl);
		}
	}
	
	void freePlanetImports(Planet@ pl) {
		array<Resource> avail;
		avail.syncFrom(pl.getAllResources());
		
		for(uint i = 0, cnt = avail.length; i < cnt; ++i) {
			Planet@ source = cast<Planet>(avail[i].origin);
			if(source !is null && source !is pl)
				markPlanetIdle(source);
		}
	}
	
	void addPlanet(Planet@ pl, Object@ purpose = null) {
		if(purpose is null)
			markPlanetIdle(pl, true);
		else
			markPlanetUsed(pl, purpose);
	}
	
	void removePlanet(Planet@ pl) {
		knownPlanets.erase(pl.id);
		int resType = pl.primaryResourceType;
		if(resType < 0)
			return;
		planetsByResource[resType].remove(pl);
	}
	
	uint nextFactoryRes = 0;
	void updateFactories() {
		auto@ list = planetsByResource[nextFactoryRes++ % planetsByResource.length];
		for(uint j = 0; j < 2; ++j) {
			auto@ planets = j == 0 ? list.idle : list.used;
			for(uint i = 0, cnt = planets.length; i < cnt; ++i) {
				Planet@ pl = planets[i];
				if(pl.valid && pl.owner is empire && pl.laborIncome > 0 && !knownFactories.contains(pl.id)) {
					knownFactories.insert(pl.id);
					factories.insertLast(pl);
				}
			}
		}
		
		for(uint i = 0, cnt = orbitals.length; i < cnt; ++i) {
			Orbital@ orb = orbitals[i];
			if(orb.valid && orb.owner is empire && orb.hasConstruction && orb.laborIncome > 0 && !knownFactories.contains(orb.id)) {
				knownFactories.insert(orb.id);
				factories.insertLast(orb);
			}
		}
	}
	
	void validateFactories() {
		for(uint i = 0, cnt = factories.length; i < cnt; ++i) {
			Object@ factory = factories[i];
			if(!factory.valid || !factory.hasConstruction || factory.laborIncome <= 0.000001 || factory.owner !is empire) {
				knownFactories.erase(factory.id);
				if(i + 1 < cnt)
					@factories[i] = factories[cnt-1];
				--cnt;
				factories.length = cnt;
			}
			else {
				++i;
			}
		}
	}
	
	bool factoriesInRegion(Region@ reg) const {
		for(uint i = 0, cnt = factories.length; i < cnt; ++i)
			if(factories[i].region is reg)
				return true;
		return false;
	}
	
	void validateOrbitals() {
		for(uint i = 0, cnt = orbitals.length; i < cnt;) {
			Orbital@ factory = orbitals[i];
			if(!factory.valid || factory.owner !is empire) {
				if(i + 1 < cnt)
					@orbitals[i] = orbitals[cnt-1];
				--cnt;
				orbitals.length = cnt;
			}
			else {
				++i;
			}
		}
	}
	
	PlanRegion@ pickRandomSys(array<PlanRegion@>& systemList) {
		uint sysCount = systemList.length;
		if(sysCount == 0)
			return null;
		else
			return systemList[randomi(0,sysCount-1)];
	}

	void aiPing(Empire@ fromEmpire, vec3d position, uint type) {
		if(empire is fromEmpire || (fromEmpire.team != empire.team && empire.team != -1))
			return;
		if(fromEmpire.SubjugatedBy !is empire || empire.SubjugatedBy !is fromEmpire)
			return;
		
		Request req;
		@req.region = findNearestRegion(position);
		req.time = gameTime;
		
		Lock lock(reqLock);
		queuedRequests.insertLast(req);
	}
	
	void commandAI(string cmd) {
		if(cmd.substr(0,7) == "planet ") {
			string name = cmd.substr(7);
			for(uint i = 0, cnt = planetsByResource.length(); i < cnt; ++i) {
				auto@ list = planetsByResource[i].idle;
				for(uint j = 0, jcnt = list.length; j < jcnt; ++j) {
					if(list[j].name == name) {
						auto@ export = list[j].nativeResourceDestination[0];
						if(export is null)
							error(name + " is idle");
						else
							error(name + " is idle, but exporting to " + export.name);
						return;
					}
				}
				
				@list = planetsByResource[i].used;
				auto@ purpose = planetsByResource[i].purpose;
				for(uint j = 0, jcnt = list.length; j < jcnt; ++j) {
					if(list[j].name == name) {
						auto@ export = list[j].nativeResourceDestination[0];
						if(export is purpose[j])
							error(name + " is used for " + purpose[j].name);
						else
							error(name + " is used for " + purpose[j].name + " but is exporting to " + (export is null ? "nowhere" : export.name));
						return;
					}
				}
			}
			
			error("Could not locate planet");
		}
		else if(cmd == "planets") {
			for(uint i = 0, cnt = planetsByResource.length(); i < cnt; ++i) {
				auto@ list = planetsByResource[i].idle;
				for(uint j = 0, jcnt = list.length; j < jcnt; ++j) {
					auto@ pl = list[j];
					auto@ export = pl.nativeResourceDestination[0];
					if(export is null)
						error(pl.name + " is idle");
					else
						error(pl.name + " is idle, but exporting to " + export.name);
				}
				
				@list = planetsByResource[i].used;
				auto@ purpose = planetsByResource[i].purpose;
				for(uint j = 0, jcnt = list.length; j < jcnt; ++j) {
					auto@ pl = list[j];
					auto@ export = pl.nativeResourceDestination[0];
					if(export is purpose[j])
						error(pl.name + " is used for " + purpose[j].name);
					else
						error(pl.name + " is used for " + purpose[j].name + " but is exporting to " + (export is null ? "nowhere" : export.name));
				}
			}
		}
		else if(cmd == "idle") {
			error("Current idle actions:");
			for(uint i = 0; i < idle.length; ++i) {
				auto@ act = idle[i];
				error(act.hash + ": " + act.state);
			}
		}
		else if(cmd == "artifacts") {
			error("Known artifacts:");
			for(uint i = 0, cnt = artifacts.length; i < cnt; ++i) {
				auto@ type = getArtifactType(i);
				if(artifacts[i] !is null)
					error(" " + type.name);
			}
		}
		else if(cmd == "fleets") {
			for(uint j = 0; j < 3; ++j) {
				FleetType type = FleetType(j);
				if(j == 2)
					type = FT_Mothership;
				auto@ f = fleets[type];
				error("Fleets of type " + j + ":");
				for(uint i = 0, cnt = f.length; i < cnt; ++i) {
					auto@ ship = f[i];
					error("\t" + ship.name + " in " + (ship.region is null ? "empty space" : ship.region.name));
				}
			}
		}
		else if(cmd == "fix war") {
			for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i)
				requestWar(getEmpire(i));
		}
		else if(cmd.substr(0,6) == "scout ") {
			auto@ sys = getSystem(cmd.substr(6));
			if(sys !is null) {
				for(uint i = 0, cnt = ourSystems.length; i < cnt; ++i) {
					if(ourSystems[i].region is sys.object) {
						ourSystems[i].scout(this, verbose=true);
						error("Scouted system");
						break;
					}
				}
			}
			else {
				error("Couldn't find system");
			}
		}
		else if(cmd.substr(0,9) == "artifact ") {
			string id = cmd.substr(9);
			auto@ art = getArtifact(getArtifactType(id));
			if(art !is null)
				error("Found artifact");
			else
				error("Found no artifact");
		}
		else if(cmd.substr(0,9) == "resource ") {
			string id = cmd.substr(9);
			auto@ res = getResource(id);
			if(res is null) {
				error("Invalid resource");
				return;
			}
			
			auto@ list = planetsByResource[res.id].idle;
			for(uint j = 0, jcnt = list.length; j < jcnt; ++j) {
				auto@ pl = list[j];
				auto@ export = pl.nativeResourceDestination[0];
				if(export is null)
					error(pl.name + " is idle");
				else
					error(pl.name + " is idle, but exporting to " + export.name);
			}
			
			@list = planetsByResource[res.id].used;
			auto@ purpose = planetsByResource[res.id].purpose;
			for(uint j = 0, jcnt = list.length; j < jcnt; ++j) {
				auto@ pl = list[j];
				auto@ export = pl.nativeResourceDestination[0];
				if(export is purpose[j])
					error(pl.name + " is used for " + purpose[j].name);
				else
					error(pl.name + " is used for " + purpose[j].name + " but is exporting to " + (export is null ? "nowhere" : export.name));
			}
		}
		else if(cmd.substr(0,5) == "diff ") {
			string newDiff = cmd.substr(5);
			toLowercase(newDiff);
			uint diff = 3;
			if(newDiff == "passive")
				diff = 0;
			else if(newDiff == "easy")
				diff = 1;
			else if(newDiff == "medium")
				diff = 2;
			else if(newDiff == "hard")
				diff = 3;
			else if(newDiff == "murderous")
				diff = 4;
			else if(newDiff == "savage")
				diff = 5;
			else
				diff = toUInt(newDiff);
			
			changeDifficulty(diff);
		}
		else if(cmd == "log war") {
			if(!logWar) {
				makeDirectory(profileRoot + "/war_logs/");
				@log = WriteFile(profileRoot + "/war_logs/" + empire.name + ".txt");
				logWar = true;
			}
		}
		else {
			error("Unknown command");
		}
	}
	
	void debugAI() {
		debug = !debug;
	}
	
	PlanRegion@ markAsColony(Region@ region) {
		for(uint i = 0, cnt = exploredSystems.length; i < cnt; ++i) {
			Region@ reg = exploredSystems[i].region;
			if(reg is region) {
				auto@ pr = exploredSystems[i];
				ourSystems.insertLast(pr);
				exploredSystems.removeAt(i);
				for(uint i = 0, cnt = pr.artifacts.length; i < cnt; ++i)
					logArtifact(pr.artifacts[i]);
				timeSinceLastExpand = 0.0;
				return ourSystems.last;
			}
		}
		
		//Check for duplicates
		for(uint i = 0, cnt = ourSystems.length; i < cnt; ++i) {
			Region@ reg = ourSystems[i].region;
			if(reg is region)
				return ourSystems[i];
		}
		
		PlanRegion@ newRegion = findSystem(region);
		if(newRegion is null) {
			@newRegion = PlanRegion(region);
			systems.set(region.id, @newRegion);
		}
		
		for(uint i = 0, cnt = newRegion.artifacts.length; i < cnt; ++i)
			logArtifact(newRegion.artifacts[i]);
		
		knownSystems.insert(region.id);
		ourSystems.insertLast(newRegion);
		timeSinceLastExpand = 0.0;
		return newRegion;
	}

	PlanRegion@ getPlanRegion(Object@ focus) {
		Region@ area = focus.region;
		if(area is null) {
			@area = cast<Region>(focus);
			if(area is null)
				return null;
		}
		
		PlanRegion@ pr;
		systems.get(area.id, @pr);
		return pr;
	}
	
	bool knownSystem(Region@ region) const {
		return knownSystems.contains(region.id);
	}
	
	PlanRegion@ findSystem(Region@ region) const {
		PlanRegion@ pr;
		systems.get(region.id, @pr);
		return pr;
	}
	
	PlanRegion@ addExploredSystem(Region@ focus) {
		PlanRegion@ region = PlanRegion(focus);
		exploredSystems.insertLast(region);
		systems.set(focus.id, @region);
		knownSystems.insert(focus.id);
		return region;
	}
	
	void addExploredSystem(PlanRegion@ region) {
		exploredSystems.insertLast(region);
		systems.set(region.region.id, @region);
		knownSystems.insert(region.region.id);
	}
	
	uint nextVision = randomi(0,10000);
	void updateRandomVision() {
		for(uint i = 0; i < 5; ++i) {
			Region@ region = getSystem(nextVision++ % systemCount).object;
			if(region.VisionMask & empire.visionMask != 0) {
				auto@ plan = findSystem(region);
				if(plan is null)
					@plan = addExploredSystem(region);
				plan.scout(this);
				break;
			}
			else if(region.SeenMask & empire.mask != 0) {
				//We may have gained memory of the planets through various means
				auto@ plan = findSystem(region);
				if(plan is null) {
					@plan = PlanRegion(region);
					systems.set(region.id, @plan);
				}
				
				if(plan.useMemory(this) && !knownSystem(region))
					addExploredSystem(plan);
				break;
			}
		}
	}
	
	array<Ship@>@ get_fleets(FleetType type) {
		if(type == FT_Scout)
			return scoutFleets;
		else if(type == FT_Mothership)
			return motherships;
		else
			return combatFleets;
	}
	
	uint get_fleetTypeCount() const {
		return 3;
	}
	
	void freeFleet(Ship@ leader, FleetType type) {
		if(leader !is null && leader.valid && leader.owner is empire)
			fleets[type].insertLast(leader);
	}
	
	void removeInvalidFleets() {
		for(uint f = 0, fCnt = fleetTypeCount; f < fCnt; ++f) {
			array<Ship@>@ Fleets = fleets[FleetType(f)];
			for(int i = int(Fleets.length) - 1; i >= 0; --i) {
				Ship@ leader = Fleets[i];
				if(!leader.valid || leader.owner !is empire) {
					Fleets.removeAt(i);
					knownLeaders.erase(leader.id);
				}
			}
		}
	}
	
	Ship@ getAvailableFleet(FleetType type, bool build = true) {
		array<Ship@>@ Fleets = fleets[type];
		
		if(Fleets.length != 0) {
			Ship@ leader = Fleets.last;
			Fleets.removeLast();
			
			if(leader.valid && leader.owner is empire)			
				return leader;
			else
				return getAvailableFleet(type);
		}
		else {
			if(build)
				requestFleetBuild(type);
			return null;
		}
	}
	
	void logArtifact(Artifact@ artifact) {
		int type = artifact.ArtifactType;
		if(type >= 0 && artifacts[type] is null)
			@artifacts[type] = artifact;
	}
	
	Artifact@ getArtifact(const ArtifactType@ Type, Region@ availableTo = null) {
		if(Type is null)
			return null;

		Artifact@ artifact = artifacts[Type.id];
		if(artifact !is null && (!artifact.valid || artifact.region is null)) {
			@artifacts[Type.id] = null;
			@artifact = null;
		}
		
		if(artifact is null && ourSystems.length != 0) {
			SysSearch search;
			for(uint i = 0; i < 8; ++i) {
				auto@ region = ourSystems[randomi(0,ourSystems.length-1)];
				for(uint j = 0, cnt = region.artifacts.length; j < cnt; ++j) {
					if(region.artifacts[j].ArtifactType == int(Type.id)) {
						@artifact = region.artifacts[j];
						break;
					}
				}
			}
			
			@artifacts[Type.id] = artifact;
		}
		
		if(artifact !is null) {
			Region@ from = artifact.region;
			Territory@ fromTerr = from !is null ? from.getTerritory(empire) : null;
			if(fromTerr is null) {
				@artifacts[Type.id] = null;
				return null;
			}
			
			if(availableTo !is null && availableTo.getTerritory(empire) !is fromTerr)
				return null;
		}
		
		return artifact;
	}
	
	bool performAction(Action@ act) {
		if(act is null) {
			error("BasicAI Error: Unexpected null action.");
			::debug();
			return true;
		}
	
		//TODO: This leaks a reference? (if exist is not null)
		Action@ exist;
		if(actions.get(act.hash, @exist))
			@act = exist;
		if(act !is null) {
			if(debug) {
				dbgMsg += "\n ";
				for(int i = printDepth; i > 0; --i)
					dbgMsg += " ";
				dbgMsg += act.state;
			}
			++printDepth;
			
			if(printDepth >= 25) {
				error("AI Recursed too deep.");
				::debug();
				actions.delete(act.hash);
				removeIdle(act);
				return true;
			}
			
			double t = 0.0;
			if(profile)
				t = getExactTime();
		
			if(act.perform(this)) {
				--printDepth;
				if(profile && debug) {
					double e = getExactTime();
					dbgMsg += "\n ";
					for(int i = printDepth; i > 0; --i)
						dbgMsg += " ";
					dbgMsg += "Took " + int((e-t) * 1.0e6) + " us";
				}
				
				actions.delete(act.hash);
				removeIdle(act);
				return true;
			}
			else {
				--printDepth;
				if(profile && debug) {
					double e = getExactTime();
					dbgMsg += "\n ";
					for(int i = printDepth; i > 0; --i)
						dbgMsg += " ";
					dbgMsg += "Took " + int((e-t) * 1.0e6) + " us";
				}
				
				actions.set(act.hash, @act);
				return false;
			}
		}
		else {
			return true;
		}
	}
	
	Action@ locateAction(int64 hash) {
		Action@ act;
		actions.get(hash, @act);
		return act;
	}
	
	void insertAction(Action@ act) {
		actions.set(act.hash, @act);
	}
	
	Action@ performKnownAction(Action@ act) {
		if(act is null)
			return null;
		
		if(debug) {
			dbgMsg += "\n ";
			for(int i = printDepth; i > 0; --i)
				dbgMsg += " ";
			dbgMsg += act.state;
		}
		++printDepth;
		
		if(printDepth >= 25) {
			error("AI Recursed too deep.");
			::debug();
			actions.delete(act.hash);
			removeIdle(act);
			return null;
		}
			
		double t = 0.0;
		if(profile)
			t = getExactTime();
		
		if(act.perform(this)) {
			--printDepth;
			if(profile && debug) {
				double e = getExactTime();
				dbgMsg += "\n ";
				for(int i = printDepth; i > 0; --i)
					dbgMsg += " ";
				dbgMsg += "Took " + int((e-t) * 1.0e6) + " us";
			}
			
			actions.delete(act.hash);
			removeIdle(act);
			return null;
		}
		else {
			--printDepth;
			if(profile && debug) {
				double e = getExactTime();
				dbgMsg += "\n ";
				for(int i = printDepth; i > 0; --i)
					dbgMsg += " ";
				dbgMsg += "Took " + int((e-t) * 1.0e6) + " us";
			}
			actions.set(act.hash, @act);
			return act;
		}
	}
	
	const Design@ getDesign(DesignType type, uint task, bool create = true) {
		if(type == DT_Flagship && task == FST_Mothership) {
			return empire.getDesign("Mothership");
		}
	
		if(create) {
			Action@ act = locateAction( designHash(type, task) );
			if(act is null)
				@act = MakeDesign(type, task);
			performKnownAction( act );
		}
		
		switch(type) {
			case DT_Support:
				if(task < ST_COUNT)
					return dsgSupports[task];
				break;
			case DT_Flagship:
				if(task < FST_COUNT)
					return dsgFlagships[task];
				break;
			case DT_Station:
				if(task < STT_COUNT)
					return dsgStations[task];
				break;
		}
		return null;
	}
	
	bool fillFleet(Object@ fleet, int maxSpend = -1) {
		if(!fleet.hasLeaderAI)
			return true;
		uint supports = fleet.SupplyAvailable;
		if(supports == 0)
			return true;
		fleet.clearAllGhosts();
		
		//Can't afford anything, probably not any time soon either
		if(empire.RemainingBudget < -250 && empire.TotalBudget < -150)
			return true;
			
		const Design@ hvy, lit, tnk, fill;
		@hvy = getDesign(DT_Support, ST_AntiFlagship);
		if(hvy is null)
			@hvy = empire.getDesign("Heavy Gunship");
		@lit = getDesign(DT_Support, ST_AntiSupport);
		if(lit is null)
			@lit = empire.getDesign("Beamship");
		@tnk = getDesign(DT_Support, ST_Tank);
		if(tnk is null)
			@tnk = empire.getDesign("Missile Boat");
		@fill = getDesign(DT_Support, ST_Filler);
		if(fill is null)
			@fill = empire.getDesign("Gunship");
		
		uint heavy = (supports / 3) / uint(hvy.size);
		uint light = (supports / 2) / uint(lit.size);
		uint tank = (supports / 7) / uint(tnk.size);
		uint filler = (supports - (heavy * uint(hvy.size) + light * uint(lit.size) + tank * uint(tnk.size))) / uint(fill.size);
		
		if(heavy + light + tank + filler == 0)
			return true;
		
		if(maxSpend >= 0) {
			int cost = hvy.total(HV_BuildCost);
			if(cost < maxSpend) {
				heavy = min(heavy, uint(maxSpend/cost));
				maxSpend -= int(heavy * cost);
			}
			
			cost = lit.total(HV_BuildCost);
			if(cost < maxSpend) {
				light = min(light, uint(maxSpend/cost));
				maxSpend -= int(light * cost);
			}
			
			cost = tnk.total(HV_BuildCost);
			if(cost < maxSpend) {
				tank = min(tank, uint(maxSpend/cost));
				maxSpend -= int(tank * cost);
			}
			
			cost = fill.total(HV_BuildCost);
			if(cost < maxSpend) {
				filler = min(filler, uint(maxSpend/cost));
				maxSpend -= int(filler * cost);
			}
		}
		
		if(heavy > 0)
			fleet.orderSupports(hvy, heavy);
		if(light > 0)
			fleet.orderSupports(lit, light);
		if(tank > 0)
			fleet.orderSupports(tnk, tank);
		if(filler > 0)
			fleet.orderSupports(fill, filler);
		return false;
	}
	
	Action@ requestFleetBuild(FleetType type) {
		Action@ act = locateAction( buildFleetHash(type) );
		if(act is null)
			@act = BuildFleet(type);
		return performKnownAction( act );
	}
	
	Action@ requestOrbital(Region& where, OrbitalType type) {
		Action@ act = locateAction( buildOrbitalHash(where, type) );
		if(act is null)
			@act = BuildOrbital(where, type);
		return performKnownAction( act );
	}
	
	Action@ requestCombatAt(Object@ system) {
		Action@ act = locateAction( buildCombatHash(system.id) );
		if(act is null)
			@act = Combat(system);
		return performKnownAction( act );
	}
	
	Action@ requestWar(Empire@ target) {
		Action@ act = locateAction( buildWarHash(target) );
		if(act is null)
			@act = War(target);
		return performKnownAction( act );
	}
	
	Action@ requestImport(Planet@ pl, array<int>@ resources, bool execute = true) {
		Action@ act = locateAction( importResHash(pl, resources) );
		if(act is null)
			@act = ImportResource( pl, resources);
		if(execute)
			return performKnownAction( act );
		else {
			insertAction( act );
			return act;
		}
	}
	
	Action@ requestPlanetImprovement(Planet@ pl, uint toLevel) {
		Action@ act = locateAction( improvePlanetHash(pl, toLevel) );
		if(act is null)
			@act = ImprovePlanet( pl, toLevel);
		return performKnownAction( act );
	}
	
	Action@ requestBuilding(Planet& pl, const BuildingType& type) {
		Action@ act = locateAction( buildBuildingHash(pl, type) );
		if(act is null)
			@act = BuildBuilding( pl, type);
		return performKnownAction( act );
	}
	
	Action@ colonizeByResource(array<int>@ resources, ObjectReceiver@ inform = null, bool execute = true) {
		Action@ act = locateAction( colonyByResHash(resources) );
		if(act is null)
			@act = ColonizeByResource( resources, inform );
		if(execute)
			return performKnownAction( act );
		else {
			insertAction( act );
			return act;
		}
	}
	
	Action@ requestColony(Planet@ pl, bool execute = true) {
		Action@ act = locateAction( colonyHash(pl) );
		if(act is null)
			@act = Colonize(this, pl);
		if(execute)
			return performKnownAction( act );
		else {
			insertAction( act );
			return act;
		}
	}
	
	Action@ requestPopulate(Planet@ pl, bool execute = true) {
		Action@ act = locateAction( populateHash(pl) );
		if(act is null)
			@act = Populate(this, pl);
		if(execute)
			return performKnownAction( act );
		else {
			insertAction( act );
			return act;
		}
	}
	
	Action@ requestExpansion() {
		Action@ act = locateAction( expandHash() );
		if(act is null)
			@act = Expand();
		return performKnownAction( act );
	}
	
	Action@ requestExploration() {
		Action@ act = locateAction( exploreHash() );
		if(act is null)
			@act = Explore();
		return performKnownAction( act );
	}
	
	Action@ requestDefense() {
		Action@ act = locateAction( defendHash() );
		if(act is null)
			@act = Defend();
		return performKnownAction( act );
	}
	
	Action@ requestBudget() {
		Action@ act = locateAction( budgetHash() );
		if(act is null)
			@act = GatherBudget();
		return performKnownAction( act );
	}
	
	void removeIdle(Action& act) {
		if(idles.contains(act.hash)) {
			idles.erase(act.hash);
			//if(idle.find(@act) < 0)
			//	::debug();
			idle.remove(@act);
		}
	}
	
	void addIdle(Action@ act) {
		if(act is null)
			return;
		
		if(!idles.contains(act.hash)) {
			idle.insertLast(@act);
			idles.insert(act.hash);
			if(debug)
				error("Adding idle action: " + act.state);
		}
		//else if(idle.find(@act) < 0) {
		//	::debug();
		//}
	}
	
	void addNewIdle(Action& act) {
		insertAction(act);
		addIdle(act);
	}
	
	void changeDifficulty(uint level) {
		int prevCheatedResources = cheatLevel;
		cheatLevel = 0;
		
		cheatFlags = 0;
		behaviorFlags = 0;
		
		if(level > 5)
			level = 5;
	
		switch(level) {
			case 0: //Passive
				skillEconomy = DIFF_Easy;
				skillCombat = DIFF_Trivial;
				skillDiplo = DIFF_Easy;
				skillTech = DIFF_Easy;
				skillScout = DIFF_Easy;
				behaviorFlags = AIB_IgnorePlayer | AIB_IgnoreAI;
				break;
			case 1: //Easy
				skillEconomy = DIFF_Easy;
				skillCombat = DIFF_Easy;
				skillDiplo = DIFF_Easy;
				skillTech = DIFF_Easy;
				skillScout = DIFF_Easy;
				break;
			case 2: //Medium
				skillEconomy = DIFF_Medium;
				skillCombat = DIFF_Medium;
				skillDiplo = DIFF_Medium;
				skillTech = DIFF_Medium;
				skillScout = DIFF_Medium;
				break;
			case 3: //Hard
				skillEconomy = DIFF_Hard;
				skillCombat = DIFF_Hard;
				skillDiplo = DIFF_Hard;
				skillTech = DIFF_Hard;
				skillScout = DIFF_Hard;
				break;
			case 4: //Murderous
				skillEconomy = DIFF_Hard;
				skillCombat = DIFF_Hard;
				skillDiplo = DIFF_Hard;
				skillTech = DIFF_Hard;
				skillScout = DIFF_Hard;
				behaviorFlags = AIB_IgnoreAI | AIB_QuickToWar;
				break;
			case 5: //Savage
				skillEconomy = DIFF_Max;
				skillCombat = DIFF_Max;
				skillDiplo = DIFF_Max;
				skillTech = DIFF_Max;
				skillScout = DIFF_Max;
				behaviorFlags = AIB_IgnoreAI | AIB_QuickToWar;
				cheatFlags = AIC_Vision | AIC_Resources;
				cheatLevel = 10;
				break;
		}
		
		if(cheatFlags & AIC_Vision != 0)
			empire.visionMask = ~0;
		else
			empire.visionMask = empire.mask;
		
		if(cheatLevel != prevCheatedResources) {
			double factor = double(cheatLevel - prevCheatedResources);
			double tiles = double(cheatLevel - prevCheatedResources) * 3.0;
			
			empire.modFTLCapacity(125.0 * factor);
			empire.modFTLIncome(0.5 * factor);
			empire.modEnergyIncome(TILE_ENERGY_RATE * tiles);
			empire.modTotalBudget(int(TILE_MONEY_RATE * tiles));
			empire.modResearchRate(TILE_RESEARCH_RATE * tiles);
		}
	}

	void init(Empire& emp, EmpireSettings& settings) {
		@empire = emp;
		buildCommonLists();
		
		changeDifficulty(settings.difficulty);
	}
	
	void init(Empire& emp) {
		@empire = emp;
		buildCommonLists();
		addNewIdle(ExpendResources());
		
		Planet@ hw = emp.Homeworld;
		if(hw !is null && hw.valid && hw.owner is emp) {
			@homeworld = hw;
			addPlanet(hw, hw);
		}
		
		if(hw !is null)
			focus = hw.position;
		
		if(head is null) {
			@head = MilitaryVictory();
			insertAction(head);
		}
	
		uint objects = emp.objectCount;
		for(uint i = 0; i < objects; ++i) {
			Object@ obj = emp.objects[i];
			
			switch(obj.type) {
				case OT_Planet: {
					Planet@ pl = cast<Planet>(obj);
					markAsColony(pl.region).scout(this);
					
					if(homeworld is null) {
						@homeworld = pl;
						addPlanet(pl, pl);
					}
				} break;
				case OT_Ship: {
					Ship@ ship = cast<Ship>(obj);
					if(ship.hasLeaderAI) {
						uint type = classifyDesign(this, ship.blueprint.design);
						if(type != FT_INVALID) {
							freeFleet(ship, FleetType(type));
							if(type == FT_Mothership)
								factories.insertLast(ship);
						}
					}
				} break;
			}
		}
	}

	void save(SaveFile& msg) {
		msg << empire;
		msg << homeworld;
		
		msg << willpower;
		
		msg << skillEconomy;
		msg << skillCombat;
		msg << skillDiplo;
		msg << skillTech;
		msg << skillScout;
		
		msg << behaviorFlags;
		msg << cheatFlags;
		msg << cheatLevel;
		
		msg << timeSinceLastExpand;
		
		msg << nextNotification;

		//System registry
		uint cnt = ourSystems.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			ourSystems[i].save(msg);

		cnt = exploredSystems.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			exploredSystems[i].save(msg);
		
		//Planet registry
		for(uint i = 0; i < planetsByResource.length; ++i)
			planetsByResource[i].save(msg);
		
		//Orbital registry
		cnt = orbitals.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << orbitals[i];
		
		//Artifact registry
		{
			Artifact@ artifact = null;
			for(uint i = 0; i < artifacts.length; ++i) {
				@artifact = artifacts[i];
				if(artifact !is null)
					msg << artifact;
			}
			
			@artifact = null;
			msg << artifact;
		}

		//Fleet registry
		cnt = scoutFleets.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << scoutFleets[i];

		cnt = combatFleets.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << combatFleets[i];

		cnt = motherships.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << motherships[i];

		cnt = untrackedFleets.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << untrackedFleets[i];
			
		//Design types
		for(uint i = 0; i < ST_COUNT; ++i)
			msg << dsgSupports[i];
		for(uint i = 0; i < FST_COUNT; ++i)
			msg << dsgFlagships[i];
		for(uint i = 0; i < STT_COUNT; ++i)
			msg << dsgStations[i];
		
		//Revenant parts (owned by others)
		cnt = revenantParts.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << revenantParts[i];
		
		//Treaty responses
		cnt = queuedTreatyJoin.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << queuedTreatyJoin[i];
			
		cnt = queuedTreatyDecline.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << queuedTreatyDecline[i];

		//Actions
		map_iterator it = actions.iterator();

		int64 hash = 0;
		Action@ act;

		msg << actions.getSize();
		while(it.iterate(hash, @act)) {
			msg << hash;
			msg << uint(act.actionType);
			act.save(this, msg);
		}

		msg << head.hash;
		
		cnt = idle.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << idle[i].hash;

		msg << thoughtCycle;
		msg << diplomacyTick;
	}

	void load(SaveFile& msg) {
		msg >> empire;
		msg >> homeworld;
		
		buildCommonLists();
		
		if(msg >= SV_0063)
			msg >> willpower;
		
		msg >> skillEconomy;
		msg >> skillCombat;
		msg >> skillDiplo;
		msg >> skillTech;
		msg >> skillScout;
		
		if(msg >= SV_0046) {
			msg >> behaviorFlags;
			msg >> cheatFlags;
			msg >> cheatLevel;
		}
		
		if(msg >= SV_0079)
			msg >> timeSinceLastExpand;
		
		if(msg >= SV_0016)
			msg >> nextNotification;

		//System registry
		uint cnt = 0;
		msg >> cnt;
		ourSystems.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			PlanRegion@ reg = PlanRegion(msg); 
			@ourSystems[i] = reg;
			systems.set(reg.region.id, @reg);
			knownSystems.insert(reg.region.id);
		}

		msg >> cnt;
		exploredSystems.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			PlanRegion@ reg = PlanRegion(msg); 
			@exploredSystems[i] = reg;
			systems.set(reg.region.id, @reg);
			knownSystems.insert(reg.region.id);
		}
		
		//Planet registry
		for(uint i = 0, cnt = msg.getPrevIdentifierCount(SI_Resource); i < cnt; ++i) {
			uint newIndex = msg.getIdentifier(SI_Resource, i);
			if(newIndex < planetsByResource.length) {
				planetsByResource[newIndex].load(this, msg);
			}
			else {
				PlanetList list;
				list.load(this, msg);
			}
		}
		
		//Orbital registry
		if(msg >= SV_0051) {
			msg >> cnt;
			orbitals.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> orbitals[i];
		}
		
		//Artifact registry
		if(msg >= SV_0036) {
			Artifact@ artifact;
			msg >> artifact;
			while(artifact !is null) {
				logArtifact(artifact);
				msg >> artifact;
			}
		}

		//Fleet registry
		msg >> cnt;
		scoutFleets.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			msg >> scoutFleets[i];

		msg >> cnt;
		combatFleets.length = cnt;
		for(uint i = 0; i < cnt; ++i)
			msg >> combatFleets[i];
		
		if(msg >= SV_0114) {
			msg >> cnt;
			motherships.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> motherships[i];
		}
		
		if(msg >= SV_0016) {
			msg >> cnt;
			untrackedFleets.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> untrackedFleets[i];
		}
		
		//Design types
		if(msg >= SV_0081) {
			for(uint i = 0; i < ST_COUNT; ++i)
				msg >> dsgSupports[i];
			uint count = (msg >= SV_0119 ? FST_COUNT : FST_COUNT_OLD1);
			for(uint i = 0; i < count; ++i)
				msg >> dsgFlagships[i];
			for(uint i = 0; i < STT_COUNT; ++i)
				msg >> dsgStations[i];
		}
		
		//Revenant parts (owned by others)
		if(msg >= SV_0087) {
			msg >> cnt;
			revenantParts.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> revenantParts[i];
		}
		
		//Treaty responses
		if(msg >= SV_0100) {
			msg >> cnt;
			queuedTreatyJoin.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> queuedTreatyJoin[i];
				
			msg >> cnt;
			queuedTreatyDecline.length = cnt;
			for(uint i = 0; i < cnt; ++i)
				msg >> queuedTreatyDecline[i];
		}

		//Actions
		int64 hash = 0;
		Action@ act;

		msg >> cnt;
		for(uint i = 0; i < cnt; ++i) {
			msg >> hash;
			uint type = 0;
			msg >> type;

			switch(type) {
				case ACT_Colonize:
					@act = Colonize(this, msg);
				break;
				case ACT_ColonizeRes:
					@act = ColonizeByResource(this, msg);
				break;
				case ACT_Explore:
					@act = Explore(this, msg);
				break;
				case ACT_Build:
					@act = BuildFleet(this, msg);
				break;
				case ACT_Trade:
					@act = ImportResource(this, msg);
				break;
				case ACT_Improve:
					@act = ImprovePlanet(this, msg);
				break;
				case ACT_Budget:
					@act = GatherBudget(this, msg);
				break;
				case ACT_Expend:
					@act = ExpendResources(this, msg);
				break;
				case ACT_Combat:
					@act = Combat(this, msg);
				break;
				case ACT_War:
					@act = War(this, msg);
				break;
				case ACT_Defend:
					@act = Defend(this, msg);
				break;
				case ACT_Expand:
					@act = Expand(this, msg);
				break;
				case ACT_Building:
					@act = BuildBuilding(this, msg);
				break;
				case ACT_BuildOrbital:
					@act = BuildOrbital(this, msg);
				break;
				case ACT_Design:
					@act = MakeDesign(this, msg);
				break;
				case ACT_Populate:
					@act = Populate(this, msg);
				break;
				case STRAT_Military:
					@act = MilitaryVictory(this, msg);
				break;
				case STRAT_Influence:
					@act = InfluenceVictory(this, msg);
				break;
			}

			if(act !is null) {
				//Hashes may need to change.
				//When they do, the AI may forget some things it was doing,
				// but that is preferable to other issues that may arise (e.g. freezes)
				if(act.hash == hash)
					actions.set(hash, @act);
			}
			else {
				error("Could not find action: " + uint64(hash) + " (" + (hash >> ACT_BIT_OFFSET) + ")");
			}
		}

		map_iterator it = actions.iterator();
		while(it.iterate(hash, @act))
			act.postLoad(this);

		int64 headHash = 0;
		msg >> headHash;
		@head = locateAction(headHash);
		if(head is null) {
			error("Couldn't find head: " + uint64(headHash));
			@head = MilitaryVictory();
			insertAction(head);
		}
		
		if(msg < SV_0021) {
			addNewIdle(ExpendResources());
		}
		else {
			msg >> cnt;
			int64 h = 0;
			
			for(uint i = 0; i < cnt; ++i) {
				msg >> h;
				Action@ act = locateAction(h);
				if(act !is null) {
					idle.insertLast(act);
					idles.insert(h);
				}
				else {
					error("Couldn't locate idle action: " + uint64(h));
				}
			}
		}

		msg >> thoughtCycle;
		msg >> diplomacyTick;
	}
	
	double diplomacyTick = 0.0;
	
	void validatePlanets() {
		WaitForSafeCalls wait(false);
		int resourceID = randomi(0, planetsByResource.length - 1);
		PlanetList@ list = planetsByResource[resourceID];
		
		for(uint i = 0; i < 3 && list.used.length + list.idle.length == 0; ++i) {
			resourceID = randomi(0, planetsByResource.length - 1);
			@list = planetsByResource[resourceID];
		}
		
		list.validate(this, empire, getResource(resourceID));
	}
	
	//Make sure we still own systems marked as ours
	void validateSystems() {
		if(ourSystems.length == 0)
			return;
		
		uint index = randomi(0, ourSystems.length-1);
		PlanRegion@ region = ourSystems[index];
		for(uint i = 0, cnt = region.planets.length; i < cnt; ++i)
			if(region.planets[i].owner is empire)
				return;
		
		ourSystems.removeAt(index);
		exploredSystems.insertLast(region);
	}
	
	array<int> queuedTreatyJoin, queuedTreatyDecline;
	double nextConsideration = gameTime + randomd(8.0, 22.0);
	bool checkJoin = true;
	
	void processTreatyQueue() {
		if(queuedTreatyJoin.length + queuedTreatyDecline.length == 0) {
			nextConsideration = gameTime + randomd(6.0, 16.0);
		}
		else if(gameTime > nextConsideration) {
			nextConsideration = gameTime + randomd(2.0, 8.0);
			checkJoin = !checkJoin;
			
			if(queuedTreatyJoin.length > 0 && checkJoin) {
				uint index = randomi(0, queuedTreatyJoin.length-1);
				joinTreaty(empire, queuedTreatyJoin[index]);
				queuedTreatyJoin.removeAt(index);
			}
			else if(queuedTreatyDecline.length > 0) {
				uint index = randomi(0, queuedTreatyDecline.length-1);
				declineTreaty(empire, queuedTreatyDecline[index]);
				queuedTreatyDecline.removeAt(index);
			}
		}
	}
	
	array<Notification@> notices;
	void getNotifications() {
		uint latest = empire.notificationCount;
		if(latest == nextNotification)
			return;
		receiveNotifications(notices, empire.getNotifications(20, nextNotification, false));
		nextNotification = latest;
		
		for(uint i = 0, cnt = notices.length; i < cnt; ++i) {
			auto@ notice = notices[i];
			switch(notice.type) {
				case NT_FlagshipBuilt:
					{
						Ship@ ship = cast<Ship>(notice.relatedObject);
						if(ship !is null && ship.owner is empire && !knownLeaders.contains(ship.id)) {
							knownLeaders.insert(ship.id);
							untrackedFleets.insertLast(ship);
						}
					} break;
				case NT_StructureBuilt:
					{
						Planet@ pl = cast<Planet>(notice.relatedObject);
						if(pl !is null && pl.owner is empire)
							optimizePlanetImports(pl, pl.nativeResourceDestination[0] is null ? min(pl.level+1, 4) : max(pl.resourceLevel, getResource(pl.primaryResourceType).level));
					} break;
				case NT_TreatyEvent:
					{
						TreatyEventNotification@ evt = cast<TreatyEventNotification>(notice);
						if(evt.eventType == TET_Invite) {
							double t = treatyWaits[evt.empOne.index];
							if(gameTime < t) {
								queuedTreatyDecline.insertLast(evt.treaty.id);
								break;
							}
							
							treatyWaits[evt.empOne.index] = gameTime + randomd(120.0,240.0);
						}
							
						if(evt.treaty.leader !is null) {
							//Ignore constant requests
							
							if(evt.eventType == TET_Invite && evt.treaty.hasClause("SubjugateClause")) {
								//Get the approximate point ratio. We add a small value to both points to reduce the noise of very small point values
								float pointRatio = float(evt.empOne.points.value + 200) / float(empire.points.value + 200);
								float reqRatio = (empire.isHostile(evt.empOne) && evt.empOne.MilitaryStrength > empire.MilitaryStrength) ? 3.f : 4.f;
								reqRatio *= pow(0.5f, -willpower / float(empire.TotalPlanets.value + 1));
								
								if(pointRatio > reqRatio)
									queuedTreatyJoin.insertLast(evt.treaty.id);
								else
									queuedTreatyDecline.insertLast(evt.treaty.id);
								break;
							}
						}
						else {
							if(evt.eventType == TET_Invite && evt.treaty.hasClause("SubjugateClause")) {
								//Someone wants to surrender, accept
								queuedTreatyJoin.insertLast(evt.treaty.id);
								break;
							}
						}
						
						if(evt.eventType == TET_Invite) {
							bool defense = evt.treaty.hasClause("MutualDefenseClause");
							//bool trade = evt.treaty.hasClause("TradeClause");
							bool vision = evt.treaty.hasClause("VisionClause");
							bool alliance = evt.treaty.hasClause("AllianceClause");
							
							double basis = -1.0;
							if(alliance && enemies.length > 0)
								basis += double(enemies.length);
							if(defense)
								basis += double(evt.empOne.MilitaryStrength - empire.MilitaryStrength);
							if(evt.empOne.isHostile(empire))
								basis -= 1.0;
							
							double chance = 0.5; pow(0.5, -basis);
							if(basis > 0)
								chance = 1.0 - pow(chance, 1.0 + basis);
							else if(basis < 0)
								chance = pow(chance, 1.0 - basis);
							
							if((defense || alliance) && behaviorFlags & AIB_QuickToWar != 0)
								chance = 0.0;
							
							if(randomd() < chance)
								queuedTreatyJoin.insertLast(evt.treaty.id);
							else
								queuedTreatyDecline.insertLast(evt.treaty.id);
						}
					} break;
				case NT_Generic:
					{
						GenericNotification@ evt = cast<GenericNotification>(notice);
						if(evt.obj.isOrbital) {
							//Check to see if this is a revenant part
							Orbital@ part = cast<Orbital>(evt.obj);
							int core = part.coreModule;
							if(	core == getOrbitalModuleID("RevenantCore") ||
								core == getOrbitalModuleID("RevenantCannon") ||
								core == getOrbitalModuleID("RevenantChassis") ||
								core == getOrbitalModuleID("RevenantEngine") )
							{
								revenantParts.insertLast(part);
							}
						}
					} break;
			}
		}
		
		notices.length = 0;
	}

	void tick(Empire& emp, double time) {
		//Copy queued requests over, so we can access them quickly, and remove old requests
		for(int i = requests.length - 1; i >= 0; --i)
			if(requests[i].time < gameTime - 600.0)
				requests.removeAt(i);
		if(queuedRequests.length > 0) {
			Lock lock(reqLock);
			for(uint i = 0, cnt = queuedRequests.length; i < cnt; ++i)
				requests.insertLast(queuedRequests[i]);
			if(requests.length > 0 && protect is null)
				@protect = getPlanRegion(requests[0].region);
		}
		while(requests.length > 5)
			requests.removeAt(0);
	
		timeSinceLastExpand += time * gameSpeed;
		didTickScan = false;
	
		profile = profile_ai.value > 0.0;
		double start = getExactTime();
	
		diplomacyTick += time;
		if(diplomacyTick >= 2.0) {
			//Ticks happen at real time, so we compensate to make it behave similarly at all game speeds
			willpower *= pow(willDecayPerBudget,diplomacyTick * gameSpeed/180.0);
			diplomacyTick = 0.0;
		}
		
		getNotifications();
		removeInvalidFleets();
		validatePlanets();
		validateSystems();
		validateOrbitals();
		validateFactories();
		updateFactories();
		processTreatyQueue();
		for(int i = revenantParts.length-1; i >= 0; --i)
			if(revenantParts[i] is null || !revenantParts[i].valid)
				revenantParts.removeAt(i);
		
		//Check for new fleets that may have been given to us
		uint empFleets = empire.fleetCount;
		{
			if(empFleets > 0) {
				auto@ fleet = cast<Ship>(empire.fleets[randomi(0, empFleets-1)]);
				if(fleet !is null && fleet.valid && fleet.owner is empire && !knownLeaders.contains(fleet.id)) {
					knownLeaders.insert(fleet.id);
					auto@ design = fleet.blueprint.design;
					if(design is null || design.owner is empire) {
						untrackedFleets.insertLast(fleet);
					}
					else {
						uint type = classifyDesign(this, design);
						if(type != FT_INVALID)
							freeFleet(fleet, FleetType(type));
					}
				}
			}
		}
		
		if(ourSystems.length == 0 && !(usesMotherships && empFleets > 0))
			return;
		
		double validateEnd = getExactTime();
		
		
		//Print depth is used both for debugging and tracking infinite recursion
		printDepth = 0;
		if(debug || profile)
			dbgMsg = empire.name + " {";
		
		if(validateEnd - start < maxAIFrame) {
			switch(thoughtCycle) {
				case 0:
					if(idle.length > 0) {
						performAction(idle[randomi(0, idle.length-1)]);
						break;
					}
				case 1:
					//Improve homeworld to level 4, then begin importing level 3 resources
					if(performAction(head)) {
						int[] l3res;
						for(uint i = 0, cnt = getResourceCount(); i < cnt; ++i) {
							const ResourceType@ type = getResource(i);
							if(type.level >= 3 && type.exportable)
								l3res.insertLast(type.id);
						}
						@head = ImportResource(homeworld, l3res);
					}
					break;
			}
		
			thoughtCycle = (thoughtCycle + 1) % 2;
		}
		
		double actionEnd = getExactTime();
		
		if(!didTickScan && actionEnd - start < maxAIFrame)
			updateRandomVision();
		
		if(profile) {
			double end = getExactTime();
			dbgMsg += format("\n\tTook $1us to validate, $2us to process, $3us for vision", toString((validateEnd-start) * 1.0e6, 1), toString((actionEnd-validateEnd) * 1.0e6 , 1), toString((end-actionEnd) * 1.0e6 , 1));
		}
		
		if(debug || profile) {
			dbgMsg += "\n}";
			print(dbgMsg);
		}
	}

	void pause(Empire& emp) {
	}

	void resume(Empire& emp) {
	}
};

AIController@ createBasicAI() {
	return BasicAI();
}

import resources;
import artifacts;
import int getOrbitalModuleID(const string&) from "orbitals";

//TODO: This doesn't represent the import request well
//		Relies on how a given planet will tend to request imports
int64 importResHash(Planet@ pl, array<int>@ res) {
	int64 Hash = (int64(ACT_Trade) << ACT_BIT_OFFSET) | int64(pl.id);
	Hash |= int64(res[0]) << 32;
	Hash |= int64(res.length) << 48;
	return Hash;
}

class ImportResource : Action {
	Planet@ dest, source;
	uint nextType = 0;
	int foundRes = -1;
	int[]@ resources;
	bool attemptExpand = false;
	int64 Hash;
	const ResourceType@ water = getResource("Water");
	
	ImportResource(Planet@ to, int[]@ Resources) {
		@dest = to;
		@resources = Resources;
		
		Hash = importResHash(to, Resources);
	}

	ImportResource(BasicAI@ ai, SaveFile& msg) {
		msg >> dest >> source;
		msg >> foundRes >> attemptExpand >> nextType;

		uint cnt = 0;
		msg >> cnt;
		@resources = array<int>(cnt);
		for(uint i = 0; i < cnt; ++i)
			resources[i] = msg.readIdentifier(SI_Resource);
		
		Hash = importResHash(dest, resources);
	}
	
	~ImportResource() {
		if(source !is null)
			error("ImportResource ended without proper resolution");
	}

	void postLoad(BasicAI@ ai) {
	}

	void save(BasicAI@ ai, SaveFile& msg) {
		msg << dest << source;
		msg << foundRes << attemptExpand << nextType;

		uint cnt = resources.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg.writeIdentifier(SI_Resource, resources[i]);
	}
	
	int64 get_hash() const {
		return Hash;
	}

	ActionType get_actionType() const {
		return ACT_Trade;
	}
	
	string get_state() const {
		if(source is null)
			return format("Looking for $1 (+$2 others) for $3", getResource(resources[0]).name, resources.length-1, dest.name);
		else
			return format("Importing $1 from  $2 to $3", getResource(foundRes).name, source.name, dest.name);
	}
	
	void clear(BasicAI@ ai) {
		if(source !is null) {
			ai.markPlanetIdle(source);
			@source = null;
		}
		ai.removeIdle(this);
	}
	
	bool hasWater(BasicAI@ ai) {
		if(ai.planets[water.id].idle.length == 0 && ai.skillEconomy >= DIFF_Medium) {
			auto@ hydro = getBuildingType("Hydrogenator");
			if((ai.usesMotherships ||ai.empire.RemainingBudget < hydro.baseBuildCost) || gameTime < 3.0 * 60.0) {
				const auto@ comet = getArtifactType("Comet");
				if(ai.empire.EnergyStored < comet.abilities[0].energyCost || ai.getArtifact(comet, dest.region) is null) {
					return false;
				}
			}
		}
		return true;
	}
	
	bool hasFood(BasicAI@ ai) {
		const ResourceClass@ cls = getResourceClass("Food");
		for(uint i = 0, cnt = cls.types.length; i < cnt; ++i)
			if(ai.planets[cls.types[i].id].idle.length != 0)
				return true;
		
		if(!ai.usesMotherships && gameTime > 3.0 * 60.0) {
			auto@ farm = getBuildingType("Farm");
			if(ai.empire.RemainingBudget >= farm.baseBuildCost)
				return true;
		}
		
		return false;
	}
	
	bool canLevelPlanet(BasicAI@ ai) const {
		return hasWater(ai) && hasFood(ai);
	}
	
	Planet@ findViablePlanet(BasicAI@ ai) {
		uint tryCount = 1;
		if(ai.skillEconomy >= DIFF_Hard)
			tryCount = resources.length;
		else if(ai.skillEconomy >= DIFF_Medium)
			tryCount = min(2, resources.length);
		
		uint checkType = randomi(0, resources.length-1);
		Empire@ owner = ai.empire;
		
		auto@ reg = dest.region;
		auto@ destTerr = reg !is null ? dest.region.getTerritory(owner) : null;
		if(destTerr is null)
			return null;
		
		//Look through a few resources for idle planets of the resources we need
		for(uint tries = 0; tries < tryCount; ++tries) {
			uint resID = resources[checkType % resources.length];
			PlanetList@ planets = ai.planets[resID];
			
			const ResourceType@ type = getResource(resID);
		
			uint cnt = planets.idle.length;
			for(uint i = 0; i < cnt; ++i) {
				Planet@ pl = planets.idle[i];
				if(pl.owner !is owner || !pl.valid)
					continue;
				auto@ r = pl.region;
				if(r is null || r.getTerritory(owner) !is destTerr)
					continue;
				
				uint plLevel = pl.level;
				if(pl.level < type.level)
					continue;
				
				return pl;
			}
			
			checkType += 1;
			if(cnt != 0)
				break;
		}
		
		return null;
	}
	
	bool perform(BasicAI@ ai) {
		if(source !is null) {
			uint resLevel = getResource(foundRes).level;
			if(source.owner !is ai.empire) {
				foundRes = -1;
				@source = null;
				ai.removeIdle(this);
			}
			else if(source.resourceLevel >= resLevel) {			
				//Attempt to export
				if(source is dest) {
					//When the homeworld moves, it can end up using its own resource - this looks a bit weird but works for this purpose
					source.exportResource(0, null);
					ai.markPlanetUsed(source, source);
					@source = null;
					return true;
				}
				else {
					source.exportResource(0, dest);
					source.wait();
					if(!source.isPrimaryDestination(dest)) {
						ai.markPlanetIdle(source);
						@source = null;
						foundRes = -1;
						ai.removeIdle(this);
					}
					else {
						ai.markPlanetUsed(source, dest);
						@source = null;
						return true;
					}
				}
			}
			else {
				//See if any other planets are available instead
				Planet@ other = findViablePlanet(ai);
				if(other !is null) {
					ai.markPlanetIdle(source);
					@source = other;
					foundRes = other.primaryResourceType;
					ai.markPlanetUsed(source, source);
				}
				else if(source.population >= 1.0) {
					//Request the planet be upgraded
					ai.requestPlanetImprovement(source, resLevel);
				}
			}
		}
		else {
			//Already found the resource and ordered the export
			if(foundRes != -1)
				return true;
		
			if(nextType >= resources.length)
				attemptExpand = true;
			
			Empire@ owner = ai.empire;
			Territory@ destTerr = null;
			{
				auto@ reg = dest.region;
				if(reg !is null)
					@destTerr = reg.getTerritory(owner);
				if(destTerr is null)
					return true;
			}
			
			Planet@ farMatch;
			
			Planet@ best = null;
			double bestScore = 0;
			uint resID;
			
			bool tryBuildWater = false, tryBuildFood = false;
			
			int aiHasBaseNeeds = -1;
			
			uint tryCount = 1;
			if(ai.skillEconomy >= DIFF_Hard)
				tryCount = resources.length;
			else if(ai.skillEconomy >= DIFF_Medium)
				tryCount = min(2, resources.length);
				
			ai.focus = dest.position;
			
			//Look through a few resources for idle planets of the resources we need
			for(uint tries = 0; tries < tryCount; ++tries) {
				resID = resources[nextType % resources.length];
				if(resID == water.id) {
					const auto@ comet = getArtifactType("Comet");
					if(owner.EnergyStored >= comet.abilities[0].energyCost) {
						auto@ artifact = ai.getArtifact(comet, dest.region);
						if(artifact !is null) {
							artifact.activateAbilityFor(owner, 0, dest);
							dest.wait();
							return true;
						}
					}
					
					if(!ai.usesMotherships && ai.skillEconomy >= DIFF_Medium && gameTime > 3.0 * 60.0 && ai.empire.RemainingBudget >= 300)
						tryBuildWater = true;
				}
				
				PlanetList@ planets = ai.planets[resID];
				
				const ResourceType@ type = getResource(resID);
			
				uint cnt = planets.idle.length;
				for(uint i = 0; i < cnt; ++i) {
					Planet@ pl = planets.idle[i];
					if(pl.owner !is owner || !pl.valid)
						continue;
					auto@ reg = pl.region;
					if(reg is null)
						continue;
					if(reg.getTerritory(owner) !is destTerr) {
						@farMatch = pl;
						continue;
					}
					
					uint plLevel = pl.level;
					if(type.level > 0 && plLevel == 0 && aiHasBaseNeeds == 0)
						continue;
					
					double score = 1.0;
					if(plLevel >= type.level)
						score = 2.0;
					else if(pl.resourceLevel >= type.level)
						score = 1.5;
					
					if(score > bestScore) {
						@best = pl;
						bestScore = score;
					}
				}
				
				//Check that the AI has enough spare planets to bother aquiring the planet
				//	Only check for Medium or harder AI early in the game
				//	TODO: Skip check based on colonization capacity, rather than a time heuristic
				if(type.level >= 1 && gameTime < 30.0 * 60.0 && ai.skillEconomy >= DIFF_Medium) {
					if(aiHasBaseNeeds == -1)
						aiHasBaseNeeds = canLevelPlanet(ai) ? 1 : 0;
				}
				else if(type.level == 0 && ai.skillEconomy >= DIFF_Medium && (best is null || cnt <= 2) && gameTime > 3.0 * 60.0 && type.cls is getResourceClass("Food")) {
					if(!ai.usesMotherships && ai.empire.RemainingBudget >= 300)
						tryBuildFood = true;
				}
				else if(resID == water.id && best !is null && cnt > 2) {
					tryBuildWater = false;
				}
				
				nextType += 1;
				if(cnt != 0)
					break;
			}
			
			if(best !is null) {
				foundRes = resID;
				@source = best;
				ai.markPlanetUsed(source, source);
				ai.addIdle(this);
				//We found a useful planet.
				//Hard AIs will go on to try to use their free money to build up food and water
				if(ai.skillEconomy < DIFF_Hard)
					return false;
			}
			else if(farMatch !is null) {
				//TODO: Request the connection of two territories
			}
			
			if(tryBuildFood) {
				ai.requestBuilding(dest, getBuildingType("Farm"));
				if(source is null)
					return true;
			}
			else if(tryBuildWater) {
				ai.requestBuilding(dest, getBuildingType("Hydrogenator"));
				if(source is null)
					return true;
			}
			else if(attemptExpand && source is null && aiHasBaseNeeds != 0) {
				//Request colonization of planet with a resource we need
				ai.colonizeByResource(resources);
			}
			else if(aiHasBaseNeeds == 0) {
				if(!hasWater(ai))
					ai.addIdle(ai.colonizeByResource(ai.getResourceList(RT_Water, onlyExportable=true), execute=false));
				if(!hasFood(ai))
					ai.addIdle(ai.colonizeByResource(ai.getResourceList(RT_Food, onlyExportable=true), execute=false));
			}
		}
		return false;
	}
}

int64 buildBuildingHash(Planet@ pl, const BuildingType@ bldg) {
	return (int64(ACT_Building) << ACT_BIT_OFFSET) | (int64(bldg.id) << 32) | int64(pl.id);
}

class BuildBuilding : Action {
	Planet@ planet;
	const BuildingType@ type;
	int64 Hash;
	uint tries = 0;
	vec2i inProgress = vec2i(-1,-1);
	
	BuildBuilding(Planet@ pl, const BuildingType@ bldg) {
		@planet = pl;
		@type = bldg;
		Hash = buildBuildingHash(pl, bldg);
	}
	
	int64 get_hash() const {
		return Hash;
	}

	ActionType get_actionType() const {
		return ACT_Building;
	}
	
	string get_state() const {
		return "Building " + type.name + " on " + planet.name;
	}
	
	BuildBuilding(BasicAI@ ai, SaveFile& msg) {
		uint typeID = 0;
		msg >> planet >> typeID >> inProgress;
		@type = getBuildingType(typeID);
		Hash = buildBuildingHash(planet, type);
	}

	void postLoad(BasicAI@ ai) {
	}

	void save(BasicAI@ ai, SaveFile& msg) {
		msg << planet << type.id << inProgress;
	}
	
	bool perform(BasicAI@ ai) {
		if(planet is null || !planet.valid || planet.owner !is ai.empire)
			return true;
		if(ai.usesMotherships)
			return true;
		
		ai.focus = planet.position;
		
		if(inProgress.x >= 0) {
			int at = planet.getBuildingAt(inProgress.x, inProgress.y);
			if(at != int(type.id)) {
				//error(type.name + " on " + planet.name + " expected at " + inProgress + " got " + at);
				inProgress = vec2i(-1,-1);
			}
			else if(planet.getBuildingProgressAt(inProgress.x, inProgress.y) >= 0.999f) {
				@planet = null;
				return true;
			}
			else {
				//Await completion
				return false;
			}
		}
		
		if(ai.empire.RemainingBudget < type.baseBuildCost)
			return true;
		
		//Try to plop it on a random tile
		if(tries++ < 20) {
			vec2i off = vec2i(type.getCenter());
		
			bool validPos = true;
			vec2i pos = vec2i(randomi(0,10), randomi(0,8));
			for(int x = pos.x, endx = pos.x + type.size.width; x < endx; ++x) {
				for(int y = pos.y, endy = pos.y + type.size.height; y < endy; ++y) {
					if(x < 0 || y < 0) {
						validPos = false;
						break;
					}
				
					int bType = planet.getBuildingAt(x - off.x,y - off.y);
					if(bType >= 0) {
						auto@ b = getBuildingType(bType);
						if(b !is null && !b.civilian) {
							validPos = false;
							break;
						}
					}
				}
				
				if(!validPos)
					break;
			}
			
			if(validPos) {
				planet.buildBuilding(type.id, pos);
				planet.wait();
				inProgress = pos;
			}
			
			return false;
		}
		else {
			return true;
		}
	}
}

int64 improvePlanetHash(Planet@ pl, uint toLevel) {
	return (int64(ACT_Improve) << ACT_BIT_OFFSET) | (int64(toLevel) << 48) | int64(pl.id);
}

class ImprovePlanet : Action {
	Planet@ planet;
	uint level = 1;
	bool requested = false;
	int64 Hash;
	Action@[] requests;
	int64[]@ reqHashes;
	uint lastResState = 0xffffffff;
	
	ImprovePlanet(Planet@ pl, uint toLevel) {
		@planet = pl;
		level = toLevel;
		Hash = improvePlanetHash(pl, toLevel);
	}

	ImprovePlanet(BasicAI@ ai, SaveFile& msg) {
		msg >> planet >> level;
		msg >> requested >> Hash;

		uint cnt = 0;
		msg >> cnt;
		@reqHashes = int64[](cnt);
		for(uint i = 0; i < cnt; ++i)
			msg >> reqHashes[i];
	}

	void postLoad(BasicAI@ ai) {
		for(uint i = 0, cnt = reqHashes.length; i < cnt; ++i) {
			Action@ act = ai.locateAction(reqHashes[i]);
			if(act !is null)
				requests.insertLast(act);
		}
		@reqHashes = null;
	}

	void save(BasicAI@ ai, SaveFile& msg) {
		msg << planet << level;
		msg << requested << Hash;

		uint cnt = requests.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i)
			msg << requests[i].hash;
	}
	
	int64 get_hash() const {
		return Hash;
	}

	ActionType get_actionType() const {
		return ACT_Improve;
	}
	
	string get_state() const {
		return "Improving " + planet.name + " to level " + level;
	}
	
	bool hasFoods(array<Resource>& avail, uint count) {
		if(count == 0)
			return true;
	
		const ResourceClass@ cls = getResourceClass("Food");
		uint levelCount = count;
		
		for(uint i = 0, cnt = avail.length; i < cnt; ++i) {
			auto@ type = avail[i].type;
			if(type.cls is cls)
				if(--count == 0)
					return true;
		}
		
		return false;
	}
	
	bool hasRequirement(array<Resource>& avail, uint level, uint count) {
		if(count == 0)
			return true;
		
		uint levelCount = count;
		
		for(uint i = 0, cnt = avail.length; i < cnt; ++i) {
			auto@ type = avail[i].type;
			if(type.level == level)
				if(--count == 0)
					return true;
		}
		
		return false;
	}
	
	bool perform(BasicAI@ ai) {
		//TODO: Doesn't this leak into the action map?
		// Looks like it should be killing the actions in requests
		// if it exits prematurely from here.
		if(!planet.valid || planet.owner !is ai.empire)
			return true;
		
		if(ai.usesMotherships && planet.Population < double(planet.maxPopulation)) {
			ai.requestPopulate(planet);
			return false;
		}
		
		uint plLevel = planet.resourceLevel;
		if(plLevel >= level)
			return true;
		
		ai.focus = planet.position;
			
		if(requests.length > 0 && lastResState == planet.resourceModID) {
			int index = randomi(0, int(requests.length)-1);
			if(ai.performAction(requests[index]))
				requests.length = 0;
		}
		else {
			lastResState = planet.resourceModID;
			//We only check against the needs for the next level, not our ultimate goal
			uint goingTo = plLevel + 1;
			requests.length = 0;
			
			auto@ reg = planet.region;
			auto@ destTerr = reg is null ? null : reg.getTerritory(ai.empire);
		
			array<Resource> avail;
			avail.syncFrom(planet.getAllResources());
			
			//Remove all resources that aren't usable or won't be soon
			for(int i = int(avail.length) - 1; i > 0; --i) {
				auto@ res = avail[i];
				if(!res.usable) {
					auto@ src = res.origin;
					auto@ srcReg = src.region;
					if(src !is planet && (src.owner !is ai.empire || srcReg is null || srcReg.getTerritory(ai.empire) !is destTerr || (src.isPlanet && src.resourceLevel < res.type.level))) {
						Planet@ source = cast<Planet>(src);
						if(source !is null) {
							source.exportResource(ai.empire, 0, null);
							ai.markPlanetIdle(source);
						}
						avail.removeAt(i);
					}
				}
			}
		
			//Look for all the resources we still need, and queue up a series of requests that can be completed simultaneously	
			bool needWater = true;
			array<int>@ waterNeed = ai.getResourceList(RT_Water);
			for(uint i = 0, cnt = avail.length; i < cnt; ++i) {
				if(waterNeed.find(avail[i].type.id) > 0) {
					needWater = false;
					break;
				}
			}
			
			if(goingTo > 2) {
				uint need = 0;
				switch(goingTo) {
					case 3: need = 1; break;
					case 4: need = 2; break;
					case 5: need = 4; break;
				}
				
				if(!hasRequirement(avail, 2, need)) {
					requests.insertLast(ai.requestImport(planet, ai.getResourceList(RT_LevelTwo, true), execute=false));
					return false;
				}
			}
			
			bool requestLowerResources = gameTime > 15.0 * 60.0;
			
			if(goingTo > 1) {
				uint need = 0;
				switch(goingTo) {
					case 2: need = 1;
					case 3: need = 2; break;
					case 4: need = 4; break;
					case 5: need = 6; break;
				}
				
				if(!hasRequirement(avail, 1, need)) {
					requests.insertLast(ai.requestImport(planet, ai.getResourceList(RT_LevelOne, true), execute=false));
					if(!requestLowerResources)
						return false;
				}
			}
			
			if(needWater)
				requests.insertLast(ai.requestImport(planet, ai.getResourceList(RT_Water, true), execute=false));
			
			if(!hasFoods(avail, goingTo))
				requests.insertLast(ai.requestImport(planet, ai.getResourceList(RT_Food, true), execute=false));
		}
		return false;
	}
}

int64 budgetHash() {
	return int64(ACT_Budget) << ACT_BIT_OFFSET;
}

class GatherBudget : Action {
	Planet@ hw;
	
	GatherBudget() {
	}

	GatherBudget(BasicAI@ ai, SaveFile& msg) {
		if(msg < SV_0024) {
			int64 dummy = 0;
			msg >> dummy;
		}
		if(msg >= SV_0114) {
			msg >> hw;
		}
	}

	void postLoad(BasicAI@ ai) {
	}

	void save(BasicAI@ ai, SaveFile& msg) {
		msg << hw;
	}
	
	int64 get_hash() const {
		return budgetHash();
	}

	ActionType get_actionType() const {
		return ACT_Budget;
	}
	
	string get_state() const {
		return "Increasing available budget";
	}
	
	Planet@ getHomeworld(BasicAI@ ai) {
		Planet@ hw = ai.homeworld;
		if(hw !is null && hw.owner is ai.empire && hw.valid)
			return hw;
		
		for(int t = 3; t >= 0; --t) {
			AIResourceType type;
			switch(t) {
				case 3: type = RT_LevelThree; break;
				case 2: type = RT_LevelTwo; break;
				case 1: type = RT_LevelOne; break;
				case 0: type = RT_Food; break;
			}
			auto@ resources = ai.getResourceList(type, onlyExportable = false);
			
			uint base = randomi(0, 250);
			for(uint r = 0, rcnt = resources.length; r < rcnt; ++r) {
				auto@ planets = ai.planets[resources[(r+base) % rcnt]].idle;
				for(uint i = 0, cnt = planets.length; i < cnt; ++i) {
					auto@ pl = planets[i];
					if(pl.valid && pl.owner is ai.empire)
						return pl;
				}
			}
		}
		
		return null;
	}
	
	bool perform(BasicAI@ ai) {
		if(hw is null)
			@hw = getHomeworld(ai);
	
		if(hw !is null) {
			uint plLevel = hw.level;
			if(plLevel < 5) {
				ai.requestPlanetImprovement(hw, plLevel+1);
			}
			else {	
				ai.requestImport(hw, ai.getResourceList(RT_LevelThree, true));
			}
		}
		else {
			ai.colonizeByResource(ai.getResourceList(RT_LevelOne, onlyExportable = false));
		}
		
		return false;
	}
}

enum OrbitalType {
	OT_Shipyard = 0,
	OT_TradeOutpost = 1
};

int64 buildOrbitalHash(Region@ at, OrbitalType type) {
	return (int64(ACT_BuildOrbital) << ACT_BIT_OFFSET) | (int64(type) << 32) | at.id;
}

class BuildOrbital : Action {
	uint type;
	Region@ sys;
	Object@ builder;
	int64 Hash;
	
	BuildOrbital(Region& at, OrbitalType Type) {
		type = Type;
		@sys = at;
		Hash = buildOrbitalHash(sys, Type);
	}

	BuildOrbital(BasicAI@ ai, SaveFile& msg) {
		msg >> type;
		msg >> sys;
		msg >> builder;
		Hash = buildOrbitalHash(sys, OrbitalType(type));
	}

	void postLoad(BasicAI@ ai) {
	}

	void save(BasicAI@ ai, SaveFile& msg) {
		msg << type;
		msg << sys;
		msg << builder;
	}
	
	int64 get_hash() const {
		return Hash;
	}

	ActionType get_actionType() const {
		return ACT_BuildOrbital;
	}
	
	string get_state() const {
		if(builder is null)
			return "Planning orbital construction in " + sys.name;
		else
			return "Building Orbital in " + sys.name;
	}
	
	bool isTradeable(Region@ region, Empire@ emp, const Territory@ territory) {
		if(territory is region.getTerritory(emp))
			return true;
	
		const SystemDesc@ system = getSystem(region);
		for(uint i = 0, cnt = system.adjacent.length; i < cnt; ++i) {
			Region@ other = getSystem(system.adjacent[i]).object;
			if(territory is other.getTerritory(emp))
				return true;
		}
		
		return false;
	}
	
	bool perform(BasicAI@ ai) {
		if(builder !is null) {
			//Look for the orbital
			auto@ reg = ai.findSystem(sys);
			if(reg is null)
				return true;
			
			reg.scout(ai);
			for(uint i = 0, cnt = reg.orbitals.length; i < cnt; ++i) {
				auto@ orb = reg.orbitals[i];
				if(orb.owner is ai.empire && ai.orbitals.find(orb) < 0) {
					ai.orbitals.insertLast(reg.orbitals[i]);
					return true;
				}
			}
			
			if(!builder.valid || builder.owner !is ai.empire || builder.constructionCount == 0)
				@builder = null;
		}
		else {			
			for(uint i = 0, cnt = ai.factories.length; i < cnt; ++i) {
				Object@ buildAt = ai.factories[i];

				if(buildAt.owner is ai.empire && buildAt.hasConstruction && buildAt.canBuildOrbitals &&
					buildAt.constructionCount == 0 && buildAt.laborIncome > 0.05)
				{
					auto@ reg = buildAt.region;
					if(reg is null || !isTradeable(sys, ai.empire, reg.getTerritory(ai.empire)))
						continue;
				
					int orbID = -1;
					switch(type) {
						case OT_Shipyard:
							orbID = getOrbitalModuleID("Shipyard");
							break;
						case OT_TradeOutpost:
							orbID = getOrbitalModuleID("TradeOutpost");
							break;
					}
					
					if(orbID < 0)
						return true;
					
					vec2d off = random2d(200.0, sys.radius - 200.0);
					
					buildAt.buildOrbital(orbID, sys.position + vec3d(off.x, 0.0, off.y));
					@builder = buildAt;
					break;
				}
			}
		}
	
		return false;
	}
}

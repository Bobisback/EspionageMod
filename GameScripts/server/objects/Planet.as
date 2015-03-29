import object_creation;
import regions.regions;
import planet_types;
import saving;
import util.target_search;
from objects.Asteroid import createAsteroid;

final class MoonData {
	uint style = 0;
	float size = 0.f;
};

final class PlanetScript {
	float timer = 0.f;
	float bonusSupply = 0.0;
	float bonusPop = 0.0;
	bool hpDelta = false;
	uint ringStyle = 0;
	array<MoonData@>@ moons;
	
	void init(Planet& planet) {
		timer = -float(uint8(planet.id)) / 255.0;
		planet.owner.recordStatDelta(stat::Planets, 1);
		planet.canBuildShips = true;
		planet.canBuildOrbitals = true;
		planet.leaderInit();
	}

	void postInit(Planet& planet) {
		if(planet.owner !is null) {
			planet.owner.TotalPlanets += 1;
			planet.owner.registerPlanet(planet);
		}
	}

	void save(Planet& planet, SaveFile& file) {
		saveObjectStates(planet, file);
		file << cast<Savable>(planet.Orbit);
		file << cast<Savable>(planet.Construction);
		file << cast<Savable>(planet.SurfaceComponent);
		file << cast<Savable>(planet.Resources);
		file << cast<Savable>(planet.LeaderAI);
		file << cast<Savable>(planet.Statuses);
		file << planet.ResearchRate;
		file << planet.OrbitSize;
		file << planet.Population;
		file << planet.renamed;
		file << bonusSupply << bonusPop;
		file << planet.Health << planet.MaxHealth;
		file << ringStyle;
		file.writeIdentifier(SI_PlanetType, planet.PlanetType);

		file << planet.hasAbilities;
		if(planet.hasAbilities)
			file << cast<Savable>(planet.Abilities);

		if(moons !is null && moons.length != 0) {
			file.write1();
			file << moons.length;
			for(uint i = 0, cnt = moons.length; i < cnt; ++i) {
				file << moons[i].size;
				file << moons[i].style;
			}
		}
		else {
			file.write0();
		}
	}
	
	void load(Planet& planet, SaveFile& file) {
		timer = -float(uint8(planet.id)) / 255.0;
		loadObjectStates(planet, file);
		file >> cast<Savable>(planet.Orbit);
		file >> cast<Savable>(planet.Construction);
		file >> cast<Savable>(planet.SurfaceComponent);
		file >> cast<Savable>(planet.Resources);
		file >> cast<Savable>(planet.LeaderAI);
		file >> cast<Savable>(planet.Statuses);
		file >> planet.ResearchRate;
		file >> planet.OrbitSize;
		file >> planet.Population;
		file >> planet.renamed;
		file >> bonusSupply >> bonusPop;
		if(file >= SV_0083) {
			if(file >= SV_0102) {
				file >> planet.Health >> planet.MaxHealth;
			}
			else {
				float hp = 0, maxhp = 0;
				file >> hp >> maxhp;
				planet.Health = hp;
				planet.MaxHealth = maxhp;
			}
		}
		if(file >= SV_0086)
			file >> ringStyle;
		planet.PlanetType = file.readIdentifier(SI_PlanetType);

		if(planet.PlanetType == -1)
			planet.PlanetType = 0;

		bool hasAbl = false;
		file >> hasAbl;
		if(hasAbl) {
			planet.activateAbilities();
			file >> cast<Savable>(planet.Abilities);
		}

		PlanetNode@ plNode = cast<PlanetNode>(bindNode(planet, "PlanetNode"));
		plNode.planetType = planet.PlanetType;
		plNode.colonized = planet.owner.valid;
		if(ringStyle != 0)
			plNode.addRing(ringStyle);

		if(file >= SV_0110) {
			if(file.readBit()) {
				if(moons is null)
					@moons = array<MoonData@>();

				uint cnt = 0;
				file >> cnt;
				moons.length = cnt;
				for(uint i = 0; i < cnt; ++i) {
					MoonData dat;
					file >> dat.size;
					file >> dat.style;
					@moons[i] = dat;

					if(plNode !is null)
						plNode.addMoon(dat.size, dat.style);
				}
			}
		}
	}

	void postLoad(Planet& planet) {
		planet.resourcesPostLoad();
		planet.surfacePostLoad();
		planet.leaderPostLoad();
		
		Node@ node = planet.getNode();
		if(node !is null)
			node.hintParentObject(planet.region, false);
	}

	bool quietDestruction = false;
	void destroyQuiet(Planet& planet) {
		quietDestruction = true;
		planet.destroy();
	}
	
	void destroy(Planet& planet) {
		if(!game_ending && !quietDestruction) {
			playParticleSystem("PlanetExplosion", planet.position, planet.rotation, planet.radius, planet.visibleMask);

			for(uint i = 0, cnt = randomi(0,4); i < cnt; ++i) {
				vec3d pos = planet.position;
				pos += random3d(80 + planet.radius);

				Asteroid@ roid = createAsteroid(pos);
				Region@ reg = planet.region;
				if(reg !is null) {
					roid.orbitAround(reg.position);
					roid.orbitSpin(randomd(20.0, 60.0));
				}
				do {
					const ResourceType@ type = getDistributedAsteroidResource();
					if(roid.getAvailableCostFor(type.id) < 0.0)
						roid.addAvailable(type.id, type.asteroidCost);
				}
				while(randomd() < 0.4);
			}
		}
	
		if(planet.owner !is null) {
			planet.owner.recordStatDelta(stat::Planets, -1);
			planet.owner.TotalPlanets -= 1;
			planet.owner.unregisterPlanet(planet);
		}
		planet.destroyConstruction();
		planet.destroyObjResources();
		planet.destroySurface();
		planet.leaderDestroy();
		planet.destroyStatus();
		leaveRegion(planet);
	}

	bool onOwnerChange(Planet& planet, Empire@ prevOwner) {
		if(prevOwner !is null) {
			prevOwner.recordStatDelta(stat::Planets, -1);
			prevOwner.TotalPlanets -= 1;
			prevOwner.unregisterPlanet(planet);
		}
		if(planet.owner !is null) {
			planet.owner.recordStatDelta(stat::Planets, 1);
			planet.owner.TotalPlanets += 1;
			planet.owner.registerPlanet(planet);
		}
		planet.clearRally();
		if(planet.hasAbilities)
			planet.abilityOwnerChange(prevOwner, planet.owner);
		planet.changeSurfaceOwner(prevOwner);
		planet.changeResourceOwner(prevOwner);
		planet.changeStatusOwner(prevOwner, planet.owner);
		regionOwnerChange(planet, prevOwner);
		planet.leaderChangeOwner(prevOwner, planet.owner);

		if(!planet.hasMover && planet.owner.hasFlingBeacons) {
			planet.activateMover();
			planet.maxAcceleration = 0;
		}
		
		cast<PlanetNode>(planet.getNode()).colonized = planet.owner.valid;
		return false;
	}

	void occasional_tick(Planet& obj) {
		Region@ region = obj.region;
		bool engaged = obj.engaged;
		obj.inCombat = engaged;
		obj.engaged = false;

		if(engaged && region !is null)
			region.EngagedMask |= obj.owner.mask;

		float newSupply = obj.owner.PlanetSupplyMod;
		if(newSupply != bonusSupply) {
			obj.modSupplyCapacity(newSupply - bonusSupply);
			bonusSupply = newSupply;
		}

		float newPop = 0.f;
		uint lev = obj.level;
		if(lev == 2)
			newPop += obj.owner.PopulationLevel2Mod;
		else if(lev >= 3)
			newPop += obj.owner.PopulationLevel3Mod;
		if(int(newPop) != int(bonusPop)) {
			obj.modMaxPopulation(int(newPop) - int(bonusPop));
			bonusPop = newPop;
		}

		if(!obj.hasMover && obj.owner.hasFlingBeacons) {
			obj.activateMover();
			obj.maxAcceleration = 0;
		}

		//Order support ships to attack
		if(engaged) {
			if(obj.supportCount > 0) {
				Object@ target = findEnemy(obj, obj, obj.owner, obj.position, 700.0);
				if(target !is null) {
					//Always target the fleet as a whole
					{
						Ship@ othership = cast<Ship>(target);
						if(othership !is null) {
							Object@ leader = othership.Leader;
							if(leader !is null)
								@target = leader;
						}
					}
					
					//Order a random support to assist
					uint cnt = obj.supportCount;
					if(cnt > 0) {
						uint attackWith = max(1, cnt / 8);
						for(uint i = 0, off = randomi(0,cnt-1); i < attackWith; ++i) {
							Object@ sup = obj.supportShip[(i+off) % cnt];
							if(sup !is null)
								sup.supportAttack(target);
						}
					}
				}
			}
		}
		
		obj.updateFleetStrength();
	}

	double tick(Planet& planet, double time) {
		//Update region
		Region@ prevRegion = planet.region;
		if(updateRegion(planet)) {
			Node@ node = planet.getNode();
			if(node !is null)
				node.hintParentObject(planet.region, false);
			planet.changeResourceRegion(prevRegion, planet.region);
			planet.changeSurfaceRegion(prevRegion, planet.region);
			planet.changeStatusRegion(prevRegion, planet.region);
			@prevRegion = planet.region;
		}

		//Take vision from region
		if(prevRegion !is null)
			planet.donatedVision |= prevRegion.DonateVisionMask;
		else
			planet.donatedVision |= ~0;

		//Tick components
		if(planet.hasMover) {
			planet.moverTick(time);

			if(prevRegion is null && isOutsideUniverseExtents(planet.position))
				limitToUniverseExtents(planet.position);
		}
		else
			planet.orbitTick(time);
		planet.leaderTick(time);
		planet.orderTick(time);
		planet.statusTick(time);

		if(planet.hasAbilities)
			planet.abilityTick(time);

		//Tick occasional stuff
		timer += float(time);
		if(timer >= 0.9f) {
			occasional_tick(planet);
			planet.surfaceTick(timer);
			planet.resourceTick(timer);
			timer = 0.f;
		}
		
		//Update biome population
		planet.Population = planet.population;

		Empire@ owner = planet.owner;
		if(owner !is null && owner.valid) {
			planet.constructionTick(time);
			if(planet.hasConstructionUnder(0.2))
				return 0.0;
			else
				return 0.2;
		}
		else {
			return 0.2;
		}
	}

	void syncInitial(const Planet& planet, Message& msg) {
		msg << float(planet.Health);
		msg << float(planet.MaxHealth);
		msg.writeSmall(planet.PlanetType);
		msg << planet.renamed;
		planet.writeResources(msg);
		planet.writeSurface(msg);
		planet.writeOrbit(msg);
		planet.writeLeaderAI(msg);
		planet.writeStatuses(msg);

		msg.writeBit(planet.hasAbilities);
		if(planet.hasAbilities)
			planet.writeAbilities(msg);
		
		msg.writeBit(ringStyle != 0);
		if(ringStyle != 0)
			msg << ringStyle;

		if(planet.hasMover) {
			msg.write1();
			planet.writeMover(msg);
		}
		else {
			msg.write0();
		}

		if(moons !is null && moons.length != 0) {
			msg.write1();
			msg.writeSmall(moons.length);
			for(uint i = 0, cnt = moons.length; i < cnt; ++i) {
				msg << moons[i].size;
				msg << moons[i].style;
			}
		}
		else {
			msg.write0();
		}
	}

	bool syncDelta(const Planet& planet, Message& msg) {
		bool used = false;
		if(planet.writeResourceDelta(msg))
			used = true;
		else
			msg.write0();

		if(planet.writeSurfaceDelta(msg))
			used = true;
		else
			msg.write0();

		if(planet.writeConstructionDelta(msg))
			used = true;
		else
			msg.write0();

		if(planet.writeLeaderAIDelta(msg))
			used = true;
		else
			msg.write0();

		if(planet.hasAbilities && planet.writeAbilityDelta(msg))
			used = true;
		else
			msg.write0();

		if(planet.writeStatusDelta(msg))
			used = true;
		else
			msg.write0();

		if(hpDelta) {
			used = true;
			hpDelta = false;
			msg.write1();
			msg << float(planet.Health);
			msg << float(planet.MaxHealth);
		}
		else
			msg.write0();

		if(planet.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();

		if(planet.writeOrbitDelta(msg))
			used = true;
		else
			msg.write0();

		return used;
	}

	void syncDetailed(const Planet& planet, Message& msg) {
		msg << float(planet.Health);
		msg << float(planet.MaxHealth);
		planet.writeResources(msg);
		planet.writeSurface(msg);
		planet.writeConstruction(msg);
		planet.writeStatuses(msg);

		msg.writeBit(planet.hasAbilities);
		if(planet.hasAbilities)
			planet.writeAbilities(msg);

		if(planet.hasMover) {
			msg.write1();
			planet.writeMover(msg);
		}
		else {
			msg.write0();
		}
	}

	void dealPlanetDamage(Planet& planet, double amount) {
		double curPop = planet.population;

		double hpDmg = 0;
		if(curPop > 1.0)
			hpDmg = amount * pow(0.4, curPop/5.0);
		else
			hpDmg = amount;
		double popDmg = amount - hpDmg;

		if(hpDmg > 0) {
			hpDelta = true;
			planet.Health -= hpDmg;

			if(planet.Health <= 0) {
				planet.Health = 0;
				planet.destroy();
				return;
			}
		}

		if(popDmg > 0) {
			double popLost = popDmg / planet.MaxHealth * 3.0 * planet.maxPopulation;
			planet.removePopulation(popLost, 1.0);
		}
	}
	
	void giveHistoricMemory(Planet& planet, Empire@ emp) {
		if(planet.memoryMask & emp.mask != 0)
			return;
		
		planet.memoryMask |= emp.mask;
		planet.giveBasicIconVision(emp);
		//TODO: Make this force a vision update on the client
	}
	
	void setRing(uint ring) {
		ringStyle = ring;
	}

	void addMoon(Planet& planet, float size = 0, uint style = 0) {
		if(moons is null)
			@moons = array<MoonData@>();
		if(style == 0)
			style = randomi();
		if(size == 0)
			size = randomd(planet.radius * 0.15, planet.radius * 0.3);

		MoonData dat;
		dat.size = size;
		dat.style = style;
		moons.insertLast(dat);

		PlanetNode@ plNode = cast<PlanetNode>(planet.getNode());
		if(plNode !is null)
			plNode.addMoon(size, style);
	}

	uint get_moonCount() {
		if(moons is null)
			return 0;
		return moons.length;
	}
};
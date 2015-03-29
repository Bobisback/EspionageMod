import regions.regions;

class ShipScript {
	float commandUsed = 0.f;

	float timer = 1.f;

	bool get_isStation(Ship& ship) {
		return ship.blueprint.design.hasTag(ST_Station);
	}

	void occasional_tick(Ship& ship, float time) {
		if(ship.hasLeaderAI)
			ship.updateFleetStrength();
	}

	double tick(Ship& ship, double time) {
		if(updateRegion(ship)) {
			auto@ node = ship.getNode();
			if(node !is null)
				node.hintParentObject(ship.region);
		}
		
		ship.moverTick(time);
		if(ship.hasLeaderAI)
			ship.leaderTick(time);

		timer += float(time);
		if(timer >= 1.f) {
			occasional_tick(ship, timer);
			timer = 0.f;
		}
		return 0.2;
	}

	void destroy(Ship& ship) {
		if(ship.inCombat) {
			auto@ region = ship.region;
			if(region !is null) {
				uint debris = uint(log(ship.blueprint.design.size) / log(2.0));
				if(debris > 0)
					region.addShipDebris(ship.position, debris);
			}
		}
		
		leaveRegion(ship);
		if(ship.hasLeaderAI)
			ship.leaderDestroy();
	}

	bool onOwnerChange(Ship& ship, Empire@ prevOwner) {
		regionOwnerChange(ship, prevOwner);
		if(ship.hasLeaderAI)
			ship.leaderChangeOwner(prevOwner, ship.owner);
		return false;
	}

	void syncInitial(Ship& ship, Message& msg) {
		//Find hull
		uint hullID = msg.readSmall();

		const Hull@ hull = getHullDefinition(hullID);

		//Sync data
		ship.blueprint.recvDetails(ship, msg);

		//Create graphics
		MeshDesc shipMesh;
		@shipMesh.model = hull.model;
		@shipMesh.material = hull.material;
		@shipMesh.iconSheet = ship.blueprint.design.distantIcon.sheet;
		shipMesh.iconIndex = ship.blueprint.design.distantIcon.index;
		shipMesh.memorable = ship.memorable;
		bindMesh(ship, shipMesh);

		if(msg.readBit()) {
			ship.activateLeaderAI();
			ship.leaderInit();
			ship.readLeaderAI(msg);
			auto@ node = ship.getNode();
			if(node !is null)
				node.animInvis = true;
		}
		else {
			ship.activateSupportAI();
			ship.readSupportAI(msg);
		}

		ship.readMover(msg);
		if(msg.readBit()) {
			msg >> ship.MaxEnergy;
			ship.Energy = msg.readFixed(0.f, ship.MaxEnergy, 16);
		}
		if(msg.readBit()) {
			msg >> ship.MaxSupply;
			ship.Supply = msg.readFixed(0.f, ship.MaxSupply, 16);
		}
		if(msg.readBit()) {
			msg >> ship.MaxShield;
			ship.Shield = msg.readFixed(0.f, ship.MaxShield, 16);
		}

		if(msg.readBit()) {
			ship.activateAbilities();
			ship.readAbilities(msg);
		}

		if(msg.readBit()) {
			ship.activateStatuses();
			ship.readStatuses(msg);
		}

		if(msg.readBit()) {
			ship.activateConstruction();
			ship.readConstruction(msg);
		}

		if(msg.readBit()) {
			ship.activateOrbit();
			ship.readOrbit(msg);
		}
	}

	void syncDetailed(Ship& ship, Message& msg, double tDiff) {
		ship.readMover(msg);
		if(ship.hasLeaderAI)
			ship.readLeaderAI(msg);
		else
			ship.readSupportAI(msg);
		ship.blueprint.recvDetails(ship, msg);
		updateStats(ship);
		msg >> ship.Energy;
		msg >> ship.MaxEnergy;
		msg >> ship.Supply;
		msg >> ship.MaxSupply;
		msg >> ship.Shield;
		msg >> ship.MaxShield;
		ship.isFTLing = msg.readBit();
		ship.inCombat = msg.readBit();
		if(ship.hasAbilities)
			ship.readAbilities(msg);
		if(ship.hasStatuses)
			ship.readStatuses(msg);
		if(msg.readBit()) {
			if(!ship.hasOrbit)
				ship.activateOrbit();
			ship.readOrbit(msg);
		}
		if(msg.readBit()) {
			if(!ship.hasConstruction)
				ship.activateConstruction();
			ship.readConstruction(msg);
		}
	}

	void updateStats(Ship& ship) {
		const Design@ dsg = ship.blueprint.design;
		if(dsg is null)
			return;
		
		ship.DPS = ship.blueprint.getEfficiencySum(SV_DPS);
		ship.MaxDPS = dsg.total(SV_DPS);
		ship.MaxSupply = dsg.total(SV_SupplyCapacity);
		ship.MaxShield = dsg.total(SV_ShieldCapacity);
		commandUsed = dsg.variable(ShV_REQUIRES_Command);
	}

	void syncDelta(Ship& ship, Message& msg, double tDiff) {
		if(msg.readBit())
			ship.readMoverDelta(msg);
		if(msg.readBit()) {
			ship.blueprint.recvDelta(ship, msg);
			updateStats(ship);
		}
		
		if(msg.readBit())
			ship.Shield = msg.readFixed(0.f, ship.MaxShield, 16);
		
		if(msg.readBit()) {
			if(ship.hasLeaderAI)
				ship.readLeaderAIDelta(msg);
			else
				ship.readSupportAIDelta(msg);
		}
		if(ship.hasAbilities) {
			if(msg.readBit())
				ship.readAbilityDelta(msg);
		}
		if(ship.hasStatuses) {
			if(msg.readBit())
				ship.readStatusDelta(msg);
		}
		if(msg.readBit()) {
			if(msg.readBit())
				msg >> ship.Energy;
			else
				ship.Energy = 0;
			if(msg.readBit())
				msg >> ship.Supply;
			else
				ship.Supply = 0;
			
			ship.isFTLing = msg.readBit();
			ship.inCombat = msg.readBit();
		}
		if(msg.readBit()) {
			if(!ship.hasOrbit)
				ship.activateOrbit();
			ship.readOrbitDelta(msg);
		}
		if(ship.hasLeaderAI) {
			if(msg.readBit()) {
				if(!ship.hasConstruction)
					ship.activateConstruction();
				ship.readConstructionDelta(msg);
			}
		}
	}
};

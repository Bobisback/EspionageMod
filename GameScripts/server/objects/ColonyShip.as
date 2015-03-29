from resources import MoneyType;
import regions.regions;
import saving;
MeshDesc shipMesh;

class ColonyShipScript {
	int moveId;

	ColonyShipScript() {
		moveId = -1;
	}

	void load(ColonyShip& obj, SaveFile& msg) {
		loadObjectStates(obj, msg);
		msg >> cast<Savable>(obj.Mover);
		@obj.Origin = msg.readObject();
		@obj.Target = msg.readObject();
		msg >> obj.CarriedPopulation;
		
		if(msg < SV_0033 && obj.Target !is null)
			obj.Target.modIncomingPop(obj.CarriedPopulation);

		msg >> moveId;

	}

	void postLoad(ColonyShip& obj) {
		//Create the graphics
		@shipMesh.model = getModel(obj.owner.ColonizerModel);
		@shipMesh.material = getMaterial(obj.owner.ColonizerMaterial);
		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(obj, shipMesh);
	}

	void save(ColonyShip& obj, SaveFile& msg) {
		saveObjectStates(obj, msg);
		msg << cast<Savable>(obj.Mover);
		msg << obj.Origin;
		msg << obj.Target;
		msg << obj.CarriedPopulation;

		msg << moveId;
	}

	void init(ColonyShip& ship) {
		//Create the graphics
		ship.sightRange = 0;
		@shipMesh.model = getModel(ship.owner.ColonizerModel);
		@shipMesh.material = getMaterial(ship.owner.ColonizerMaterial);
		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(ship, shipMesh);
	}

	void postInit(ColonyShip& ship) {
		if(ship.Target !is null)
			ship.Target.modIncomingPop(ship.CarriedPopulation);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation), MoT_Colonizers);
	}

	bool onOwnerChange(ColonyShip& ship, Empire@ prevOwner) {
		if(prevOwner !is null && prevOwner.valid)
			prevOwner.modMaintenance(-round(80.0 * ship.CarriedPopulation), MoT_Colonizers);
		if(ship.owner !is null && ship.owner.valid)
			ship.owner.modMaintenance(round(80.0 * ship.CarriedPopulation), MoT_Colonizers);
		regionOwnerChange(ship, prevOwner);
		return false;
	}

	void destroy(ColonyShip& ship) {
		if(ship.owner !is null && ship.owner.valid && ship.CarriedPopulation > 0)
			ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation), MoT_Colonizers);
		if(ship.CarriedPopulation > 0 && ship.Origin !is null && ship.Target !is null) {
			ship.Origin.reducePopInTransit(ship.Target, ship.CarriedPopulation);
			ship.Target.modIncomingPop(-ship.CarriedPopulation);
		}
		leaveRegion(ship);
	}
	
	double tick(ColonyShip& ship, double time) {
		Object@ target = ship.Target;
	
		if(moveId == -1 && target is null)
			return 0.2;
		ship.moverTick(time);

		updateRegion(ship);

		if(target is null) {
			ship.destroy();
		}
		else if(ship.position.distanceTo(target.position) <= (ship.radius + target.radius + 0.1) || ship.moveTo(target, moveId, enterOrbit=false)) {
			ship.destroy();
			if(target.isPlanet) {
				target.colonyShipArrival(ship.owner, ship.CarriedPopulation);
				if(ship.Origin !is null)
					ship.Origin.reducePopInTransit(ship.Target, ship.CarriedPopulation);
				if(ship.owner !is null && ship.owner.valid)
					ship.owner.modMaintenance(-round(80.0 * ship.CarriedPopulation), MoT_Colonizers);
				ship.CarriedPopulation = 0;
			}
		}
		else if(target.isPlanet && ship.owner !is null && ship.owner.major && !target.isEmpireColonizing(ship.owner)) {
			if(ship.Origin !is null && ship.position.distanceTo(ship.Origin.position) < 3000.0)
				ship.destroy();
		}
		return 0.2;
	}

	void damage(ColonyShip& ship, DamageEvent& evt, double position, const vec2d& direction) {
		ship.Health -= evt.damage;
		if(ship.Health <= 0)
			ship.destroy();
	}

	void syncInitial(const ColonyShip& ship, Message& msg) {
		ship.writeMover(msg);
	}

	void syncDetailed(const ColonyShip& ship, Message& msg) {
		ship.writeMover(msg);
	}

	bool syncDelta(const ColonyShip& ship, Message& msg) {
		bool used = false;
		if(ship.writeMoverDelta(msg))
			used = true;
		else
			msg.write0();
		return used;
	}
};

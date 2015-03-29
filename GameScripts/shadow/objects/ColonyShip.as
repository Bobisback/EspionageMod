import regions.regions;

class ColonyShipScript {
	ColonyShipScript() {
	}

	void init(ColonyShip& ship) {
		//Create the graphics
		MeshDesc shipMesh;
		@shipMesh.model = getModel(ship.owner.ColonizerModel);
		@shipMesh.material = getMaterial(ship.owner.ColonizerMaterial);
		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(ship, shipMesh);
	}

	void destroy(ColonyShip& ship) {
		leaveRegion(ship);
	}

	bool onOwnerChange(ColonyShip& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		return false;
	}
	
	double tick(ColonyShip& ship, double time) {
		updateRegion(ship);
		ship.moverTick(time);
		return 0.2;
	}

	void syncInitial(ColonyShip& ship, Message& msg) {
		ship.readMover(msg);
	}

	void syncDetailed(ColonyShip& ship, Message& msg, double tDiff) {
		ship.readMover(msg);
	}

	void syncDelta(ColonyShip& ship, Message& msg, double tDiff) {
		if(msg.readBit())
			ship.readMoverDelta(msg);
	}
};


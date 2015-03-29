import regions.regions;

class FreighterScript {
	FreighterScript() {
	}

	void init(Freighter& ship) {
		//Create the graphics
		MeshDesc shipMesh;
		@shipMesh.model = model::Fighter;
		@shipMesh.material = material::Ship10;
		@shipMesh.iconSheet = spritesheet::HullIcons;
		shipMesh.iconIndex = 0;

		bindMesh(ship, shipMesh);
	}

	void destroy(Freighter& ship) {
		leaveRegion(ship);
	}

	bool onOwnerChange(Freighter& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		return false;
	}
	
	double tick(Freighter& ship, double time) {
		updateRegion(ship);
		ship.moverTick(time);
		return 0.2;
	}

	void syncInitial(Freighter& ship, Message& msg) {
		ship.readMover(msg);
	}

	void syncDetailed(Freighter& ship, Message& msg, double tDiff) {
		ship.readMover(msg);
	}

	void syncDelta(Freighter& ship, Message& msg, double tDiff) {
		if(msg.readBit())
			ship.readMoverDelta(msg);
	}
};


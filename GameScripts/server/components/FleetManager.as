import saving;

class FleetManager : Component_FleetManager, Savable {
	ReadWriteMutex fleetMutex;
	Object@[] fleetList;
	double[] strengths;
	uint nextUpdate = 0;

	FleetManager() {
	}

	uint get_fleetCount() {
		return fleetList.length;
	}

	Object@ get_fleets(uint index) {
		ReadLock lock(fleetMutex);
		if(index >= fleetList.length)
			return null;
		return fleetList[index];
	}

	double getTotalFleetStrength() {		
		WriteLock lock(fleetMutex);
		uint fltCnt = fleetList.length;
		if(fltCnt == 0)
			return 0.0;
		
		for(uint n = 0; n < fltCnt; ++n) {
			uint updateInd = (nextUpdate++) % fltCnt;
			
			Object@ flt = fleetList[updateInd];
			if(flt.supportCount == 0 && flt.isShip) {
				Ship@ ship = cast<Ship>(flt);
				strengths[updateInd] = sqrt(ship.blueprint.design.totalHP * ship.MaxDPS);
			}
			else {
				strengths[updateInd] = sqrt(flt.getFleetMaxStrength());
				break;
			}
		}
		
		double total = 0;
		for(uint i = 0; i < fltCnt; ++i)
			total += strengths[i];
		return total;
	}

	void load(SaveFile& msg) {
		uint cnt = 0;
		msg >> cnt;
		fleetList.length = cnt;
		strengths.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			msg >> fleetList[i];
			if(msg >= SV_0065)
				msg >> strengths[i];
			else
				strengths[i] = 0.0;
		}
	}

	void save(SaveFile& msg) {
		uint cnt = fleetList.length;
		msg << cnt;
		for(uint i = 0; i < cnt; ++i) {
			msg << fleetList[i];
			msg << strengths[i];
		}
	}

	Object@ getFleetFromPosition(vec3d pos) {
		ReadLock lock(fleetMutex);
		for(uint i = 0, cnt = fleetList.length; i < cnt; ++i) {
			Object@ leader = fleetList[i];
			double rad = leader.getFormationRadius();

			if(leader.position.distanceToSQ(pos) < rad * rad)
				return leader;
		}
		return null;
	}

	void registerFleet(Empire& emp, Object@ obj) {
		WriteLock lock(fleetMutex);
		fleetList.insertLast(obj);
		strengths.insertLast(0);
	}

	void unregisterFleet(Empire& emp, Object@ obj) {
		WriteLock lock(fleetMutex);
		int ind = fleetList.find(obj);
		if(ind != -1) {
			fleetList.removeAt(ind);
			strengths.removeAt(ind);
		}
	}

	void getFlagships() {
		ReadLock lock(fleetMutex);
		for(uint i = 0, cnt = fleetList.length; i < cnt; ++i) {
			Object@ leader = fleetList[i];
			if(leader.isShip && !leader.hasOrbit)
				yield(leader);
		}
	}

	void getStations() {
		ReadLock lock(fleetMutex);
		for(uint i = 0, cnt = fleetList.length; i < cnt; ++i) {
			Object@ leader = fleetList[i];
			if(leader.isShip && leader.hasOrbit)
				yield(leader);
		}
	}

	void giveFleetVisionTo(Empire@ toEmpire, bool normalSpace = true, bool inFTL = true, bool stations = false) {
		if(toEmpire is null)
			return;
		ReadLock lock(fleetMutex);
		for(uint i = 0, cnt = fleetList.length; i < cnt; ++i) {
			Ship@ ship = cast<Ship>(fleetList[i]);
			if(ship is null)
				continue;
			if(!stations && ship.isStation)
				continue;
			if(ship.inFTL) {
				if(!inFTL)
					continue;
			}
			else {
				if(!normalSpace)
					continue;
			}
			ship.donatedVision |= toEmpire.mask;
		}
	}
};

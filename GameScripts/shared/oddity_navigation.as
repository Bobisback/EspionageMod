export PathNode;
import saving;

final class PathNode : Serializable, Savable {
	Object@ pathEntry;
	Object@ pathExit;
	vec3d pathTo;
	float dist = 0;

	void write(Message& msg) {
		msg.writeBit(pathEntry !is null);
		if(pathEntry !is null) {
			msg << pathEntry;
			msg << pathExit;
		}
		else {
			msg.writeMedVec3(pathTo);
			msg << dist;
		}
	}

	void read(Message& msg) {
		if(msg.readBit()) {
			msg >> pathEntry;
			msg >> pathExit;
		}
		else {
			@pathEntry = null;
			@pathExit = null;
			pathTo = msg.readMedVec3();
			msg >> dist;
		}
	}

	void save(SaveFile& file) {
		file << pathEntry;
		file << pathExit;
		file << pathTo;
		file << dist;
	}

	void load(SaveFile& file) {
		file >> pathEntry;
		file >> pathExit;
		file >> pathTo;
		if(file >= SV_0086)
			file >> dist;
	}

	vec3d pathOut() {
		if(pathExit !is null)
			return pathExit.position;
		return pathTo;
	}
	
#section server-side
	uint get_visionMask() const {
		if(pathExit !is null)
			return pathExit.visibleMask;
		return 0;
	}
#section all

	bool valid(Object& obj) {
		if(pathEntry !is null && !pathEntry.valid)
			return false;
		if(pathExit !is null && !pathExit.valid)
			return false;
		/*Orbital@ orb = cast<Orbital>(pathEntry);*/
		/*if(orb !is null && orb.Disabled)*/
		/*	return false;*/
		/*if(pathExit !is null) {*/
		/*	if(!pathExit.valid)*/
		/*		return false;*/
		/*	@orb = cast<Orbital>(pathExit);*/
		/*	if(orb !is null && orb.Disabled)*/
		/*		return false;*/
		/*}*/
		return true;
	}
};

#section server-side
ReadWriteMutex mutex;
array<Oddity@> gates;

export addOddityGate;
void addOddityGate(Oddity& gate) {
	WriteLock lock(mutex);
	gates.insertLast(gate);
}

export removeOddityGate;
void removeOddityGate(Oddity& gate) {
	WriteLock lock(mutex);
	gates.remove(gate);
}

export pathOddityGates;
double pathOddityGates(Empire@ emp, array<PathNode@>@ path, const vec3d& from, const vec3d& to, double accel = 0.0) {
	ReadLock lock(mutex);
	double eta = 0.0;
	doPathing(emp, from, to, 0, path, eta, accel);
	return eta;
}

double dumbETA(double dist, double accel) {
	return sqrt(4.0 * (dist / accel));
}

export getPathETA;
double getPathETA(const vec3d& startPos, const vec3d& endPos, double accel, array<PathNode@>@ path = null) {
	double eta = 0.0;
	vec3d pos = startPos;
	if(path !is null) {
		for(uint i = 0, cnt = path.length; i < cnt; ++i) {
			auto@ node = path[i];
			if(node.pathEntry !is null)
				eta += dumbETA(node.pathEntry.position.distanceTo(pos), accel);
			else 
				eta += dumbETA(node.pathTo.distanceTo(pos), accel);
			if(node.pathExit !is null)
				pos = node.pathExit.position;
			else
				pos = node.pathTo;
		}
	}
	eta += dumbETA(pos.distanceTo(endPos), accel);
	return eta;
}

const double SQRT_2 = sqrt(2.0);
uint doPathing(Empire@ emp, const vec3d& from, const vec3d& to, uint index, array<PathNode@>@ path, double& eta, double accel) {
	//Check which gate jump makes this journey shorter by the most
	Oddity@ shortest;
	Object@ shortestGateIn; Object@ shortestGateOut;
	double shortestDist = from.distanceTo(to);

	if(emp.hasStargates()) {
		Object@ entryGate = emp.getStargate(from);
		Object@ exitGate = emp.getStargate(to);

		if(entryGate !is null && exitGate !is null && entryGate !is exitGate) {
			double gateDist = from.distanceTo(entryGate.position);
			gateDist += exitGate.position.distanceTo(to);
			gateDist *= SQRT_2;

			if(gateDist < shortestDist) {
				shortestDist = gateDist;
				@shortestGateIn = entryGate;
				@shortestGateOut = exitGate;
			}
		}
	}

	for(uint i = 0, cnt = gates.length; i < cnt; ++i) {
		Oddity@ gate = gates[i];
		if(emp !is null && !gate.isKnownTo(emp))
			continue;

		vec3d enter = gate.position;
		vec3d exit = gate.getGateDest();

		double enterDist = enter.distanceTo(from);
		double exitDist = exit.distanceTo(to);
		double dist = (enterDist + exitDist) * SQRT_2;

		if(accel > 0) {
			double timer = gate.getTimer();
			if(timer >= 0) {
				double curETA = eta + dumbETA(enterDist, accel);
				if(curETA >= timer - 20.0)
					continue;
			}
		}

		if(dist < shortestDist) {
			shortestDist = dist;
			@shortest = gate;
		}
	}

	if(shortest !is null) {
		//Add to path
		PathNode node;
		@node.pathEntry = shortest;
		@node.pathExit = shortest.getLink();
		
		if(index > path.length)
			path.length = index+1;
		path.insertAt(index, node);

		//Recurse into more paths
		uint amount = 1;
		amount += doPathing(emp, from, shortest.position, index, path, eta, accel);
		eta += dumbETA(path[index+amount-1].pathOut().distanceTo(shortest.position), accel);
		amount += doPathing(emp, shortest.getGateDest(), to, index+amount, path, eta, accel);
		return amount;
	}
	else if(shortestGateIn !is null) {
		//Add to path
		PathNode node;
		@node.pathEntry = shortestGateIn;
		@node.pathExit = shortestGateOut;
		
		if(index > path.length)
			path.length = index+1;
		path.insertAt(index, node);

		//Recurse into more paths
		uint amount = 1;
		amount += doPathing(emp, from, shortestGateIn.position, index, path, eta, accel);
		eta += dumbETA(path[index+amount-1].pathOut().distanceTo(shortestGateIn.position), accel);
		amount += doPathing(emp, shortestGateOut.position, to, index+amount, path, eta, accel);
		return amount;
	}

	return 0;
}

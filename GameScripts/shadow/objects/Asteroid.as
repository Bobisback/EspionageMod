import resources;
import regions.regions;
import saving;

class AsteroidScript {
	StrategicIconNode@ icon;
	array<const ResourceType@> available;
	array<float> costs;
	array<bool> exploited;
	uint resourceLimit = 1;
	uint currentResources = 0;

	void makeMesh(Asteroid& obj) {
		MeshDesc mesh;
		@mesh.model = model::Asteroid;
		switch(obj.id % 3) {
			case 0:
				@mesh.material = material::AsteroidPegmatite; break;
			case 1:
				@mesh.material = material::AsteroidMagnetite; break;
			case 2:
				@mesh.material = material::AsteroidTonalite; break;
		}
		mesh.memorable = true;
		bindMesh(obj, mesh);

		@icon = StrategicIconNode();
		icon.establish(obj, 0.015, spritesheet::AsteroidIcon, 0);
		icon.memorable = true;
		
		if(obj.region !is null)
			obj.region.addStrategicIcon(-1, obj, icon);
	}

	void destroy(Asteroid& obj) {
		if(obj.region !is null)
			obj.region.removeStrategicIcon(-1, icon);
		icon.markForDeletion();
		@icon = null;

		leaveRegion(obj);
		obj.destroyObjResources();
	}

	bool onOwnerChange(Asteroid& obj, Empire@ prevOwner) {
		regionOwnerChange(obj, prevOwner);
		return false;
	}

	double tick(Asteroid& obj, double time) {
		Region@ prevRegion = obj.region;
		if(updateRegion(obj)) {
			Region@ newRegion = obj.region;
			if(prevRegion !is null)
				prevRegion.removeStrategicIcon(-1, icon);
			if(newRegion !is null)
				newRegion.addStrategicIcon(-1, obj, icon);
			@prevRegion = newRegion;
		}
		icon.visible = obj.isVisibleTo(playerEmpire);

		obj.orbitTick(time);
		obj.resourceTick(time);
		return 0.2;
	}

	bool canDevelop(Asteroid& obj, Empire@ emp) {
		return (!obj.owner.valid || obj.owner is emp) && currentResources < resourceLimit;
	}

	bool canGainLimit(Asteroid& obj, Empire@ emp) {
		if(!obj.owner.valid || obj.owner is emp)
			return false;
		return currentResources < available.length;
	}

	vec3d get_strategicIconPosition(Asteroid& obj) {
		if(icon is null)
			return obj.position;
		return icon.position;
	}

	uint getAvailableCount() {
		if(currentResources >= resourceLimit)
			return 0;
		return available.length;
	}

	uint getAvailable(uint index) {
		if(index >= available.length)
			return uint(-1);
		if(exploited[index])
			return uint(-1);
		return available[index].id;
	}

	double getAvailableCost(uint index) {
		if(index >= costs.length)
			return -1.0;
		if(exploited[index])
			return -1.0;
		return costs[index];
	}

	double getAvailableCostFor(uint resId) {
		const ResourceType@ type = getResource(resId);
		if(type is null)
			return -1.0;

		for(uint i = 0, cnt = available.length; i < cnt; ++i) {
			if(exploited[i])
				continue;
			if(available[i] is type)
				return costs[i];
		}

		return -1.0;
	}

	void _readAsteroid(Asteroid& obj, Message& msg) {
		@obj.origin = msg.readObject();
		uint cnt = msg.readSmall();
		available.length = cnt;
		costs.length = cnt;
		exploited.length = cnt;
		for(uint i = 0; i < cnt; ++i) {
			@available[i] = getResource(msg.readLimited(getResourceCount()-1));
			msg >> costs[i];
			msg >> exploited[i];
		}
		resourceLimit = msg.readSmall();
		currentResources = msg.readSmall();
	}

	void syncInitial(Asteroid& obj, Message& msg) {
		_readAsteroid(obj, msg);
		obj.readResources(msg);
		obj.readOrbit(msg);
		makeMesh(obj);
	}

	void syncDelta(Asteroid& obj, Message& msg, double tDiff) {
		if(msg.readBit())
			_readAsteroid(obj, msg);
		if(msg.readBit())
			obj.readResourceDelta(msg);
		if(msg.readBit())
			obj.readOrbitDelta(msg);
	}

	void syncDetailed(Asteroid& obj, Message& msg, double tDiff) {
		_readAsteroid(obj, msg);
		obj.readResources(msg);
		obj.readOrbit(msg);
	}
};

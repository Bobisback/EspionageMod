import biomes;
import buildings;

enum SurfaceFlags {
	SuF_Usable = 1,
};

class PlanetSurface : Serializable {
	vec2u size;

	//Data grid
	array<uint8> biomes;
	array<uint8> flags;
	array<SurfaceBuilding@> tileBuildings;
	const Biome@ baseBiome;

	//Resources and pressures
	double[] resources = double[](TR_COUNT, 0);
	float[] saturates = float[](TR_COUNT, 0);
	float[] pressures = float[](TR_COUNT, 0.f);
	double totalResource = 0;
	float totalSaturate = 0;
	double totalPressure = 0.0;

	//Improving tiles to usable status
	vec2u nextReady;
	double readyTimer = -1.0;
	int Maintenance = 0;
	uint usableTiles = 0;
	uint citiesBuilt = 0;
	uint civsBuilt = 0;
	uint pressureCap = 0;

	//Civilian building construction
	array<SurfaceBuilding@> buildings;
	SurfaceBuilding@ civConstructing;

	PlanetSurface() {
	}

	uint get_dataSize() {
		return size.width * size.height;
	}
	
	bool isValidPosition(const vec2i& pos) const {
		return uint(pos.x) < size.width && uint(pos.y) < size.height;
	}
	
	bool isValidPosition(const vec2u& pos) const {
		return pos.x < size.width && pos.y < size.height;
	}

	void clearState() {
		for(uint i = 0, cnt = flags.length; i < cnt; ++i)
			flags[i] = 0;
		for(uint i = 0, cnt = flags.length; i < cnt; ++i)
			@tileBuildings[i] = null;
		buildings.length = 0;
	}
	
	void write(Message& msg) {
		write(msg, false);
	}

	void write(Message& msg, bool delta) {
		msg.writeSmall(size.width);
		msg.writeSmall(size.height);

		msg << baseBiome.id;
		msg.writeSmall(Maintenance);
		msg.writeSmall(pressureCap);
		msg.writeSmall(civsBuilt);

		uint maxBiomeID = getBiomeCount() - 1;
		uint dsize = biomes.length;
		uint8 prevFlags = 0, prevBiome = baseBiome.id;
		for(uint i = 0; i < dsize; ++i) {
			uint8 biome = biomes[i];
			if(biome != prevBiome) {
				msg.write0();
				msg.writeLimited(biome,maxBiomeID);
				prevBiome = biome;
			}
			else {
				msg.write1();
			}
			
			uint8 _flags = flags[i];
			if(_flags != prevFlags) {
				msg.write0();
				msg << _flags;
				prevFlags = _flags;
			}
			else {
				msg.write1();
			}
		}

		uint bcnt = buildings.length;
		msg.writeSmall(bcnt);
		int civIndex = -1;
		for(uint i = 0; i < bcnt; ++i) {
			SurfaceBuilding@ bldg = buildings[i];
			if(bldg is civConstructing)
				civIndex = int(i);
			if(delta) {
				msg.writeBit(bldg.delta);
				if(!bldg.delta)
					continue;
				bldg.delta = false;
			}
			bldg.write(msg);
		}
		
		if(civIndex > 0) {
			msg.write1();
			msg.writeSmall(uint(civIndex));
		}
		else {
			msg.write0();
		}
		
		for(uint i = 0; i < TR_COUNT; ++i) {
			if(resources[i] != 0) {
				msg.write1();
				msg << float(resources[i]);
			}
			else {
				msg.write0();
			}
			
			if(pressures[i] != 0) {
				msg.write1();
				msg << pressures[i];
				msg << saturates[i];
			}
			else {
				msg.write0();
			}
		}
	}
	
	void read(Message& msg) {
		read(msg, false);
	}

	void read(Message& msg, bool delta) {
		size.width = msg.readSmall();
		size.height = msg.readSmall();
		
		uint8 baseId = 0;
		msg >> baseId;
		@baseBiome = ::getBiome(baseId);
		Maintenance = msg.readSmall();
		pressureCap = msg.readSmall();
		civsBuilt = msg.readSmall();

		uint maxBiomeID = getBiomeCount() - 1;
		
		uint dsize = dataSize;
		biomes.length = dsize;
		flags.length = dsize;
		tileBuildings.length = dsize;
		
		uint8 prevFlags = 0, prevBiome = baseId;
		for(uint i = 0; i < dsize; ++i) {
			if(!msg.readBit())
				prevBiome = msg.readLimited(maxBiomeID);
			biomes[i] = prevBiome;
			
			if(!msg.readBit())
				msg >> prevFlags;
			flags[i] = prevFlags;
			
			@tileBuildings[i] = null;
		}

		uint bcnt = msg.readSmall();
		buildings.length = bcnt;

		for(uint i = 0; i < bcnt; ++i) {
			if(buildings[i] is null)
				@buildings[i] = SurfaceBuilding();

			SurfaceBuilding@ bld = buildings[i];
			if(delta && !msg.readBit())
				continue;
			
			bld.read(msg);

			vec2u pos = bld.position;
			vec2u center = bld.type.getCenter();

			for(uint x = 0; x < bld.type.size.x; ++x) {
				for(uint y = 0; y < bld.type.size.y; ++y) {
					vec2u rpos = (pos - center) + vec2u(x, y);
					uint index = rpos.y * size.width + rpos.x;
					@tileBuildings[index] = bld;
				}
			}
		}

		if(msg.readBit()) {
			uint civIndex = msg.readSmall();
			if(civIndex < buildings.length)
				@civConstructing = buildings[civIndex];
		}
		else {
			@civConstructing = null;
		}
		
		totalPressure = 0;
		totalSaturate = 0;
		totalResource = 0;

		for(uint i = 0; i < TR_COUNT; ++i) {
			if(msg.readBit()) {
				float resource = 0;
				msg >> resource;
				resources[i] = resource;
				totalResource += resource;
			}
			else {
				resources[i] = 0;
			}
			
			if(msg.readBit()) {
				msg >> pressures[i];
				totalPressure += pressures[i];

				msg >> saturates[i];
				totalSaturate += saturates[i];
			}
			else {
				pressures[i] = 0;
			}
		}
	}

	uint getIndex(int x, int y) {
		return y * size.width + x;
	}

	const Biome@ getBiome(int x, int y) {
		uint index = y * size.width + x;
		if(index >= biomes.length)
			return null;
		return ::getBiome(biomes[index]);
	}

	uint8 getFlags(int x, int y) {
		uint index = y * size.width + x;
		if(index >= flags.length)
			return 0;
		return flags[index];
	}
	
	bool checkFlags(int x, int y, uint8 f) {
		uint index = y * size.width + x;
		if(index >= flags.length)
			return false;
		return (flags[index] & f) == f;
	}

	void setFlags(int x, int y, uint8 f) {
		uint index = y * size.width + x;
		if(index >= flags.length)
			return;
		flags[index] = f;
	}

	void addFlags(int x, int y, uint8 f) {
		uint index = y * size.width + x;
		if(index >= flags.length)
			return;
		flags[index] |= f;
	}

	void removeFlags(int x, int y, uint8 f) {
		uint index = y * size.width + x;
		if(index >= flags.length)
			return;
		flags[index] &= ~f;
	}

	SurfaceBuilding@ getBuilding(int x, int y) {
		uint index = y * size.width + x;
		if(index >= tileBuildings.length)
			return null;
		return tileBuildings[index];
	}

	float getBuildingBuildWeight(int x, int y) {
		uint index = y * size.width + x;
		if(index >= tileBuildings.length)
			return 0;
		SurfaceBuilding@ bld = tileBuildings[index];
		if(bld is null)
			return 0;
		return bld.type.hubWeight;
	}

	void setBuilding(int x, int y, SurfaceBuilding@ bld) {
		uint index = y * size.width + x;
		if(index >= tileBuildings.length)
			return;
		@tileBuildings[index] = bld;
	}
};

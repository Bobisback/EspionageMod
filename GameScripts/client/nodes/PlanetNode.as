import planet_types;

const double PLANET_DIST_MAX = 300;

enum PlanetSpecial {
	PS_None,
	PS_Asteroids,
	PS_Ring
};

//Draws the physical star, its corona, and a distant star sprite
final class MoonData {
	uint style = 0;
	float size = 0.f;
};

final class PlanetNodeScript {
	bool Colonized = false;
	const Material@ emptyMat = material::PlanetSurface;
	const Material@ colonyMat = material::PlanetSurfaceCities;
	const Material@ atmosMat;
	PlanetSpecial special = PS_None;
	double ringScale = 1.0, ringAngle = 0.0;
	float ringMin = 0.f, ringMax = 1.f;
	const Material@ ringMat;
	array<MoonData@>@ moons;
	
	PlanetNodeScript(Node& node) {
		node.memorable = true;
		node.animInvis = false;
	}
	
	void set_planetType(Node& node, int planetTypeID) {
		//Cache values for performance
		const PlanetType@ type = getPlanetType(planetTypeID);
		@emptyMat = type.emptyMat;
		@colonyMat = type.colonyMat;
		//@dyingMat = type.dyingMat;
		@atmosMat = type.atmosMat;
		node.transparent = atmosMat !is null;
	}
	
	void set_colonized(bool isColonized) {
		Colonized = isColonized;
	}
	
	void addRing(Node& node, uint rnd) {
		node.autoCull = false;
		special = PS_Ring;
		
		uint matIndex = rnd % 7;
		rnd /= 7;
		
		uint scale = rnd % 256;
		rnd /= 256;
		
		uint inner = rnd % 128;
		rnd /= 128;
		
		uint outer = rnd % 64;
		rnd /= 64;
		
		uint angle = rnd % 64;
		rnd /= 64;
		
		ringScale = 1.2 + 2.0 * double(scale) / 1024.0;
		ringMin = double(inner) * 0.9 / 1024.0;
		ringMax = max(1.0 - ((1.0 - ringMin) * double(outer)/1024.0), ringMin + 0.1);
		ringAngle = pi * (-0.07 + (0.14 * double(angle)/64.0));
		
		@ringMat = getMaterial("PlanetRing" + (1 + matIndex));
	}

	void addMoon(Node& node, float size, uint style = 0) {
		if(moons is null)
			@moons = array<MoonData@>();
		MoonData dat;
		dat.size = size;
		dat.style = style;
		moons.insertLast(dat);
	}
	
	void giveAsteroids(Node& node) {
		node.autoCull = true;
		special = PS_Asteroids;
	}
	
	bool preRender(Node& node) {
		if(moons !is null) {
			//NOTE: this doesn't seem to actually work, for rings neither. If the planet is offscreen, the ring disappears
			if(node.sortDistance * config::GFX_DISTANCE_MOD < PLANET_DIST_MAX * pixelSizeRatio * node.abs_scale * 9.0 * 8.5) {
				return isSphereVisible(node.abs_position, node.abs_scale * 9.0);
			}
		}
		else if(special == PS_Ring) {
			if(node.sortDistance * config::GFX_DISTANCE_MOD < PLANET_DIST_MAX * pixelSizeRatio * node.abs_scale * ringScale * 8.5) {
				return isSphereVisible(node.abs_position, ringScale * node.abs_scale);
			}
		}
		else {
			return node.sortDistance * config::GFX_DISTANCE_MOD < PLANET_DIST_MAX * pixelSizeRatio * node.abs_scale;
		}
		return false;
	}

	void render(Node& node) {
		bool hasAtmos = atmosMat !is null;
		if(hasAtmos && node.sortDistance * config::GFX_DISTANCE_MOD < PLANET_DIST_MAX * pixelSizeRatio * node.abs_scale)
			drawBuffers();
	
		node.applyTransform();
		
		if(Colonized)
			colonyMat.switchTo();
		else
			emptyMat.switchTo();
		model::Sphere_max.draw(node.sortDistance / (node.abs_scale * pixelSizeRatio));
		
		if(hasAtmos) {
			applyAbsTransform(vec3d(), vec3d(1.015), quaterniond_fromAxisAngle(vec3d_up(), fraction(gameTime / 240.0) * twopi));
			
			atmosMat.switchTo();
			//Use the same lod as the planet to avoid weirdness
			model::Sphere_max.draw(node.sortDistance / (node.abs_scale * pixelSizeRatio));
			undoTransform();
		}
		
		if(special == PS_Asteroids) {
			material::AsteroidPegmatite.switchTo();			
			applyAbsTransform(vec3d(2.0,2.0,2.0), vec3d(0.01), quaterniond());
			model::Asteroid.draw();
			undoTransform();
			
			material::AsteroidMagnetite.switchTo();	
			applyAbsTransform(vec3d(2.3,1.5,1.95), vec3d(0.0125), quaterniond_fromAxisAngle(vec3d(0,0.32,-0.1).normalize(), 1.3));
			model::Asteroid.draw();
			undoTransform();
			
			material::AsteroidTonalite.switchTo();
			applyAbsTransform(vec3d(2.4,2.8,2.1), vec3d(0.008), quaterniond_fromAxisAngle(vec3d(1).normalize(), 0.782));
			model::Asteroid.draw();
			undoTransform();
		}
		else if(special == PS_Ring) {
			auto ringRot = node.abs_rotation.inverted() *
				quaterniond_fromAxisAngle(vec3d_front(), ringAngle) *
				quaterniond_fromAxisAngle(vec3d_up(), ((gameTime / 30.0) % (2.0 * pi)));
			
			vec3d starDir = node.parent.abs_position - node.abs_position;
			starDir = (node.abs_rotation * ringRot).inverted() * starDir;
			
			shader::STAR_DIRECTION = vec2f(starDir.x, starDir.z);
			shader::PLANET_RING_RATIO = 1.0 / ringScale;
			shader::RING_MIN = ringMin;
			shader::RING_MAX = ringMax;
			
			applyAbsTransform(vec3d(), vec3d(ringScale), ringRot);
			ringMat.switchTo();
			model::PlanetRing.draw();
			undoTransform();
		}

		if(moons !is null && node.sortDistance < 10000) {
			for(uint i = 0, cnt = moons.length; i < cnt; ++i) {
				auto@ dat = moons[i];

				uint st = dat.style;
				double rot = fraction(gameTime / (2.0 + 20.0 * double(st % 256) / 256.0)) * twopi;
				st >> 8;
				double angle = fraction(gameTime / (10.0 + 40.0 * double(st % 256) / 256.0)) * twopi;
				st >> 8;
				double distance = double(st % 256) / 256.0 * 7.0 + 2.0;
				st >> 8;
				vec3d offset = quaterniond_fromAxisAngle(vec3d_up(), angle) * vec3d_front(distance);

				applyAbsTransform(offset, vec3d(dat.size / node.abs_scale), quaterniond_fromAxisAngle(vec3d_up(), rot));
				material::PlanetBarren.switchTo();
				model::Sphere_max.draw(node.sortDistance / (node.abs_scale * pixelSizeRatio));
				undoTransform();
			}
		}
		
		undoTransform();
	}
};

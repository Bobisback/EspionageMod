import statuses;

uint typeMask = DF_Flag1 | DF_Flag2;

enum DamageTypes {
	DT_Generic = 0,
	DT_Projectile,
	DT_Energy,
	DT_Explosive,
	DT_IgnoreDR,
};

DamageFlags QuadDRPenalty = DF_Flag3;
DamageFlags ReachedInternals = DF_Flag4;


void Damage(Event& evt, double Amount) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;

	evt.target.damage(dmg, -1.0, evt.direction);
}

void EnergyDamage(Event& evt, double Amount) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Energy | ReachedInternals;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	//if(dmg.flags & ReachedInternals != 0 && evt.target.isShip)
	//	cast<Ship>(evt.target).startFire();
}

void ExplDamage(Event& evt, double Amount) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Explosive | ReachedInternals;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	//if(dmg.flags & ReachedInternals != 0 && evt.target.isShip)
	//	cast<Ship>(evt.target).mangle(Amount);
}

void SelfDestruct(Event& evt, double Amount, double Radius, double Hits) {
	if(evt.obj.inCombat)
		AreaExplDamage(evt, Amount, Radius, Hits, 0);
}

void AreaExplDamage(Event& evt, double Amount, double Radius, double Hits) {
	AreaExplDamage(evt, Amount, Radius, Hits, 0);
}

void AreaExplDamage(Event& evt, double Amount, double Radius, double Hits, double Spillable) {
	Object@ targ = evt.target !is null ? evt.target : evt.obj;

	vec3d center = targ.position + evt.impact.normalize(targ.radius);
	array<Object@>@ objs = findInBox(center - vec3d(Radius), center + vec3d(Radius), evt.obj.owner.hostileMask);

	playParticleSystem("TorpExplosionRed", center, quaterniond(), Radius / 3.0, targ.visibleMask);

	uint hits = round(Hits);
	double maxDSq = Radius * Radius;
	
	for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
		Object@ target = objs[i];
		vec3d off = target.position - center;
		double dist = off.length - target.radius;
		if(dist > Radius)
			continue;
		
		double deal = Amount;
		if(dist > 0.0)
			deal *= 1.0 - (dist / Radius);
		
		//Rock the boat
		if(target.hasMover) {
			double amplitude = deal * 0.2 / (target.radius * target.radius);
			target.impulse(off.normalize(min(amplitude,8.0)));
			target.rotate(quaterniond_fromAxisAngle(off.cross(off.cross(target.rotation * vec3d_front())).normalize(), (randomi(0,1) == 0 ? 1.0 : -1.0) * atan(amplitude * 0.2) * 2.0));
		}
		
		DamageEvent dmg;
		@dmg.obj = evt.obj;
		@dmg.target = target;
		dmg.source_index = evt.source_index;
		dmg.flags |= DT_Projectile;
		dmg.impact = off.normalized(target.radius);
		dmg.spillable = Spillable != 0;
		
		vec2d dir = vec2d(off.x, off.z).normalized();

		for(uint n = 0; n < hits; ++n) {
			dmg.partiality = evt.partiality / double(hits);
			dmg.damage = deal * double(evt.efficiency) * double(dmg.partiality);

			target.damage(dmg, -1.0, dir);
		}
	}
}

void ProjDamage(Event& evt, double Amount, double Pierce, double Suppression) {
	ProjDamage(evt, Amount, Pierce, Suppression, 0);
}

void ProjDamage(Event& evt, double Amount, double Pierce, double Suppression, double IgnoreDR) {
	DamageEvent dmg;
	dmg.damage = Amount * double(evt.efficiency) * double(evt.partiality);
	dmg.partiality = evt.partiality;
	dmg.pierce = Pierce;
	dmg.impact = evt.impact;

	@dmg.obj = evt.obj;
	@dmg.target = evt.target;
	dmg.source_index = evt.source_index;
	dmg.flags |= DT_Projectile;

	if(IgnoreDR != 0)
		dmg.flags |= DT_IgnoreDR;

	evt.target.damage(dmg, -1.0, evt.direction);
	
	if(Suppression > 0 && evt.target.isShip) {
		double r = evt.target.radius;
		double suppress = Suppression * double(evt.efficiency) * double(evt.partiality) / (r*r*r);
		cast<Ship>(evt.target).suppress(suppress);
	}
}

void BombardDamage(Event& evt, double Amount) {
	Planet@ planet = cast<Planet>(evt.target);
	if(planet !is null)
		planet.removePopulation(Amount);
}

void SurfaceBombard(Event& evt, double Duration, double Stacks) {
	int stacks = int(Stacks);
	Planet@ planet = cast<Planet>(evt.target);
	if(planet !is null) {
		Duration /= double(planet.level) * 0.5 + 1.0;
		int status = getStatusID("Devastation");
		for(int i = 0; i < stacks; ++i)
			planet.addStatus(status, Duration);
	}
}

bool WeaponFire(const Effector& efftr, Object& obj, Object& target, float& efficiency, double supply) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return true;

	ship.consumeSupply(supply);
	return true;
}

bool RequiresSupply(const Effector& efftr, Object& obj, Object& target, float& efficiency, double supply) {
	Ship@ ship = cast<Ship>(obj);
	if(ship is null)
		return true;

	return ship.consumeMinSupply(supply);
}

DamageEventStatus CapDamage(DamageEvent& evt, const vec2u& position,
	double maxDamage, double MinimumPercent)
{
	if(evt.flags & DT_IgnoreDR != 0)
		return DE_Continue;
	if(evt.damage > maxDamage * evt.partiality)
		evt.damage = max(maxDamage * evt.partiality, evt.damage * MinimumPercent);
	return DE_Continue;
}

DamageEventStatus ReduceDamage(DamageEvent& evt, const vec2u& position,
	double ProjResist, double EnergyResist, double ExplResist, double MinPct)
{
	if(evt.flags & DT_IgnoreDR != 0)
		return DE_Continue;

	//Prevent internal-only effects
	evt.flags &= ~ReachedInternals;

	double dmg = evt.damage;
	double dr;
	switch(evt.flags & typeMask) {
		case DT_Projectile:
			dr = ProjResist; break;
		case DT_Energy:
			dr = EnergyResist; break;
		case DT_Explosive:
			dr = ExplResist; break;
		case DT_Generic:
		default:
			dr = (ProjResist + EnergyResist + ExplResist) / 3.0; break;
	}
	
	if(evt.flags & QuadDRPenalty == 0)
		dr *= 4.0;
	
	dmg -= dr * evt.partiality;
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	return DE_Continue;
}

DamageEventStatus DamageResist(DamageEvent& evt, const vec2u& position, double Amount, double MinPct)
{
	if(evt.flags & DT_IgnoreDR != 0)
		return DE_Continue;

	double dmg = evt.damage - (Amount * evt.partiality);
	double minDmg = evt.damage * MinPct;
	if(dmg < minDmg)
		dmg = minDmg;
	evt.damage = dmg;
	return DE_Continue;
}

import saving;

//Time needed for a support ship to expire if left without a leader
const double SUPPORT_EXPIRE_TIME = 3.0 * 60.0;

//Max distance a support ship can find a leader to attach to
const double MAX_LEADER_RESCUE_DIST = 1000.0;
const double MAX_LEADER_RESCUE_DIST_SQ = MAX_LEADER_RESCUE_DIST * MAX_LEADER_RESCUE_DIST;
const double MAX_SUPPORT_ABANDON_DIST = 1250.0;
const double MAX_SUPPORT_ABANDON_DIST_SQ = MAX_SUPPORT_ABANDON_DIST * MAX_SUPPORT_ABANDON_DIST;

enum SupportOrder {
	SO_Idle,
	SO_Attack,
	SO_Interfere,
	SO_Retreat
};

final class SupportAI : Component_SupportAI, Savable {
	double expire_progress = 0;
	bool findLeader = true;
	bool leaderDelta = false;
	vec3d newOffset;
	
	float psr = randomf(0.f,1.f);
	
	double engageRange = -1.0;
	SupportOrder order = SO_Idle;
	Object@ target, relTarget;

	SupportAI() {
	}

	void load(SaveFile& msg) {
		msg >> expire_progress;
		msg >> findLeader;
		msg >> newOffset;
		if(msg < SV_0054) {
			order = SO_Attack; //The ship will automatically reset to the correct state
			engageRange = 75.0;
		}
		else {
			uint o = SO_Idle;
			msg >> o;
			order = SupportOrder(o);
			msg >> target >> relTarget;
			msg >> engageRange;
			if(msg < SV_0068 && engageRange < 0.0)
				engageRange = 75.0;
		}
	}

	void save(SaveFile& msg) {
		msg << expire_progress;
		msg << findLeader;
		msg << newOffset;
		msg << uint(order);
		msg << target << relTarget;
		msg << engageRange;
	}
	
	void supportIdle(Object& obj) {
		obj.leaderLock = true;
		order = SO_Idle;
		@target = null;
		@relTarget = null;
	}
	
	void supportAttack(Object& obj, Object@ targ) {
		//Ignore attack orders if there are no weapons
		if(engageRange <= 0)
			return;
		order = SO_Attack;
		if(obj.isShip) {
			Ship@ ship = cast<Ship>(obj);
			auto@ leader = ship.Leader;
			if(targ !is null)
				ship.blueprint.target(obj, targ, TF_Preference);
		}
		@target = targ;
		@relTarget = null;
	}
	
	void supportInterfere(Object& obj, Object@ tar, Object@ protect) {
		order = SO_Interfere;
		@target = tar;
		@relTarget = protect;
	}
	
	void supportRetreat(Object& obj) {
		order = SO_Retreat;
		@target = null;
		@relTarget = null;
	}
	
	void set_supportEngageRange(double range) {
		engageRange = range;
	}

	void preventExpire() {
		expire_progress = -FLOAT_INFINITY;
	}

	//Complete a leader change received from the leader
	void completeRegisterLeader(Object& obj, Object@ leader) {
		Ship@ ship = cast<Ship>(obj);
		Object@ prevLeader = ship.Leader;
		if(prevLeader !is null)
			prevLeader.unregisterSupport(obj, false);
		@ship.Leader = leader;
		if(newOffset.lengthSQ > 0.0001)
			obj.setFleetOffset(newOffset);
		ship.triggerLeaderChange(prevLeader, leader);
		leaderDelta = true;
	}

	void clearLeader(Object& obj, Object@ prevLeader) {
		Ship@ ship = cast<Ship>(obj);
		if(ship.Leader is prevLeader) {
			@ship.Leader = null;
			ship.triggerLeaderChange(prevLeader, null);
		}
	}

	void transferTo(Object& obj, Object@ leader) {
		newOffset = vec3d();
		leader.registerSupport(obj);

		Ship@ ship = cast<Ship>(obj);
		if(ship !is null && ship.isFree)
			ship.makeNotFree();
	}

	void transferTo(Object& obj, Object@ leader, vec3d offset) {
		newOffset = offset;
		leader.registerSupport(obj);

		Ship@ ship = cast<Ship>(obj);
		if(ship !is null && ship.isFree)
			ship.makeNotFree();
	}

	void setFleetOffset(Object& obj, vec3d offset) {
		Ship@ ship = cast<Ship>(obj);
		Object@ leader = ship.Leader;
		double fradius = leader.getFormationRadius();

		if(leader !is ship.Leader)
			return;
		if(offset.length > fradius)
			return;
		ship.formationDest.xyz = offset;
		newOffset = offset;
		leaderDelta = true;
	}

	void supportDestroy(Object& obj) {
		Ship@ ship = cast<Ship>(obj);
		if(ship.Leader !is null) {
			auto@ prevLeader = ship.Leader;
			ship.Leader.unregisterSupport(obj, true);
			@ship.Leader = null;
			ship.triggerLeaderChange(prevLeader, null);
		}
		@target = null;
		@relTarget = null;
	}

	void supportScuttle(Object& obj) {
		Ship@ ship = cast<Ship>(obj);
		Object@ prevLeader = ship.Leader;
		if(prevLeader !is null)
			prevLeader.unregisterSupport(obj, false);
		findLeader = false;
		@ship.Leader = null;
		ship.triggerLeaderChange(prevLeader, null);
		obj.destroy();
		leaderDelta = true;
	}

	Object@ findNearbyLeader(Object& obj, Object& findFrom, uint depth, int size) {
		--depth;

		vec3d pos = obj.position;
		for(uint i = 0; i < TARGET_COUNT; ++i) {
			Object@ other = findFrom.targets[i];
			if(other.owner is obj.owner) {
				Object@ check = other;
				if(check.isShip && check.hasSupportAI)
					@check = cast<Ship>(check).Leader;
				if(check !is null && check.hasLeaderAI) {
					if(pos.distanceToSQ(check.position) < MAX_LEADER_RESCUE_DIST_SQ && check.canTakeSupport(size))
						return check;
				}
			}

			if(depth != 0) {
				@other = findNearbyLeader(obj, other, depth, size);
				if(other !is null)
					return other;
			}
		}

		return null;
	}

	void supportTick(Object& obj, double time) {
		Ship@ ship = cast<Ship>(obj);
		Object@ leader = ship.Leader;

		//Tick forward the expiration
		if(leader is null) {
			if(ship.velocity.lengthSQ > 0.01)
				ship.stopMoving(false);
			expire_progress += time;
			if(expire_progress > SUPPORT_EXPIRE_TIME + (double(uint8(obj.id)) / 128.0) - 1.0) {
				obj.destroy();
				return;
			}
		}
		else if(expire_progress > time) {
			expire_progress -= time;
		}
		else {
			expire_progress = 0;
		}

		if(leader !is null) {
			if(leader.owner !is obj.owner
				|| (ship.position.distanceToSQ(leader.position) > MAX_SUPPORT_ABANDON_DIST_SQ
						&& (ship.region is null || ship.region !is leader.region)
						&& !ship.isFTLing && (!leader.isShip || !cast<Ship>(leader).isFTLing))) {
				//We tell the leader we died, as we are being abandoned and will probably die
				leader.unregisterSupport(obj, true);
				auto@ prevLeader = ship.Leader;
				@ship.Leader = null;
				ship.triggerLeaderChange(prevLeader, null);
			}
			else {
				switch(order) {
					case SO_Idle:
						if(engageRange > 0) {
							Object@ targ = ship.blueprint.getCombatTarget();
							if(targ is null) {
								for(uint i = 0; i < TARGET_COUNT; ++i) {
									Object@ t = obj.targets[i];
									if(obj.owner.isHostile(t.owner) && ship.blueprint.canTarget(obj, t)) {
										@targ = t;
										break;
									}
								}
							}
							
							if(targ !is null && obj.owner.isHostile(targ.owner))
								supportAttack(obj, targ);
						}
						else {
							Object@ targ;
							for(uint i = 0; i < TARGET_COUNT; ++i) {
								Object@ t = obj.targets[i];
								if(obj.owner.isHostile(t.owner) && (t.isShip || t.isOrbital)) {
									@targ = t;
									break;
								}
							}
							
							if(targ !is null)
								supportInterfere(obj, leader, targ);
						}
						break;
					case SO_Attack:
						if(target is null || !target.valid || !obj.owner.isHostile(target.owner)) {
							supportIdle(obj);
						}
						else {
							vec3d dest = leader.position + obj.internalDestination;
							double fleetRad = leader.getFormationRadius();
							//If the target is out of range, return to the fleet
							if(leader.position.distanceToSQ(target.position) > sqr(engageRange + fleetRad)) {
								supportIdle(obj);
								break;
							}
							
							vec3d fireFrom = obj.leaderLock ? obj.position : dest;
							
							bool relocate = fireFrom.distanceToSQ(target.position) > engageRange * engageRange || fireFrom.distanceToSQ(leader.position) > fleetRad * fleetRad || obj.isColliding;
							if(!relocate) {
								if(obj.leaderLock || obj.position.distanceToSQ(dest) < obj.radius * obj.radius) {
									line3dd line = line3dd(obj.position, target.position);
									Object@ hit = trace(line, obj.owner.hostileMask | 0x1);
									if(hit !is target)
										relocate = true;
								}
							}
							
							if(relocate) {
								vec3d off = target.position - leader.position;
								double innerDist = leader.radius + obj.radius;
								vec3d dest = random3d(innerDist, fleetRad);
								if((dest + leader.position).distanceToSQ(target.position) < engageRange * engageRange) {
									line3dd line = line3dd(dest + leader.position, target.position);
									Object@ hit = trace(line, obj.owner.hostileMask | 0x1);
									if(hit is target) {
										int moveId = -1;
										obj.leaderLock = false;
										obj.moveTo(dest, moveId, doPathing=false, enterOrbit=false);
									}
								}
							}
						}
						break;
					case SO_Interfere:
						if(target is null || relTarget is null || !target.valid || !relTarget.valid || !obj.owner.isHostile(target.owner))
							supportIdle(obj);
						else {
							double fleetRad = leader.getFormationRadius();
							line3dd path = line3dd(leader.position, target.position);
							double targDist = path.length;
							
							if(targDist > fleetRad * 4.0) {
								supportIdle(obj);
								break;
							}
							
							vec3d curDest = leader.position + obj.internalDestination;
							vec3d pt = path.getClosestPoint(curDest, false);
							if(obj.leaderLock || pt.distanceToSQ(curDest) > obj.radius * obj.radius) {							
								double outerDist = targDist - obj.radius * 1.5 - target.radius;
								if(outerDist > fleetRad)
									outerDist = fleetRad;
								
								double innerDist = leader.radius + obj.radius * 1.5;
								vec3d dest = path.direction * (innerDist + (outerDist - innerDist) * psr) + random3d(obj.radius * 0.5);
								int moveId = -1;
								obj.leaderLock = false;
								obj.moveTo(dest, moveId, doPathing=false, enterOrbit=false);
							}
						}
						break;
					case SO_Retreat:
						supportIdle(obj);
						break;
				}
			}
		}
		else if(findLeader) {
			//Try to find a new leader
			Object@ newLeader = findNearbyLeader(obj, obj, 2, ship.blueprint.design.size);
			if(newLeader !is null)
				newLeader.registerSupport(obj, true);
		}
	}

	void writeSupportAI(const Object& obj, Message& msg) {
		const Ship@ ship = cast<const Ship>(obj);
		msg << ship.Leader;
	}

	bool writeSupportAIDelta(const Object& obj, Message& msg) {
		const Ship@ ship = cast<const Ship>(obj);
		if(leaderDelta) {
			msg.write1();
			msg << ship.Leader;
			leaderDelta = false;
			return true;
		}
		return false;
	}
};

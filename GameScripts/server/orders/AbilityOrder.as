import orders.Order;
import saving;

class AbilityOrder : Order {
	int abilityId = -1;
	int moveId = -1;
	double range = 100.0;
	vec3d target;
	Object@ objTarget;

	AbilityOrder(int id, vec3d targ, double range) {
		abilityId = id;
		target = targ;
		this.range = range;
	}

	AbilityOrder(int id, Object@ targ, double range) {
		abilityId = id;
		@objTarget = targ;
		this.range = range;
	}

	bool get_hasMovement() {
		return true;
	}

	vec3d getMoveDestination(const Object& obj) {
		if(objTarget !is null)
			return objTarget.position;
		return target;
	}

	AbilityOrder(SaveFile& file) {
		Order::load(file);
		file >> target;
		file >> moveId;
		file >> abilityId;
		file >> objTarget;
	}

	void save(SaveFile& file) {
		Order::save(file);
		file << target;
		file << moveId;
		file << abilityId;
		if(file >= SV_0081)
			file << objTarget;
	}

	string get_name() {
		return "Use Ability";
	}

	OrderType get_type() {
		return OT_Ability;
	}

	OrderStatus tick(Object& obj, double time) {
		if(!obj.hasMover)
			return OS_COMPLETED;

		if(objTarget !is null) {
			double distSQ = obj.position.distanceToSQ(objTarget.position);
			if(distSQ > range * range && ! obj.moveTo(objTarget, moveId, range)) {
				return OS_BLOCKING;
			}
			else {
				if(moveId != -1) {
					obj.stopMoving();
					moveId = -1;
				}
				if(obj.isAbilityOnCooldown(abilityId))
					return OS_BLOCKING;
				obj.activateAbility(abilityId, objTarget);
				return OS_COMPLETED;
			}
		}
		else {
			double distSQ = obj.position.distanceToSQ(target);
			if(distSQ > range * range) {
				obj.moveTo(target, moveId);
				return OS_BLOCKING;
			}
			else {
				if(moveId != -1) {
					obj.stopMoving();
					moveId = -1;
				}
				if(obj.isAbilityOnCooldown(abilityId))
					return OS_BLOCKING;
				obj.activateAbility(abilityId, target);
				return OS_COMPLETED;
			}
		}
	}
};

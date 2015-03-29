import generic_effects;
import hooks;

class SubsystemEffect : SubsystemHook, Hook, RegionChangeable, LeaderChangeable {
#section server
	void start(SubsystemEvent& event) const {}
	void tick(SubsystemEvent& event, double time) const {}
	void suspend(SubsystemEvent& event) const {}
	void resume(SubsystemEvent& event) const {}
	void destroy(SubsystemEvent& event) const {}
	void end(SubsystemEvent& event) const {}
	void change(SubsystemEvent& event) const {}
	void ownerChange(SubsystemEvent& event, Empire@ prevOwner, Empire@ newOwner) const {}

	DamageEventStatus damage(SubsystemEvent& event, DamageEvent& damage, const vec2u& position) const {
		return DE_Continue;
	}

	DamageEventStatus globalDamage(SubsystemEvent& event, DamageEvent& damage, const vec2u& position, vec2d& endPoint) const {
		return DE_Continue;
	}

	void preRetrofit(SubsystemEvent& event) const {}
	void postRetrofit(SubsystemEvent& event) const {}

	void save(SubsystemEvent& event, SaveFile& file) const {}
	void load(SubsystemEvent& event, SaveFile& file) const {}
#section all

	void regionChange(SubsystemEvent& event, Region@ prevRegion, Region@ newRegion) const {}
	void leaderChange(SubsystemEvent& event, Object@ prevLeader, Object@ newLeader) const {}
};

class AddSupplyToFleet : SubsystemEffect {
	Document doc("Add a bonus amount of supply storage to the fleet.");
	Argument amount(AT_Decimal, doc="Amount of supply capacity to add.");
	Argument leakpctpersec(AT_Decimal, doc="Drain rate per second when fully damaged.");

#section server
	void tick(SubsystemEvent& event, double time) const override {
		if(event.workingPercent <= 1.0) {
			Ship@ ship = cast<Ship>(event.obj);
			Ship@ leader = cast<Ship>(ship.Leader);
			if(leader !is null)
				leader.consumeSupply(ship.MaxSupply * leakpctpersec.decimal * (1.0 - sqr(event.workingPercent)) * time);
		}
	}

	void leaderChange(SubsystemEvent& event, Object@ prevLeader, Object@ newLeader) const override {
		if(prevLeader !is null && prevLeader.isShip)
			cast<Ship>(prevLeader).modSupplyBonus(-amount.decimal);
		if(newLeader !is null && newLeader.isShip)
			cast<Ship>(newLeader).modSupplyBonus(+amount.decimal);
	}
#section all
};

class AddPermanentStatus : SubsystemEffect {
	Document doc("Add a status that doesn't go away during a retrofit.");
	Argument status(AT_Status, doc="Status to add.");

#section server
	void start(SubsystemEvent& event) const {
		if(event.obj.hasStatuses && !event.obj.hasStatusEffect(status.integer))
			event.obj.addStatus(status.integer);
	}
#section all
};

import hooks;
import influence;
from bonus_effects import BonusEffect;
import hook_globals;
import systems;

#section server
from influence_global import createInfluenceEffect;
#section all

//ClaimPlanet(<Event>, <Target>)
// Claim <Target> planet if <Event> happens.
// <Event> should be one of 'pass' or 'fail'.
class ClaimPlanet : InfluenceVoteEffect {
	Document doc("Claims a target planet when the vote passes or fails.");
	Argument event("Event", AT_PassFail, doc="Either 'pass' or 'fail' to choose when the result occurs.");
	Argument targ("Target", TT_Object);

#section server
	void onStart(InfluenceVote@ vote) const override {
		Object@ obj = targ.fromTarget(vote.targets).obj;
		obj.setContestion(true);
	}

	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const override {
		Object@ obj = targ.fromTarget(vote.targets).obj;
		if(passed == event.boolean)
			obj.takeoverPlanet(vote.startedBy, 0.5);
		obj.setContestion(false);
	}
#section all
};

//CreateEffect(<Event>, <Effect>, <Target>, <Duration> = 0)
// Create a new influence effect if <Event> happens.
// <Event> should be one of 'pass' or 'fail'.
// If duration is set to 0, the default from the effect is used.
class CreateEffect : InfluenceVoteEffect {
	Document doc("Starts a new influence effect when the vote passes or fails.");
	Argument event("Event", AT_PassFail, doc="Either 'pass' or 'fail' to choose when the result occurs.");
	Argument effect("Effect", AT_InfluenceEffect, doc="ID of the influence effect to create.");
	Argument targ("Target", TT_Any, EMPTY_DEFAULT);
	Argument duration("Duration", AT_Decimal, "0", doc="Duration in seconds for the effect to last.");
	Argument give_to_contributor(AT_Boolean, "False", doc="If set, the effect is given to the highest contributor of the vote, instead of the empire that started it.");
	const InfluenceEffectType@ effectType;

	void init(InfluenceVoteType@ type) override {
		@effectType = getInfluenceEffectType(effect.str);
		if(effectType is null)
			error("Error: CreateEffect() could not find effect "+effect.str);
	}

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != event.boolean)
			return;

		Targets effTargs = effectType.targets;
		if(targ.integer != -1 && effTargs.targets.length != 0)
			effTargs.targets[0] = targ.fromTarget(vote.targets);

		Empire@ owner = vote.startedBy;
		if(give_to_contributor.boolean) {
			Empire@ contrib = vote.highestContribPoints;
			if(contrib !is null && vote.getVoteFrom(contrib) != 0)
				@owner = contrib;
		}
		createInfluenceEffect(owner, effectType, effTargs, duration.decimal);
	}
#section all
};

//Trigger(<Object>, <Hook>(...), <Event> = Pass)
// Run <Hook> as a single-time effect hook on <Planet>.
class Trigger : InfluenceVoteEffect {
	Document doc("Triggers another hook when the vote passes or fails.");
	Argument targ("Object", TT_Object);
	Argument hookID("Hook", AT_Hook, "bonus_effects::EmpireTrigger", doc="Hook to trigger.");
	Argument event("Event", AT_PassFail, "Pass", doc="Either 'pass' or 'fail' to choose when the result occurs.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(arguments[1].str, "bonus_effects::"));
		if(hook is null) {
			error("BonusEffect(): could not find inner hook: "+escape(arguments[1].str));
			return false;
		}
		return InfluenceVoteEffect::instantiate();
	}

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != arguments[2].boolean)
			return;
		auto@ objTarg = arguments[0].fromTarget(vote.targets);
		if(objTarg is null || objTarg.obj is null)
			return;
		hook.activate(objTarg.obj, vote.startedBy);

	}
#section all
};

class TriggerHighestContributor : InfluenceVoteEffect {
	Document doc("Trigger an effect on the empire that contributed the most to this vote.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::EmpireTrigger", doc="Hook to trigger.");
	Argument event("Event", AT_PassFail, "Pass", doc="Either 'pass' or 'fail' to choose when the result occurs.");
	Argument randomize(AT_Boolean, "False", doc="Whether to pick a random one if multiple empires apply.");
	Argument multiple(AT_Boolean, "True", doc="Whether to apply to all empires if multiple empires apply.");
	Argument require_positive(AT_Boolean, "True", doc="Whether to require at least 1 support to trigger, or allow triggering on 0 as well.");
	Argument use_points(AT_Boolean, "True", doc="Whether to judge contributions by integrated contribution points over time. If set to false, only the final support value of each empire is used.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::"));
		if(hook is null) {
			error("BonusEffect(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return InfluenceVoteEffect::instantiate();
	}

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != event.boolean)
			return;

		double highest = -INFINITY;
		if(require_positive.boolean)
			highest = 0.01;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			if(!getEmpire(i).major)
				continue;
			double val = 0;
			if(use_points.boolean)
				val = vote.contribPoints[i];
			else
				val = vote.empireVotes[i];

			if(val > highest)
				highest = val;
		}

		array<Empire@> choices;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			if(!getEmpire(i).major)
				continue;
			double val = 0;
			if(use_points.boolean)
				val = vote.contribPoints[i];
			else
				val = vote.empireVotes[i];

			if(val >= highest - 0.0001)
				choices.insertLast(getEmpire(i));
		}

		if(choices.length == 0) {
			return;
		}
		else if(choices.length == 1) {
			hook.activate(null, choices[0]);
		}
		else {
			if(randomize.boolean) {
				Empire@ targ = choices[randomi(0, choices.length-1)];
				hook.activate(null, choices[0]);
			}
			else if(multiple.boolean) {
				for(uint i = 0, cnt = choices.length; i < cnt; ++i)
					hook.activate(null, choices[i]);
			}
		}
	}
#section all
};

class TriggerLowestContributor : InfluenceVoteEffect {
	Document doc("Trigger an effect on the empire that contributed the least to this vote.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::EmpireTrigger", doc="Hook to trigger.");
	Argument event("Event", AT_PassFail, "Pass", doc="Either 'pass' or 'fail' to choose when the result occurs.");
	Argument randomize(AT_Boolean, "False", doc="Whether to pick a random one if multiple empires apply.");
	Argument multiple(AT_Boolean, "True", doc="Whether to apply to all empires if multiple empires apply.");
	Argument require_negative(AT_Boolean, "False", doc="Whether to only trigger for empires that actually opposed, instead of just being the lowest support.");
	Argument use_points(AT_Boolean, "True", doc="Whether to judge contributions by integrated contribution points over time. If set to false, only the final support value of each empire is used.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::"));
		if(hook is null) {
			error("BonusEffect(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return InfluenceVoteEffect::instantiate();
	}

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != event.boolean)
			return;

		double lowest = INFINITY;
		if(require_negative.boolean)
			lowest = -0.01;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			if(!getEmpire(i).major)
				continue;
			double val = 0;
			if(use_points.boolean)
				val = vote.contribPoints[i];
			else
				val = vote.empireVotes[i];

			if(val < lowest)
				lowest = val;
		}

		array<Empire@> choices;
		for(uint i = 0, cnt = getEmpireCount(); i < cnt; ++i) {
			if(!getEmpire(i).major)
				continue;
			double val = 0;
			if(use_points.boolean)
				val = vote.contribPoints[i];
			else
				val = vote.empireVotes[i];

			if(val <= lowest + 0.0001)
				choices.insertLast(getEmpire(i));
		}

		if(choices.length == 0) {
			return;
		}
		else if(choices.length == 1) {
			hook.activate(null, choices[0]);
		}
		else {
			if(randomize.boolean) {
				Empire@ targ = choices[randomi(0, choices.length-1)];
				hook.activate(null, choices[0]);
			}
			else if(multiple.boolean) {
				for(uint i = 0, cnt = choices.length; i < cnt; ++i)
					hook.activate(null, choices[i]);
			}
		}
	}
#section all
};

class OnOwner : InfluenceVoteEffect {
	Document doc("Triggers an empire hook when the vote passes or fails.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to trigger.");
	Argument event("Event", AT_PassFail, "Pass", doc="Either 'pass' or 'fail' to choose when the result occurs.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(hookID.str, "bonus_effects::"));
		if(hook is null) {
			error("BonusEffect(): could not find inner hook: "+escape(hookID.str));
			return false;
		}
		return InfluenceVoteEffect::instantiate();
	}

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != event.boolean)
			return;
		hook.activate(null, vote.startedBy);

	}
#section all
};

//CancelOnWar(<Target>)
// Cancel the vote when the owner becomes at war with the target.
class CancelOnWar : InfluenceVoteEffect {
	Document doc("Ends the vote when the vote starter is at war with the target.");
	Argument targ("Target", TT_Empire);

#section server
	bool onTick(InfluenceVote@ vote, double time) const override {
		Empire@ to = arguments[0].fromTarget(vote.targets).emp;
		if(vote.startedBy !is null && vote.startedBy.isHostile(to))
			vote.end(false, true);
		return false;
	}
#section all
};

//CancelOnDestroyed(<Target>)
// Cancel the vote when the target is no longer valid.
class CancelOnDestroyed : InfluenceVoteEffect {
	Document doc("Ends the vote when the target object is no longer valid (destroyed).");
	Argument targ("Target", TT_Object);

#section server
	bool onTick(InfluenceVote@ vote, double time) const override {
		Object@ obj = arguments[0].fromTarget(vote.targets).obj;
		if(obj is null || !obj.valid)
			vote.end(false, true);
		return false;
	}
#section all
};

//CancelOnLost(<Target>)
// Cancel the vote when the target is no longer ours.
class CancelOnLost : InfluenceVoteEffect {
	Document doc("Ends the vote when the target object is no longer owned by this empire.");
	Argument targ("Target", TT_Object);

#section server
	bool onTick(InfluenceVote@ vote, double time) const override {
		Object@ obj = arguments[0].fromTarget(vote.targets).obj;
		if(obj is null || !obj.valid || obj.owner !is vote.startedBy)
			vote.end(false, true);
		return false;
	}
#section all
};

//ClaimSystem(<Event>, <Target>)
// Claim all planets in <Target> system if <Event> happens.
// <Event> should be one of 'pass' or 'fail'.
class ClaimSystem : InfluenceVoteEffect {
	Document doc("Claims a target system when the vote passes or fails.");
	Argument event("Event", AT_PassFail, doc="Either 'pass' or 'fail' to choose when the result occurs.");
	Argument targ("Target", TT_Object);

#section server
	void onStart(InfluenceVote@ vote) const {
		Object@ obj = arguments[1].fromTarget(vote.targets).obj;
		for(uint i = 0, cnt = obj.planetCount; i < cnt; ++i) {
			Planet@ pl = obj.planets[i];
			if(pl !is null && pl.owner !is null && pl.owner !is vote.startedBy && pl.owner.valid)
				obj.planets[i].setContestion(true);
		}
	}

	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != arguments[0].boolean)
			return;

		Object@ obj = arguments[1].fromTarget(vote.targets).obj;
		for(uint i = 0, cnt = obj.planetCount; i < cnt; ++i) {
			Planet@ pl = obj.planets[i];
			if(pl !is null && pl.owner !is null && pl.owner !is vote.startedBy && pl.owner.valid) {
				pl.takeoverPlanet(vote.startedBy, 0.5);
				pl.setContestion(true);
			}
		}
	}
#section all
};

//FlagContested(<Target>)
// Mark <Target> as contested for the duration of the vote.
class FlagContested : InfluenceVoteEffect {
	Document doc("Marks an object as contested while the vote is in progress.");
	Argument targ("Target", TT_Object);

#section server
	void onStart(InfluenceVote@ vote) const {
		Object@ obj = arguments[0].fromTarget(vote.targets).obj;
		if(obj.isPlanet)
			obj.setContestion(true);
		else if(obj.isOrbital)
			cast<Orbital>(obj).setContested(true);
	}

	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		Object@ obj = arguments[0].fromTarget(vote.targets).obj;
		if(obj.isPlanet)
			obj.setContestion(false);
		else if(obj.isOrbital)
			cast<Orbital>(obj).setContested(false);
	}
#section all
};

//ModGlobal(<Event>, <Global>, <Amount>)
// Modify a global value when an event happens.
class ModGlobal : InfluenceVoteEffect {
	Document doc("Adds a value to a global when the vote passes or fails.");
	Argument event("Event", AT_PassFail, doc="Either 'pass' or 'fail' to choose when the result occurs.");
	Argument global("Global", AT_Global, doc="Which global value to modify.");
	Argument amount("Amount", AT_Decimal, doc="Amount to modify it by.");

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const override {
		if(passed == arguments[0].boolean) {
			auto@ glob = getGlobal(arguments[1].integer);
			glob.add(arguments[2].decimal);
		}
	}
#section all
};

//TriggerAllPlanets(<Hook>(...), <Event> = Pass)
// Run <Hook> as a single-time effect hook on all planets in the galaxy.
class TriggerAllPlanets : InfluenceVoteEffect {
	Document doc("Runs another hook on all planets when the vote passes or fails.");
	Argument hookID("Hook", AT_Hook, "bonus_effects::BonusEffect", doc="Hook to trigger.");
	Argument event("Event", AT_PassFail, "Pass", doc="Either 'pass' or 'fail' to choose when the result occurs.");
	BonusEffect@ hook;

	bool instantiate() override {
		@hook = cast<BonusEffect>(parseHook(arguments[0].str, "bonus_effects::"));
		if(hook is null) {
			error("BonusEffect(): could not find inner hook: "+escape(arguments[0].str));
			return false;
		}
		return InfluenceVoteEffect::instantiate();
	}

#section server
	void onEnd(InfluenceVote@ vote, bool passed, bool withdrawn) const {
		if(passed != arguments[1].boolean)
			return;
		for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
			auto@ sys = getSystem(i);
			for(uint n = 0, ncnt = sys.object.planetCount; n < ncnt; ++n) {
				Object@ obj = sys.object.planets[n];
				hook.activate(obj, vote.startedBy);
			}
		}
	}
#section all
};

class AddStartWeight : InfluenceVoteEffect {
	Document doc("Add an amount of weight to the vote when it is started.");
	Argument weight(AT_Integer, doc="Amount of weight to add.");

#section server
	void onStart(InfluenceVote@ vote) const {
		if(weight.integer > 0)
			vote.totalFor += weight.integer;
		else
			vote.totalAgainst -= weight.integer;
	}
#section all
};

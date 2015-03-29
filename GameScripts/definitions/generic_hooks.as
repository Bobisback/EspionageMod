import buildings;
from buildings import IBuildingHook;
import resources;
import util.formatting;
import systems;
import saving;
import influence;
from influence import InfluenceStore, IInfluenceEffectEffect;
from statuses import IStatusHook, Status, StatusInstance;
from resources import integerSum, decimalSum;
from traits import ITraitEffect;
from bonus_effects import BonusEffect;
import orbitals;
from orbitals import IOrbitalEffect;
import attributes;
import hook_globals;
import research;

class GenericEffect : Hook, IResourceHook, IBuildingHook, IStatusHook, IOrbitalEffect, SubsystemHook, RegionChangeable, LeaderChangeable {
	uint hookIndex = 0;

	//Generic reusable hooks
	void enable(Object& obj, any@ data) const {}
	void disable(Object& obj, any@ data) const {}
	void tick(Object& obj, any@ data, double time) const {}
	void ownerChange(Object& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const {}
	void regionChange(Object& obj, any@ data, Region@ fromRegion, Region@ toRegion) const {}
	void save(any@ data, SaveFile& file) const {}
	void load(any@ data, SaveFile& file) const {}

	//Lets this be used as a resource hook
	void initialize(ResourceType@ type, uint index) { hookIndex = index; }
	bool canTerraform(Object@ from, Object@ to) const { return true; }
	void applyGraphics(Object& obj, Node& node) const {}
	void onTerritoryAdd(Object& obj, Resource@ r, Territory@ terr) const {}
	void onTerritoryRemove(Object& obj, Resource@ r, Territory@ terr) const {}
	bool get_hasEffect() const { return false; }
	bool mergesEffect(Object& obj, const IResourceHook@ other) const {
		if(getClass(other) !is getClass(this))
			return false;
		return mergesEffect(cast<const GenericEffect>(other));
	}
	bool mergesEffect(const GenericEffect@ eff) const { return true; }
	string formatEffect(Object& obj, array<const IResourceHook@>& hooks) const { return "---"; }
	const IResourceHook@ get_carriedHook() const { return null; }
	const IResourceHook@ get_displayHook() const { return this; }
	void onGenerate(Object& obj, Resource@ native) const {}
	void nativeTick(Object&, Resource@ native, double time) const {}
	void onDestroy(Object&, Resource@ native) const {}
	void nativeSave(Resource@ native, SaveFile& file) const {}
	void nativeLoad(Resource@ native, SaveFile& file) const {}
	bool shouldVanish(Object& obj, Resource@ native) const { return false; }
	void onAdd(Object& obj, Resource@ r) const { enable(obj, r.data[hookIndex]); }
	void onRemove(Object& obj, Resource@ r) const { disable(obj, r.data[hookIndex]); }
	void onTick(Object& obj, Resource@ r, double time) const { tick(obj, r.data[hookIndex], time); }
	void onTradeDeliver(Civilian& civ, Object@ origin, Object@ target) const {}
	void onTradeDestroy(Civilian& civ, Object@ origin, Object@ target, Object@ destroyer) const {}
	void onOwnerChange(Object& obj, Resource@ r, Empire@ prevOwner, Empire@ newOwner) const {
		ownerChange(obj, r.data[hookIndex], prevOwner, newOwner);
	}
	void onRegionChange(Object& obj, Resource@ r, Region@ fromRegion, Region@ toRegion) const {
		regionChange(obj, r.data[hookIndex], fromRegion, toRegion);
	}
	void save(Resource@ r, SaveFile& file) const {
		save(r.data[hookIndex], file);
	}
	void load(Resource@ r, SaveFile& file) const {
		load(r.data[hookIndex], file);
	}

	//Lets this be used as a building hook
	void initialize(BuildingType@ type, uint index) { hookIndex = index; }
	void startConstruction(Object& obj, SurfaceBuilding@ bld) const {}
	void cancelConstruction(Object& obj, SurfaceBuilding@ bld) const {}
	void complete(Object& obj, SurfaceBuilding@ bld) const { enable(obj, bld.data[hookIndex]); }
	void remove(Object& obj, SurfaceBuilding@ bld) const { disable(obj, bld.data[hookIndex]); }
	void ownerChange(Object& obj, SurfaceBuilding@ bld, Empire@ prevOwner, Empire@ newOwner) const {
		ownerChange(obj, bld.data[hookIndex], prevOwner, newOwner);
	}
	void tick(Object& obj, SurfaceBuilding@ bld, double time) const {
		tick(obj, bld.data[hookIndex], time);
	}
	bool canBuildOn(Object& obj, bool ignoreState = false) const { return true; }
	bool canRemove(Object& obj) const { return true; }
	void save(SurfaceBuilding@ bld, SaveFile& file) const { save(bld.data[hookIndex], file); }
	void load(SurfaceBuilding@ bld, SaveFile& file) const { load(bld.data[hookIndex], file); }
	bool getVariable(Object@ obj, Sprite& sprt, string& name, string& value, Color& color, bool isOption) const {
		return false;
	}

	//Lets this be used as a status hook
	// Planet effects do not deal with status stacks, so they will only
	// trigger once per status, regardless of collapsing.
	void onCreate(Object& obj, Status@ status, any@ data) { enable(obj, data); }
	void onDestroy(Object& obj, Status@ status, any@ data) { disable(obj, data); }
	void onObjectDestroy(Object& obj, Status@ status, any@ data) {}
	bool onTick(Object& obj, Status@ status, any@ data, double time) { tick(obj, data, time); return true; }
	void onAddStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) {}
	void onRemoveStack(Object& obj, Status@ status, StatusInstance@ instance, any@ data) {}
	bool onOwnerChange(Object& obj, Status@ status, any@ data, Empire@ prevOwner, Empire@ newOwner) {
		ownerChange(obj, data, prevOwner, newOwner); return true; }
	bool onRegionChange(Object& obj, Status@ status, any@ data, Region@ prevRegion, Region@ newRegion) {
		regionChange(obj, data, prevRegion, newRegion); return true; }
	void save(Status@ status, any@ data, SaveFile& file) { save(data, file); }
	void load(Status@ status, any@ data, SaveFile& file) { load(data, file); }
	bool shouldApply(Empire@ emp, Region@ region, Object@ obj) const { return true; }
	bool getVariable(Object@ obj, Sprite& sprt, string& name, string& value, Color& color) const { return false; }

	//Lets this be used as an orbital hook
	void onEnable(Orbital& obj, any@ data) const { enable(obj, data); }
	void onDisable(Orbital& obj, any@ data) const { disable(obj, data); }
	void onCreate(Orbital& obj, any@ data) const {}
	void onDestroy(Orbital& obj, any@ data) const {}
	void onTick(Orbital& obj, any@ data, double time) const { tick(obj, data, time); }
	void onOwnerChange(Orbital& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const {
		ownerChange(obj, data, prevOwner, newOwner);
	}
	void onRegionChange(Orbital& obj, any@ data, Region@ prevRegion, Region@ newRegion) const {
		regionChange(obj, data, prevRegion, newRegion);
	}
	void onMakeGraphics(Orbital& obj, any@ data, OrbitalNode@ node) const {}
	bool checkRequirements(OrbitalRequirements@ reqs, bool apply) const { return true; }
	void revertRequirements(OrbitalRequirements@ reqs) const {}
	bool canBuildBy(Object@ obj) const { return true; }
	bool canBuildOn(Orbital& obj) const { return true; }
	bool shouldDisable(Orbital& obj, any@ data) const { return false; }
	bool shouldEnable(Orbital& obj, any@ data) const { return true; }
	void onKill(Orbital& obj, any@ data, Empire@ killedBy) const {}
	void write(any@ data, Message& msg) const {}
	void read(any@ data, Message& msg) const {}
	bool getValue(Player& pl, Orbital& obj, any@ data, uint index, double& value) const { return false; }
	bool sendValue(Player& pl, Orbital& obj, any@ data, uint index, double value) const { return false; }
	bool getDesign(Player& pl, Orbital& obj, any@ data, uint index, const Design@& value) const { return false; }
	bool sendDesign(Player& pl, Orbital& obj, any@ data, uint index, const Design@ value) const { return false; }
	bool getObject(Player& pl, Orbital& obj, any@ data, uint index, Object@& value) const { return false; }
	bool sendObject(Player& pl, Orbital& obj, any@ data, uint index, Object@ value) const { return false; }
	bool getData(Orbital& obj, string& txt, bool enabled) const { return false; }
	bool canBuildAt(Object@ obj, const vec3d& pos) const { return true; }
	string getBuildError(Object@ obj, const vec3d& pos) const { return ""; }

	//Subsystem hooks
	void start(SubsystemEvent& event) const { enable(event.obj, event.data); }
	void tick(SubsystemEvent& event, double time) const { tick(event.obj, event.data, time); }
	void suspend(SubsystemEvent& event) const { disable(event.obj, event.data); }
	void resume(SubsystemEvent& event) const { enable(event.obj, event.data); }
	void destroy(SubsystemEvent& event) const {}
	void end(SubsystemEvent& event) const { disable(event.obj, event.data); }
	void change(SubsystemEvent& event) const {}
	void ownerChange(SubsystemEvent& event, Empire@ prevOwner, Empire@ newOwner) const {
		ownerChange(event.obj, event.data, prevOwner, newOwner);
	}
	void regionChange(SubsystemEvent& event, Region@ prevRegion, Region@ newRegion) const {
		regionChange(event.obj, event.data, prevRegion, newRegion);
	}
	void leaderChange(SubsystemEvent& event, Object@ prevLeader, Object@ newLeader) const {}

	DamageEventStatus damage(SubsystemEvent& event, DamageEvent& damage, const vec2u& position) const {
		return DE_Continue;
	}

	DamageEventStatus globalDamage(SubsystemEvent& event, DamageEvent& damage, const vec2u& position, vec2d& endPoint) const {
		return DE_Continue;
	}

	void preRetrofit(SubsystemEvent& event) const {}
	void postRetrofit(SubsystemEvent& event) const {}
	void save(SubsystemEvent& event, SaveFile& file) const { save(event.data, file); }
	void load(SubsystemEvent& event, SaveFile& file) const { load(event.data, file); }
};

interface TriggerableGeneric {
};

interface RegionChangeable {
	void regionChange(SubsystemEvent& event, Region@ prevRegion, Region@ newRegion) const;
};

interface LeaderChangeable {
	void leaderChange(SubsystemEvent& event, Object@ prevLeader, Object@ newLeader) const;
};

interface ShowsRange {
	bool getShowRange(Object& obj, double& range, Color& color) const;
};

class EmpireEffect : GenericEffect, IInfluenceEffectEffect, ITraitEffect {
	void enable(Empire& emp, any@ data) const {}
	void disable(Empire& emp, any@ data) const {}
	void tick(Empire& emp, any@ data, double time) const {}
	void save(any@ data, SaveFile& file) const {}
	void load(any@ data, SaveFile& file) const {}
	
	//Generic effects on objects
	void enable(Object& obj, any@ data) const { if(obj.owner !is null) enable(obj.owner, data); }
	void disable(Object& obj, any@ data) const { if(obj.owner !is null) disable(obj.owner, data); }
	void tick(Object& obj, any@ data, double time) const { if(obj.owner !is null) tick(obj.owner, data, time); }
	void ownerChange(Object& obj, any@ data, Empire@ prevOwner, Empire@ newOwner) const {
		if(prevOwner !is null)
			disable(prevOwner, data);
		if(newOwner !is null)
			enable(newOwner, data);
	}
	void regionChange(Object& obj, any@ data, Region@ fromRegion, Region@ toRegion) const {}

	//Influence effects
	void set_dataIndex(uint ind) { hookIndex = ind; }

	void init(InfluenceEffectType@ type) {}
	void onStart(InfluenceEffect@ effect) const { enable(effect.owner, effect.data[hookIndex]); }
	bool onTick(InfluenceEffect@ effect, double time) const { tick(effect.owner, effect.data[hookIndex], time); return false; }
	void onDismiss(InfluenceEffect@ effect, Empire@ byEmpire) const {}
	void onEnd(InfluenceEffect@ effect) const { disable(effect.owner, effect.data[hookIndex]); }
	bool canDismiss(const InfluenceEffect@ effect, Empire@ byEmpire) const { return true; }
	void save(InfluenceEffect@ effect, SaveFile& file) const { save(effect.data[hookIndex], file); }
	void load(InfluenceEffect@ effect, SaveFile& file) const { load(effect.data[hookIndex], file); }

	//Trait effects
	void preInit(Empire& emp, any@ data) const {}
	void init(Empire& emp, any@ data) const { enable(emp, data); }
	void postInit(Empire& emp, any@ data) const {}
};

import settings.game_settings;

import AIController@ createBumAI() from "empire_ai.BumAI";
import AIController@ createBasicAI() from "empire_ai.BasicAI";

interface AIController {
	void debugAI();
	void commandAI(string cmd);
	void aiPing(Empire@ fromEmpire, vec3d position, uint type);
	void init(Empire& emp, EmpireSettings& settings);
	void init(Empire& emp);
	void tick(Empire& emp, double time);
	void pause(Empire& emp);
	void resume(Empire& emp);
	void load(SaveFile& msg);
	void save(SaveFile& msg);
	int getDifficultyLevel();
	vec3d get_aiFocus();
}

class EmpireAI : Component_EmpireAI, Savable {
	AIController@ ctrl;
	uint aiType;
	bool paused = false;
	bool override = false;

	EmpireAI() {
	}
	
	vec3d get_aiFocus() {
		if(ctrl !is null)
			return ctrl.aiFocus;
		else
			return vec3d();
	}
	
	int get_difficulty() {
		if(ctrl !is null)
			return ctrl.getDifficultyLevel();
		else
			return -1;
	}

	uint getAIType() {
		return aiType;
	}
	
	void debugAI() {
		if(ctrl !is null)
			ctrl.debugAI();
	}
	
	void commandAI(string cmd) {
		if(ctrl !is null)
			ctrl.commandAI(cmd);
	}

	void load(SaveFile& msg) {
		msg >> paused;
		msg >> override;
		msg >> aiType;

		createAI(aiType);
		if(ctrl !is null)
			ctrl.load(msg);
	}

	void save(SaveFile& msg) {
		msg << paused;
		msg << override;
		msg << aiType;

		if(ctrl !is null)
			ctrl.save(msg);
	}

	void createAI(uint type) {
		WaitForSafeCalls wait(true);
		aiType = type;

		//Create the controller
		switch(type) {
			case ET_Player:
				//Do nothing
			break;
			case ET_BumAI:
				@ctrl = createBasicAI();
			break;
		}

	}

	void aiPing(Empire@ fromEmpire, vec3d position, uint type = 0) {
		if(ctrl !is null)
			ctrl.aiPing(fromEmpire, position, type);
	}

	void init(Empire& emp, EmpireSettings& settings) {
		createAI(settings.type);

		//Initialize
		if(ctrl !is null)
			ctrl.init(emp, settings);
	}

	void initBasicAI(Empire& emp) {
		override = true;
		if(ctrl !is null)
			return;

		createAI(ET_BumAI);

		if(ctrl !is null) {
			WaitForSafeCalls wait(true);
			EmpireSettings settings;
			ctrl.init(emp, settings);
			ctrl.init(emp);
		}
	}
	
	void init(Empire& emp) {
		WaitForSafeCalls wait(true);

		if(ctrl !is null)
			ctrl.init(emp);
	}

	void aiTick(Empire& emp, double tick) {
		if(ctrl is null)
			return;

		//WaitForSafeCalls wait(true);

		if(emp.player is null || override) {
			if(paused) {
				ctrl.resume(emp);
				paused = false;
			}
			ctrl.tick(emp, tick);
		}
		else {
			if(!paused) {
				ctrl.pause(emp);
				paused = true;
			}
		}
	}
};

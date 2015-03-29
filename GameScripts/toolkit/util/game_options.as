import elements.BaseGuiElement;
import util.gui_options;
import settings.game_settings;

interface GameOption {
	void apply(SettingsContainer&);
	void load(SettingsContainer&);
	void reset();
};

uint MASK_CONFIG = 0x71 << 16;

mixin class IsGameBoolOption {
	uint Setting;
	bool Default;

	void set_defaultValue(bool val) {
		Default = val;
	}

	void set_setting(int val) {
		Setting = val;
	}

	void apply(SettingsContainer& gs) {
		bool v = get();
		if(Setting & MASK_CONFIG != 0) {
			if(v != Default)
				gs.setNamed(config::getName(Setting & ~MASK_CONFIG), v ? 1.0 : 0.0);
			else
				gs.clearNamed(config::getName(Setting & ~MASK_CONFIG));
		}
		else
			gs[Setting] = v ? 1.0 : 0.0;
	}

	void load(SettingsContainer& gs) {
		if(Setting & MASK_CONFIG != 0)
			set(gs.getNamed(config::getName(Setting & ~MASK_CONFIG), Default ? 1.0 : 0.0) != 0);
		else
			set(gs[Setting] != 0);
	}

	void reset() {
		set(Default);
	}
};

mixin class IsGameDoubleOption {
	uint Setting;
	double Default;

	void set_defaultValue(double val) {
		Default = val;
	}

	void set_setting(int val) {
		Setting = val;
	}

	void apply(SettingsContainer& gs) {
		double v = get();
		if(Setting & MASK_CONFIG != 0) {
			if(v != Default)
				gs.setNamed(config::getName(Setting & ~MASK_CONFIG), v);
			else
				gs.clearNamed(config::getName(Setting & ~MASK_CONFIG));
		}
		else
			gs[Setting] = v;
	}

	void load(SettingsContainer& gs) {
		if(Setting & MASK_CONFIG != 0)
			set(gs.getNamed(config::getName(Setting & ~MASK_CONFIG), Default));
		else
			set(gs[Setting]);
	}

	void reset() {
		set(Default);
	}
};

uint config(const string& name) {
	return MASK_CONFIG | config::getIndex(name);
}

class GuiGameToggle : GuiToggleOption, GameOption, IsGameBoolOption {
	GuiGameToggle(BaseGuiElement@ parent, const recti& pos, const string&in text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	GuiGameToggle(BaseGuiElement@ parent, Alignment@ pos, const string& text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}
};

class GuiGameSlider : GuiSliderOption, GameOption, IsGameDoubleOption {
	GuiGameSlider(BaseGuiElement@ parent, const recti& pos, const string&in text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	GuiGameSlider(BaseGuiElement@ parent, Alignment@ pos, const string& text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}
};

class GuiGameOccurance : GuiOccuranceOption, GameOption, IsGameDoubleOption {
	GuiGameOccurance(BaseGuiElement@ parent, const recti& pos, const string&in text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	GuiGameOccurance(BaseGuiElement@ parent, Alignment@ pos, const string& text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	void set_defaultValue(double val) {
		defaultValue = val;
		Default = val;
	}
};

class GuiGameFrequency : GuiFrequencyOption, GameOption, IsGameDoubleOption {
	GuiGameFrequency(BaseGuiElement@ parent, const recti& pos, const string&in text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	GuiGameFrequency(BaseGuiElement@ parent, Alignment@ pos, const string& text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	void set_defaultValue(double val) {
		defaultValue = val;
		Default = val;
	}
};

class GuiGameNumber : GuiNumberOption, GameOption, IsGameDoubleOption {
	GuiGameNumber(BaseGuiElement@ parent, const recti& pos, const string&in text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}

	GuiGameNumber(BaseGuiElement@ parent, Alignment@ pos, const string& text, int settingid) {
		super(parent, pos, text);
		setting = settingid;
	}
};

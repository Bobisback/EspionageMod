import overlays.InfoBar;
import elements.BaseGuiElement;
import elements.GuiResources;
import elements.Gui3DObject;
import elements.GuiText;
import elements.GuiMarkupText;
import elements.GuiButton;
import elements.GuiProgressbar;
import elements.GuiGroupDisplay;
import elements.GuiBlueprint;
import elements.GuiSkinElement;
import ship_groups;
import util.formatting;
from obj_selection import isSelected, selectObject, clearSelection, addToSelection;

class AsteroidInfoBar : InfoBar {
	Asteroid@ obj;
	Gui3DObject@ objView;

	GuiSkinElement@ nameBox;
	GuiText@ name;

	GuiSkinElement@ resourceBox;
	GuiResourceGrid@ resources;
	
	GuiSkinElement@ stateBox;
	GuiMarkupText@ state;

	ActionBar@ actions;

	AsteroidInfoBar(IGuiElement@ parent) {
		super(parent);
		@alignment = Alignment(Left, Bottom-228, Left+395, Bottom);

		@objView = Gui3DObject(this, Alignment(
			Left-1.f, Top, Right, Bottom+3.f));
		objView.objectRotation = false;
		objView.internalRotation = quaterniond_fromAxisAngle(vec3d(0.0, 0.0, 1.0), -0.15*pi);

		@actions = ActionBar(this, vec2i(305, 172));
		actions.noClip = true;

		int y = 110;
		@nameBox = GuiSkinElement(this, Alignment(Left+12, Top+y, Left+196, Top+y+34), SS_PlainOverlay);
		@name = GuiText(nameBox, Alignment().padded(8, 0));
		name.font = FT_Medium;

		y += 40;
		@resourceBox = GuiSkinElement(this, Alignment(Left+12, Top+y, Left+226, Top+y+34), SS_PlainOverlay);
		@resources = GuiResourceGrid(resourceBox, Alignment(Left+8, Top+5, Right-8, Bottom-5));
		resources.spacing.x = 6;
		resources.horizAlign = 0.0;

		y += 40;
		@stateBox = GuiSkinElement(this, Alignment(Left+12, Top+y, Left+226, Top+y+34), SS_PlainOverlay);
		@state = GuiMarkupText(stateBox, Alignment(Left+8, Top+4, Right+8, Bottom));

		updateAbsolutePosition();
	}

	void updateActions() {
		actions.clear();
		
		if(obj.owner is playerEmpire) {
			actions.addBasic(obj);
			actions.addEmpireAbilities(playerEmpire, obj);
		}

		actions.init(obj);
	}

	bool compatible(Object@ obj) override {
		return obj.isAsteroid;
	}

	Object@ get() override {
		return obj;
	}

	void set(Object@ obj) override {
		@this.obj = cast<Asteroid>(obj);
		@objView.object = obj;
		updateTimer = 0.0;
		updateActions();
	}

	bool displays(Object@ obj) override {
		if(obj is this.obj)
			return true;
		return false;
	}

	bool showManage(Object@ obj) override {
		return false;
	}

	double updateTimer = 1.0;
	void update(double time) override {
		updateTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1,0.9);
			Empire@ owner = obj.owner;

			//Update name
			name.text = obj.name;
			if(owner !is null)
				name.color = owner.color;
			
			if(owner is null || !owner.valid) {
				state.text = locale::ASTEROID_UNOWNED;
				state.tooltip = locale::ASTEROID_UNOWNED_TOOLTIP;
			}
			else {
				state.text = format(locale::ASTEROID_OWNED, owner.flagDef, toString(owner.color));
				state.tooltip = locale::ASTEROID_OWNED_TOOLTIP;
			}

			//Update resource display
			resources.resources.syncFrom(obj.getAllResources());
			resources.resources.sortDesc();
			resources.setSingleMode(align=0.0);

			//Update action bar
			updateActions();
		}
	}

	IGuiElement@ elementFromPosition(const vec2i& pos) override {
		IGuiElement@ elem = BaseGuiElement::elementFromPosition(pos);
		if(elem is this)
			return null;
		if(elem is objView) {
			int height = AbsolutePosition.size.height;
			vec2i origin(AbsolutePosition.topLeft.x, AbsolutePosition.botRight.y);
			origin.y += height;
			if(pos.distanceTo(origin) > height * 1.6)
				return null;
		}
		return elem;
	}

	void draw() override {
		if(actions.visible) {
			recti pos = actions.absolutePosition;
			skin.draw(SS_Panel, SF_Normal, recti(pos.topLeft - vec2i(70, 0), pos.botRight + vec2i(0, 20)));
		}
		InfoBar::draw();
	}
};

InfoBar@ makeAsteroidInfoBar(IGuiElement@ parent, Object@ obj) {
	AsteroidInfoBar bar(parent);
	bar.set(obj);
	return bar;
}

import overlays.InfoBar;
import elements.BaseGuiElement;
import elements.GuiResources;
import elements.Gui3DObject;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiProgressbar;
import elements.GuiGroupDisplay;
import elements.GuiBlueprint;
import elements.GuiSkinElement;
import elements.GuiIconGrid;
import elements.MarkupTooltip;
import ship_groups;
import orbitals;
import util.formatting;
import icons;
from overlays.ContextMenu import openContextMenu, FinanceDryDock;
from overlays.Construction import ConstructionOverlay;
from obj_selection import isSelected, selectObject, clearSelection, addToSelection, selectedObject;
from tabs.GalaxyTab import zoomTabTo, openOverlay;

class ModuleGrid : GuiIconGrid {
	array<OrbitalSection> sections;

	ModuleGrid(IGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	uint get_length() override {
		return sections.length;
	}

	void drawElement(uint index, const recti& pos) override {
		sections[index].type.icon.draw(pos);
	}

	string get_tooltip() override {
		if(hovered < 0 || hovered >= int(length))
			return "";
		return sections[hovered].type.getTooltip();
	}
};

class OrbitalInfoBar : InfoBar {
	Orbital@ obj;
	Gui3DObject@ objView;
	ConstructionOverlay@ overlay;

	GuiSkinElement@ nameBox;
	GuiText@ name;

	GuiSkinElement@ resourceBox;
	GuiResourceGrid@ resources;

	GuiSkinElement@ moduleBox;
	ModuleGrid@ modules;

	ActionBar@ actions;

	OrbitalInfoBar(IGuiElement@ parent) {
		super(parent);
		@alignment = Alignment(Left, Bottom-228, Left+395, Bottom);

		@objView = Gui3DObject(this, Alignment(
			Left-1.f, Top, Right, Bottom+1.f));

		@actions = ActionBar(this, vec2i(305, 172));
		actions.noClip = true;

		int y = 90;
		@nameBox = GuiSkinElement(this, Alignment(Left+12, Top+y, Left+196, Top+y+34), SS_PlainOverlay);
		@name = GuiText(nameBox, Alignment().padded(8, 0));
		name.font = FT_Medium;

		y += 40;
		@resourceBox = GuiSkinElement(this, Alignment(Left+12, Top+y, Left+226, Top+y+34), SS_PlainOverlay);
		@resources = GuiResourceGrid(resourceBox, Alignment(Left+8, Top+5, Right-8, Bottom-5));
		resources.spacing.x = 6;
		resources.horizAlign = 0.0;

		y += 40;
		@moduleBox = GuiSkinElement(this, Alignment(Left+12, Top+y, Left+256, Top+y+50), SS_PlainOverlay);
		@modules = ModuleGrid(moduleBox, Alignment(Left+8, Top+5, Right-8, Bottom-5));
		modules.iconSize = vec2i(40, 40);
		modules.spacing.x = 16;
		modules.horizAlign = 0.0;
		addLazyMarkupTooltip(modules, width=350);

		updateAbsolutePosition();
	}

	void updateActions() {
		actions.clear();
		
		if(obj.owner is playerEmpire) {
			auto@ core = getOrbitalModule(obj.coreModule);
			if(!core.isStandalone)
				actions.add(ManageAction());
			if(obj.getDesign(OV_PackUp) !is null)
				actions.add(PackUpAction());
			actions.addBasic(obj);
			actions.addFTL(obj);
			actions.addAbilities(obj);
			actions.addEmpireAbilities(playerEmpire, obj);
		}
		else {
		}

		actions.init(obj);
	}

	void draw() override {
		if(actions.visible) {
			recti pos = actions.absolutePosition;
			skin.draw(SS_Panel, SF_Normal, recti(vec2i(-5, pos.topLeft.y), pos.botRight + vec2i(0, 20)));
		}
		InfoBar::draw();
	}

	void remove() override {
		if(overlay !is null)
			overlay.remove();
		InfoBar::remove();
	}

	bool compatible(Object@ obj) override {
		return obj.isOrbital;
	}

	Object@ get() override {
		return obj;
	}

	void set(Object@ obj) override {
		@this.obj = cast<Orbital>(obj);
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
		if(overlay !is null)
			overlay.remove();
		if(cast<Orbital>(obj).getDesign(OV_DRY_Design) !is null) {
			FinanceDryDock(obj);
			return false;
		}
		if(obj.hasConstruction)
			@overlay = ConstructionOverlay(findTab(), obj);
		visible = false;
		return false;
	}

	double updateTimer = 1.0;
	void update(double time) override {
		if(overlay !is null) {
			if(overlay.parent is null) {
				@overlay = null;
				visible = true;
			}
			else
				overlay.update(time);
		}

		updateTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1,0.9);
			Empire@ owner = obj.owner;

			//Update name
			name.text = obj.name;
			if(obj.isDisabled)
				name.color = colors::Red;
			else if(owner !is null)
				name.color = owner.color;
			else
				name.color = colors::White;

			//Update resource display
			resources.resources.syncFrom(obj.getAllResources());
			resources.resources.sortDesc();

			//Update section display
			modules.sections.syncFrom(obj.getSections());

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

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is objView) {
					switch(evt.value) {
						case OA_LeftClick:
							selectObject(obj, shiftKey);
							return true;
						case OA_RightClick:
							if(selectedObject is null)
								openContextMenu(obj, obj);
							else
								openContextMenu(obj);
							return true;
						case OA_MiddleClick:
							zoomTabTo(obj);
							return true;
						case OA_DoubleClick:
							showManage(obj);
							return true;
					}
				}
			break;
		}
		return InfoBar::onGuiEvent(evt);
	}
};

class ManageAction : BarAction {
	void init() override {
		icon = icons::Manage;
		tooltip = locale::TT_MANAGE_ORBITAL;
	}

	void call() override {
		selectObject(obj);
		openOverlay(obj);
	}
};

class PackUpAction : BarAction {
	void init() override {
		icon = icons::Gate;
		tooltip = locale::TT_PACKUP_ORBITAL;
	}

	void call() override {
		cast<Orbital>(obj).sendValue(OV_PackUp);
	}
};

InfoBar@ makeOrbitalInfoBar(IGuiElement@ parent, Object@ obj) {
	OrbitalInfoBar bar(parent);
	bar.set(obj);
	return bar;
}

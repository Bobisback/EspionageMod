import overlays.Popup;
import elements.GuiText;
import elements.GuiSprite;
import elements.GuiSkinElement;
import elements.GuiImage;
import elements.GuiButton;
import elements.GuiProgressbar;
import elements.GuiResources;
import elements.MarkupTooltip;
import elements.Gui3DObject;
import elements.GuiStatusBox;
import biomes;
import orbitals;
from obj_selection import isSelected;
import constructible;
import util.constructible_view;
import util.obj_locate;
from overlays.ContextMenu import openContextMenu;
import statuses;

const uint CONSTRUCTION_SLIDESHOW_TIMER = 2.0;

class PlanetPopup : Popup {
	Constructible[] cons;
	uint consDisp = 0;
	double consDispTimer = 0;

	GuiText@ name;
	array<GuiStatusBox@> statusIcons;
	GuiSprite@ level;
	Gui3DObject@ objView;
	GuiSprite@ defIcon;

	BaseGuiElement@ popBox;
	GuiSprite@ popIcon;
	GuiText@ popValue;

	BaseGuiElement@ loyBox;
	GuiSprite@ loyIcon;
	GuiText@ loyValue;

	GuiResourceGrid@ resources;

	GuiSkinElement@ statusBox;

	GuiProgressbar@ health;

	Planet@ pl;
	bool selected = false;
	bool showOrbitalConstruction = true;
	double lastUpdate = -INFINITY;

	PlanetPopup(BaseGuiElement@ parent) {
		super(parent);
		size = vec2i(180, 135);

		@name = GuiText(this, Alignment(Left+4, Top+2, Right-4, Top+24));
		name.horizAlign = 0.5;

		@objView = Gui3DObject(this, Alignment(Left+4, Top+25, Right-4, Top+95));

		@defIcon = GuiSprite(this, Alignment(Left+4, Top+25, Width=40, Height=40));
		defIcon.desc = icons::Defense;
		setMarkupTooltip(defIcon, locale::TT_IS_DEFENDING);
		defIcon.visible = false;

		@level = GuiSprite(this, Alignment(Right-68, Top+25, Right-4, Top+47));

		GuiSkinElement band(this, Alignment(Left+3, Bottom-35, Right-4, Bottom-2), SS_SubTitle);
		band.color = Color(0xaaaaaaff);

		@popBox = BaseGuiElement(this, Alignment(Left+3, Bottom-67, Left+50, Bottom-35));
		@popIcon = GuiSprite(popBox, Alignment(Left-12, Top+2, Left+24, Bottom+6));
		popIcon.desc = icons::Population;
		@popValue = GuiText(popBox, Alignment(Left+26, Top+12, Right, Height=20));
		popIcon.tooltip = locale::POPULATION;
		popValue.tooltip = locale::POPULATION;

		@loyBox = BaseGuiElement(this, Alignment(Right-50, Bottom-67, Right-5, Bottom-35));
		@loyIcon = GuiSprite(loyBox, Alignment(Right-24, Top+8, Right, Bottom-1));
		loyIcon.desc = icons::Loyalty;
		@loyValue = GuiText(loyBox, Alignment(Right-50, Top+12, Right-26, Height=20));
		loyValue.horizAlign = 1.0;
		loyIcon.tooltip = locale::LOYALTY;
		loyValue.tooltip = locale::LOYALTY;

		@resources = GuiResourceGrid(band, Alignment(Left+4, Top+4, Right-3, Bottom-4));

		@statusBox = GuiSkinElement(this, Alignment(Right-2, Top, Right+34, Bottom), SS_PlainBox);
		statusBox.noClip = true;
		statusBox.visible = false;

		@health = GuiProgressbar(this, Alignment(Left+8, Top+28, Right-8, Top+50));
		health.visible = false;

		auto@ healthIcon = GuiSprite(health, Alignment(Left-8, Top-9, Left+24, Bottom-8), icons::Health);
		healthIcon.noClip = true;

		updateAbsolutePosition();
	}

	bool compatible(Object@ obj) {
		return cast<Planet>(obj) !is null;
	}

	void set(Object@ obj) {
		@pl = cast<Planet>(obj);
		@objView.object = obj;
		@resources.drawFrom = obj;
		lastUpdate = -INFINITY;
	}

	Object@ get() {
		return pl;
	}

	void draw() {
		Popup::updatePosition(pl);
		recti bgPos = AbsolutePosition;

		uint flags = SF_Normal;
		SkinStyle style = isSelectable ? SS_SelectablePopup : SS_PopupBG;
		if(selected)
			flags |= SF_Active;
		if(isSelectable && Hovered)
			flags |= SF_Hovered;
		
		Empire@ owner = pl.visibleOwner;
		if(owner !is null) {
			skin.draw(style, flags, bgPos, owner.color);
			if(owner.flag !is null) {
				vec2i s = objView.absolutePosition.size;
				owner.flag.draw(
					objView.absolutePosition
						.resized(s.x*0.5, s.y*0.5, 0.0, 0.0)
						.aspectAligned(1.0, horizAlign=0.0, vertAlign=0.0),
					owner.color * Color(0xffffff40));
			}
		}
		else
			skin.draw(style, flags, bgPos, Color(0xffffffff));

		objView.draw();

		//Construction display
		if(cons.length != 0) {
			//Slide through different constructions
			if(consDisp >= cons.length)
				consDisp = 0;
			if(consDispTimer < frameTime) {
				consDispTimer = frameTime + CONSTRUCTION_SLIDESHOW_TIMER;
				consDisp = (consDisp + 1) % cons.length;
			}

			//Draw the construction
			recti plPos = objView.absolutePosition;
			const Font@ ft = skin.getFont(FT_Small);
			drawConstructible(cons[consDisp], plPos, ft);
		}

		objView.Visible = false;
		BaseGuiElement::draw();
		objView.Visible = true;
	}

	bool onGuiEvent(const GuiEvent& evt) {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is objView) {
					dragging = false;
					if(!dragged) {
						switch(evt.value) {
							case OA_LeftClick:
								emitClicked(PA_Select);
								return true;
							case OA_RightClick:
								openContextMenu(pl);
								return true;
							case OA_MiddleClick:
								emitClicked(PA_Zoom);
								return true;
							case OA_DoubleClick:
								emitClicked(PA_Manage);
								return true;
						}
					}
				}
			break;
		}
		return Popup::onGuiEvent(evt);
	}

	void update() {
		if(frameTime - 0.2 < lastUpdate)
			return;
		if(pl is null)
			return;
		lastUpdate = frameTime;

		bool owned = pl.owner is playerEmpire;
		bool colonized = pl.visibleOwner !is null && pl.visibleOwner.valid;
		if(!isSelectable)
			selected = separated && isSelected(pl);
		const Font@ ft = skin.getFont(FT_Normal);

		defIcon.visible = playerEmpire.isDefending(pl);

		//Update planet name
		name.text = pl.name;
		if(ft.getDimension(name.text).x > name.size.width)
			name.font = FT_Detail;
		else
			name.font = FT_Normal;

		//Update statuses
		{
			array<Status> statuses;
			if(pl.statusEffectCount > 0)
				statuses.syncFrom(pl.getStatusEffects());
			uint prevCnt = statusIcons.length, cnt = statuses.length;
			for(uint i = cnt; i < prevCnt; ++i)
				statusIcons[i].remove();
			statusIcons.length = cnt;
			statusBox.visible = cnt != 0;
			for(uint i = 0; i < cnt; ++i) {
				auto@ icon = statusIcons[i];
				if(icon is null) {
					@icon = GuiStatusBox(statusBox, recti_area(2, 2+32*i, 30, 30));
					icon.noClip = true;
					@statusIcons[i] = icon;
				}
				icon.update(statuses[i]);
			}
		}

		//Update health
		if(pl.Health < pl.MaxHealth) {
			health.progress = pl.Health / pl.MaxHealth;
			health.frontColor = colors::Red.interpolate(colors::Green, health.progress);
			health.text = standardize(pl.Health)+" / "+standardize(pl.MaxHealth);
			health.visible = true;
		}
		else {
			health.visible = false;
		}

		//Update level icon
		int lv = pl.level;
		if(lv >= 1) {
			level.visible = true;
			level.desc = Sprite(spritesheet::PlanetLevelIcons, lv-1);
		}
		else {
			level.visible = false;
		}

		//Update resources
		resources.resources.syncFrom(pl.getAllResources());
		resources.resources.sortDesc();
		resources.setSingleMode();

		//Update population display
		if(colonized) {
			double pop = pl.population, maxPop = pl.maxPopulation;
			if(pop < 1.0)
				popValue.text = toString(pl.population, 1);
			else if(maxPop >= 10.0 || pop >= 10.0)
				popValue.text = toString(pl.population, 0);
			else
				popValue.text = toString(floor(pl.population), 0) + "/" + toString(pl.maxPopulation, 0);
			popValue.color = Color(0xffffffff);
			popValue.visible = true;
			popIcon.visible = true;
		}
		else {
			popValue.visible = false;
			popIcon.visible = false;
		}

		//Update loyalty display
		if(colonized) {
			loyValue.text = toString(pl.currentLoyalty);
			loyValue.visible = true;
			loyIcon.visible = true;
		}
		else {
			loyValue.visible = false;
			loyIcon.visible = false;
		}

		//Update construction
		uint consIndex = 0;
		if(owned) {
			if(pl.constructionCount != 0) {
				if(cons.length <= consIndex)
					cons.length = consIndex + 1;
				DataList@ list = pl.getConstructionQueue(1);
				receive(list, cons[consIndex]);
				++consIndex;
			}
		}

		if(cons.length > consIndex)
			cons.length = consIndex;

		Popup::update();
		Popup::updatePosition(pl);
	}
};

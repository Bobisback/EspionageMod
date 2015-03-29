import tabs.Tab;
import research;
import icons;
import util.formatting;
import elements.BaseGuiElement;
import elements.GuiSkinElement;
import elements.GuiMarkupText;
import elements.MarkupTooltip;
import elements.GuiText;
import elements.GuiSprite;
import elements.GuiPanel;
import elements.GuiButton;
import elements.GuiOverlay;
import elements.GuiListbox;
import elements.GuiIconGrid;
import elements.GuiBackgroundPanel;
import elements.GuiProgressbar;
import elements.GuiContextMenu;
import editor.completion;
import editor.locale;
from gui import animate_time, navigateInto, animate_speed, animate_remove, animate_snap;
from tabs.tabbar import newTab, switchToTab;

Tab@ createResearchTab() {
	return ResearchTab();
}

const vec2i T_SIZE(201, 134);
const uint T_SPAC = 27;
const uint T_OFF = 20;
const uint T_IMG = 134 - T_OFF*2 - 30;
const uint TT_WIDTH = 400;

class TechDisplay : BaseGuiElement {
	TechnologyNode node;
	const TechnologyType@ prevType;
	bool hovered = false;
	bool selected = false;
	GuiMarkupText@ description;
	GuiMarkupText@ cost;
	GuiProgressbar@ timer;
	double zoom = 1.0;

	TechDisplay(IGuiElement@ parent) {
		super(parent, recti());

		@description = GuiMarkupText(this, Alignment(Left+10, Top+T_OFF+25, Right-10, Bottom-T_OFF));
		description.defaultStroke = colors::Black;
		@cost = GuiMarkupText(this, Alignment(Left+10, Top+T_OFF+70, Right-10, Bottom));
		cost.defaultStroke = colors::Black;
		@timer = GuiProgressbar(this, Alignment(Left+10, Top+T_OFF+55, Right-10, Top+T_OFF+80));
		timer.visible = false;
	}

	void update(double zoom = 1.0) {
		this.zoom = zoom;
		vec2i pos;
		pos.x = double(node.position.x * T_SIZE.x) * zoom;
		pos.y = double(node.position.y * (T_SIZE.y - T_SPAC)) * zoom;
		if(node.position.y % 2 != 0)
			pos.x += double(T_SIZE.x / 2) * zoom;
		pos.x -= double(T_SIZE.x / 2) * zoom;
		pos.y -= double(T_SIZE.y / 2) * zoom;

		size = vec2i(double(T_SIZE.x) * zoom, double(T_SIZE.y) * zoom);
		position = pos;

		bool canUnlock = node.canUnlock(playerEmpire);
		cost.visible = !node.bought && node.available && zoom >= 1.0;
		description.visible = !node.bought && zoom >= 1.0;
		timer.visible = node.timer >= 0.01 && zoom >= 1.0;

		if(!canUnlock)
			description.defaultColor = Color(0x909090ff);
		else
			description.defaultColor = Color(0xffffffff);

		if(node.timer >= 0.0) {
			auto totalTime = node.getTimeCost();
			if(totalTime > 0) {
				timer.progress = (totalTime - node.timer) / totalTime;
				timer.text = formatTime(node.timer);
			}
			else {
				timer.visible = false;
			}
		}

		if(prevType !is node.type) {
			description.text = format("[center]$1[/center]", node.type.blurb);
			@prevType = node.type;

			string costText = "";
			bool haveSecondary = false;

			costText = node.getSecondaryCost(playerEmpire);
			haveSecondary = costText.length != 0;

			if(node.type.pointCost != 0) {
				if(costText.length != 0)
					costText = format(" [color=#888]$1[/color] ", locale::RESEARCH_COST_OR)+costText;
				costText = format("[img=$1;$4/][color=$2][b]$3[/b][/color]",
					getSpriteDesc(icons::Research), toString(colors::Research),
					toString(node.type.pointCost, 0), haveSecondary?"20":"30")+costText;
			}

			if(!haveSecondary)
				cost.defaultFont = FT_Medium;
			else
				cost.defaultFont = FT_Normal;
			cost.text = format("[center]$1[/center]", costText);
			timer.frontColor = node.type.color;
		}
	}

	bool onGuiEvent(const GuiEvent& event) {
		switch(event.type) {
			case GUI_Mouse_Entered:
				if(event.caller is this) {
					hovered = true;
					emitHoverChanged();
				}
			break;
			case GUI_Mouse_Left:
				if(event.caller is this) {
					hovered = false;
					emitHoverChanged();
				}
			break;
		}
		return BaseGuiElement::onGuiEvent(event);
	}

	bool onMouseEvent(const MouseEvent& event, IGuiElement@ source) {
		if(event.type == MET_Button_Up && isAncestorOf(source)) {
			emitClicked(event.button);
			return true;
		}
		return BaseGuiElement::onMouseEvent(event, source);
	}

	IGuiElement@ elementFromPosition(const vec2i& pos) override {
		IGuiElement@ elem = BaseGuiElement::elementFromPosition(pos);
		if(elem is this) {
			vec2i relPos = pos-AbsolutePosition.topLeft;
			relPos.x = double(relPos.x) / zoom;
			relPos.y = double(relPos.y) / zoom;
			if(!spritesheet::TechBase.isPixelActive(0, relPos))
				return null;
		}
		return elem;
	}

	void draw() {
		if(node.type is null)
			return;

		bool canUnlock = node.canUnlock(playerEmpire);
		uint index = 0;
		if(node.bought)
			index = 1;
		else if(canUnlock)
			index = 0;
		else
			index = 2;

		Color col = node.type.color;
		if(canUnlock) {
			(spritesheet::TechBase+index).draw(AbsolutePosition, col);
		}
		else {
			shader::SATURATION_LEVEL = 0.05f;
			(spritesheet::TechBase+index).draw(AbsolutePosition,
					col.interpolate(Color(0x808080ff), 0.75f), shader::Desaturate);
		}
		if(hovered)
			(spritesheet::TechBase+3).draw(AbsolutePosition, col);
		if(selected)
			(spritesheet::TechBase+4).draw(AbsolutePosition, col);

		Sprite icon = node.type.icon;
		if(icon.valid) {
			recti iconPos;
			if(zoom < 1.0) {
				iconPos = recti_area((size.width-(size.height-60.0*zoom))/2,30.0*zoom,
							size.height-60.0*zoom,size.height-60.0*zoom)+absolutePosition.topLeft;
			}
			//else if(node.type.blurb.length == 0) {
			//	iconPos = recti_area((size.width-(size.height-80))/2,40,
			//				size.height-80,size.height-80)+absolutePosition.topLeft;
			//}
			else {
				icon.color.a = 0x40;
				iconPos = recti_area((size.width-(size.height-40))/2,20,
							size.height-40,size.height-40)+absolutePosition.topLeft;
			}
			vec2i isize = icon.size;
			if(isize.y != 0)
				iconPos = iconPos.aspectAligned(double(isize.x) / double(isize.y));

			if(canUnlock) {
				icon.draw(iconPos);
			}
			else {
				shader::SATURATION_LEVEL = 0.3f;
				icon.draw(iconPos, colors::White, shader::Desaturate);
			}
		}

		if(zoom >= 0.4) {
			Color titleColor = node.type.color;
			if(!canUnlock)
				titleColor = titleColor.interpolate(Color(0x808080ff), 0.8f);

			const Font@ ft = skin.getFont(FT_Medium);
			bool enough = ft.getDimension(node.type.name).x < size.width-20;

			if(!enough) {
				@ft = skin.getFont(FT_Subtitle);
				enough = ft.getDimension(node.type.name).x < size.width-20;
			}
			if(!enough) {
				@ft = skin.getFont(FT_Bold);
				enough = ft.getDimension(node.type.name).x < size.width-20;
			}
			if(!enough)
				@ft = skin.getFont(FT_Small);

			ft.draw(
				pos=recti_area(10,T_OFF, size.width-20,30)+absolutePosition.topLeft,
				text=node.type.name,
				stroke=colors::Black,
				color=titleColor,
				horizAlign=0.5,
				vertAlign=0.0);
		}

		BaseGuiElement::draw();
	}
};

class TechTooltip : BaseGuiElement {
	GuiMarkupText@ description;
	TechDisplay@ tied;

	GuiButton@ researchButton;
	GuiMarkupText@ researchText;

	GuiButton@ secondaryButton;
	GuiMarkupText@ secondaryText;
	
	TechTooltip(IGuiElement@ parent) {
		super(parent, recti());

		@description = GuiMarkupText(this, recti_area(12,12,TT_WIDTH-24,300));

		@researchButton = GuiButton(this, Alignment(Left+0.5f-110, Bottom-52, Width=220, Height=40));
		researchButton.color = colors::Research;
		@researchText = GuiMarkupText(researchButton, Alignment().padded(-1,8,0,4));
		researchText.defaultFont = FT_Bold;

		@secondaryButton = GuiButton(this, Alignment(Left+0.5f-110, Bottom-52-46, Width=220, Height=40));
		@secondaryText = GuiMarkupText(secondaryButton, Alignment().padded(0,8,0,4));
		secondaryText.defaultFont = FT_Bold;
	}

	void updateAbsolutePosition() {
		if(tied !is null) {
			if(researchButton.visible)
				secondaryButton.alignment.top.pixels = 52+46;
			else
				secondaryButton.alignment.top.pixels = 52;
		}
		BaseGuiElement::updateAbsolutePosition();
		if(tied is null)
			return;
		int h = 24;
		if(researchButton.visible)
			h += 46;
		if(secondaryButton.visible)
			h += 46;
		size = vec2i(TT_WIDTH, description.size.height+h);
		position = vec2i(tied.position.x+tied.size.x, tied.position.y+tied.size.y/2-size.y/2);
	}


	bool onGuiEvent(const GuiEvent& event) {
		if(event.caller is researchButton && event.type == GUI_Clicked) {
			playerEmpire.research(tied.node.id);
			emitClicked();
			return true;
		}
		else if(event.caller is secondaryButton && event.type == GUI_Clicked) {
			playerEmpire.research(tied.node.id, secondary=true);
			emitClicked();
			return true;
		}
		return BaseGuiElement::onGuiEvent(event);
	}

	void update(double time) {
		if(tied is null)
			return;

		bool canUnlock = tied.node.canUnlock(playerEmpire);
		auto@ type = tied.node.type;
		auto cost = tied.node.getPointCost(playerEmpire);
		researchButton.visible = cost > 0 && !tied.node.bought && canUnlock;
		researchButton.disabled = playerEmpire.ResearchPoints < cost || !tied.node.available;
		researchText.text = format("[center]$1: [img=$3;20/][color=$4]$2[/color][/center]",
				locale::RESOURCE_RESEARCH, toString(cost, 0),
				getSpriteDesc(icons::Research), toString(colors::Research));

		string sec = tied.node.getSecondaryCost(playerEmpire);
		if(sec.length != 0) {
			secondaryButton.color = type.color;
			secondaryText.text = format("[center]$1: $2[/center]", type.secondaryTerm, sec);
			secondaryButton.visible = !tied.node.bought && canUnlock;
			secondaryButton.disabled = !tied.node.canSecondaryUnlock(playerEmpire);
		}
		else {
			secondaryButton.visible = false;
		}
	}

	void update(TechDisplay@ tech) {
		@tied = tech;

		auto@ type = tied.node.type;
		string desc = type.description;

		auto cost = tied.node.getPointCost(playerEmpire);
		if(cost > 0) {
			desc += format("\n\n[img=$1;20/] [b]$2[/b]: [offset=200]$3[/offset]",
					getSpriteDesc(icons::Research), locale::RESEARCH_COST, toString(cost,0));
		}

		auto time = tied.node.getTimeCost(playerEmpire);
		if(time > 0) {
			if(cost <= 0)
				desc += "\n";
			desc += format("\n[img=$1;20/] [b]$2[/b]: [offset=200]$3[/offset]",
					getSpriteDesc(icons::Duration), locale::RESEARCH_TIME, formatTime(time));
		}

		description.text = format(
			"[font=Medium][color=$2]$1[/color][/font]\n\n$3",
			type.name, toString(type.color), desc);


		update(0.0);
		parent.updateAbsolutePosition();
	}

	void draw() {
		skin.draw(SS_Panel, SF_Normal, AbsolutePosition);
		BaseGuiElement::draw();
		if(tied !is null){
			Color col = tied.node.type.color;
			col.a = 0x20;
			drawRectangle(recti_area(5,12,TT_WIDTH-13,32)+AbsolutePosition.topLeft, Color(col));
		}
	}
};

class ResearchTab : Tab {
	GuiPanel@ panel;
	array<TechDisplay@> techs;

	TechTooltip@ ttip;
	TechDisplay@ selected;
	double zoom = 1.0;

	ResearchTab() {
		title = locale::RESEARCH;

		@panel = GuiPanel(this, Alignment(Left, Top, Right, Bottom));
		panel.setScrollPane(true);
		panel.minPanelSize = recti(-20000,-20000, 20000,20000);
		panel.dragThreshold = 10;
		panel.allowScrollDrag = false;

		@ttip = TechTooltip(panel);
	}

	void show() override {
		update();
		Tab::show();
	}
	
	Color get_activeColor() {
		return Color(0xd482ffff);
	}

	Color get_inactiveColor() {
		return Color(0xa800ffff);
	}

	Color get_seperatorColor() {
		return Color(0x75488dff);
	}	

	TabCategory get_category() {
		return TC_Research;
	}

	Sprite get_icon() {
		return Sprite(material::TabResearch);
	}

	void update() {
		auto@ dat = playerEmpire.getTechnologyNodes();
		uint index = 0;
		uint prevCnt = techs.length;
		while(true) {
			if(index >= techs.length)
				techs.insertLast(TechDisplay(panel));

			if(!receive(dat, techs[index].node))
				break;

			techs[index].update(zoom);
			++index;
		}
		for(uint i = index, cnt = techs.length; i < cnt; ++i)
			techs[i].remove();
		techs.length = index;
		if(prevCnt == 0)
			panel.centerAround(vec2i(0,0));
		ttip.bringToFront();
	}

	void updatePositions() {
		for(uint i = 0, cnt = techs.length; i < cnt; ++i)
			techs[i].update(zoom);
	}

	void updateAbsolutePosition() {
		Tab::updateAbsolutePosition();
		update();
	}

	double timer = 0;
	void tick(double time) override {
		timer += time;
		if(timer >= 1.0) {
			if(ttip !is null && ttip.visible)
				ttip.update(timer);
			update();
			timer = 0;
		}
	}

	void draw() override {
		skin.draw(SS_ResearchBG, SF_Normal, AbsolutePosition);
		Tab::draw();
	}

	bool onMouseEvent(const MouseEvent& event, IGuiElement@ source) {
		if(event.type == MET_Button_Up && event.button == 0 && !ttip.isAncestorOf(source)) {
			if(selected !is null) {
				selected.selected = false;
				@selected = null;
			}
			ttip.visible = false;
			panel.stopDrag();
			return true;
		}
		if(event.type == MET_Scrolled) {
			//Keep position under cursor constant
			vec2i mOff = mousePos - panel.absolutePosition.topLeft;

			double prevZoom = zoom;
			zoom = clamp(zoom + double(event.y) * 0.2, 0.2, 1.0);

			panel.scrollOffset.x = (zoom * double(mOff.x + panel.scrollOffset.x)) / prevZoom - mOff.x;
			panel.scrollOffset.y = (zoom * double(mOff.y + panel.scrollOffset.y)) / prevZoom - mOff.y;

			updatePositions();
			panel.updateAbsolutePosition();
			return true;
		}
		return BaseGuiElement::onMouseEvent(event, source);
	}

	bool onGuiEvent(const GuiEvent& event) {
		if(event.type == GUI_Hover_Changed) {
			auto@ disp = cast<TechDisplay>(event.caller);
			if(disp !is null && selected is null) {
				if(!disp.hovered && disp is ttip.tied) {
					ttip.visible = false;
				}
				else {
					ttip.update(disp);
					ttip.visible = true;
				}
				return true;
			}
		}
		else if(event.type == GUI_Clicked) {
			if(event.caller is ttip) {
				update();
				timer = 0.3;
				ttip.visible = false;
				if(selected !is null) {
					selected.selected = false;
					@selected = null;
				}
				return true;
			}
			else if(event.value == 0) {
				auto@ disp = cast<TechDisplay>(event.caller);
				if(disp !is null) {
					if(!panel.isDragging) {
						if(selected !is null)
							selected.selected = false;
						if(selected !is disp) {
							@selected = disp;
							selected.selected = true;
							ttip.update(disp);
							ttip.visible = true;
						}
						else {
							@selected = null;
							ttip.visible = false;
						}
					}
					panel.stopDrag();
					return true;
				}
			}
		}
		return BaseGuiElement::onGuiEvent(event);
	}
};

class ResearchEditor : ResearchTab {
	bool created = false;
	vec2i hovered(INT_MAX,INT_MAX);

	ResearchEditor() {
		super();
		panel.minPanelSize = recti(-20000,-20000, 20000,20000);
	}

	void show() {
		created = false;
		update();
		Tab::show();
	}

	Completion@ getCompletion(const string& ident) {
		for(uint i = 0, cnt = techCompletions.length; i < cnt; ++i) {
			if(techCompletions[i].ident == ident) {
				return techCompletions[i];
			}
		}
		return null;
	}

	TechnologyType@ makeType(Completion@ compl) {
		TechnologyType type;
		type.ident = compl.ident;
		type.name = compl.name;
		type.description = compl.longDescription;
		if(compl.description.length < 30)
			type.blurb = compl.description;
		type.icon = compl.icon;
		type.color = compl.color;
		return type;
	}

	void update() {
		if(!created) {
			created = true;
			initCompletions();
			uint prevCnt = techs.length;

			for(uint i = 0, cnt = techs.length; i < cnt; ++i)
				techs[i].remove();
			techs.length = 0;

			const string fname = resolve("data/research/base_grid.txt");
			ReadFile file(fname, true);
			while(file++) {
				if(file.key != "Grid") {
					vec2i pos;
					int xp = file.value.findFirst(",");
					if(xp == -1) {
						pos.x = toInt(file.value);
					}
					else {
						pos.x = toInt(file.value.substr(0,xp));
						pos.y = toInt(file.value.substr(xp+1));
					}

					Completion@ compl = getCompletion(file.key);
					if(compl !is null) {
						TechDisplay disp(panel);
						@disp.node.type = makeType(compl);
						disp.node.position = pos;
						disp.update(zoom);
						techs.insertLast(disp);
					}
				}
			}

			if(prevCnt == 0)
				panel.centerAround(vec2i(0,0));
			ttip.bringToFront();
		}
	}

	bool onMouseEvent(const MouseEvent& event, IGuiElement@ source) {
		if(event.type == MET_Button_Up && event.button == 0 && !ttip.isAncestorOf(source)) {
			ttip.visible = false;
			if(hovered.x != INT_MAX && hovered.y != INT_MAX)
				showChanger(hovered);
			panel.stopDrag();
			return true;
		}
		else if(event.type == MET_Moved) {
			vec2i relPos = mousePos - panel.AbsolutePosition.topLeft;
			relPos += T_SIZE / 2;
			hovered.y = floor(double(relPos.y) / double(T_SIZE.y - T_SPAC));
			if(hovered.y % 2 != 0)
				relPos.x -= T_SIZE.x / 2;
			hovered.x = floor(double(relPos.x) / double(T_SIZE.x));
		}
		return BaseGuiElement::onMouseEvent(event, source);
	}

	void save() {
		const string fname = path_join(topMod.abspath, "data/research/base_grid.txt");
		ensureFile(fname);
		WriteFile file(fname);
		file.writeKeyValue("Grid", "Base");
		file.indent();

		for(uint i = 0, cnt = techs.length; i < cnt; ++i) {
			auto@ node = techs[i].node;
			if(getCompletion(node.type.ident) is null)
				continue;
			file.writeKeyValue(node.type.ident, ""+node.position.x+","+node.position.y);
		}
	}

	void setNode(const vec2i& pos, const TechnologyType@ type) {
		for(uint i = 0, cnt = techs.length; i < cnt; ++i) {
			if(techs[i].node.position == pos) {
				@techs[i].node.type = type;
				techs[i].update();
				save();
				return;
			}
		}

		TechDisplay disp(panel);
		disp.node.position = pos;
		@disp.node.type = type;

		techs.insertLast(disp);
		disp.update();
		save();
	}

	void deleteNode(const vec2i& pos) {
		for(uint i = 0, cnt = techs.length; i < cnt; ++i) {
			if(techs[i].node.position == pos) {
				techs[i].remove();
				techs.removeAt(i);
				save();
				return;
			}
		}
	}

	bool onGuiEvent(const GuiEvent& event) {
		if(event.type == GUI_Hover_Changed) {
			auto@ disp = cast<TechDisplay>(event.caller);
			if(disp !is null && selected is null) {
				if(!disp.hovered && disp is ttip.tied) {
					ttip.visible = false;
				}
				else {
					ttip.update(disp);
					ttip.visible = true;
				}
				return true;
			}
		}
		else if(event.type == GUI_Clicked) {
			auto@ disp = cast<TechDisplay>(event.caller);
			if(disp !is null) {
				if(!panel.isDragging) {
					if(event.value == 0) {
						showChanger(disp.node.position);
					}
					else if(event.value == 1) {
						deleteNode(disp.node.position);
					}
				}
				panel.stopDrag();
				return true;
			}
		}
		return BaseGuiElement::onGuiEvent(event);
	}

	void draw() {
		ResearchTab::draw();
		if(hovered.x != INT_MAX && hovered.y != INT_MAX) {
			vec2i pos;
			pos.x = hovered.x * T_SIZE.x;
			pos.y = double(hovered.y * (T_SIZE.y - T_SPAC));
			if(hovered.y % 2 != 0)
				pos.x += T_SIZE.x / 2;
			pos -= T_SIZE / 2;

			(spritesheet::TechBase+4).draw(recti_area(pos + panel.AbsolutePosition.topLeft, T_SIZE));
		}
	}

	void showChanger(const vec2i& pos) {
		GuiContextMenu menu(mousePos, width=300);
		menu.itemHeight = 50;

		for(uint i = 0, cnt = techCompletions.length; i < cnt; ++i) {
			auto@ type = makeType(techCompletions[i]);
			menu.addOption(TechnologyItem(this, type, pos));
		}

		menu.finalize();
	}
};

class TechnologyItem : GuiMarkupContextOption {
	const TechnologyType@ type;
	vec2i pos;
	ResearchEditor@ editor;

	TechnologyItem(ResearchEditor@ editor, const TechnologyType@ type, vec2i pos) {
		@this.type = type;
		this.pos = pos;
		@this.editor = editor;

		super(format("[img=$3;40][color=$4][b]$1[/b]\n[offset=20][i]$2[/i][/offset][/color][/img]",
				type.name, type.blurb,
				getSpriteDesc(type.icon),
				toString(type.color)));
	}

	void call(GuiContextMenu@ menu) {
		editor.setNode(pos, type);
	}
}

class ResearchEditorCommand : ConsoleCommand {
	void execute(const string& args) {
		Tab@ editor = ResearchEditor();
		newTab(editor);
		switchToTab(editor);
	}
};

void init() {
	addConsoleCommand("research_editor", ResearchEditorCommand());
}

import elements.BaseGuiElement;
import elements.GuiText;
import elements.GuiTextbox;
import elements.GuiButton;
import elements.GuiSprite;
import elements.GuiContextMenu;
import elements.MarkupTooltip;
import resources;
import research;

from tabs.tabbar import switchToTab, newTab, TabCategory;
from tabs.ResearchTab import createResearchTab;
from tabs.DiplomacyTab import createDiplomacyTab;

const int RESOURCE_WIDTH = 256;
const double UPDATE_INTERVAL = 0.05;
const double RESEARCH_FLASH = 2.0;

class BarResource : BaseGuiElement {
	string ttText;

	BarResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);

		MarkupTooltip tt("", 320, 0.5f, true, false);
		tt.Lazy = true;
		tt.LazyUpdate = true;
		@tooltipObject = tt;
	}

	void updateAbsolutePosition() {
		BaseGuiElement::updateAbsolutePosition();

		MarkupTooltip@ tt = cast<MarkupTooltip>(tooltipObject);
		tt.offset = vec2i(-size.width, size.height);
	}

	void set_tooltip(const string& text) {
		ttText = text;
	}

	string get_tooltip() {
		return ttText;
	}

	void drawRate(FontType fontType, const recti& pos, double rate, double align = 0.0,
					bool pers = true, bool dispzero = true, double valign = 0.0) {
		string text;
		Color color;
		
		bool permin = false;

		if(rate < 0) {
			if(pers && rate > -0.999) {
				rate *= 60.0;
				permin = true;
			}
			text = standardize(rate, true);
			color = Color(0xff0000ff);
		}
		else if(rate == 0) {
			if(!dispzero)
				return;
			text = "±0";
			color = Color(0xbbbbbbff);
		}
		else {
			if(pers && rate < 0.999) {
				rate *= 60.0;
				permin = true;
			}
			text = "+"+standardize(rate, true);
			color = Color(0x00ff00ff);
		}

		if(pers) {
			if(permin)
				text += locale::PER_MINUTE;
			else
				text += locale::PER_SECOND;
		}

		const Font@ ft = skin.getFont(fontType);
		ft.draw(pos, text, locale::ELLIPSIS, color, align, valign);
	}

	string formatRate(int rate, bool persec = true) {
		if(persec) {
			if(rate < 0)
				return format("[color=#f00]$1/s[/color]", standardize(rate, true));
			else if(rate == 0)
				return "[color=#bbb]±0/s[/color]";
			else
				return format("[color=#0f0]+$1/s[/color]", standardize(rate, true));
		}
		else {
			if(rate < 0)
				return format("[color=#f00]$1[/color]", standardize(rate, true));
			else if(rate == 0)
				return "[color=#bbb]±0[/color]";
			else
				return format("[color=#0f0]+$1[/color]", standardize(rate, true));
		}
	}
};

class ChangeWelfare : GuiContextOption {
	ChangeWelfare(const string& text, uint index) {
		value = int(index);
		this.text = text;
		icon = Sprite(spritesheet::ConvertIcon, index);
	}

	void call(GuiContextMenu@ menu) override {
		playerEmpire.WelfareMode = uint(value);
	}
};

class BudgetResource : BarResource {
	Sprite icon;
	int curBudget = 0;
	int nextBudget = 0;
	int bonusBudget = 0;
	float progress = 0.f;
	float remainingTime = 0.f;

	GuiButton@ welfareButton;
	GuiSprite@ welfareIcon;

	BudgetResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);

		@welfareButton = GuiButton(this, Alignment(Right-84+40-25, Top, Width=50, Height=24));
		@welfareIcon = GuiSprite(welfareButton, Alignment(Left+8, Top-5, Right-8, Bottom+5),
				Sprite(spritesheet::ConvertIcon, 0));

		setMarkupTooltip(welfareButton, locale::WELFARE_TT, hoverStyle=false);
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		if(evt.caller is welfareButton && evt.type == GUI_Clicked) {
			GuiContextMenu menu(mousePos);
			menu.itemHeight = 54;
			string money = formatMoney(350.0 / playerEmpire.WelfareEfficiency);
			menu.addOption(ChangeWelfare(format(locale::WELFARE_INFLUENCE, money), 0));
			menu.addOption(ChangeWelfare(format(locale::WELFARE_ENERGY, money), 1));
			menu.addOption(ChangeWelfare(format(locale::WELFARE_RESEARCH, money), 2));
			menu.addOption(ChangeWelfare(format(locale::WELFARE_LABOR, money), 3));
			menu.updateAbsolutePosition();
			return true;
		}
		return BarResource::onGuiEvent(evt);
	}

	string get_tooltip() {
		string tt = format(locale::GTT_MONEY,
				formatMoneyChange(curBudget, colored=true),
				formatMoneyChange(nextBudget, colored=true),
				formatTime(remainingTime),
				getSpriteDesc(welfareIcon.desc));
		tt += format("\n[font=Medium]$1[/font]\n", locale::RESOURCE_BUDGET);
		for(int i = MoT_COUNT - 1; i >= 0; --i) {
			int money = playerEmpire.getMoneyFromType(i);
			if(money != 0) {
				tt += format("$1: [right]$2[/right]",
					localize("MONEY_TYPE_"+i), formatMoneyChange(money, true));
			}
		}

		int bonusMoney = playerEmpire.BonusBudget;
		if(bonusMoney != 0)
			tt += "\n\n"+format(locale::GTT_BONUS_MONEY, formatMoney(bonusMoney));

		float debtFactor = playerEmpire.DebtFactor;
		if(debtFactor > 1.f) {
			float effFactor = pow(0.5f, debtFactor-1.f);
			tt += "\n\n"+format(locale::GTT_FLEET_PENALTY, "-"+toString((1.f - effFactor)*100.f, 0)+"%");
		}
		if(debtFactor > 0.f) {
			float growthFactor = 1.f;
			for(; debtFactor > 0; debtFactor -= 1.f)
				growthFactor *= 0.33f + 0.67f * (1.f - min(debtFactor, 1.f));
			tt += "\n\n"+format(locale::GTT_DEBT_PENALTY, "-"+toString((1.f - growthFactor)*100.f, 0)+"%");
		}
		return tt;
	}

	void draw() {
		//Draw the icon
		int iconSize = size.height;
		icon.draw(recti_area(
				AbsolutePosition.topLeft,
				vec2i(iconSize, iconSize))
			.padded(0, 3)
			.aspectAligned(1.0));

		const Font@ medium = skin.getFont(FT_Medium);
		const Font@ normal = skin.getFont(FT_Normal);
		const Font@ small = skin.getFont(FT_Small);
		Color color(0xffffffff);

		//Draw current budget
		string cur = formatMoney(curBudget);
		if(curBudget < 0)
			color = Color(0xff0000ff);
		else if(curBudget - bonusBudget < 0)
			color = Color(0xff8000ff);
		else
			color = Color(0xffffffff);
		medium.draw(recti_area(vec2i(4+iconSize, 0) + AbsolutePosition.topLeft,
			vec2i(size.width - 8 - iconSize, 24)), cur,
			locale::ELLIPSIS, color, 0, 0.5);

		//Draw timer
		int w = size.width - 88 - iconSize;
		int h = size.height - 28;
		skin.draw(SS_BudgetProgress, SF_Normal, recti_area(
			vec2i(4+iconSize, 26) + AbsolutePosition.topLeft,
			vec2i(w, h)));

		int progw = ceil(float(w-2) * progress);
		skin.draw(SS_BudgetProgressBar, SF_Normal, recti_area(
			vec2i(5+iconSize, 27) + AbsolutePosition.topLeft,
			vec2i(progw, h-2)));

		small.draw(recti_area(vec2i(4+iconSize, 26) + AbsolutePosition.topLeft,
			vec2i(w, h)), formatTime(remainingTime),
			locale::ELLIPSIS, Color(0xffffffff), 0.5, 0.5);

		//Draw next budget
		string next = formatMoney(nextBudget);
		if(nextBudget < 0)
			color = Color(0xbb0000ff);
		else
			color = Color(0xbbbbbbff);
		normal.draw(recti_area(vec2i(size.width - 84, 26) + AbsolutePosition.topLeft,
			vec2i(80, h)), next,
			locale::ELLIPSIS, color, 0.5, 0.5);

		BarResource::draw();
	}
};

class StoredResource : BarResource {
	Sprite icon;
	int stored = 0;
	int capacity = 0;
	double income = 0;

	StoredResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	string get_tooltip() {
		return format(locale::GTT_FTL,
				toString(stored),
				toString(capacity),
				::formatRate(income));
	}

	void draw() {
		//Draw resource type icon
		int iconSize = size.height;
		icon.draw(recti_area(
				AbsolutePosition.topLeft,
				vec2i(iconSize, iconSize))
			.padded(0, 3)
			.aspectAligned(1.0));

		//Draw total resource stored
		const Font@ medium = skin.getFont(FT_Medium);
		const Font@ normal = skin.getFont(FT_Normal);

		Color storedCol;
		if(stored < 0.001)
			storedCol = Color(0x888888ff);
		else if(stored >= capacity - 0.001)
			storedCol = Color(0xc9a014ff);
		else
			storedCol = Color(0x00ff00ff);

		string storedText = toString(stored, 0);
		string capText = "/"+toString(capacity, 0);
		vec2i storedDim = medium.getDimension(storedText);
		int hdiff = medium.getLineHeight() - normal.getLineHeight();

		int x = size.height + 10;
		medium.draw(AbsolutePosition.topLeft + vec2i(x, 2),
			storedText, storedCol);
		x += storedDim.width + 2;
		normal.draw(AbsolutePosition.topLeft + vec2i(x, 2 + hdiff),
			capText, Color(0xccccccff));

		//Draw the income rate
		drawRate(FT_Normal, recti(
				AbsolutePosition.topLeft + vec2i(size.height + 10, 24),
				AbsolutePosition.botRight - vec2i(2, 2)),
			income, 0.5, true, true, 0.5);

		BarResource::draw();
	}
};

class NumberResource : BarResource {
	Sprite icon;
	int stored = 0;
	double income = 0;

	NumberResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	void draw() {
		//Draw resource type icon
		int iconSize = size.height;
		icon.draw(recti_area(
				AbsolutePosition.topLeft,
				vec2i(iconSize, iconSize))
			.padded(0, 3)
			.aspectAligned(1.0));

		//Draw total resource stored
		const Font@ medium = skin.getFont(FT_Medium);
		const Font@ normal = skin.getFont(FT_Normal);

		Color storedCol(0xffffffff);
		string storedText = standardize(stored, true);

		int x = size.height + 10;
		medium.draw(AbsolutePosition.topLeft + vec2i(x, 2),
			storedText, storedCol);

		drawRate(FT_Normal, recti(
				AbsolutePosition.topLeft + vec2i(size.height + 10, 24),
				AbsolutePosition.botRight - vec2i(2, 2)),
			income, 0.5, true, true, 0.5);

		BarResource::draw();
	}
};

class PercentageResource : BarResource {
	Sprite icon;
	int stored = 0;
	double income = 0;
	double percentage = 0;
	double efficiency = 1.0;
	double cap = 0;

	PercentageResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	string get_tooltip() {
		return format(locale::GTT_INFLUENCE,
				toString(stored), toString(cap, 0),
				::formatRate(income),
				toString(percentage*100.0, 0)+"%");
	}

	void draw() {
		//Draw resource type icon
		int iconSize = size.height;
		icon.draw(recti_area(
				AbsolutePosition.topLeft,
				vec2i(iconSize, iconSize))
			.padded(0, 3)
			.aspectAligned(1.0));

		//Draw total resource stored
		const Font@ medium = skin.getFont(FT_Medium);
		const Font@ normal = skin.getFont(FT_Normal);

		Color storedCol(0xffffffff);
		storedCol = Color(0xff0000ff).interpolate(storedCol, efficiency);
		string storedText = toString(stored, 0);
		string capText = "/"+toString(cap, 0);

		vec2i storedDim = medium.getDimension(storedText);
		int hdiff = medium.getLineHeight() - normal.getLineHeight();

		int x = size.height + 10;
		medium.draw(AbsolutePosition.topLeft + vec2i(x, 2),
			storedText, storedCol);
		x += storedDim.width + 2;
		normal.draw(AbsolutePosition.topLeft + vec2i(x, 2 + hdiff),
			capText, Color(0xccccccff));

		recti botArea = recti(
				AbsolutePosition.topLeft + vec2i(size.height + 10, 24),
				AbsolutePosition.botRight - vec2i(2, 2));

		normal.draw(recti_area(botArea.topLeft, vec2i(botArea.size.width/2, botArea.size.height)),
					toString(percentage * 100.0, 0)+"%", locale::ELLIPSIS, Color(0xbbbbbbff), 0.5, 0.5);

		drawRate(FT_Normal, recti(botArea.topLeft + vec2i(botArea.size.width/2, 0), botArea.botRight),
			income, 0.5, true, true, 0.5);

		BarResource::draw();
	}
};

class ResearchResource : BarResource {
	Sprite icon;
	int stored = 0;
	double income = 0;
	array<TechnologyNode> researching;
	TechnologyNode activeTech;

	ResearchResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	string get_tooltip() {
		string tt = format(locale::GTT_RESEARCH,
				toString(stored),
				::formatRate(income));
		for(uint i = 0, cnt = researching.length; i < cnt; ++i) {
			tt += "\n"+format(locale::GTT_RESEARCH_TECH,
				researching[i].type.name, formatTime(researching[i].timer),
				toString(researching[i].type.color));
		}
		return tt;
	}

	void draw() {
		//Draw resource type icon
		int iconSize = size.height;
		icon.draw(recti_area(
				AbsolutePosition.topLeft,
				vec2i(iconSize, iconSize))
			.padded(0, 3)
			.aspectAligned(1.0));

		//Draw timer
		float progress = 0.f;
		float remainingTime = 0.f;
		Color col;
		if(activeTech.type !is null) {
			float totalTime = activeTech.getTimeCost();
			remainingTime = activeTech.timer;
			progress = 1.f - (remainingTime / totalTime);
			col = activeTech.type.color;
		}

		int w = size.width - 88 - iconSize;
		int h = size.height - 28;
		skin.draw(SS_BudgetProgress, SF_Normal, recti_area(
			vec2i(6+iconSize, 24) + AbsolutePosition.topLeft,
			vec2i(w, h)));

		int progw = ceil(float(w-2) * progress);
		skin.draw(SS_BudgetProgressBar, SF_Normal, recti_area(
			vec2i(7+iconSize, 25) + AbsolutePosition.topLeft,
			vec2i(progw, h-2)), col);

		if(activeTech.type !is null)
			activeTech.type.icon.draw(recti_area(vec2i(6+iconSize, 22)+AbsolutePosition.topLeft, vec2i(24, 24)));

		const Font@ small = skin.getFont(FT_Small);
		if(remainingTime > 0.f) {
			small.draw(recti_area(vec2i(6+iconSize, 24) + AbsolutePosition.topLeft,
				vec2i(w, h)), formatTime(remainingTime),
				locale::ELLIPSIS, Color(0xffffffff), 0.5, 0.5);
		}
		else {
			small.draw(recti_area(vec2i(6+iconSize, 24) + AbsolutePosition.topLeft,
				vec2i(w, h)), locale::NOT_RESEARCHING,
				locale::ELLIPSIS, Color(0xaaaaaaff), 0.5, 0.5);
		}

		//Draw total resource stored
		const Font@ medium = skin.getFont(FT_Medium);
		const Font@ normal = skin.getFont(FT_Normal);

		string storedText = toString(stored, 0);

		int x = size.height + 10;
		medium.draw(AbsolutePosition.topLeft + vec2i(x, 1), storedText);

		drawRate(FT_Normal, recti(
				AbsolutePosition.topLeft + vec2i(size.width - 84, 23),
				AbsolutePosition.botRight - vec2i(2, 2)),
			income, 0.5, true, true, 0.5);

		BarResource::draw();
	}
};

class EnergyResource : BarResource {
	Sprite icon;
	int stored = 0;
	double income = 0;
	double factor = 0;

	EnergyResource(BaseGuiElement@ parent, Alignment@ align) {
		super(parent, align);
	}

	string get_tooltip() {
		return format(locale::GTT_ENERGY,
				toString(stored),
				::formatRate(income),
				toString(playerEmpire.FreeEnergyStorage, 0),
				"-"+toString((1.0-factor)*100.0, 0)+"%");
	}

	void draw() {
		//Draw resource type icon
		int iconSize = size.height;
		icon.draw(recti_area(
				AbsolutePosition.topLeft,
				vec2i(iconSize, iconSize))
			.padded(0, 3)
			.aspectAligned(1.0));

		//Draw total resource stored
		const Font@ medium = skin.getFont(FT_Medium);
		const Font@ normal = skin.getFont(FT_Normal);

		string storedText = toString(stored, 0);

		int x = size.height + 10;
		medium.draw(AbsolutePosition.topLeft + vec2i(x, 2), storedText);

		drawRate(FT_Normal, recti(
				AbsolutePosition.topLeft + vec2i(size.height + 10, 24),
				AbsolutePosition.botRight - vec2i(2, 2)),
			income, 0.5, true, true, 0.5);

		BarResource::draw();
	}
};

class GlobalBar : BaseGuiElement {
	BaseGuiElement@ container;
	BudgetResource@ budget;
	EnergyResource@ energy;
	StoredResource@ ftl;
	PercentageResource@ influence;
	ResearchResource@ research;
	double updateTimer = -INFINITY;
	bool firstGlow = true;

	GlobalBar() {
		super(null, recti());

		int hrw = RESOURCE_WIDTH / 2;
		float rpct = float(hrw) / 1280.f;

		@container = BaseGuiElement(this, Alignment_Fill());
		
		float x = rpct;
		@budget = BudgetResource(container, Alignment(Left+x+4-hrw, Top+2, Left+x+4+hrw, Bottom-2));
		@budget.icon.sheet = spritesheet::ResourceIcon;
		budget.icon.index = 0;
		budget.tooltip = locale::RESOURCE_BUDGET;
		x += rpct * 2;

		@influence = PercentageResource(container, Alignment(Left+x+4-hrw, Top+2, Left+x+4+hrw, Bottom-2));
		@influence.icon.sheet = spritesheet::ResourceIcon;
		influence.icon.index = 1;
		influence.tooltip = locale::RESOURCE_INFLUENCE;
		x += rpct * 2;

		@energy = EnergyResource(container, Alignment(Left+x+4-hrw, Top+2, Left+x+4+hrw, Bottom-2));
		@energy.icon.sheet = spritesheet::ResourceIcon;
		energy.icon.index = 2;
		energy.tooltip = locale::RESOURCE_ENERGY;
		x += rpct * 2;

		@ftl = StoredResource(container, Alignment(Left+x+4-hrw, Top+2, Left+x+4+hrw, Bottom-2));
		@ftl.icon.sheet = spritesheet::ResourceIcon;
		ftl.icon.index = 3;
		ftl.tooltip = locale::RESOURCE_FTL;
		x += rpct * 2;

		@research = ResearchResource(container, Alignment(Left+x+4-hrw, Top+2, Left+x+4+hrw, Bottom-2));
		@research.icon.sheet = spritesheet::ResourceIcon;
		research.icon.index = 4;
		research.tooltip = locale::RESOURCE_RESEARCH;
		x += rpct * 2;

		updateAbsolutePosition();
	}

	void update() {
		//Budget
		budget.curBudget = playerEmpire.RemainingBudget;
		budget.bonusBudget = playerEmpire.BonusBudget;
		budget.nextBudget = playerEmpire.EstNextBudget;

		double cycle = playerEmpire.BudgetCycle;
		double timer = playerEmpire.BudgetTimer;

		budget.progress = timer / cycle;
		budget.remainingTime = cycle - timer;
		budget.welfareIcon.desc = Sprite(spritesheet::ConvertIcon, playerEmpire.WelfareMode);

		//FTL
		ftl.stored = playerEmpire.FTLStored;
		ftl.capacity = playerEmpire.FTLCapacity;
		ftl.income = playerEmpire.FTLIncome - playerEmpire.FTLUse;

		//Energy
		energy.stored = playerEmpire.EnergyStored;
		energy.factor = playerEmpire.EnergyEfficiency;

		double netEnergy = playerEmpire.EnergyIncome - playerEmpire.EnergyUse;
		if(netEnergy > 0)
			netEnergy *= energy.factor;
		energy.income = netEnergy;

		//Influence
		influence.stored = playerEmpire.Influence;
		influence.income = playerEmpire.InfluenceIncome;
		influence.percentage = playerEmpire.InfluencePercentage;
		influence.efficiency = playerEmpire.InfluenceEfficiency;
		influence.cap = playerEmpire.InfluenceCap;

		//Research
		research.stored = playerEmpire.ResearchPoints;
		research.income = playerEmpire.ResearchRate;
		research.researching.syncFrom(playerEmpire.getResearchingNodes());
		if(research.researching.length != 0) {
			research.researching.sortAsc();
			research.activeTech = research.researching[0];
		}
		else {
			@research.activeTech.type = null;
		}
	}

	void draw() {
		if(frameTime - UPDATE_INTERVAL >= updateTimer) {
			update();
			updateTimer = frameTime;
		}

		skin.draw(SS_GlobalBar, SF_Normal, AbsolutePosition);
		BaseGuiElement::draw();
	}
}

BaseGuiElement@ createGlobalBar() {
	return GlobalBar();
}

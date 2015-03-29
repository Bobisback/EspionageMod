import tabs.Tab;
import elements.GuiEmpire;
import elements.GuiPanel;
import elements.GuiText;
import elements.GuiSkinElement;
import elements.GuiMarkupText;
import elements.GuiImage;
import elements.GuiSprite;
import elements.GuiButton;
import elements.GuiContextMenu;
import elements.GuiBackgroundPanel;
import elements.GuiCheckbox;
import elements.GuiTextbox;
import elements.GuiInfluenceCard;
import elements.GuiProgressbar;
import elements.GuiIconGrid;
import elements.GuiSprite;
import elements.MarkupTooltip;
import elements.GuiOfferList;
import dialogs.QuestionDialog;
import dialogs.InputDialog;
import util.formatting;
import systems;
import resources;
import influence;
import traits;
//import tabs.BobisbackHomeTabPanel;
from gui import animate_time, animate_retarget;
import void zoomTo(Object@) from "tabs.GalaxyTab";
import uint addButtonWithOnClick(const string&, Sprite, Color, onButtonClick@) from "tabs.BobisbackHomeTabPanel";

from tabs.tabbar import ActiveTab, browseTab;

class EspionageTab : Tab {
	GuiPanel@ panel;
	GuiPanel@ southPanel;
	
	BaseGuiElement@ empirePanel;
	//EmpireBox@[] empires;
	GuiText@ noEmpireText;
	
	GuiProgressbar@ drawProgress;
	GuiBackgroundPanel@ missionStackBG;
	BaseGuiElement@ missionStackPanel;
	//array<InfluenceCard@> cardStack;
	//array<StackCard@> stackBoxes;
	
	GuiBackgroundPanel@ cardBG;
	BaseGuiElement@ cardPanel;
	//array<InfluenceCard@> cards;
	//array<GuiInfluenceCard@> cardBoxes;
	
	GuiBackgroundPanel@ agentsBG;
	BaseGuiElement@ agentsPanel;
	GuiText@ noAgentsText;
	
	GuiBackgroundPanel@ missionBG;
	BaseGuiElement@ missionPanel;
	GuiText@ noMissionsText;
	GuiButton@ missionHistoryButton;
	
	EspionageTab() {
		super();
		title = locale::ESPIONAGE;
		@panel = GuiPanel(this, Alignment_Fill());
		panel.horizType = ST_Never;
		
		//Other Empires
		//@empirePanel = BaseGuiElement(panel, recti_area(0, 0, screenSize.width, screenSize.height/3-145));
		@empirePanel = BaseGuiElement(panel, Alignment(Left, Top, Right, Top+0.33f));

		@noEmpireText = GuiText(empirePanel, Alignment(Left, Top, Right, Bottom));
		noEmpireText.text = locale::NO_MET_EMPIRES;
		noEmpireText.font = FT_Subtitle;
		noEmpireText.color = Color(0xaaaaaaff);
		noEmpireText.stroke = colors::Black;
		noEmpireText.horizAlign = 0.5;
		noEmpireText.VertAlign = 0.5;
		noEmpireText.visible = true;
		
		@southPanel = GuiPanel(this, Alignment(Left, Top+0.33f, Right, Bottom));
		
		//Mission stack
		@missionStackBG = GuiBackgroundPanel(southPanel, Alignment(Left, Top, Right, Top+145));
		missionStackBG.title = locale::ESPIONAGE_CARD_STACK;
		missionStackBG.titleColor = Color(0x53feb3ff);
		missionStackBG.picture = Sprite(material::DiplomacyActions);

		@drawProgress = GuiProgressbar(missionStackBG, Alignment(Right-185, Top+3, Right-5, Top+28), 0.f);
		drawProgress.frontColor = Color(0x20adffff);

		@missionStackPanel = BaseGuiElement(missionStackBG, recti(8, 34, 100, 100));

		//Available Espionage Cards
		@cardBG = GuiBackgroundPanel(southPanel, Alignment(Left, Top+145, Left+0.5f, Bottom));
		cardBG.title = locale::ESPIONAGE_AVAILABLE_CARDS;
		cardBG.titleColor = Color(0xb3fe00ff);
		cardBG.picture = Sprite(material::DiplomacyActions);

		@cardPanel = BaseGuiElement(cardBG, recti(8, 34, 100, 100));

		//Agents list
		@agentsBG = GuiBackgroundPanel(southPanel, Alignment(Left+0.5f, Top+145, Right-0.25f, Bottom));
		agentsBG.title = locale::ACTIVE_VOTES;
		agentsBG.titleColor = Color(0x00bffeff);
		agentsBG.picture = Sprite(material::Propositions);

		@agentsPanel = BaseGuiElement(agentsBG, recti(8, 34, 100, 100));
		@noAgentsText = GuiText(agentsPanel, recti(4, 4, 400, 24), locale::NO_VOTES);
		noAgentsText.color = Color(0xaaaaaaff);
		
		//Active Missions
		@missionBG = GuiBackgroundPanel(southPanel, Alignment(Right-0.25f, Top+145, Right, Bottom));
		missionBG.title = locale::ESPIONAGE_ACTIVE_CARDS;
		missionBG.titleColor = Color(0xfe8300ff);
		missionBG.picture = Sprite(material::ActiveEffects);
		
		@missionHistoryButton = GuiButton(missionBG, Alignment(Right-185, Top+3, Right-5, Top+28), locale::VIEW_ESPIONAGE_VOTE_HISTORY);
		missionHistoryButton.color = Color(0x9be5feff);

		@missionPanel = BaseGuiElement(missionBG, recti(8, 34, 100, 100));
		@noMissionsText = GuiText(missionPanel, recti(4, 4, 400, 24), locale::ESPIONAGE_NO_EFFECTS);
		noMissionsText.color = Color(0xaaaaaaff);
	}
	
	TabCategory get_category() {
		return TC_Other;
	}
	
	Sprite get_icon() {
		return Sprite(material::TabEspionage);
	}
}

void init() {
	addButtonWithOnClick(locale::ESPIONAGE, Sprite(material::TabEspionage), Color(0x606060ff), EspionageButtonEvent());
}

Tab@ createEspionageTab() {
	return EspionageTab();
}

class EspionageButtonEvent : onButtonClick {
	bool onClick(GuiButton@ btn) {
		browseTab(ActiveTab, createEspionageTab(), false);
		return true;
	}
}



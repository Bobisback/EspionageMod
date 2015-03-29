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

import bool isHomeTab(Tab@) from "tabs.HomeTab";

from tabs.tabbar import ActiveTab, browseTab;

GuiPanel@ bobisbackModPanel;
GuiBackgroundPanel@ bobisbackModPanelBG;
GuiButton@ espionageButton;
array<GuiButton@> guiButtons;

void init() {
	@bobisbackModPanel = GuiPanel(null, Alignment(Left+0.25f, Bottom-0.33f, Right-0.25f, Bottom-20));
	bobisbackModPanel.visible = false;
	
	@bobisbackModPanelBG = GuiBackgroundPanel(bobisbackModPanel, Alignment_Fill());
	bobisbackModPanelBG.title = locale::BOBISBACK_PANEL_TITLE;
	bobisbackModPanelBG.titleColor = Color(0x3b5998ff);
	bobisbackModPanelBG.visible = false;
}

uint addButtonWithOnClick(const string& DefaultText, Sprite buttonIcon, Color buttonColor, onButtonClick@ onClick) {
	GuiButton@ newButton;
	uint position = guiButtons.length;
	int heightMutipler = (position/3); //if there are more then 3 on a row we need to mutiplay the height. 
	int w = 300, hw = w/2;
	
	if (position == 0 || position % 3 == 0) { //if it is in the first position align left
		@newButton = GuiButton(bobisbackModPanel, Alignment(Left+0.5f-w-hw, Top+(50 + (heightMutipler * 90)), Width=w-10, Height=80), DefaultText);
	} else if (position % 3 == 1) { //if it is in the second position align middle
		@newButton = GuiButton(bobisbackModPanel, Alignment(Left+0.5f-hw, Top+(50 + (heightMutipler * 90)), Width=w-10, Height=80), DefaultText);
	} else if (position % 3 == 2) { //if it is in the thrid position align right
		@newButton = GuiButton(bobisbackModPanel, Alignment(Left+0.5f+hw, Top+(50 + (heightMutipler * 90)), Width=w-10, Height=80), DefaultText);
	}
	
	newButton.font = FT_Medium;
	newButton.buttonIcon = buttonIcon;
	newButton.color = buttonColor;
	newButton.visible = false;
	@newButton.onClick = onClick;
	
	guiButtons.insertLast(newButton);
	
	return guiButtons.length-1;
}

bool removeButton(uint index) {
	if(index < 0 || index >= guiButtons.length) {
		return false;
	}
	guiButtons.removeAt(index);
	return true;
}

void tick(double time) {
	if (isHomeTab(ActiveTab)) {
		bobisbackModPanel.visible = true;
		bobisbackModPanel.bringToFront();
		
		bobisbackModPanelBG.visible = true;
		bobisbackModPanelBG.bringToFront();
		
		for (uint i = 0; i < guiButtons.length; i++) {
			guiButtons[i].visible = true;
			guiButtons[i].disabled = false;
			guiButtons[i].bringToFront();
		}
	} else {
		bobisbackModPanel.visible = false;
		bobisbackModPanelBG.visible = false;
				
		for (uint i = 0; i < guiButtons.length; i++) {
			guiButtons[i].visible = false;
			guiButtons[i].disabled = true;
			guiButtons[i].bringToFront();
		}
	}
}

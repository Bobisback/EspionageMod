import tabs.Tab;
import dialogs.MaterialChooser;
import dialogs.InputDialog;
import dialogs.QuestionDialog;
import elements.GuiText;
import elements.GuiTextbox;
import elements.GuiListbox;
import elements.GuiSpinbox;
import elements.GuiSprite;
import elements.GuiBlueprint;

from tabs.tabbar import newTab, switchToTab;

/*class ConfirmClear : QuestionDialogCallback {
	HullEditor@ editor;

	ConfirmClear(HullEditor@ he) {
		@editor = he;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			editor.clearFiles();
	}
};

class ConfirmReset : QuestionDialogCallback {
	HullEditor@ editor;

	ConfirmReset(HullEditor@ he) {
		@editor = he;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes) {
			editor.loadFromGame();
			editor.saveToProfile();
		}
	}
};

class ConfirmSave : QuestionDialogCallback {
	HullEditor@ editor;

	ConfirmSave(HullEditor@ he) {
		@editor = he;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			editor.saveToGame();
	}
};

class CreateFile : InputDialogCallback {
	HullEditor@ editor;

	CreateFile(HullEditor@ he) {
		@editor = he;
	}

	void inputCallback(InputDialog@ dialog, bool accepted) {
		if(!accepted)
			return;
		editor.addFile(dialog.getTextInput(0));
	}
};

class ConfirmDeleteHull : QuestionDialogCallback {
	HullEditor@ editor;
	Hull@ hull;

	ConfirmDeleteHull(HullEditor@ he, Hull@ h) {
		@editor = he;
		@hull = h;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			editor.deleteHull(hull);
	}
};

class ConfirmDeleteFile : QuestionDialogCallback {
	HullEditor@ editor;
	HullFile@ file;

	ConfirmDeleteFile(HullEditor@ he, HullFile@ f) {
		@editor = he;
		@file = f;
	}

	void questionCallback(QuestionDialog@ dialog, int answer) {
		if(answer == QA_Yes)
			editor.deleteFile(file);
	}
};

class ChooseBackground : MaterialChoiceCallback {
	HullEditor@ editor;

	ChooseBackground(HullEditor@ e) {
		@editor = e;
	}

	void onMaterialChosen(const Material@ material, const string& id) {
		editor.backgroundField.text = id;
		editor.update();
	}

	void onSpriteSheetChosen(const SpriteSheet@ spritebank, uint spriteIndex, const string& id) {
	}
};

class ChooseIconSheet : MaterialChoiceCallback {
	HullEditor@ editor;

	ChooseIconSheet(HullEditor@ e) {
		@editor = e;
	}

	void onMaterialChosen(const Material@ material, const string& id) {
	}

	void onSpriteSheetChosen(const SpriteSheet@ spritebank, uint spriteIndex, const string& id) {
		editor.iconSheet.text = id;
		editor.iconIndex.text = toString(spriteIndex);
		editor.update();
	}
};

class ChooseMaterial : MaterialChoiceCallback {
	HullEditor@ editor;

	ChooseMaterial(HullEditor@ e) {
		@editor = e;
	}

	void onMaterialChosen(const Material@ material, const string& id) {
		editor.materialField.text = id;
		editor.update();
	}

	void onSpriteSheetChosen(const SpriteSheet@ spritebank, uint spriteIndex, const string& id) {
	}
};

class HullFile {
	string file;
	Hull@[] hulls;
};*/

class HullEditor : Tab { /*
	HullFile@[] files;
	HullFile@ curFile;
	Hull@ selected;
	int brushButton;
	bool exteriorBrush;

	GuiButton@ resetButton;
	GuiButton@ clearButton;
	GuiButton@ saveButton;

	GuiText@ fileHeader;
	GuiListbox@ fileList;
	GuiButton@ addFileButton;
	GuiButton@ deleteFileButton;

	GuiText@ hullHeader;
	GuiListbox@ hullList;
	GuiButton@ addHullButton;
	GuiButton@ deleteHullButton;

	GuiText@ idLabel;
	GuiTextbox@ idField;
	GuiText@ nameLabel;
	GuiTextbox@ nameField;

	GuiText@ hexSizeLabel;
	GuiSpinbox@ hexSize;

	GuiText@ gridOffsetLabel;
	GuiSpinbox@ gridX;
	GuiText@ gridOffsetSep;
	GuiSpinbox@ gridY;
	GuiText@ gridOffsetSep2;
	GuiSpinbox@ gridX2;
	GuiText@ gridOffsetSep3;
	GuiSpinbox@ gridY2;

	GuiText@ scaleLabel;
	GuiSpinbox@ scaleField;

	GuiText@ backgroundLabel;
	GuiTextbox@ backgroundField;
	GuiButton@ chooseBackground;

	GuiText@ meshLabel;
	GuiTextbox@ meshField;

	GuiText@ materialLabel;
	GuiTextbox@ materialField;
	GuiButton@ chooseMaterial;

	GuiSprite@ iconSprite;
	GuiText@ iconSheetLabel;
	GuiTextbox@ iconSheet;

	GuiText@ iconIndexLabel;
	GuiTextbox@ iconIndex;
	GuiButton@ chooseIcon;

	GuiDraggable@ tlHandle;
	GuiDraggable@ brHandle;

	GuiBlueprint@ bp;
	GuiText@ helpText;

	HullEditor() {
		super();
		
		//Global buttons
		@resetButton = GuiButton(this, Alignment(Left, Bottom-32, Left+200, Bottom-0), locale::RESET_GAME_DATA);

		@clearButton = GuiButton(this, Alignment(Left+204, Bottom-32, Left+404, Bottom-0), locale::HULL_CLEAR);

		@saveButton = GuiButton(this, Alignment(Left+408, Bottom-32, Left+608, Bottom-0), locale::SAVE_GAME_DATA);

		//File list
		@fileHeader = GuiText(this, Alignment(Left, Top, Left+256, Top+32), locale::HULL_FILES);
		fileHeader.font = FT_Big;

		@fileList = GuiListbox(this, Alignment(Left, Top+36, Left+256, Bottom-56));
		fileList.required = true;

		@addFileButton = GuiButton(this, Alignment(Left, Bottom-56, Left+128, Bottom-36), locale::ADD);

		@deleteFileButton = GuiButton(this, Alignment(Left+128, Bottom-56, Left+256, Bottom-36), locale::DELETE);

		//Hull list
		@hullHeader = GuiText(this, Alignment(Left+264, Top+36, Left+500, Top+66), locale::HULL_HULLS);
		hullHeader.font = FT_Medium;

		@hullList = GuiListbox(this, Alignment(Left+264, Top+70, Left+500, Bottom-56));
		hullList.required = true;

		@addHullButton = GuiButton(this, Alignment(Left+264, Bottom-56, Left+382, Bottom-36), locale::ADD);

		@deleteHullButton = GuiButton(this, Alignment(Left+382, Bottom-56, Left+500, Bottom-36), locale::DELETE);

		//Data fields
		@bp = GuiBlueprint(this, Alignment(Left+525, Top+70, Right-4, Top+400));
		bp.displayInactive = true;
		bp.displayExterior = true;
		bp.activateAll = true;

		//Drag handles
		@tlHandle = GuiDraggable(this, recti_area(vec2i(525, 70), vec2i(16, 16)));
		GuiSkinElement(tlHandle, Alignment_Fill(), SS_DragHandle);

		@brHandle = GuiDraggable(this, recti_area(vec2i(525, 70), vec2i(16, 16)));
		GuiSkinElement(brHandle, Alignment_Fill(), SS_DragHandle);

		//Help text
		@helpText = GuiText(this, Alignment(Left+525, Top+400, Right-20, Top+440),
			locale::HULL_EDITOR_HELP);
		helpText.vertAlign = 0.0;
		helpText.horizAlign = 0.5;
		helpText.font = FT_Detail;

		int y = 450;

		//ID
		@idLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_ID);

		@idField = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		y += 26;

		//Name
		@nameLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_NAME);

		@nameField = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		y += 26;

		//Grid Size
		@hexSizeLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_HEX_SIZE);

		@hexSize = GuiSpinbox(this,
			recti(700, y, 800, y+22));
		hexSize.min = 0.05;
		hexSize.decimals = 2;
		hexSize.step = 0.05;

		y += 26;

		//Grid Offset
		@gridOffsetLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_GRID_OFFSET);

		@gridX = GuiSpinbox(this,
			recti(700, y, 760, y+22));

		@gridOffsetSep = GuiText(this,
			recti(760, y, 770, y+22), "x");
		gridOffsetSep.horizAlign = 0.5;

		@gridY = GuiSpinbox(this,
			recti(770, y, 830, y+22));

		@gridOffsetSep2 = GuiText(this,
			recti(830, y, 840, y+22), ",");
		gridOffsetSep2.horizAlign = 0.5;

		@gridX2 = GuiSpinbox(this,
			recti(840, y, 900, y+22));

		@gridOffsetSep3 = GuiText(this,
			recti(900, y, 910, y+22), "x");
		gridOffsetSep3.horizAlign = 0.5;

		@gridY2 = GuiSpinbox(this,
			recti(910, y, 970, y+22));

		y += 26;

		//Background scale
		@scaleLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_BACKGROUND_SCALE);

		@scaleField = GuiSpinbox(this,
			recti(700, y, 760, y+22));
		scaleField.min = 0.01;
		scaleField.decimals = 2;
		scaleField.step = 0.05;

		y += 26;

		//Background
		@backgroundLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_BACKGROUND);

		@backgroundField = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		@chooseBackground = GuiButton(this,
			recti(1010, y, 1090, y+22), locale::CHOOSE);

		y += 26;

		//Mesh
		@meshLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_MODEL);

		@meshField = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		y += 26;

		//Material
		@materialLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_MATERIAL);

		@materialField = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		@chooseMaterial = GuiButton(this,
			recti(1010, y, 1090, y+22), locale::CHOOSE);

		y += 26;

		//Icon Sheet
		@iconSheetLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_ICON);

		@iconSheet = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		@chooseIcon = GuiButton(this,
			recti(1010, y, 1090, y+22), locale::CHOOSE);

		y += 26;

		//Icon Index
		@iconIndexLabel = GuiText(this,
			recti(525, y, 695, y+22),
			locale::HULL_ICON_INDEX);

		@iconIndex = GuiTextbox(this,
			recti(700, y, 1000, y+22));

		y += 26;

		//Icon display
		@iconSprite = GuiSprite(this,
			recti(525, y, 625, y+100),
			null, 0);

		brushButton = -1;
	}

	void init() {
		if(!loadFromProfile())
			loadFromGame();
	}

	string& get_title() {
		return locale::HULL_EDITOR;
	}

	Color get_activeColor() {
		return Color(0x83cfffff);
	}

	Color get_inactiveColor() {
		return Color(0x009cffff);
	}

	TabCategory get_category() {
		return TC_Designs;
	}

	Sprite get_icon() {
		return Sprite(material::TabDesigns);
	}

	void loadFromGame() {
		files.length = 0;
		@curFile = null;
		@selected = null;

		FileList list("data/shipsets", "*");
		uint cnt = list.length;
		for(uint i = 0; i < cnt; ++i) {
			if(!list.isDirectory[i])
				continue;
			
			//Use path name to get file
			HullFile f;
			f.file = list.basename[i];
			error("Path: " + f.file);

			readHullDefinitions(list.path[i] + "/hulls.txt", f.hulls);

			files.insertLast(f);
		}

		updateFileList();
	}

	bool loadFromProfile() {
		FileList list(profileRoot + "/editor", "hulls_*.txt");
		uint cnt = list.length;
		if(cnt == 0)
			return false;
		for(uint i = 0; i < cnt; ++i) {
			HullFile f;
			f.file = list.basename[i];
			f.file = f.file.substr(6, f.file.length - 6);

			readHullDefinitions(list.path[i], f.hulls);

			files.insertLast(f);
		}

		updateFileList();
		return true;
	}

	void saveToProfile() {
		for(uint i = 0, cnt = files.length; i < cnt; ++i) {
			HullFile@ f = files[i];
			string fname = profileRoot + "/editor/hulls_" + f.file + ".txt";
			writeHullDefinitions(fname, f.hulls);
		}
	}

	void saveToGame() {
		FileList list("data/hulls", "*.txt");
		uint cnt = list.length;
		for(uint i = 0; i < cnt; ++i)
			::deleteFile(list.path[i]);

		cnt = files.length;
		for(uint i = 0; i < cnt; ++i)
			writeHullDefinitions("data/shipsets/" + files[i].file + "/hulls.txt",
				files[i].hulls);
	}

	void updateFileList() {
		fileList.clearItems();
		for(uint i = 0, cnt = files.length; i < cnt; ++i) {
			fileList.addItem(files[i].file);
			if(files[i] is curFile)
				fileList.selected = i;
		}

		if(curFile is null && files.length != 0) {
			fileList.selected = 0;
			selectFile(files[0]);
		}
	}

	void selectFile(HullFile@ fl) {
		if(fl is null) {
			@curFile = null;
			hullList.clearItems();
			return;
		}

		@curFile = fl;

		//Update hull list
		hullList.clearItems();
		bool foundSelected = false;
		for(uint i = 0, cnt = fl.hulls.length; i < cnt; ++i) {
			hullList.addItem(fl.hulls[i].name);
			if(selected is fl.hulls[i]) {
				foundSelected = true;
				hullList.selected = i;
			}
		}

		//Update selected hull
		if(!foundSelected) {
			if(fl.hulls.length == 0)
				select(null);
			else {
				select(fl.hulls[0]);
				hullList.selected = 0;
			}
		}
		else {
			select(fl.hulls[hullList.selected]);
		}
	}

	void addFile(string fname) {
		if(!fname.endswith(".txt"))
			fname += ".txt";

		HullFile f;
		f.file = fname;
		files.insertLast(f);
		selectFile(f);
		updateFileList();
		update();
	}

	void deleteFile(HullFile@ file) {
		if(file is curFile)
			selectFile(null);
		::deleteFile(profileRoot + "/editor/hulls_"+file.file);
		files.remove(file);
		updateFileList();
		update();
	}

	void deleteHull(Hull@ hull) {
		curFile.hulls.remove(hull);
		if(hull is selected)
			selectFile(curFile);
		update();
	}

	void clearFiles() {
		for(uint i = 0, cnt = files.length; i < cnt; ++i) {
			deleteFile(files[i]);
			--i; --cnt;
		}
		selectFile(null);
		select(null);

		update();
	}

	void clear() {
		@bp.hull = null;
		idField.text = "";
		nameField.text = "";
		hexSize.value = 1.0;
		gridX.value = 0;
		gridY.value = 0;
		gridX2.value = 0;
		gridY2.value = 0;
		backgroundField.text = "";
		meshField.text = "";
		materialField.text = "";
		iconSheet.text = "";
		iconIndex.text = "0";
		scaleField.value = 1.0;

		@iconSprite.sheet = null;
		iconSprite.sprite = 0;
	}

	void select(Hull@ hull) {
		clear();
		@selected = hull;

		if(selected is null)
			return;

		@bp.hull = selected;
		bp.updateAbsolutePosition();

		idField.text = selected.ident;
		nameField.text = selected.name;
		gridX.value = selected.gridOffset.topLeft.x;
		gridY.value = selected.gridOffset.topLeft.y;
		gridX2.value = selected.gridOffset.botRight.x;
		gridY2.value = selected.gridOffset.botRight.y;
		backgroundField.text = selected.backgroundName;
		meshField.text = selected.modelName;
		materialField.text = selected.materialName;
		iconSheet.text = selected.iconName;
		iconIndex.text = toString(selected.iconIndex);
		scaleField.value = selected.backgroundScale;

		vec2i tl = (bp.bgPos + bp.AbsolutePosition.topLeft
				- AbsolutePosition.topLeft) - vec2i(8, 8);
		tl.x += round(double(selected.gridOffset.topLeft.x) * bp.zoom);
		tl.y += round(double(selected.gridOffset.topLeft.y) * bp.zoom);
		tlHandle.position = tl;

		vec2i br = (bp.bgPos + bp.bgSize + bp.AbsolutePosition.topLeft
				- AbsolutePosition.topLeft) - vec2i(8, 8);
		br.x -= round(double(selected.gridOffset.botRight.x) * bp.zoom);
		br.y -= round(double(selected.gridOffset.botRight.y) * bp.zoom);
		brHandle.position = br;

		double bw = 512.0;
		bw -= selected.gridOffset.topLeft.x;
		bw -= selected.gridOffset.botRight.x;
		double w = selected.gridSize.width;

		hexSize.value = (bw / w) / 50.0 / 0.75;

		@iconSprite.sheet = selected.iconSheet;
		iconSprite.sprite = selected.iconIndex;
	}

	void update() {
		if(selected is null)
			return;

		bool nameChanged = false;
		if(selected.name != nameField.text)
			nameChanged = true;

		selected.ident = idField.text;
		selected.name = nameField.text;
		selected.backgroundScale = scaleField.value;

		selected.backgroundName = backgroundField.text;
		@selected.background = getMaterial(selected.backgroundName);

		selected.gridOffset.topLeft.x = gridX.value;
		selected.gridOffset.topLeft.y = gridY.value;
		selected.gridOffset.botRight.x = gridX2.value;
		selected.gridOffset.botRight.y = gridY2.value;

		double hs = hexSize.value * 50.0;
		double hexAspect = double(spritesheet::HexagonBasic.width)
			/ double(spritesheet::HexagonBasic.height);
		double hexHeight = hs / hexAspect;

		double bw = 512.0;
		bw -= selected.gridOffset.topLeft.x;
		bw -= selected.gridOffset.botRight.x;
		uint w = clamp(round(bw / (0.75 * hs)), 1, 100);

		double bh = 256.0;
		bh -= selected.gridOffset.topLeft.y;
		bh -= selected.gridOffset.botRight.y;
		uint h = clamp(round(bh / hexHeight), 1, 100);

		if(w != selected.active.width || h != selected.active.height) {
			HexGridb oldActive(selected.active);
			HexGridb oldExterior(selected.exterior);

			selected.active.resize(w, h);
			selected.active.clear(false);

			selected.exterior.resize(w, h);
			selected.exterior.clear(false);

			for(uint x = 0, mx = min(w, oldActive.width); x < mx; ++x) {
				for(uint y = 0, my = min(h, oldActive.height); y < my; ++y) {
					selected.active.get(x, y) = oldActive.get(x, y);
					selected.exterior.get(x, y) = oldExterior.get(x, y);
				}
			}

			selected.gridSize.x = w;
			selected.gridSize.y = h;
		}

		vec2i tl = (bp.bgPos + bp.AbsolutePosition.topLeft
				- AbsolutePosition.topLeft) - vec2i(8, 8);
		tl.x += round(double(selected.gridOffset.topLeft.x) * bp.zoom);
		tl.y += round(double(selected.gridOffset.topLeft.y) * bp.zoom);
		tlHandle.position = tl;

		vec2i br = (bp.bgPos + bp.bgSize + bp.AbsolutePosition.topLeft
				- AbsolutePosition.topLeft) - vec2i(8, 8);
		br.x -= round(double(selected.gridOffset.botRight.x) * bp.zoom);
		br.y -= round(double(selected.gridOffset.botRight.y) * bp.zoom);
		brHandle.position = br;

		selected.gridOffset.botRight.x = 512
			- selected.gridOffset.topLeft.x - (0.75 * hs) * w;

		selected.gridOffset.botRight.y = 256
			- selected.gridOffset.topLeft.y - hexHeight * h;

		selected.modelName = meshField.text;
		@selected.model = getModel(selected.modelName);

		selected.materialName = materialField.text;
		@selected.material = getMaterial(selected.materialName);

		selected.iconName = iconSheet.text;
		@selected.iconSheet = getSpriteSheet(selected.iconName);
		selected.iconIndex = toInt(iconIndex.text);

		@iconSprite.sheet = selected.iconSheet;
		iconSprite.sprite = selected.iconIndex;

		if(nameChanged)
			selectFile(curFile);
		saveToProfile();
		bp.updateAbsolutePosition();
	}

	void updateHandles() {
		if(tlHandle.position.x >= brHandle.position.x - 10)
			tlHandle.position = vec2i(brHandle.position.x - 10, tlHandle.position.y);
		if(tlHandle.position.y >= brHandle.position.y - 10)
			tlHandle.position = vec2i(tlHandle.position.x, brHandle.position.y - 10);

		vec2d tl = vec2d(tlHandle.absolutePosition.topLeft - bp.bgPos
				- bp.AbsolutePosition.topLeft + vec2i(8, 8));
		tl /= bp.zoom;

		vec2d br = vec2d(bp.bgPos + bp.AbsolutePosition.topLeft + bp.bgSize
				- brHandle.absolutePosition.topLeft - vec2i(8, 8));
		br /= bp.zoom;

		gridX.value = round(tl.x);
		gridY.value = round(tl.y);
		gridX2.value = round(br.x);
		gridY2.value = round(br.y);
		update();
	}

	void modHex(const vec2u& hex, int button) {
		bool active = selected.active.get(hex);
		bool exterior = selected.exterior.get(hex);

		switch(button) {
			case 0:
				if(!active) {
					selected.active.get(hex) = true;
					selected.exterior.get(hex) = false;
				}
			break;
			case 1:
				if(active) {
					selected.active.get(hex) = false;
				}
			break;
			case 2:
				if(active) {
					if(brushButton == -1)
						exteriorBrush = !exterior;
					selected.exterior.get(hex) = exteriorBrush;
				}
			break;
		}
	}

	bool onMouseEvent(const MouseEvent& event, IGuiElement@ source) {
		if(source is bp) {
			vec2u hex(bp.hexHovered.x, bp.hexHovered.y);
			switch(event.type) {
				case MET_Button_Down: {
					//Ignore presses outside of bounds
					if(bp.hexHovered.x < 0 || bp.hexHovered.y < 0)
						return BaseGuiElement::onMouseEvent(event, source);

					modHex(hex, event.button);
					brushButton = event.button;
				} return true;
				case MET_Button_Up: {
					if(brushButton != -1)
						update();
					brushButton = -1;
				} return true;
			}
		}
		return BaseGuiElement::onMouseEvent(event, source);
	}

	bool onGuiEvent(const GuiEvent& event) {
		if(event.type == GUI_Clicked) {
			if(event.caller is addFileButton) {
				InputDialog@ dialog = InputDialog(CreateFile(this), this);
				dialog.accept.text = locale::CREATE;
				dialog.addTextInput(locale::LABEL_NAME, "");
				addDialog(dialog);
				dialog.focusInput();
				return true;
			}
			else if(event.caller is resetButton) {
				question(locale::RESET_GAME_DATA_CONFIRM, ConfirmReset(this), this);
			}
			else if(event.caller is clearButton) {
				question(locale::HULL_CONFIRM_CLEAR, ConfirmClear(this), this);
			}
			else if(event.caller is saveButton) {
				question(locale::SAVE_GAME_DATA_CONFIRM, ConfirmSave(this), this);
			}
			else if(event.caller is chooseBackground) {
				openMaterialChooser(ChooseBackground(this), MCM_Materials);
			}
			else if(event.caller is chooseMaterial) {
				openMaterialChooser(ChooseMaterial(this), MCM_Materials);
			}
			else if(event.caller is chooseIcon) {
				openMaterialChooser(ChooseIconSheet(this), MCM_Spritesheets);
			}
			else if(curFile !is null) {
				if(event.caller is deleteFileButton) {
					question(format(locale::HULL_DELETE_FILE_CONFIRM,
									curFile.file),
							ConfirmDeleteFile(this, curFile));
					update();
				}
				else if(event.caller is deleteHullButton) {
					if(selected !is null)
						question(format(locale::HULL_DELETE_HULL_CONFIRM,
										selected.name),
								ConfirmDeleteHull(this, selected));
					update();
				}
				else if(event.caller is addHullButton) {
					Hull hull;
					curFile.hulls.insertLast(hull);
					select(hull);
					selectFile(curFile);
					update();
				}
			}
		}
		else if(event.type == GUI_Changed) {
			if(event.caller is fileList) {
				if(fileList.selected != -1)
					selectFile(files[fileList.selected]);
			}
			else if(event.caller is hullList) {
				if(hullList.selected != -1)
					select(curFile.hulls[hullList.selected]);
			}
			else if(event.caller is tlHandle || event.caller is brHandle) {
				updateHandles();
			}
		}

		if(event.caller is bp) {
			switch(event.type) {
				case GUI_Hover_Changed:
					if(brushButton != -1 && bp.hexHovered.x >= 0 && bp.hexHovered.y >= 0)
						modHex(vec2u(bp.hexHovered), brushButton);
				break;
			}
		}
		if(event.type == GUI_Confirmed || event.type == GUI_Focus_Lost) {
			if(event.caller is idField || event.caller is nameField || event.caller is backgroundField
				|| event.caller is meshField || event.caller is materialField
				|| event.caller is iconSheet || event.caller is iconIndex
				|| event.caller is hexSize || event.caller is gridX
				|| event.caller is gridY || event.caller is gridX2 ||
				event.caller is gridY2 || event.caller is scaleField) {
				update();
			}
		}
		else if(event.type == GUI_Clicked) {
			if(event.caller is hexSize || event.caller is gridX
				|| event.caller is gridY || event.caller is gridX2
				|| event.caller is gridY2 || event.caller is scaleField) {
				update();
			}
		}
		return BaseGuiElement::onGuiEvent(event);
	}

	void draw() {
		skin.draw(SS_DesignEditorBG, SF_Normal, AbsolutePosition);

		BaseGuiElement::draw();
		drawLine(tlHandle.absolutePosition.topLeft + vec2i(8, 16),
				 vec2i(tlHandle.absolutePosition.topLeft.x + 8,
					 brHandle.absolutePosition.topLeft.y + 8),
				Color(0xff000080), 3);
		drawLine(vec2i(brHandle.absolutePosition.topLeft.x + 8,
					 tlHandle.absolutePosition.topLeft.y + 8),
				brHandle.absolutePosition.topLeft + vec2i(8, 0),
				Color(0xff000080), 3);
		drawLine(tlHandle.absolutePosition.topLeft + vec2i(16, 8),
				 vec2i(brHandle.absolutePosition.topLeft.x + 8,
					 tlHandle.absolutePosition.topLeft.y + 8),
				Color(0xff000080), 3);
		drawLine(vec2i(tlHandle.absolutePosition.topLeft.x + 8,
					 brHandle.absolutePosition.topLeft.y + 8),
				brHandle.absolutePosition.topLeft + vec2i(0, 8),
				Color(0xff000080), 3);
	}
*/};

Tab@ createHullEditorTab() {
	return HullEditor();
}

class HullEditorCommand : ConsoleCommand {
	void execute(const string& args) {
		Tab@ editor = createHullEditorTab();
		newTab(editor);
		switchToTab(editor);
	}
};

void init() {
	addConsoleCommand("hull_editor", HullEditorCommand());
}

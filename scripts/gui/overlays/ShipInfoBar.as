import overlays.InfoBar;
import elements.BaseGuiElement;
import elements.Gui3DObject;
import elements.GuiText;
import elements.GuiButton;
import elements.GuiSprite;
import elements.GuiProgressbar;
import elements.GuiGroupDisplay;
import elements.GuiBlueprint;
import elements.GuiSkinElement;
import elements.MarkupTooltip;
import elements.GuiStatusBox;
import ship_groups;
import util.formatting;
import statuses;
import icons;
from overlays.Construction import ConstructionOverlay;
from obj_selection import isSelected, selectObject, clearSelection, addToSelection;
from tabs.GalaxyTab import zoomTabTo, openOverlay, toggleSupportOverlay;

bool SHIP_INFOBAR_EXPANDED = false;

class ShipInfoBar : InfoBar {
	Ship@ ship;
	ConstructionOverlay@ construction;

	GuiBlueprint@ bpdisp;

	GuiText@ name;
	GuiText@ subsystem;

	GuiSprite@ healthIcon;
	GuiText@ healthLabel;
	GuiProgressbar@ health;

	GuiSprite@ supplyIcon;
	GuiText@ supplyLabel;
	GuiProgressbar@ supply;

	GuiSprite@ energyIcon;
	GuiText@ energyLabel;
	GuiProgressbar@ energy;

	GuiSprite@ ftlIcon;
	GuiText@ ftlLabel;
	GuiProgressbar@ ftl;

	GuiProgressbar@ ftlCrystals;
	GuiSprite@ ftlCrystalsIcon;

	GuiSprite@ strengthIcon;
	GuiText@ strengthLabel;
	GuiProgressbar@ strength;

	GuiSkinElement@ groupBox;
	GuiGroupDisplay@ groupdisp;

	BaseGuiElement@ buttonBar;
	GuiButton@ supportsButton;
	GuiButton@ formationButton;
	GuiButton@ ordersButton;

	GuiProgressbar@ shield;
	GuiSprite@ shieldIcon;

	GuiButton@ expandButton;

	ActionBar@ actions;
	bool expanded = false;

	array<Status> statuses;
	array<GuiStatusBox@> statusBoxes;

	ShipInfoBar(IGuiElement@ parent) {
		super(parent);
		@alignment = Alignment(Left, Bottom-297, Left+395, Bottom);

		@actions = ActionBar(this, vec2i(385, 241));
		actions.noClip = true;

		int y = -8;

		y += 38;
		@bpdisp = GuiBlueprint(this, Alignment(Left+4, Top+y, Right-128, Bottom-104));
		bpdisp.noClip = true;
		bpdisp.popHover = true;
		bpdisp.popSize = vec2i(77, 40);
		bpdisp.horizAlign = 0.25;
		bpdisp.vertAlign = 1.0;
		bpdisp.hoverArcs = true;

		@name = GuiText(bpdisp, Alignment(Left+12, Top+28, Right-12, Top+60));
		name.horizAlign = 0.0;
		name.vertAlign = 0.0;
		name.font = FT_Medium;
		name.stroke = colors::Black;
		name.visible = false;

		@subsystem = GuiText(bpdisp, Alignment(Left+12, Top+28, Right-12, Top+60));
		subsystem.horizAlign = 1.0;
		subsystem.vertAlign = 0.0;
		subsystem.font = FT_Subtitle;
		subsystem.stroke = colors::Black;
		subsystem.visible = false;

		@expandButton = GuiButton(bpdisp, Alignment(Right+75, Bottom-20, Width=20, Height=20), icons::Add);
		expandButton.noClip = true;
		expandButton.style = SS_IconButton;

		@health = GuiProgressbar(this, Alignment(Left+8, Bottom-102, Left+200, Bottom-72));
		health.textHorizAlign = 0.9;

		@healthIcon = GuiSprite(health, Alignment(Left-8, Top-9, Left+24, Bottom-8), icons::Health);
		healthIcon.noClip = true;
		@healthLabel = GuiText(health, Alignment(Left+23, Top, Left+100, Bottom));
		healthLabel.font = FT_Bold;
		healthLabel.text = locale::HEALTH;
		healthLabel.stroke = colors::Black;

		@shield = GuiProgressbar(this, Alignment(Left+9, Bottom-82, Left+199, Bottom-72));
		shield.noClip = true;
		shield.textHorizAlign = 0.85;
		shield.textVertAlign = 1.65;
		shield.visible = false;
		shield.frontColor = Color(0x429cffff);
		shield.backColor = Color(0x59a8ff20);

		@shieldIcon = GuiSprite(shield, Alignment(Right-25, Bottom-25, Width=30, Height=30), icons::Shield);
		shieldIcon.noClip = true;

		@supply = GuiProgressbar(this, Alignment(Left+206, Bottom-102, Right-22, Bottom-72));
		supply.textHorizAlign = 0.9;

		@supplyIcon = GuiSprite(supply, Alignment(Left-5, Top-6, Left+24, Bottom-8), icons::Supply);
		supplyIcon.noClip = true;
		@supplyLabel = GuiText(supply, Alignment(Left+23, Top, Left+100, Bottom));
		supplyLabel.font = FT_Bold;
		supplyLabel.text = locale::SUPPLY;
		supplyLabel.stroke = colors::Black;

		@ftl = GuiProgressbar(this, Alignment(Left+8, Bottom-68, Left+200, Bottom-38));
		ftl.textHorizAlign = 0.9;
		ftl.frontColor = colors::FTLResource;

		@ftlIcon = GuiSprite(ftl, Alignment(Left-8, Top-9, Left+24, Bottom-8), icons::FTL);
		ftlIcon.noClip = true;
		@ftlLabel = GuiText(ftl, Alignment(Left+23, Top, Left+100, Bottom));
		ftlLabel.font = FT_Bold;
		ftlLabel.text = locale::SHIP_FTL;
		ftlLabel.stroke = colors::Black;

		@ftlCrystals = GuiProgressbar(this, Alignment(Left+9, Bottom-48, Left+199, Bottom-38));
		ftlCrystals.noClip = true;
		ftlCrystals.textHorizAlign = 0.85;
		ftlCrystals.textVertAlign = 1.65;
		ftlCrystals.frontColor = Color(0xcd20ddff);
		ftlCrystals.backColor = Color(0xc88bcd20);

		@ftlCrystalsIcon = GuiSprite(ftlCrystals, Alignment(Right-25, Bottom-25, Width=30, Height=30), Sprite(spritesheet::ResourceIcons, 22));
		ftlCrystalsIcon.noClip = true;

		@energy = GuiProgressbar(this, Alignment(Left+206, Bottom-68, Right-22, Bottom-38));
		energy.textHorizAlign = 0.9;

		@energyIcon = GuiSprite(energy, Alignment(Left-5, Top-6, Left+24, Bottom-8), icons::Energy);
		energyIcon.noClip = true;
		@energyLabel = GuiText(energy, Alignment(Left+23, Top, Left+100, Bottom));
		energyLabel.font = FT_Bold;
		energyLabel.text = locale::SHIP_ENERGY;
		energyLabel.stroke = colors::Black;

		@strength = GuiProgressbar(this, Alignment(Left+8, Bottom-34, Left+200, Bottom-4));
		strength.textHorizAlign = 0.9;

		@strengthIcon = GuiSprite(strength, Alignment(Left-5, Top-6, Left+24, Bottom-8), icons::Strength);
		strengthIcon.noClip = true;
		@strengthLabel = GuiText(strength, Alignment(Left+23, Top, Left+100, Bottom));
		strengthLabel.font = FT_Bold;
		strengthLabel.text = locale::STRENGTH;
		strengthLabel.stroke = colors::Black;

		@groupBox = GuiSkinElement(this, Alignment(Left+206, Bottom-34, Right-22, Bottom-5), SS_PlainOverlay);
		@groupdisp = GuiGroupDisplay(groupBox, Alignment(Left+3, Top+4, Right-3, Bottom));
		groupdisp.horizAlign = 0.0;

		updateAbsolutePosition();
		setExpanded(SHIP_INFOBAR_EXPANDED);
	}

	void remove() override {
		if(construction !is null)
			construction.remove();
		InfoBar::remove();
	}

	void setExpanded(bool value) {
		if(expanded == value)
			return;
		expanded = value;

		bpdisp.alignment.set(Left+4, Top+30, Right-128, Bottom-70);
		if(expanded) {
			bpdisp.alignment.padded(0,
					-480.0/1920.0*double(screenSize.width),
					-610.0/1080.0*double(screenSize.height),
					0);
			bpdisp.horizAlign = 0.5;
			bpdisp.vertAlign = 0.5;
			expandButton.alignment.set(Right-34, Bottom-20, Right-34+28, Bottom-20+28);
			expandButton.setIcon(icons::Minus);
		}
		else {
			bpdisp.horizAlign = 0.25;
			bpdisp.vertAlign = 1.0;
			expandButton.alignment.set(Right+75, Bottom-20, Right+75+20, Bottom-20+20);
			expandButton.setIcon(icons::Add);
		}

		bpdisp.updateAbsolutePosition();

		bpdisp.popHover = !expanded;
		name.visible = expanded;
		subsystem.visible = expanded;
	}

	void updateActions() {
		actions.clear();
		
		if(ship.owner !is null && ship.owner.controlled) {
			actions.addBasic(ship);
			actions.addFTL(ship);
			actions.addAbilities(ship);
			actions.addEmpireAbilities(ship.owner, ship);
			actions.addScouting(ship);
		}

		actions.init(ship);
	}

	bool compatible(Object@ obj) override {
		return obj.isShip;
	}

	Object@ get() override {
		return ship;
	}

	void set(Object@ obj) override {
		@ship = cast<Ship>(obj);
		bpdisp.display(ship);

		setExpanded(SHIP_INFOBAR_EXPANDED);
		updateActions();
	}

	bool displays(Object@ obj) override {
		if(obj is ship)
			return true;
		return false;
	}

	bool showManage(Object@ obj) override {
		if(construction !is null)
			construction.remove();
		if(obj.hasConstruction && obj.owner.controlled) {
			@construction = ConstructionOverlay(findTab(), obj);
			return false;
		}
		if(!expanded)
			setExpanded(true);
		return false;
	}

	void toggleExpanded() {
		if(expanded == SHIP_INFOBAR_EXPANDED) {
			SHIP_INFOBAR_EXPANDED = !SHIP_INFOBAR_EXPANDED;
			setExpanded(SHIP_INFOBAR_EXPANDED);
		}
		else {
			setExpanded(!expanded);
		}
	}

	double lastClick = -INFINITY;
	bool onMouseEvent(const MouseEvent& event, IGuiElement@ source) {
		switch(event.type) {
			case MET_Button_Up: {
				if(event.button == 0) {
					if(lastClick > frameTime - double(settings::iDoubleClickMS) / 1000.0) {
						selectObject(ship);
						setExpanded(!expanded);
						if(SHIP_INFOBAR_EXPANDED && !expanded)
							SHIP_INFOBAR_EXPANDED = false;
					}
					else
						lastClick = frameTime;
				}
				else if(event.button == 2) {
					zoomTabTo(ship);
					return true;
				}
				else if(event.button == 1) {
					toggleExpanded();
					return true;
				}
			} break;
		}
		return InfoBar::onMouseEvent(event, source);
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is groupdisp) {
					if(groupdisp.hovered == 0) {
						selectObject(groupdisp.leader);
					}
					else {
						if(!shiftKey)
							clearSelection();
						Object@ leader = groupdisp.leader;
						GroupData@ dat = groupdisp.groups[groupdisp.hovered-1];
						for(uint i = 0, cnt = leader.supportCount; i < cnt; ++i) {
							Ship@ supp = cast<Ship>(leader.supportShip[i]);
							if(supp !is null && supp.valid && supp.blueprint.design is dat.dsg)
								addToSelection(supp);
						}
					}
					return true;
				}
				else if(evt.caller is expandButton) {
					toggleExpanded();
					return true;
				}
			break;
			case GUI_Hover_Changed:
				if(evt.caller is bpdisp) {
					updateHealthBar();
					return true;
				}
			break;
		}
		return InfoBar::onGuiEvent(evt);
	}

	void updateHealthBar() {
		if(ship is null)
			return;

		const Blueprint@ bp = ship.blueprint;
		const Design@ design = bp.design;
		const Hull@ hull = design.hull;

		Color high;
		Color low;

		double curHP = 0, maxHP = 1;
		if(bpdisp.hexHovered.x < 0 || bpdisp.hexHovered.y < 0) {
			curHP = bp.currentHP;
			maxHP = design.totalHP;

			high = Color(0x00ff00ff);
			low = Color(0xff0000ff);

			subsystem.visible = false;
		}
		else {
			ObjectLock lock(ship, true);
			vec2u hex = vec2u(bpdisp.hexHovered);
			const HexStatus@ status = bp.getHexStatus(hex.x, hex.y);
			if(status !is null) {
				maxHP = design.variable(hex, HV_HP);
				curHP = maxHP * double(status.hp) / double(0xff);
			}

			high = Color(0x9768ffff);
			low = Color(0xff689bff);

			auto@ sys = design.subsystem(hex);
			auto@ mod = design.module(hex);
			if(sys !is null && expanded) {
				subsystem.visible = true;
				if(mod is null || mod is sys.type.coreModule || mod is sys.type.defaultModule) {
					if(mod is sys.type.coreModule)
						subsystem.text = format("$1 ($2)", sys.type.name, locale::SUBSYS_CORE);
					else
						subsystem.text = sys.type.name;
					subsystem.color = sys.type.color;
				}
				else {
					subsystem.text = mod.name;
					subsystem.color = mod.color;
				}
			}
			else {
				subsystem.visible = false;
			}
		}

		if(!ship.visible)
			curHP = maxHP;

		health.progress = curHP / maxHP;
		health.frontColor = low.interpolate(high, health.progress);
		health.text = standardize(curHP)+" / "+standardize(maxHP);

		double repair = 0.0, combatMod = 1.0;
		if(design !is null) {
			repair = design.total(SV_Repair);
			combatMod *= min(bp.shipEffectiveness, 1.0);
		}

		string tt = format(locale::TT_SHIP_HEALTH,
			standardize(curHP), standardize(maxHP),
			standardize(repair * 1.0/3.0 * combatMod), standardize(repair));

		//Update shields
		double curShield = ship.Shield;
		double maxShield = ship.MaxShield;

		if(maxShield != 0) {
			shield.visible = true;
			health.textHorizAlign = 0.25;
			healthLabel.visible = false;

			shield.progress = min(curShield / max(maxShield, 0.01), 1.0);
			shield.text = standardize(curShield, true);

			double shieldRegen = design.total(SV_ShieldRegen);
			tt += "\n\n";
			tt += format(locale::TT_SHIP_SHIELD,
				standardize(curShield), standardize(maxShield),
				standardize(shieldRegen));
		}
		else {
			shield.visible = false;
			health.textHorizAlign = 0.9;
			healthLabel.visible = true;
		}

		setMarkupTooltip(health, tt, width = 350);
		@shield.tooltipObject = health.tooltipObject;
	}

	void updateStrengthBar() {
		if(groupdisp.leader is null) {
			strength.progress = 0.f;
			strength.text = "-";
			setMarkupTooltip(strength, "");
			return;
		}

		double curStr = groupdisp.leader.getFleetStrength() * 0.001;
		double totStr = groupdisp.leader.getFleetMaxStrength() * 0.001;

		if(!ship.visible)
			curStr = totStr;

		if(totStr == 0) {
			strength.progress = 0.f;
			strength.frontColor = Color(0xff6a00ff);
			strength.text = "-";
		}
		else {
			strength.progress = curStr / totStr;
			if(strength.progress > 1.001f) {
				strength.progress = 1.f;
				strength.font = FT_Bold;
			}
			else {
				strength.font = FT_Normal;
			}

			strength.frontColor = Color(0xff6a00ff).interpolate(Color(0xffc600ff), strength.progress);
			strength.text = standardize(curStr);
		}

		double dps = groupdisp.leader.getFleetDPS();
		double hp = groupdisp.leader.getFleetHP();
		float eff = groupdisp.leader.getFleetEffectiveness() / groupdisp.leader.getBaseFleetEffectiveness();
		setMarkupTooltip(strength, format(locale::TT_SHIP_STRENGTH,
			standardize(curStr), standardize(totStr),
			standardize(hp), standardize(dps),
			toString(eff*100.f, 0)+"%"),
			width = 350);
	}

	void updateFTLBar() {
		if(ship is null)
			return;

		double curFTL = 0.0;
		double maxFTL = 0.0;
		double curCrystals = 0.0;
		double maxCrystals = 0.0;
	
		Ship@ leader = cast<Ship>(groupdisp.leader);
		const Design@ design;
		if(leader !is null) {
			curFTL = leader.FTL;
			maxFTL = leader.MaxFTL;
			curCrystals = leader.Crystals;
			maxCrystals = leader.MaxCrystals;
			@design = leader.blueprint.design;
		}

		if(maxFTL == 0) {
			ftl.progress = 0.f;
			ftl.text = "-";
		}
		else {
			ftl.progress = curFTL / maxFTL;
			if(ftl.progress > 1.001f) {
				ftl.progress = 1.f;
				ftl.font = FT_Bold;
			}
			else
				ftl.font = FT_Normal;
		
			ftl.text = standardize(curFTL)+" / "+standardize(maxFTL);
		}

		double regen = 0.0;
		double emergencyRegen = 0.0;
		double resupply = 0.0;
		if(design !is null) {
			regen = ship.blueprint.getEfficiencySum(SV_FTLRegen);
			emergencyRegen = (ship.blueprint.getEfficiencySum(SV_Power) - design.variable(ShV_REQUIRES_Power)) / 100;
			resupply = ship.blueprint.getEfficiencySum(SV_CrystalRate);
		}

		string tt = format(locale::TT_SHIP_FTL_1, standardize(curFTL), standardize(maxFTL)) + "\n\n" + format(locale::TT_SHIP_FTL_2,
			standardize(emergencyRegen), standardize(regen), standardize(curCrystals), standardize(maxCrystals), standardize(resupply));
		
		if(maxCrystals == 0) {
			ftlCrystals.visible = false;
			ftl.textHorizAlign = 0.9;
			ftlLabel.visible = true;
		}
		else {
			ftlCrystals.visible = true;
			ftl.textHorizAlign = 0.25;
			ftlLabel.visible = false;

			ftlCrystals.progress = min(curCrystals / max(maxCrystals, 0.01), 1.0);
			ftlCrystals.text = standardize(curCrystals, true);
		}

		setMarkupTooltip(ftl, tt, width = 350);
		@ftlCrystals.tooltipObject = ftl.tooltipObject;
	}

	void updateEnergyBar() {
		if(ship is null)
			return;

		double curEnergy = 0.0;
		double maxEnergy = 0.0;
		const Design@ design = ship.blueprint.design;
		curEnergy = ship.Energy;
		maxEnergy = ship.MaxEnergy;

		if(!ship.visible)
			curEnergy = maxEnergy;

		if(maxEnergy == 0) {
			energy.progress = 0.f;
			energy.frontColor = colors::Energy;
			energy.text = "-";
		}
		else {
			energy.progress = curEnergy / maxEnergy;
			if(energy.progress > 1.001f) {
				energy.progress = 1.f;
				energy.font = FT_Bold;
			}
			else {
				energy.font = FT_Normal;
			}

			if(energy.progress > 0.4f)
				energy.frontColor = colors::Energy;
			else
				energy.frontColor = Color(0xec370fff).interpolate(colors::Energy, energy.progress/0.4f);

			energy.text = standardize(curEnergy);
		}

		double regen = 0.0;
		if(design !is null)
			regen = ship.blueprint.getEfficiencySum(SV_Power) - design.variable(ShV_REQUIRES_Power);
		setMarkupTooltip(energy, format(locale::TT_SHIP_ENERGY,
			standardize(curEnergy), standardize(maxEnergy),
			standardize(regen)),
			width = 350);
	}

	void updateSupplyBar() {
		double curSup = 0.0;
		double totSup = 0.0;

		Ship@ leader = cast<Ship>(groupdisp.leader);
		const Design@ design;
		if(leader !is null) {
			curSup = leader.Supply;
			totSup = leader.MaxSupply;
			@design = leader.blueprint.design;
		}

		if(!ship.visible)
			curSup = totSup;

		if(totSup == 0) {
			supply.progress = 0.f;
			supply.frontColor = Color(0xff6a00ff);
			supply.text = "-";
		}
		else {
			supply.progress = curSup / totSup;
			if(supply.progress > 1.001f) {
				supply.progress = 1.f;
				supply.font = FT_Bold;
			}
			else {
				supply.font = FT_Normal;
			}

			if(supply.progress < 0.4f)
				supply.frontColor = Color(0xd53f1eff).interpolate(Color(0xd5cc1eff), supply.progress/0.4f);
			else
				supply.frontColor = Color(0x4a9487ff);
			supply.text = standardize(curSup);
		}

		double resupply = 0.0;
		if(design !is null)
			resupply = design.total(SV_SupplyRate);
		setMarkupTooltip(supply, format(locale::TT_SHIP_SUPPLY,
			standardize(curSup), standardize(totSup),
			standardize(resupply * 0.12f), standardize(resupply)),
			width = 350);
	}

	IGuiElement@ elementFromPosition(const vec2i& pos) override {
		IGuiElement@ elem = BaseGuiElement::elementFromPosition(pos);
		if(!expanded && (elem is this || elem is bpdisp)) {
			vec2i relPos = pos - AbsolutePosition.topLeft;
			bool active = material::ShipInfoBar.isPixelActive(relPos);
			if(!active)
				return null;
		}
		return elem;
	}

	double updateTimer = 1.0;
	void update(double time) override {
		Empire@ owner = ship.owner;
		bool owned = owner is playerEmpire;
		const Blueprint@ bp = ship.blueprint;
		const Design@ design = bp.design;
		const Hull@ hull = design.hull;

		if(expanded && !SHIP_INFOBAR_EXPANDED && !ship.selected)
			setExpanded(false);

		if(design !is bpdisp.design)
			set(ship);

		if(ship.visible) {
			@bpdisp.bp = bp;
			groupdisp.visible = true;
		}
		else {
			@bpdisp.bp = null;
			groupdisp.visible = false;
		}

		if(construction !is null) {
			if(construction.parent is null) {
				@construction = null;
				visible = true;
			}
			else
				construction.update(time);
		}

		//Update ship data
		name.font = FT_Medium;
		name.text = formatShipName(ship);
		if(owner !is null)
			name.color = owner.color;
		vec2i dim = name.getTextDimension();
		int w = clamp(dim.x+26, 160, 1000);
		if(dim.x > name.size.width) {
			name.font = FT_Bold;
			dim = name.getTextDimension();
			if(dim.x > name.size.width)
				name.font = FT_Small;
		}

		//Update statuses
		Object@ leader = groupdisp.leader;
		if(leader !is null && leader.statusEffectCount > 0)
			statuses.syncFrom(leader.getStatusEffects());
		else
			statuses.length = 0;

		updateStatusBoxes(bpdisp, statuses, statusBoxes, fromObject=leader);
		int off = expanded ? -70 : 30;
		for(uint i = 0, cnt = statusBoxes.length; i < cnt; ++i) {
			statusBoxes[i].noClip = true;
			statusBoxes[i].rect = recti_area(bpdisp.size.width+off-36*i, bpdisp.size.height-26, 32,32);
		}

		//Update whatever health is displayed
		updateHealthBar();
		updateSupplyBar();
		updateStrengthBar();
		updateFTLBar();
		updateEnergyBar();

		//Update group
		groupdisp.update(ship);

		updateTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = 1.0;
			updateActions();
		}

		InfoBar::update(time);
	}

	void draw() override {
		Color col;
		Empire@ owner = ship.owner;
		if(owner !is null)
			col = owner.color;

		if(!expanded)
			material::ShipInfoBar.draw(AbsolutePosition.padded(0,0,0,35), col);
		else {
			skin.draw(SS_Panel, SF_Normal, bpdisp.absolutePosition.padded(-20,0,0,-100), col);
			skin.draw(SS_BG3D, SF_Normal, bpdisp.absolutePosition.padded(0,4,4,-12), col);
		}

		if(actions.visible) {
			recti pos = actions.absolutePosition;
			skin.draw(SS_Panel, SF_Normal, recti(pos.topLeft - vec2i(50, 0), pos.botRight + vec2i(0, 20)));
		}

		skin.draw(SS_InfoBar, SF_Normal, recti_area(vec2i(AbsolutePosition.topLeft.x, AbsolutePosition.botRight.y-40), vec2i(AbsolutePosition.width-13, 45)));
		BaseGuiElement::draw();
	}
};

InfoBar@ makeShipInfoBar(IGuiElement@ parent, Object@ obj) {
	ShipInfoBar bar(parent);
	bar.set(obj);
	return bar;
}

#include "include/resource_constants.as"
import elements.BaseGuiElement;
import elements.Gui3DObject;
import elements.GuiOverlay;
import elements.GuiSkinElement;
import elements.GuiText;
import elements.GuiSprite;
import elements.GuiButton;
import elements.GuiListbox;
import elements.GuiAccordion;
import elements.GuiPanel;
import elements.GuiDistributionBar;
import elements.GuiMarkupText;
import elements.MarkupTooltip;
import planets.PlanetSurface;
import elements.GuiPlanetSurface;
import elements.GuiResources;
import elements.GuiContextMenu;
import planet_levels;
import constructible;
import tile_resources;
import buildings;
import orbitals;
import util.formatting;
import icons;
import systems;
import cargo;
import traits;
import overlays.Construction;
from tabs.PlanetsTab import PlanetTree;
from gui import animate_time;

const double ANIM1_TIME = 0.15;
const double ANIM2_TIME = 0.001;
const uint BORDER = 20;
const uint WIDTH = 500;
const uint S_HEIGHT = 360;
const uint INCOME_HEIGHT = 140;
const uint VAR_H = 40;
const int MIN_TILE_SIZE = 18;
const int MIN_TILE_SIZE_HD = 26;
Resources available;

// {{{ Overlay
class PlanetOverlay : GuiOverlay, ConstructionParent {
	Gui3DObject@ objView;
	Planet@ obj;
	bool closing = false;

	SurfaceDisplay@ surface;
	IncomeDisplay@ incomes;
	ResourceDisplay@ resources;
	ConstructionDisplay@ construction;
	Resource[] resList;

	Alignment@ objTarget;

	PlanetOverlay(IGuiElement@ parent, Planet@ Obj) {
		super(parent);
		fade.a = 0;
		@obj = Obj;

		vec2i parSize = parent.size;
		@objView = Gui3DObject(this, recti_area(vec2i(-456, parSize.y-228), vec2i(912, 912)));
		objView.internalRotation = quaterniond_fromAxisAngle(vec3d(0.0, 0.0, 1.0), -0.25*pi);
		@objView.object = obj;

		int plSize = parSize.x * 2;
		@objTarget = Alignment(Left+0.5f-plSize/2, Top+0.5f, Width=plSize, Height=plSize);
		recti targPos = objTarget.resolve(parSize);
		animate_time(objView, targPos, ANIM1_TIME);

		float offset = 0.05f;
		if(parent.size.width > 1300)
			offset = 0.1f;

		updateAbsolutePosition();

		vec2i origin = targPos.center;
		@construction = ConstructionDisplay(this, origin, Alignment(Right-offset-WIDTH,
					Top+BORDER, Right-offset, Bottom-BORDER));
		@surface = SurfaceDisplay(this, origin, Alignment(Left+offset,
					Top+BORDER, Right-offset-BORDER-WIDTH, Top+0.6f-BORDER/2));
		@resources = ResourceDisplay(this, origin, Alignment(Left+offset,
					Top+0.6f+BORDER/2, Right-offset-BORDER-WIDTH, Bottom-BORDER));
	}

	IGuiElement@ elementFromPosition(const vec2i& pos) override {
		IGuiElement@ elem = BaseGuiElement::elementFromPosition(pos);
		if(elem is objView)
			return this;
		return elem;
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Animation_Complete:
				if(evt.caller is objView) {
					if(closing) {
						GuiOverlay::close();
						return true;
					}

					//Make sure the object view stays in the right position
					@objView.alignment = objTarget;

					//Start showing all the data
					surface.animate();
					resources.animate();
					construction.animate();

					return true;
				}
				break;
		}
		return GuiOverlay::onGuiEvent(evt);
	}

	bool onMouseEvent(const MouseEvent& evt, IGuiElement@ source) override {
		switch(evt.type) {
			case MET_Button_Up:
				if(surface.selBuilding !is null) {
					surface.stopBuild();
					return true;
				}
				else if(resources.tree.isDragging || resources.tree.dragging !is null) {
					resources.tree.stopDragging();
					return true;
				}
				break;
		}

		return GuiOverlay::onMouseEvent(evt, source);
	}

	void close() override {
		if(parent is null || objView is null || closing)
			return;
		closing = true;
		@objView.alignment = null;

		surface.visible = false;
		resources.visible = false;
		construction.visible = false;

		vec2i parSize = parent.size;
		recti targPos = recti_area(vec2i(-456, parSize.y-228), vec2i(912, 912));
		animate_time(objView, targPos, ANIM1_TIME);
	}

	void startBuild(const BuildingType@ type) {
		if(surface !is null)
			surface.startBuild(type);
	}

	Object@ get_object() {
		return obj;
	}

	void triggerUpdate() {
	}

	void update(double time) {
		surface.update(time);
		resources.update(time);
		construction.update(time);
	}

	void draw() {
		if(!settings::bGalaxyBG && objView.Alignment !is null)
			material::Skybox.draw(AbsolutePosition);
		GuiOverlay::draw();
	}
};

class DisplayBox : BaseGuiElement {
	PlanetOverlay@ overlay;
	Alignment@ targetAlign;

	DisplayBox(PlanetOverlay@ ov, vec2i origin, Alignment@ target) {
		@overlay = ov;
		@targetAlign = target;
		super(overlay, recti_area(origin, vec2i(1,1)));
		visible = false;
		updateAbsolutePosition();
	}

	void animate() {
		visible = true;
		animate_time(this, targetAlign.resolve(overlay.size), ANIM2_TIME);
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Animation_Complete:
				@alignment = targetAlign;
				return true;
		}
		return BaseGuiElement::onGuiEvent(evt);
	}

	bool pressed = false;
	bool onMouseEvent(const MouseEvent& evt, IGuiElement@ source) override {
		switch(evt.type) {
			case MET_Button_Down:
				if(evt.button == 0) {
					pressed = true;
					return true;
				}
				break;
			case MET_Button_Up:
				if(evt.button == 0 && pressed) {
					pressed = false;
					return true;
				}
				break;
		}

		return BaseGuiElement::onMouseEvent(evt, source);
	}

	void remove() override {
		@overlay = null;
		BaseGuiElement::remove();
	}

	void update(double time) {
	}

	void draw() {
		skin.draw(SS_OverlayBox, SF_Normal, AbsolutePosition, Color(0x888888ff));
		BaseGuiElement::draw();
	}
};
//}}}

// {{{ Surface
class VarBox : BaseGuiElement {
	GuiSprite@ icon;
	GuiText@ value;
	Color color;

	VarBox(IGuiElement@ parent, const recti& pos) {
		super(parent, pos);

		@icon = GuiSprite(this, Alignment(Left+4, Top+2, Left+VAR_H, Bottom-2));
		@value = GuiText(this, Alignment(Left+4, Top+2, Right-4, Bottom-6));
		value.font = FT_Subtitle;
		value.stroke = colors::Black;
		value.vertAlign = 1.0;
		value.horizAlign = 1.0;
	}

	void draw() {
		skin.draw(SS_PlainBox, SF_Normal, AbsolutePosition.padded(-2, 2, -2, 2));

		Color glowCol = color;
		glowCol.a = 0x18;
		drawRectangle(AbsolutePosition.padded(0, 3, 0, 3),
				Color(0x22222218), Color(0x22222218),
				glowCol, glowCol);

		BaseGuiElement::draw();
	}
};

class SurfaceDisplay : DisplayBox {
	Planet@ pl;

	GuiPanel@ surfPanel;
	GuiPlanetSurface@ sdisplay;
	PlanetSurface surface;

	GuiMarkupText@ name;
	GuiText@ level;

	GuiSkinElement@ resDisplay;
	GuiPanel@ varPanel;

	const BuildingType@ selBuilding;

	SurfaceDisplay(PlanetOverlay@ ov, vec2i origin, Alignment@ target) {
		super(ov, origin, target);

		@surfPanel = GuiPanel(this, Alignment(Left+158, Top+38, Right-8, Bottom-8));
		@sdisplay = GuiPlanetSurface(surfPanel, recti());
		@sdisplay.surface = surface;
		sdisplay.maxSize = 0.02 * double(ov.size.width);

		@name = GuiMarkupText(this, Alignment(Left+8, Top-2, Right-8, Top+38));
		name.noClip = true;
		name.defaultFont = FT_Big;
		name.defaultStroke = colors::Black;

		@level = GuiText(this, Alignment(Left+8, Top+8, Right-8, Top+38));
		level.font = FT_Medium;
		level.horizAlign = 1.0;
		level.stroke = colors::Black;
		level.visible = false;

		@resDisplay = GuiSkinElement(this, Alignment(Left+1, Top+38, Left+150, Bottom-2), SS_PatternBox);
		@varPanel = GuiPanel(resDisplay, Alignment().fill());

		@pl = overlay.obj;
		updateAbsolutePosition();
	}

	void updateAbsolutePosition() {
		DisplayBox::updateAbsolutePosition();

		if(sdisplay !is null && pl !is null) {
			int minSize = screenSize.width >= 1910 ? MIN_TILE_SIZE_HD : MIN_TILE_SIZE;
			int sw = max(surfPanel.size.width - (surfPanel.vert.visible ? 20 : 0), minSize * surface.size.width);
			int sh = max(surfPanel.size.height - (surfPanel.horiz.visible ? 20 : 0), minSize * surface.size.height);
			vec2i prevSize = sdisplay.size;
			if(prevSize.x != sw || prevSize.y != sh) {
				sdisplay.size = vec2i(sw, sh);
				surfPanel.updateAbsolutePosition();
			}
		}
	}

	void startBuild(const BuildingType@ type) {
		@selBuilding = type;
		sdisplay.showTooltip = false;
	}

	void stopBuild() {
		@selBuilding = null;
		sdisplay.showTooltip = true;
	}

	void openBuildingMenu(const vec2i& pos, SurfaceBuilding@ bld) {
		GuiContextMenu menu(mousePos);
		if(bld.type.canRemove(pl)) {
			if(bld.completion >= 1.f)
				menu.addOption(DestroyBuildingOption(pl, format(locale::DESTROY_BUILDING, bld.type.name), pos));
			else
				menu.addOption(DestroyBuildingOption(pl, format(locale::CANCEL_BUILDING, bld.type.name), pos));
		}
		menu.finalize();
	}

	uint varIndex = 0;
	array<VarBox@> variables;
	void resetVars() {
		varIndex = 0;
	}

	void addVariable(const Sprite& icon, const string& value, const string& tooltip = "", const Color& color = colors::White) {
		if(varIndex >= variables.length)
			variables.insertLast(VarBox(varPanel, recti()));

		int w = min(varPanel.size.width, 149) - 2;
		if(varPanel.vert.visible && varPanel.size.height >= 30)
			w -= 20;

		auto@ box = variables[varIndex];
		box.rect = recti_area(1, 4+varIndex*VAR_H, w, VAR_H);

		box.icon.desc = icon;
		box.value.text = value;
		box.value.color = color;
		box.color = color;
		setMarkupTooltip(box, tooltip, width=399);

		++varIndex;
	}

	void finalizeVars() {
		for(uint i = varIndex, cnt = variables.length; i < cnt; ++i)
			variables[i].remove();
		variables.length = varIndex;
	}

	void updateVars() {
		resetVars();

		if(pl.visible) {
			if(pl.owner.valid) {
				Color popColor = colors::White;
				if(!pl.primaryResourceUsable) {
					if(pl.population < getPlanetLevelRequiredPop(pl.resourceLevel) && !pl.inCombat) {
						popColor = colors::Orange;
					}
				}
				string popText = standardize(pl.population, true) + " / " + standardize(pl.maxPopulation, true);
				addVariable(icons::Population, popText, locale::PLANET_POPULATION_TIP, popColor);
			}
		}
		if(pl.owner is playerEmpire) {
			auto@ scTrait = getTrait("StarChildren");
			if(scTrait is null || !playerEmpire.hasTrait(scTrait.id)) {
				Color color = colors::White;
				if(int(surface.totalPressure) > int(surface.pressureCap))
					color = colors::Red;
				string value = standardize(surface.totalPressure, true) + " / " + standardize(surface.pressureCap, true);
				string ttip = format(locale::PLANET_PRESSURE_TIP, standardize(surface.totalPressure, true), standardize(surface.totalSaturate, true), standardize(surface.pressureCap, true));
				addVariable(icons::Pressure, value, ttip, color);
			}
			{
				Color color = colors::Money;
				int income = pl.income;
				if(income < 0)
					color = colors::Red;
				string value = formatMoney(income);
				string ttip = format(locale::PLANET_INCOME_TIP, standardize(surface.pressures[TR_Money], true), standardize(surface.resources[TR_Money], true));
				addVariable(icons::Money, value, ttip, color);
			}

		}
		if(pl.owner.valid) {
			string loyText = toString(pl.currentLoyalty, 0);
			addVariable(icons::Loyalty, loyText, locale::PLANET_LOYALTY_TIP, colors::White);
		}
		if(pl.owner is playerEmpire) {
			if(surface.resources[TR_Energy] > 0 || surface.pressures[TR_Energy] > 0) {
				Color color = colors::Energy;
				string value = "+"+formatRate(surface.resources[TR_Energy] * TILE_ENERGY_RATE * pl.owner.EnergyEfficiency);
				string ttip = format(locale::PLANET_ENERGY_TIP, standardize(surface.pressures[TR_Energy], true), standardize(surface.saturates[TR_Energy], true));
				addVariable(icons::Energy, value, ttip, color);
			}

			if(surface.resources[TR_Defense] > 0 || surface.pressures[TR_Defense] > 0) {
				Color color = colors::Defense;
				string value = standardize(surface.resources[TR_Defense], true);
				string ttip = format(locale::PLANET_DEFENSE_TIP, standardize(surface.pressures[TR_Defense], true), standardize(surface.saturates[TR_Defense], true));
				addVariable(icons::Defense, value, ttip, color);
			}

			if(surface.resources[TR_Influence] > 0 || surface.pressures[TR_Influence] > 0) {
				Color color = colors::Influence;
				string value = standardize(surface.resources[TR_Influence], true);
				string ttip = format(locale::PLANET_INFLUENCE_TIP, standardize(surface.pressures[TR_Influence], true), standardize(surface.saturates[TR_Influence], true));
				addVariable(icons::Influence, value, ttip, color);
			}

			if(surface.resources[TR_Research] > 0 || surface.pressures[TR_Research] > 0) {
				Color color = colors::Research;
				string value = "+"+formatRate(surface.resources[TR_Research] * TILE_RESEARCH_RATE * pl.owner.ResearchEfficiency);
				string ttip = format(locale::PLANET_RESEARCH_TIP, standardize(surface.pressures[TR_Research], true), standardize(surface.saturates[TR_Research], true));
				addVariable(icons::Research, value, ttip, color);
			}

			if(pl.laborIncome > 0) {
				Color color = colors::Labor;
				string value = formatMinuteRate(pl.laborIncome);
				string ttip = format(locale::PLANET_LABOR_TIP, standardize(surface.pressures[TR_Labor], true), standardize(surface.saturates[TR_Labor], true));
				addVariable(icons::Labor, value, ttip, color);
			}

			uint cargoCnt = pl.cargoTypes;
			for(uint i = 0; i < cargoCnt; ++i) {
				auto@ type = getCargoType(pl.cargoType[i]);
				if(type is null)
					continue;
				string value = standardize(pl.getCargoStored(type.id), true);
				string ttip = format("[font=Medium]$1[/font]\n$2", type.name, type.description);
				addVariable(type.icon, value, ttip, type.color);
			}
		}

		finalizeVars();
	}

	bool onGuiEvent(const GuiEvent& evt) {
		switch(evt.type) {
			case GUI_Clicked:
				if(evt.caller is sdisplay) {
					if(evt.value == 1) {
						auto@ bld = sdisplay.surface.getBuilding(sdisplay.hovered.x, sdisplay.hovered.y);
						if(selBuilding !is null)
							stopBuild();
						else if(sdisplay.surface.isValidPosition(sdisplay.hovered)) {
							if(bld !is null && !bld.type.civilian)
								openBuildingMenu(sdisplay.hovered, bld);
						}
						else
							overlay.close();
						return true;
					}

					if(selBuilding !is null) {
						pl.buildBuilding(selBuilding.id, sdisplay.hovered);
						if(!shiftKey) {
							stopBuild();
							overlay.construction.deselect();
							overlay.construction.updateTimer = 0.0;
						}
					}
					return true;
				}
				break;
		}
		return DisplayBox::onGuiEvent(evt);
	}

	double updateTimer = 0.0;
	void update(double time) override {
		updateTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1,0.9);

			Empire@ owner = pl.visibleOwner;
			bool owned = owner is playerEmpire;
			bool colonized = owner !is null && owner.valid;

			//Update name
			name.text = format("[center][obj_icon=$1;42/] $2[/center]", pl.id, pl.name);;
			if(owner !is null)
				name.defaultColor = owner.color;

			//Update level
			uint lv = pl.level;
			level.text = locale::LEVEL+" "+lv;

			//Update surface
			@sdisplay.obj = pl;
			receive(pl.getPlanetSurface(), surface);
			if(!pl.visible)
				surface.clearState();
			updateVars();
		}
	}

	void draw() override {
		Empire@ owner = pl.visibleOwner;
		Color color;
		if(owner !is null)
			color = owner.color;

		skin.draw(SS_OverlayBox, SF_Normal, AbsolutePosition.padded(0,36,0,0), Color(0x888888ff));
		skin.draw(SS_FullTitle, SF_Normal, recti_area(AbsolutePosition.topLeft, vec2i(AbsolutePosition.width, 38)), color);
		BaseGuiElement::draw();

		if(selBuilding !is null) {
			clearClip();
			drawHoverBuilding(skin, selBuilding, mousePos, sdisplay.hovered, sdisplay);
		}
	}
};

class DestroyBuildingOption : GuiContextOption {
	Object@ obj;
	vec2i pos;

	DestroyBuildingOption(Object@ obj, const string& text, const vec2i& pos) {
		this.pos = pos;
		this.text = text;
		@this.obj = obj;
	}

	void call(GuiContextMenu@ menu) override {
		obj.destroyBuilding(pos);
	}
};
// }}}

// {{{ Incomes
class IncomeDisplay : DisplayBox {
	Planet@ pl;
	GuiSprite@ desigPlus;
	GuiSprite@ desigIcon;
	GuiText@ desigValue;

	GuiSkinElement@ requireBox;
	GuiText@ reqLabel;
	GuiText@ reqTimer;
	GuiMarkupText@ popReq;
	GuiResourceReqGrid@ reqDisplay;

	GuiSkinElement@ popBox;
	GuiSprite@ popIcon;
	GuiText@ popValue;

	GuiSkinElement@ loyBox;
	GuiSprite@ loyIcon;
	GuiText@ loyValue;

	GuiSkinElement@ pressureBox;
	GuiSprite@ pressureIcon;
	GuiText@ pressureValue;

	GuiSkinElement@ incomeBox;
	GuiDistributionBar@ incomes;

	IncomeDisplay(PlanetOverlay@ ov, vec2i origin, Alignment@ target) {
		super(ov, origin, target);
		@pl = ov.obj;

		//Requirements
		@requireBox = GuiSkinElement(this, Alignment(Right-123, Top+8, Right-8, Top+42), SS_PlainOverlay);
		setMarkupTooltip(requireBox, locale::PLANET_REQUIREMENTS_TIP, width=400);
		@reqLabel = GuiText(requireBox, Alignment(Left-4, Top-6, Left+96, Top+6), locale::REQUIRED_RESOURCES);
		reqLabel.noClip = true;
		reqLabel.font = FT_Small;
		@reqTimer = GuiText(requireBox, Alignment(Right-96, Top-6, Right+4, Top+6));
		reqTimer.color = Color(0xff0000fff);
		reqTimer.noClip = true;
		reqTimer.font = FT_Small;
		reqTimer.horizAlign = 1.0;
		reqTimer.visible = false;
		@reqDisplay = GuiResourceReqGrid(requireBox, Alignment(Left+8, Top+8, Right-8, Bottom));
		reqDisplay.spacing.x = 6;
		reqDisplay.horizAlign = 0.0;
		reqDisplay.vertAlign = 0.0;
		@popReq = GuiMarkupText(requireBox, Alignment(Left+4, Top+8, Right-4, Bottom));
		popReq.visible = false;

		//Incomes
		@incomeBox = GuiSkinElement(this, Alignment(Left+8, Top+50, Right-8, Top+90), SS_PlainOverlay);
		@incomes = GuiDistributionBar(incomeBox, Alignment().fill());
		incomes.font = FT_Medium;
		addLazyMarkupTooltip(incomes);
		initResourceDistribution(incomes);

		//Tile resources
		int y = 98, w = 156;
		int x = 8;
		@popBox = GuiSkinElement(this, Alignment(Left+x, Top+y, Left+x+w, Top+y+34), SS_PlainOverlay);
		setMarkupTooltip(popBox, locale::PLANET_POPULATION_TIP, width=400);
		@popIcon = GuiSprite(popBox, Alignment(Left-16, Top-8, Width=50, Height=50));
		popIcon.desc = icons::Population;
		@popValue = GuiText(popBox, Alignment(Left+32, Top, Right-8, Bottom));
		popValue.horizAlign = 0.5;

		x += w+8;
		@pressureBox = GuiSkinElement(this, Alignment(Left+x, Top+y, Left+x+w, Top+y+34), SS_PlainOverlay);
		setMarkupTooltip(pressureBox, locale::PLANET_PRESSURE_TIP, width=400);
		@pressureIcon = GuiSprite(pressureBox, Alignment(Left+2, Top+2, Width=32, Height=32));
		pressureIcon.desc = icons::Pressure;
		@pressureValue = GuiText(pressureBox, Alignment(Left+32, Top, Right-8, Bottom));
		pressureValue.horizAlign = 0.5;

		x += w+8;
		@loyBox = GuiSkinElement(this, Alignment(Left+x, Top+y, Left+x+w, Top+y+34), SS_PlainOverlay);
		setMarkupTooltip(loyBox, locale::PLANET_LOYALTY_TIP, width=400);
		@loyIcon = GuiSprite(loyBox, Alignment(Left+2, Top+2, Width=32, Height=32));
		loyIcon.desc = icons::Loyalty;
		@loyValue = GuiText(loyBox, Alignment(Left+32, Top, Right-8, Bottom));
		loyValue.horizAlign = 0.5;
	}

	double updateTimer = 0.0;
	uint modID = 0;
	void update(double time) override {
		updateTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1,0.9);
			Empire@ owner = pl.owner;
			bool owned = owner is playerEmpire;
			bool colonized = owner !is null && owner.valid;

			//Update income distribution
			array<double>@ resources = overlay.surface.surface.resources;
			int income = pl.income;
			double tot = overlay.surface.surface.totalResource;
			float minimum = 2.f / 14.f, moneyMinimum = 4.f / 14.f, reserved = moneyMinimum;

			for(uint i = 0, cnt = TR_COUNT; i < cnt; ++i) {
				if(i != TR_Money && resources[i] > 0)
					reserved += minimum;
			}
			for(uint i = 0, cnt = TR_COUNT; i < cnt; ++i) {
				if(i == TR_Money) {
					incomes.elements[i].text = formatMoney(income);
					if(income < 0)
						incomes.elements[i].textColor = Color(0xff0000ff);
					else
						incomes.elements[i].textColor = colors::White;
					if(tot > 0)
						incomes.elements[i].amount = moneyMinimum + (abs(resources[i]) / tot) * (1.f - reserved);
					else
						incomes.elements[i].amount = 1.f;
				}
				else {
					if(i == TR_Energy)
						incomes.elements[i].text = standardize(resources[i]*TILE_ENERGY_RATE*60.0, true)+locale::PER_MINUTE;
					else
						incomes.elements[i].text = standardize(resources[i], true);

					if(resources[i] > 0) {
						if(tot > 0)
							incomes.elements[i].amount = minimum + (resources[i] / tot) * (1.f - reserved);
						else
							incomes.elements[i].amount = 1.f;
					}
					else
						incomes.elements[i].amount = 0.f;
				}
			}

			//Update population display
			if(colonized) {
				popValue.text = standardize(pl.population) + " / " + standardize(pl.maxPopulation);
				popValue.color = Color(0xffffffff);
			}
			else {
				popValue.text = "-";
			}

			//Update loyalty display
			if(colonized)
				loyValue.text = toString(pl.currentLoyalty);
			else
				loyValue.text = "-";

			//Update pressure display
			double pressureCap = pl.pressureCap;
			double pressure = overlay.surface.surface.totalPressure;
			if(colonized) {
				pressureValue.text = toString(pressure, 0)+" / "+toString(pressureCap, 0);
				if(pressure > pressureCap)
					pressureBox.color = Color(0xff0000ff);
				else
					pressureBox.color = Color(0xffffffff);
			}
			else {
				pressureValue.text = "-";
				pressureBox.color = Color(0xffffffff);
			}

			//Update level requirements
			array<Resource>@ resList = overlay.resList;
			uint lv = pl.level;
			double decay = pl.decayTime;
			if(!owned || (lv == MAX_PLANET_LEVEL && decay <= 0) || (lv >= uint(pl.maxLevel) && decay <= 0)) {
				requireBox.visible = false;
			}
			else if(decay > 0) {
				requireBox.visible = true;
				reqTimer.visible = true;
				reqTimer.text = formatTime(decay);
				reqLabel.color = Color(0xff0000ff);
				reqLabel.tooltip = format(locale::REQ_STOP_DECAY, toString(lv-1), formatTime(decay));

				uint newMod = pl.resourceModID;
				if(newMod != modID) {
					available.clear();
					receive(pl.getResourceAmounts(), available);

					const PlanetLevel@ lvl = getPlanetLevel(lv);
					reqDisplay.set(lvl.reqs, available);
					reqDisplay.visible = true;
					reqLabel.visible = true;

					popReq.visible = reqDisplay.length == 0;
					if(popReq.visible)
						popReq.text = format(locale::POP_REQ, standardize(lvl.requiredPop, true));

					reqLabel.tooltip = format(locale::REQ_FOR_LEVEL, toString(lv + 1));
					modID = newMod;
				}
			}
			else {
				requireBox.visible = true;
				reqTimer.visible = false;
				reqLabel.color = Color(0xffffffff);

				uint newMod = pl.resourceModID;
				if(newMod != modID) {
					available.clear();
					receive(pl.getResourceAmounts(), available);

					const PlanetLevel@ lvl = getPlanetLevel(lv + 1);
					reqDisplay.set(lvl.reqs, available);
					reqDisplay.visible = true;
					reqLabel.visible = true;

					popReq.visible = reqDisplay.length == 0;
					if(popReq.visible)
						popReq.text = format(locale::POP_REQ, standardize(lvl.requiredPop, true));

					reqLabel.text = format(locale::REQUIRED_RESOURCES, toString(lv+1));
					reqLabel.tooltip = format(locale::REQ_FOR_LEVEL, toString(lv + 1));
					modID = newMod;
				}
			}
		}
	}
};
// }}}

// {{{ Resources
class EffectBox : BaseGuiElement {
	GuiResources@ resources;
	GuiMarkupText@ text;
	array<const IResourceHook@> hooks;
	Object@ obj;

	GuiResources@ carryList;

	EffectBox(IGuiElement@ elem, const recti& pos) {
		super(elem, pos);
		@resources = GuiResources(this, recti_area(
					vec2i(2, 7), vec2i(100, pos.height-14)));
		resources.horizAlign = 0.0;
		@text = GuiMarkupText(this, recti(
					vec2i(52, 0), pos.size - vec2i(16, 0)));
	}

	void add(Resource@ r, const IResourceHook@ hook, Resource@ carry = null) {
		resources.resources.insertLast(r);
		hooks.insertLast(hook);

		if(carry !is null) {
			if(carryList is null) {
				@carryList = GuiResources(this, Alignment(Right-25, Bottom-25, Right+5, Bottom+5));
				carryList.sendToBack();
				carryList.horizAlign = 0.0;
			}

			bool found = false;
			for(uint i = 0, cnt = carryList.resources.length; i < cnt; ++i) {
				if(carryList.resources[i].type is carry.type) {
					found = true;
					break;
				}
			}

			if(!found)
				carryList.resources.insertLast(carry);
		}
	}

	void update(Resource@ r) {
		for(uint i = 0, cnt = resources.resources.length; i < cnt; ++i) {
			Resource@ other = resources.resources[i];
			if(other.id == r.id && other.origin is r.origin)
				other = r;
		}
	}

	void update() {
		int rSize = min(60, resources.length * 48);
		resources.size = vec2i(rSize, 30);
		text.position = vec2i(rSize+8, 0);
		text.size = size - vec2i(rSize+24+(carryList is null ? 0 : 20), 0);

		text.text = hooks[0].formatEffect(obj, hooks);

		const ResourceType@ type;
		for(uint i = 0, cnt = resources.resources.length; i < cnt; ++i) {
			if(i == 0) {
				@type = resources.resources[i].type;
			}
			else {
				if(type !is resources.resources[i].type) {
					@type = null;
					break;
				}
				else {
					@type = resources.resources[i].type;
				}
			}
		}

		if(type !is null)
			setMarkupTooltip(this, getResourceTooltip(type));
		else
			setMarkupTooltip(this, "");

		updateAbsolutePosition();
	}

	void draw() override {
		skin.draw(SS_PlainOverlay, SF_Normal, AbsolutePosition);
		BaseGuiElement::draw();
	}
};

class ResourceDisplay : DisplayBox {
	Planet@ pl;

	PlanetTree@ tree;
	bool doCenter = false;

	GuiSkinElement@ levelBar;
	GuiText@ level;

	GuiSkinElement@ requireBox;
	GuiText@ reqLabel;
	GuiText@ reqTimer;
	GuiMarkupText@ popReq;
	GuiResourceReqGrid@ reqDisplay;

	ResourceDisplay(PlanetOverlay@ ov, vec2i origin, Alignment@ target) {
		super(ov, origin, target);
		@pl = ov.obj;

		//Level indicator
		@levelBar = GuiSkinElement(this, Alignment(Left+1, Top+1, Right-0.5f-4, Top+42), SS_PlainOverlay);
		@level = GuiText(levelBar, Alignment(Left+8, Top+4, Right-8, Bottom-4));
		level.font = FT_Medium;

		//Requirements
		@requireBox = GuiSkinElement(this, Alignment(Right-0.5f+4, Top+1, Right-1, Top+42), SS_PlainOverlay);
		setMarkupTooltip(requireBox, locale::PLANET_REQUIREMENTS_TIP, width=400);
		@reqLabel = GuiText(requireBox, Alignment(Left-4, Top-6, Left+96, Top+6), locale::REQUIRED_RESOURCES);
		reqLabel.noClip = true;
		reqLabel.font = FT_Small;
		@reqTimer = GuiText(requireBox, Alignment(Right-96, Top-6, Right+4, Top+6));
		reqTimer.color = Color(0xff0000fff);
		reqTimer.noClip = true;
		reqTimer.font = FT_Small;
		reqTimer.horizAlign = 1.0;
		reqTimer.visible = false;
		@reqDisplay = GuiResourceReqGrid(requireBox, Alignment(Left+8, Top+8, Right-8, Bottom));
		reqDisplay.iconSize = vec2i(30, 30);
		reqDisplay.spacing.x = 6;
		reqDisplay.horizAlign = 0.0;
		reqDisplay.vertAlign = 0.0;
		@popReq = GuiMarkupText(requireBox, Alignment(Left+4, Top+8, Right-4, Bottom));
		popReq.visible = false;

		//Tree of local planets
		@tree = PlanetTree(this, Alignment().padded(8, 42, 8, 8));
		@tree.focusObject = pl;
	}

	double updateTimer = 0.0;
	uint modID = 0;

	void update(double time) override {
		tree.visible = pl.owner is playerEmpire;
		if(tree.visible)
			tree.tick(time);

		updateTimer -= time;
		if(updateTimer <= 0) {
			updateTimer = randomd(0.1,0.9);
			level.text = locale::LEVEL+" "+pl.visibleLevel;

			if(pl.owner !is playerEmpire) {
				requireBox.visible = false;
				return;
			}

			Empire@ owner = pl.owner;
			bool owned = owner is playerEmpire;
			bool colonized = owner !is null && owner.valid;

			//Update level requirements
			array<Resource>@ resList = overlay.resList;
			if(owned)
				resList.syncFrom(pl.getAllResources());
			else
				resList.syncFrom(pl.getNativeResources());

			uint lv = pl.level;
			double decay = pl.decayTime;
			if(!owned || (lv == MAX_PLANET_LEVEL && decay <= 0)) {
				requireBox.visible = false;
			}
			else if(decay > 0) {
				requireBox.visible = true;
				reqTimer.visible = true;
				reqTimer.text = formatTime(decay);
				reqLabel.color = Color(0xff0000ff);
				reqLabel.tooltip = format(locale::REQ_STOP_DECAY, toString(lv-1), formatTime(decay));

				uint newMod = pl.resourceModID;
				if(newMod != modID) {
					available.clear();
					receive(pl.getResourceAmounts(), available);

					const PlanetLevel@ lvl = getPlanetLevel(lv);
					reqDisplay.set(lvl.reqs, available);
					reqDisplay.visible = true;
					reqLabel.visible = true;

					popReq.visible = reqDisplay.length == 0;
					if(popReq.visible)
						popReq.text = format(locale::POP_REQ, standardize(lvl.requiredPop, true));

					reqLabel.tooltip = format(locale::REQ_FOR_LEVEL, toString(lv + 1));
					modID = newMod;
				}
			}
			else {
				requireBox.visible = true;
				reqTimer.visible = false;
				reqLabel.color = Color(0xffffffff);

				uint newMod = pl.resourceModID;
				if(newMod != modID) {
					available.clear();
					receive(pl.getResourceAmounts(), available);

					const PlanetLevel@ lvl = getPlanetLevel(lv + 1);
					reqDisplay.set(lvl.reqs, available);
					reqDisplay.visible = true;
					reqLabel.visible = true;

					popReq.visible = reqDisplay.length == 0;
					if(popReq.visible)
						popReq.text = format(locale::POP_REQ, standardize(lvl.requiredPop, true));

					reqLabel.text = format(locale::REQUIRED_RESOURCES, toString(lv+1));
					reqLabel.tooltip = format(locale::REQ_FOR_LEVEL, toString(lv + 1));
					modID = newMod;
				}
			}
		}
	}

	bool onGuiEvent(const GuiEvent& evt) override {
		switch(evt.type) {
			case GUI_Animation_Complete:
				updateAbsolutePosition();
				tree.update();
				updateAbsolutePosition();
				doCenter = true;
			break;
		}
		return DisplayBox::onGuiEvent(evt);
	}

	void draw() {
		DisplayBox::draw();
		if(doCenter) {
			doCenter = false;
			tree.center();
		}
	}
};
// }}}

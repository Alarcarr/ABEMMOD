import resources;
import ftl;
from obj_selection import selectedObject, selectedObjects, getSelectionPosition, getSelectionScale;
import targeting.PointTarget;
import targeting.targeting;
from targeting.MoveTarget import getFleetTargetPositions;

class HyperdriveTarget : PointTarget {
	double avgCost = 0.0;
	Object@ obj;
	array<vec3d>@ offsets;
	array<int> costs;
	array<int> invalidObjs;
	array<Object@> objs;

	HyperdriveTarget(Object@ Obj) {
		@obj = Obj;
		objs = selectedObjects;
	}

	vec3d get_origin() override {
		if(shiftKey) {
			Object@ obj = selectedObject;
			if(obj is null)
				return vec3d();
			return obj.finalMoveDestination;
		}
		else {
			return getSelectionPosition(true);
		}
	}

	bool hover(const vec2i& mpos) override {
		PointTarget::hover(mpos);

		//if(selectedObjects.length > 1) {
			auto@ positions = getFleetTargetPositions(objs, hovered);
			avgCost = 0;
			int validJumps = 0;
			for(uint i = 0, cnt = objs.length; i < cnt; ++i) {
				avgCost += hyperdriveCost(objs[i], positions[i]);
				costs.insertLast(hyperdriveCost(objs[i], positions[i]));
				if(costs[i] < cast<Ship>(objs[i]).FTL)
					validJumps++;
				else
					invalidObjs.insertLast(i);
			}
			avgCost /= objs.length;
			range = objs.length == validJumps ? 0.0 : INFINITY;
		//}
		//else {
		//	range = hyperdriveRange(obj);
		//	cost = hyperdriveCost(obj, hovered);
		//}
		return canHyperdriveTo(obj, hovered) && (distance <= range || shiftKey);
	}

	bool click() override {
		return distance <= range || shiftKey;
	}
};

class HyperdriveDisplay : PointDisplay {
	void draw(TargetMode@ mode) override {
		PointDisplay::draw(mode);

		HyperdriveTarget@ ht = cast<HyperdriveTarget>(mode);
		if(ht is null)
			return;

		Color color;
		if(ht.distance <= ht.range && ht.valid)
			color = Color(0x00ff00ff);
		else
			color = Color(0xff0000ff);

		font::DroidSans_11_Bold.draw(mousePos + vec2i(16, 0),
			format(locale::AVG_FTLCOST, toString(ht.avgCost), toString(ht.distance, 0)),
			color);
		
		if(ht.distance > ht.range) {
			font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 16),
				locale::INSUFFICIENT_FTL,
				color);
			for(uint i = 0; cnt = invalidObjs.length; i < cnt; ++i) {
				Ship@ ship = cast<Ship>(objs[invalidObjs[i]]);
				font::OpenSans_11_Italic.draw(mousePos + vec2i(16, 32 + 16*i),
				format(locale::NEEDS_MORE_FTL, ship.name, toString(costs[invalidObjs[i]]), toString(ship.FTL), toString(ship.MaxFTL)),
				color);		
			}
		}
	}

	void render(TargetMode@ mode) override {
		inColor = Color(0x00c0ffff);
		if(shiftKey)
			outColor = Color(0xffe400ff);
		else
			outColor = colors::Red;
		PointDisplay::render(mode);
	}
};

class HyperdriveCB : TargetCallback {
	void call(TargetMode@ mode) override {
		bool anyDidFTL = false;
		Object@[] selection = selectedObjects;
		auto@ positions = getFleetTargetPositions(selection, mode.position);
		for(uint i = 0, cnt = selection.length; i < cnt; ++i) {
			Object@ obj = selection[i];
			if(!obj.hasMover || !obj.hasLeaderAI || !canHyperdrive(obj))
				continue;
			anyDidFTL = true;
			obj.addHyperdriveOrder(positions[i], shiftKey || obj.inFTL);
		}
		
		if(anyDidFTL)
			sound::order_hyperdrive.play(priority=true);
		
		if(shiftKey) {
			HyperdriveTarget targ(selectedObject);
			targ.isShifted = true;
			HyperdriveDisplay disp;
			HyperdriveCB cb;
			startTargeting(targ, disp, cb);
		}
	}
};

void targetHyperdrive() {
	HyperdriveTarget targ(selectedObject);
	HyperdriveDisplay disp;
	HyperdriveCB cb;

	startTargeting(targ, disp, cb);
}

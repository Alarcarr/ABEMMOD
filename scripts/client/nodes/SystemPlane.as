import planet_loyalty;

vec4f ContestedVec;
vec4f GainingVec;
vec4f LosingVec;
vec4f ProtectedVec;
vec4f ZealotVec;

enum DebrisType {
	DT_Rock1,
	DT_Rock2,
	DT_Rock3,
	DT_Metal,
	
	DT_COUNT,
	
	DT_ROCK_START = DT_Rock1,
	DT_ROCK_END = DT_Rock3,
	
	DT_METAL_START = DT_Metal,
	DT_METAL_END = DT_Metal
};

void init() {
	ContestedColors[CM_Contested].toVec4(ContestedVec);
	ContestedVec.w = 0.5f;

	ContestedColors[CM_GainingLoyalty].toVec4(GainingVec);
	GainingVec.w = 0.5f;

	ContestedColors[CM_LosingLoyalty].toVec4(LosingVec);
	LosingVec.w = 0.5f;

	ContestedColors[CM_Protected].toVec4(ProtectedVec);
	ProtectedVec.w = 0.5f;

	ContestedColors[CM_Zealot].toVec4(ZealotVec);
	ZealotVec.w = 0.5f;
}

bool SHOW_SYSTEM_PLANES = true;
void setSystemPlanesShown(bool enabled) {
	SHOW_SYSTEM_PLANES = enabled;
}

bool getSystemPlanesShown() {
	return SHOW_SYSTEM_PLANES;
}

final class SystemDebris {
	DebrisType type;
	quaterniond rot;
	vec3d pos, vel, axis;
	float scale, life, rotSpeed;
	bool draw = false;
	double dist = 0;
	
	int opCmp(const SystemDebris& other) {
		return int(type) - int(other.type);
	}
};

class SystemPlaneNodeScript {
	Region@ obj;
	vec3d origin;
	float outerRadius;
	float innerRadius;
	uint contested = CM_None;
	bool decaying = false;
	Color primaryColor;
	float alpha = 1.f;
	
	bool drawPlane = false, drawDebris = false;
	array<SystemDebris@> debris;

	SystemPlaneNodeScript(Node& node) {
	}

	void setContested(uint mode) {
		contested = mode;
	}
	
	void establish(Node& node, Region& region) {
		@obj = region;
		origin = region.position;
		outerRadius = region.OuterRadius;
		innerRadius = region.InnerRadius;

		node.scale = region.radius;
		node.position = origin;
		node.rebuildTransform();
	}

	void setPrimaryEmpire(Empire@ emp) {
		if(emp !is null)
			primaryColor = emp.color;
		else
			primaryColor = Color(0xaaaaaaff);
	}
	
	void addMetalDebris(vec3d position, uint count = 1) {
		double spread = double(count) - 1.0;
	
		for(uint i = 0; i < count; ++i) {
			SystemDebris d;
			d.type = DebrisType(randomi(DT_METAL_START,DT_METAL_END));
			vec2d off = random2d(200.0, innerRadius);
			d.pos = position + random3d(spread);
			d.scale = randomd(1.0,2.0);
			d.axis = random3d(1.0);
			d.rotSpeed = randomd(pi * -0.125, pi * 0.125);
			double dist = cameraPos.distanceTo(d.pos);			
			d.vel = random3d(-8.0,8.0);
			d.life = randomd(30.0,60.0);
			d.rot = quaterniond_fromAxisAngle(random3d(1.0), randomd(0.0,twopi));
			debris.insertLast(d);
		}
	}
	
	void generateDebris() {
		uint count = uint(innerRadius * settings::dSystemDebris / 10.0);
		if(debris.length < count) {
			for(uint i = debris.length; i < count; ++i) {
				SystemDebris d;
				d.type = DebrisType(randomi(0,DT_COUNT-1));
				vec2d off = random2d(200.0, innerRadius);
				d.pos = origin + vec3d(off.x, randomd(-15.0,15.0), off.y);
				d.scale = randomd(1.0,2.0);
				d.axis = random3d(1.0);
				d.rotSpeed = randomd(pi * -0.125, pi * 0.125);
				double dist = cameraPos.distanceTo(d.pos);
				if(dist < pixelSizeRatio * 2000.0 * d.scale && isSphereVisible(d.pos, d.scale))
					continue;
				
				d.vel = random3d(-8.0,8.0);
				d.life = randomd(30.0,60.0);
				d.rot = quaterniond_fromAxisAngle(random3d(1.0), randomd(0.0,twopi));
				debris.insertLast(d);
			}
			
			debris.sortAsc();
		}
	}
	
	void tickDebris(double time) {
		vec3d cam = cameraPos;
		for(int i = int(debris.length-1); i >= 0; --i) {
			auto@ d = debris[i];
			d.life -= time;
			d.pos += d.vel * time;
			d.dist = cam.distanceTo(d.pos) / (pixelSizeRatio * d.scale);
			d.draw = d.dist < 2000.0 && isSphereVisible(d.pos, d.scale);
			
			if(d.life <= 0 && !d.draw) {
				debris.removeAt(i);
				continue;
			}
			
			if(d.draw)
				d.rot = quaterniond_fromAxisAngle(d.axis, d.rotSpeed * time) * d.rot;
		}
	}
	
	void renderDebris() {
		for(uint i = 0, cnt = debris.length; i < cnt; ++i) {	
			auto@ d = debris[i];
			if(!d.draw)
				continue;
			
			applyTransform(d.pos, d.scale, d.rot);
			switch(d.type) {
				case DT_Rock1:
					material::AsteroidPegmatite.switchTo();
					model::Asteroid.draw(d.dist);
					break;
				case DT_Rock2:
					material::AsteroidTonalite.switchTo();
					model::Asteroid.draw(d.dist);
					break;
				case DT_Rock3:
					material::AsteroidMagnetite.switchTo();
					model::Asteroid.draw(d.dist);
					break;
				case DT_Metal:
					material::Asteroid.switchTo();
					model::Debris.draw(d.dist);
					break;
			}
			undoTransform();
		}
	}

	bool preRender(Node& node) {
		if(playerEmpire !is null && playerEmpire.valid && obj.ExploredMask & playerEmpire.visionMask == 0)
			return false;

		double d = node.abs_scale * pixelSizeRatio;
		drawPlane = SHOW_SYSTEM_PLANES && (node.sortDistance < 200.0 * d);
		drawDebris = node.sortDistance < 5.0 * node.abs_scale * pixelSizeRatio;
		
		alpha = 1.0 - clamp((node.sortDistance - 150.0 * d) / (50.0 * d), 0.0, 1.0);
		
		if(drawDebris) {
			tickDebris(frameLength * gameSpeed);
			generateDebris();
		}
		
		return drawPlane || drawDebris;
	}
	
	void render(Node& node) {
		if(drawDebris)
			renderDebris();
		
		if(drawPlane) {
			shader::RADIUS = outerRadius;
			shader::INNER_RADIUS = innerRadius;

			//Calculate distance to plane
			line3dd camLine(cameraPos, cameraPos+cameraFacing);
			vec3d intersect;
			if(!camLine.intersectY(intersect, obj.position.y, false)) {
				intersect = cameraPos;
				intersect.y = obj.position.y;
				shader::PLANE_DISTANCE = sqrt(
						sqr(max(0.0, intersect.distanceTo(obj.position) - outerRadius))
						+ sqr(cameraPos.y - obj.position.y));
			}
			else {
				shader::PLANE_DISTANCE = intersect.distanceTo(cameraPos);
					max(0.0, intersect.distanceTo(obj.position) - outerRadius);
			}

			switch(contested) {
				case CM_None:
					shader::GLOW_COLOR.w = 0.f;
				break;
				case CM_Contested:
					shader::GLOW_COLOR = ContestedVec;
				break;
				case CM_LosingLoyalty:
					shader::GLOW_COLOR = LosingVec;
				break;
				case CM_GainingLoyalty:
					shader::GLOW_COLOR = GainingVec;
				break;
				case CM_Protected:
					shader::GLOW_COLOR = ProtectedVec;
				break;
				case CM_Zealot:
					shader::GLOW_COLOR = ZealotVec;
				break;
			}

			Color c = primaryColor;
			c.a = uint8(alpha * 255.f);
			
			drawPolygonStart(PT_Quads, 1, material::SystemPlane);
			drawPolygonPoint(origin + vec3d(-outerRadius, 0, -outerRadius), vec2f(0.f, 0.f), c);
			drawPolygonPoint(origin + vec3d(+outerRadius, 0, -outerRadius), vec2f(1.f, 0.f));
			drawPolygonPoint(origin + vec3d(+outerRadius, 0, +outerRadius), vec2f(1.f, 1.f));
			drawPolygonPoint(origin + vec3d(-outerRadius, 0, +outerRadius), vec2f(0.f, 1.f));
			drawPolygonEnd();
		}
	}
};

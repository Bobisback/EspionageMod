import elements.BaseGuiElement;
import planet_types;
import orbitals;
import pickups;
import artifacts;
import civilians;

export Gui3DDisplay;
export ObjectAction;
export Gui3DObject;
export drawLitModel;
export Draw3D, makeDrawMode;

Colorf white, black(0,0,0);
vec3f lightPos = vec3f(float(screenSize.width) * 0.5f, float(screenSize.height) * 0.5f, 800.0f);

interface Draw3D {
	void preRender(Object@ obj);
	void draw(const recti &in pos, quaterniond rotation);
};

class DrawModel : Draw3D {
	const Material@ mat;
	const Model@ model;

	DrawModel(const Model@ Model, const Material@ Mat) {
		@mat = Mat;
		@model = Model;
	}

	void preRender(Object@ obj) {
	}

	void draw(const recti &in pos, quaterniond rotation) {
		drawLitModel(model, mat, pos, rotation);
	}
};

class DrawPlanet : Draw3D {
	const Material@ mat, atmos;
	
	DrawPlanet(Planet@ pl) {
		const PlanetType@ type = getPlanetType(cast<Planet>(pl).PlanetType);
		@mat = type.emptyMat;
		@atmos = type.atmosMat;
	}

	void preRender(Object@ obj) {
	}

	void draw(const recti &in pos, quaterniond rotation) {
		if(atmos !is null) {
			drawLitModel(model::Sphere_max, mat, pos, rotation, 1/1.025);
			shader::MODEL_SCALE = double(min(pos.height, pos.width)) / 2 / 1.025;

			quaterniond atmosRot = quaterniond_fromAxisAngle(vec3d_up(), fraction(gameTime / 120.0) * twopi);
			drawLitModel(model::Sphere_max, material::FlatAtmosphere, pos, rotation * atmosRot);
		}
		else {
			drawLitModel(model::Sphere_max, mat, pos, rotation);
		}
	}
};

class DrawStar : Draw3D {
	double temp;
	
	DrawStar(Star@ star) {
		temp = star.temperature;
	}

	void preRender(Object@ obj) {
		shader::STAR_TEMP = temp;
	}

	void draw(const recti &in pos, quaterniond rotation) {
		drawLitModel(model::Sphere_max, material::PopupStarSurface, pos, rotation);
	}
};

class Gui3DDisplay : BaseGuiElement {
	Draw3D@ drawMode;
	quaterniond rotation;

	Gui3DDisplay(BaseGuiElement@ parent, recti pos) {
		super(parent, pos);
	}

	Gui3DDisplay(BaseGuiElement@ parent, Alignment@ pos) {
		super(parent, pos);
	}

	void draw() {
		if(drawMode !is null)
			drawMode.draw(AbsolutePosition, rotation);
		BaseGuiElement::draw();
	}
};

enum ObjectAction {
	OA_LeftClick,
	OA_RightClick,
	OA_DoubleClick,
	OA_MiddleClick,
};

void drawLitModel(const Model@ model, const Material@ material, const recti& position, const quaterniond& rotation, double scale = 1.0) {
	Light@ light = ::light[0];
	light.position = lightPos;
	light.diffuse = white;
	light.specular = black;
	light.att_quadratic = 0.0;
	light.enable();
	light.att_quadratic = 1.0;
	light.enable();
	
	model.draw(material, position, rotation, scale);
	
	resetLights();
}

Draw3D@ makeDrawMode(Object@ obj) {
	if(obj is null || !obj.valid || !obj.initialized)
		return null;
	switch(obj.type) {
		case OT_Planet:
			return DrawPlanet(cast<Planet>(obj));
		case OT_Orbital: {
			const OrbitalModule@ def = getOrbitalModule(cast<Orbital>(obj).coreModule);
			return DrawModel(def.model, def.material);
		}
		case OT_Ship: {
			const Hull@ hull = cast<Ship>(obj).blueprint.design.hull;
			return DrawModel(hull.model, hull.material);
		}
		case OT_ColonyShip:
			return DrawModel(getModel(obj.owner.ColonizerModel), getMaterial(obj.owner.ColonizerMaterial));
		case OT_Freighter:
			return DrawModel(model::Fighter, material::Ship10);
		case OT_Asteroid:
			return DrawModel(model::Asteroid, material::Asteroid);
		case OT_Anomaly: {
			Anomaly@ anom = cast<Anomaly>(obj);
			return DrawModel(getModel(anom.model), getMaterial(anom.material));
		}
		case OT_Artifact: {
			Artifact@ art = cast<Artifact>(obj);
			auto@ type = getArtifactType(art.ArtifactType);
			return DrawModel(type.model, type.material);
		}
		case OT_Star:
			return DrawStar(cast<Star>(obj));
		case OT_Pickup: {
			const PickupType@ type = getPickupType(cast<Pickup>(obj).PickupType);
			return DrawModel(type.model, type.material);
		}
		case OT_Civilian: {
			uint type = cast<Civilian>(obj).getCivilianType();
			return DrawModel(getCivilianModel(type, obj.radius), getCivilianMaterial(type, obj.radius));
		}
	}
	return null;
}

class Gui3DObject : Gui3DDisplay {
	Object@ obj;
	double dblClick = 0;
	quaterniond internalRotation;
	bool objectRotation = true;

	Gui3DObject(BaseGuiElement@ parent, recti pos, Object@ Obj = null) {
		super(parent, pos);
		@object = Obj;
	}

	Gui3DObject(BaseGuiElement@ parent, Alignment@ pos, Object@ Obj = null) {
		super(parent, pos);
		@object = Obj;
	}

	void set_object(Object@ Obj) {
		if(Obj is obj)
			return;
		@obj = Obj;
		@drawMode = makeDrawMode(Obj);
	}

	Object@ get_object() {
		return obj;
	}

	void draw() {
		if(obj is null)
			return;

		//Update from object values
		if(objectRotation) {
			rotation = internalRotation * obj.node_rotation;
			rotation.normalize();
		}
		else {
			rotation = internalRotation;
		}
		if(drawMode !is null)
			drawMode.preRender(obj);

		Gui3DDisplay::draw();
	}

	bool onMouseEvent(const MouseEvent& evt, IGuiElement@ source) {
		switch(evt.type) {
			case MET_Button_Up:
				if(evt.button == 0) {
					if(frameTime < dblClick) {
						emitClicked(OA_DoubleClick);
					}
					else {
						emitClicked(OA_LeftClick);
						dblClick = frameTime + 0.2;
					}
					return true;
				}
				else if(evt.button == 1) {
					emitClicked(OA_RightClick);
					return true;
				}
				else if(evt.button == 2) {
					emitClicked(OA_MiddleClick);
					return true;
				}
			break;
		}
		return BaseGuiElement::onMouseEvent(evt, source);
	}
};

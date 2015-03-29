#priority init 50
import systems;

ElevationMap emap;
double epower = 4.0;
double egrid = 1000.0;
double vgrid = 1000.0;
bool drawGrid = false;

void init() {
	//Elevation map
	for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
		auto@ sys = getSystem(i);
		emap.addPoint(sys.position, sys.radius);
	}
	emap.generate(vec2d(egrid, egrid), epower);

	addConsoleCommand("grid_smoothing", GridPowerCommand());
	addConsoleCommand("grid_spacing", GridSpacingCommand());
	addConsoleCommand("grid_visual", GridVisualCommand());
	addConsoleCommand("show_grid", ShowGridCommand());
}

void recalculateElevation() {
	emap.clear();
	for(uint i = 0, cnt = systemCount; i < cnt; ++i) {
		auto@ sys = getSystem(i);
		emap.addPoint(sys.position, sys.radius);
	}
	emap.generate(vec2d(egrid, egrid), epower);
}

double getElevation(double x, double z) {
	vec2d p(x, z);
	return emap.get(p);
}

double getAverageElevation() {
	return emap.gridStart.y;
}

bool getElevationIntersect(const line3dd& line, vec3d&out point) {
	return emap.getClosestPoint(line, point);
}

class GridPowerCommand : ConsoleCommand {
	void execute(const string& args) {
		epower = toDouble(args);
		emap.generate(vec2d(egrid, egrid), epower);
	}
};

class GridSpacingCommand : ConsoleCommand {
	void execute(const string& args) {
		egrid = toDouble(args);
		emap.generate(vec2d(egrid, egrid), epower);
	}
};

class GridVisualCommand : ConsoleCommand {
	void execute(const string& args) {
		vgrid = toDouble(args);
	}
};

class ShowGridCommand : ConsoleCommand {
	void execute(const string& args) {
		drawGrid = args.length == 0 || toBool(args);
	}
};

void render(double time) {
	if(!drawGrid)
		return;

	//Draw the elevation grid
	for(int x = -10, xcnt = emap.gridSize.x / vgrid + 10; x < xcnt; ++x) {
		for(int y = -10, ycnt = emap.gridSize.y / vgrid + 10; y < ycnt; ++y) {
			vec3d tlpos = emap.gridStart + vec3d(vgrid * x, 0, vgrid * y);
			vec3d brpos = tlpos + vec3d(vgrid, 0.0, vgrid);

			vec3d tl = vec3d(tlpos.x, emap.get(tlpos.x, tlpos.z), tlpos.z);
			vec3d tr = vec3d(brpos.x, emap.get(brpos.x, tlpos.z), tlpos.z);
			vec3d bl = vec3d(tlpos.x, emap.get(tlpos.x, brpos.z), brpos.z);
			vec3d br = vec3d(brpos.x, emap.get(brpos.x, brpos.z), brpos.z);

			drawPolygonStart(2, material::TestGrid);
			drawPolygonPoint(tl, vec2f(0.f, 0.f));
			drawPolygonPoint(tr, vec2f(1.f, 0.f));
			drawPolygonPoint(br, vec2f(1.f, 1.f));

			drawPolygonPoint(tl, vec2f(0.f, 0.f));
			drawPolygonPoint(bl, vec2f(0.f, 1.f));
			drawPolygonPoint(br, vec2f(1.f, 1.f));
			drawPolygonEnd();
		}
	}
}

//Adds functionality to the normal engine camera to make it
//more intelligent and context-sensitive

import double getElevation(double x, double z) from "navigation.elevation";
import double getAverageElevation() from "navigation.elevation";
import bool getElevationIntersect(const line3dd& line, vec3d& point) from "navigation.elevation";
import Object@ get_hoveredObject() from "obj_selection";

bool CAM_PANNED = false;
bool CAM_ZOOMED = false;
bool CAM_ROTATED = false;

class SmartCamera {
	//Main engine camera
	Camera camera;

	//Configuration
	double camAnglesPerPixel;
	double movePerPixel;
	double tickZoom;

	SmartCamera() {
		camAnglesPerPixel = 0.22 * twopi / 360.0;
		movePerPixel = 8.0;
		tickZoom = 1.2;
		camera.setPositionBound(vec3d(-200000), vec3d(200000));
	}

	void reset() {
		//Set the camera to the normal angle
		camera.resetRotation();
		camera.resetZoom();
		camera.zoom(5.0);
		camera.pitch(0.7);
		camera.snap();
	}

	vec3d get_lookAt() {
		return camera.lookAt;
	}

	vec3d get_finalLookAt() {
		return camera.finalLookAt;
	}

	double screenAngle(const vec3d& pos) {
		return camera.screenAngle(pos);
	}

	double get_distance() {
		return camera.distance;
	}

	//Rotate by a certain amount of screen pixels dragged
	void rotate(int dx, int dy) {
		CAM_ROTATED = true;
		if(settings::bInvertHorizRot)
			dx = -dx;
		if(settings::bInvertVertRot)
			dy = -dy;

		if(settings::bFreeCamera) {
			camera.yaw(clamp(double(dx) * camAnglesPerPixel, -pi * 0.5, pi * 0.5));
			camera.pitch(clamp(double(dy) * camAnglesPerPixel, -pi * 0.5, pi * 0.5));
		}
		else {
			camera.abs_yaw(clamp(double(dx) * camAnglesPerPixel, -pi * 0.5, pi * 0.5));
			camera.pitch(clamp(double(dy) * camAnglesPerPixel, -pi * 0.5, pi * 0.5));
		}
	}

	//Roll based on dragged script pixels
	void roll(int delta) {
		CAM_ROTATED = true;
		camera.roll(double(delta) * camAnglesPerPixel);
	}

	//Zoom with world plane
	void zoom(int delta) {
		//Get zoom speed
		double factor;
		if(settings::bInvertZoom)
			factor = pow(tickZoom, delta * settings::dZoomSpeed);
		else
			factor = pow(tickZoom, -delta * settings::dZoomSpeed);
		CAM_ZOOMED = true;

		if(factor < 1.0 ? settings::bZoomToCursor : settings::bZoomFromCursor) {
			//Interpolate plane position
			line3dd ray = screenToRay(mousePos);
			if(factor > 1.0)
				ray.start -= ray.direction * 1.0;
			
			vec3d point;
			if(!getElevationIntersect(ray, point))
				return;

			double minDist = 0.0;
			if(hoveredObject !is null)
				minDist = hoveredObject.radius * getMinZoomDist(hoveredObject);

			camera.zoomTo(factor, point, minDist);
		}
		else {
			camera.zoom(factor);
		}
	}

	void zoomTo(Object@ obj) {
		zoomTo(obj.position);
	}

	void zoomTo(const vec3d& pos) {
		vec3d finalPos = camera.finalLookAt;
		vec3d movement;
		movement.x = pos.x - finalPos.x;
		movement.z = pos.z - finalPos.z;
		movement.y = getElevation(pos.x, pos.z) - finalPos.y;

		camera.move_abs(movement);
	}

	double getMinZoomDist(Object@ obj) {
		switch(obj.type) {
			case OT_Star:
				return 1.4;
			case OT_Planet:
				return 1.6;
		}
		return 1.15;
	}

	//Pan on top of the world plane
	void pan(int dx, int dy) {
		if(!settings::bInvertPanX)
			dx = -dx;
		if(settings::bInvertPanY)
			dy = -dy;

		//Normal world plane movement
		vec2d movement;
		movement.x = movePerPixel * double(dx);
		movement.y = movePerPixel * double(dy);

		pan(movement);
	}

	void pan(vec2d movement) {
		//Speed based on zoom and modifiers
		double speed = camera.distance / 2500.0;
		if(shiftKey)
			speed *= 3.0;
		else if(altKey)
			speed *= 0.333;

		//Normal world plane movement
		movement *= settings::dPanSpeed * speed;
		vec3d prevPos = camera.finalLookAt;
		camera.move_world_abs(vec3d(movement.x, 0, movement.y));

		//Change in elevation
		vec3d nextPos = camera.finalLookAt;
		camera.move_abs(vec3d(0, getElevation(nextPos.x, nextPos.z) - prevPos.y, 0));
		CAM_PANNED = true;
	}

	bool panTo(const vec3d& pos, double speed, double threshold = 10.0) {
		//Modify speed
		speed *= max(camera.distance / 2500.0, 0.2);
		if(shiftKey)
			speed *= 3.0;
		else if(altKey)
			speed *= 0.333;
		speed *= settings::dPanSpeed;

		//Pan on a flat plane
		vec3d cur = lookAt;
		vec3d final = finalLookAt;

		vec3d flatPos = pos;
		flatPos.y = 0;
		cur.y = 0;
		final.y = 0;

		vec3d panDir = flatPos - final;
		double len = panDir.length;
		if(len <= threshold) {
			return true;
		}
		else {
			if(len > speed)
				panDir.length = speed;

			vec3d prevPos = camera.finalLookAt;
			camera.move_abs(panDir);
			vec3d nextPos = camera.finalLookAt;
			camera.move_abs(vec3d(0, getElevation(nextPos.x, nextPos.z) - prevPos.y, 0));
		}
		return false;
	}

	line3dd screenToRay(const vec2i& pos) {
		vec2i size = screenSize;
		return camera.screenToRay(double(pos.x) / double(size.x),
								double(pos.y) / double(size.y));
	}

	vec3d screenToPoint(const vec2i& pos) {
		line3dd ray = screenToRay(mousePos);
		vec3d point;
		if(!getElevationIntersect(ray, point))
			ray.intersectY(point, getAverageElevation(), false);
		return point;
	}
}

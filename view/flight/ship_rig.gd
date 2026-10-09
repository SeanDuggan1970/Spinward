## Drives a ship model's moving parts (the rig from ship_builder.gd).
##
## Every panel turns about its boom, the ship's X axis. A panel can only face a
## direction in the ship's Y-Z plane, so in transit the ship rolls about its line of
## travel (roll_to_sun) to put the Sun in that plane; then solar wings face it
## square on and radiators turn edge-on to it, so they shed heat instead of
## soaking up sunlight. While docking the pilot owns the roll, and the panels do the
## best a single hinge can.
##
## For docking the panels stow: each turns flat (in the ship's X-Z plane), then folds
## up accordion-fashion at its boom's end, and the dish parks. rig["fold_to"] (0 out,
## 1 stowed) is where the view wants them; rig["fold"] follows it at FOLD_RATE.
##
## The high-gain dish turns on azimuth (about the mast, +Y) and elevation, toward
## the comms target, typically the point-ahead direction from sim/light_time.gd.
extends RefCounted

## Slew rates, radians per real second: the hardware is not fast.
const ARRAY_RATE := 0.5
const DISH_RATE := 0.8
## The mast can't look down through the hull.
const DISH_MIN_EL := -0.35
## Folding, fraction of the whole stow per real second (about 25 s end to end).
const FOLD_RATE := 0.04
## The share of the stow spent turning the panels flat before the segments fold.
const FLATTEN := 0.25
## How long after leaving port a ship keeps its panels stowed (game seconds).
const DEPLOY_AFTER_S := 60.0


## An attitude with -Z along `forward` and the Sun in the ship's Y-Z plane (on the
## +Y side), so every panel hinge can find it.
static func roll_to_sun(forward: Vector3, sun: Vector3) -> Basis:
	var f := forward.normalized()
	var up := sun - f * sun.dot(f)
	if up.length() < 1e-3:
		# Sun dead ahead or astern: any roll will do.
		up = Vector3.UP if absf(f.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(f, up.normalized())


## One step of a turn with inertia: swing `forward` toward `target`, accelerating at
## up to `accel` (rad/s^2) to at most `rate` (rad/s), coasting, then braking so it
## stops lined up. omega is the angular velocity (a world vector). Returns
## [forward, omega].
static func turn_step(forward: Vector3, omega: Vector3, target: Vector3, rate: float, accel: float, dt: float) -> Array:
	var f := forward.normalized()
	var to := target.normalized()
	var angle := f.angle_to(to)
	var axis := f.cross(to)
	if axis.length() < 1e-6:
		# Dead ahead or dead astern: keep any turn already going, else pick a side.
		axis = omega if omega.length() > 1e-6 else f.cross(Vector3.UP if absf(f.y) < 0.98 else Vector3.RIGHT)
	axis = axis.normalized()
	# The fastest rate from which we can still stop in the angle left.
	var want := axis * minf(rate, sqrt(2.0 * accel * angle))
	omega = omega.move_toward(want, accel * dt)
	# Only swinging the nose matters; spin about it is the roll's business.
	omega -= f * omega.dot(f)
	if omega.length() > 1e-9:
		f = f.rotated(omega.normalized(), omega.length() * dt)
	if angle < 1e-3 and omega.length() < accel * dt:
		return [to, Vector3.ZERO]
	return [f.normalized(), omega]


## Seconds to swing through `angle` from rest to rest.
static func turn_time(angle: float, rate: float, accel: float) -> float:
	if accel <= 0.0:
		return INF
	if angle < rate * rate / accel:
		return 2.0 * sqrt(angle / accel)
	return angle / rate + rate / accel


## Turn the panels and dish. ship_basis: the model's world basis (may be scaled);
## sun and target: world directions from the ship. dt < 0 snaps straight there.
static func aim(rig: Dictionary, ship_basis: Basis, sun: Vector3, target: Vector3, dt: float) -> void:
	if rig.is_empty():
		return
	var to_local := ship_basis.orthonormalized().transposed()
	var s := to_local * sun.normalized()
	# Panel normal (0, cos a, sin a) after turning a about X; face the Sun's Y-Z part.
	var face := atan2(s.z, s.y)
	var fold := _fold_step(rig, dt)
	# Stowing, the panels first turn flat, then fold; deploying, the reverse.
	var flat := clampf(fold / FLATTEN, 0.0, 1.0)
	var bend := clampf((fold - FLATTEN) / (1.0 - FLATTEN), 0.0, 1.0)
	bend = bend * bend * (3.0 - 2.0 * bend)
	for a in rig.get("arrays", []):
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			continue
		var want: float = face if a["kind"] == "solar" else face + PI * 0.5
		if fold > 0.0:
			# Ease from the tracking angle to flat as the stow begins.
			node.rotation.x = wrapf(lerp_angle(want, 0.0, flat), -PI, PI)
		else:
			node.rotation.x = _slew(node.rotation.x, want, ARRAY_RATE, dt)
		_bend(a, bend)
	var dish: Dictionary = rig.get("dish", {})
	if dish.is_empty() or not is_instance_valid(dish["az"]):
		return
	var d := to_local * target.normalized()
	var az := atan2(d.x, d.z)
	var el := clampf(atan2(d.y, Vector2(d.x, d.z).length()), DISH_MIN_EL, PI * 0.5)
	if fold > 0.0:
		# Parked: straight ahead and level.
		az = 0.0 if fold >= 1.0 else az * (1.0 - fold)
		el = 0.0 if fold >= 1.0 else el * (1.0 - fold)
	var az_node: Node3D = dish["az"]
	var el_node: Node3D = dish["el"]
	az_node.rotation.y = _slew(az_node.rotation.y, az, DISH_RATE, dt)
	el_node.rotation.x = _slew(el_node.rotation.x, -el, DISH_RATE, dt)


## Where the view wants the panels: 0 deployed, 1 stowed. The first call, or snap,
## puts them straight there; after that they fold or unfold at FOLD_RATE.
static func set_fold(rig: Dictionary, to: float, snap: bool = false) -> void:
	if rig.is_empty():
		return
	rig["fold_to"] = clampf(to, 0.0, 1.0)
	if snap or not rig.has("fold"):
		rig["fold"] = rig["fold_to"]


## The model's radius about its long axis with the panels stowed (for docking bays):
## measured from its meshes, the plume left out. Leaves the fold where it was.
static func stowed_radius(model: Dictionary) -> float:
	var rig: Dictionary = model["rig"]
	var was := [rig.get("fold", 0.0), rig.get("fold_to", 0.0)]
	set_fold(rig, 1.0, true)
	aim(rig, Basis.IDENTITY, Vector3.UP, Vector3.FORWARD, -1.0)
	var root: Node3D = model["node"]
	var plume := root.find_child("DrivePlume", true, false)
	var r := 0.0
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		for c in (item[0] as Node).get_children():
			if c == plume or not c is Node3D:
				continue
			var xf: Transform3D = item[1] * (c as Node3D).transform
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var box: AABB = xf * (c as MeshInstance3D).mesh.get_aabb()
				for i in 8:
					var e := box.get_endpoint(i)
					r = maxf(r, Vector2(e.x, e.y).length())
			stack.append([c, xf])
	set_fold(rig, float(was[0]), true)
	rig["fold_to"] = was[1]
	aim(rig, Basis.IDENTITY, Vector3.UP, Vector3.FORWARD, -1.0)
	return r


## In transit, a ship leaving port keeps its panels stowed until it is clear, and a
## ship running quiet (ship.stowed, sim/systems/detection_system.gd) keeps them in.
static func transit_fold(location: Dictionary, t: float, ship: Dictionary = {}) -> float:
	if ship.get("stowed", false):
		return 1.0
	return 1.0 if t - float(location.get("depart_t", -INF)) < DEPLOY_AFTER_S else 0.0


static func _fold_step(rig: Dictionary, dt: float) -> float:
	var to := float(rig.get("fold_to", 0.0))
	var now := float(rig.get("fold", 0.0))
	now = to if dt < 0.0 else move_toward(now, to, FOLD_RATE * dt)
	rig["fold"] = now
	return now


## Fold a panel's segments: the first stands up off the boom, the rest zig-zag back
## down on it, so the stowed panel is a short stack at the boom's end.
static func _bend(array: Dictionary, bend: float) -> void:
	var hinges: Array = array.get("hinges", [])
	var side := float(array.get("side", 1.0))
	for k in hinges.size():
		var h: Node3D = hinges[k]
		if not is_instance_valid(h):
			continue
		var angle := PI * 0.5 if k == 0 else PI * 0.96 * (-1.0 if k % 2 == 1 else 1.0)
		h.rotation.z = side * angle * bend


static func _slew(from: float, to: float, rate: float, dt: float) -> float:
	if dt < 0.0:
		return wrapf(to, -PI, PI)
	return wrapf(rotate_toward(from, to, rate * dt), -PI, PI)

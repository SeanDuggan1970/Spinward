## Drives a ship model's moving parts (the rig from ship_builder.gd).
##
## Every panel turns about its boom, the ship's X axis (or, for the turned pair of a
## cross of radiators, X rolled by the entry's "roll" about the keel). A panel on an
## X boom can only face a direction in the ship's Y-Z plane, so in transit the ship
## rolls about its line of travel (roll_to_sun) to put the Sun in that plane; then
## solar wings face it square on and radiators turn edge-on to it, so they shed heat
## instead of soaking up sunlight. A radiator on a Y boom is edge-on to that plane
## already, so it holds square to the ship's X axis. While docking the pilot owns
## the roll, and the panels do the best a single hinge can.
##
## For docking the panels stow: each turns flat (in the plane of its boom and the
## keel: X-Z, or Y-Z for a turned pair), then folds
## up accordion-fashion at its boom's end, and the dish parks. rig["fold_to"] (0 out,
## 1 stowed) is where the view wants them; rig["fold"] follows it at FOLD_RATE.
## rig["spring"] (a share of the fold, usually 0) flexes the deployed panels and the
## dish's mast past straight, for the bounce as they snap out leaving port.
##
## The high-gain dish turns on azimuth (about the mast, +Y) and elevation, toward
## the comms target, typically the point-ahead direction from sim/light_time.gd.
extends RefCounted

## Slew rates, radians per real second: the hardware is not fast.
const ARRAY_RATE := 0.5
const DISH_RATE := 0.8
## The mast can't look down through the hull.
const DISH_MIN_EL := -0.35
## Folding, fraction of the whole stow per second (game seconds in transit).
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
	var spring := float(rig.get("spring", 0.0)) if fold <= FLATTEN else 0.0
	# Stowing, the panels first turn flat, then fold; deploying, the reverse.
	var flat := clampf(fold / FLATTEN, 0.0, 1.0)
	var bend := clampf((fold - FLATTEN) / (1.0 - FLATTEN), 0.0, 1.0)
	bend = bend * bend * (3.0 - 2.0 * bend)
	for a in rig.get("arrays", []):
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			continue
		var aim_face := face
		var roll := float(a.get("roll", 0.0))
		if roll != 0.0:
			# The boom's own frame: the Sun as seen with the boom laid along X.
			var r := Basis(Vector3.BACK, -roll) * s
			aim_face = atan2(r.z, r.y)
		var want: float = aim_face if a["kind"] == "solar" else aim_face + PI * 0.5
		if fold > 0.0:
			# Ease from the tracking angle to flat as the stow begins.
			node.rotation.x = wrapf(lerp_angle(want, 0.0, flat), -PI, PI)
		else:
			node.rotation.x = _slew(node.rotation.x, want, ARRAY_RATE, dt)
		_bend(a, bend - spring)
	var dish: Dictionary = rig.get("dish", {})
	if dish.is_empty() or not is_instance_valid(dish["az"]):
		return
	var d := to_local * target.normalized()
	var az := atan2(d.x, d.z)
	var el := clampf(atan2(d.y, Vector2(d.x, d.z).length()), DISH_MIN_EL, PI * 0.5)
	if fold > 0.0:
		# Stowing: turned to face forward and level (as the panels go flat), then the
		# mast folds down aft on its foot hinge, which leaves the bowl facing up.
		var fold_node = dish.get("fold")
		if fold_node != null and is_instance_valid(fold_node):
			az = lerp_angle(az, PI, flat)
			el = lerpf(el, 0.0, flat)
			(fold_node as Node3D).rotation.x = (bend - spring) * PI * 0.5
			if dt < 0.0 or flat >= 1.0:
				az_node_set(dish, az, -el)
				return
		else:
			az = 0.0 if fold >= 1.0 else az * (1.0 - fold)
			el = 0.0 if fold >= 1.0 else el * (1.0 - fold)
	elif dish.get("fold") != null and is_instance_valid(dish["fold"]):
		(dish["fold"] as Node3D).rotation.x = -spring * PI * 0.5
	var az_node: Node3D = dish["az"]
	var el_node: Node3D = dish["el"]
	az_node.rotation.y = _slew(az_node.rotation.y, az, DISH_RATE, dt)
	el_node.rotation.x = _slew(el_node.rotation.x, -el, DISH_RATE, dt)


## Sets the dish's azimuth and elevation hinges directly (stowing, where the angles
## follow the fold rather than a target).
static func az_node_set(dish: Dictionary, az: float, el_rot: float) -> void:
	(dish["az"] as Node3D).rotation.y = wrapf(az, -PI, PI)
	(dish["el"] as Node3D).rotation.x = el_rot


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


## A sphere round the ship's origin that holds the hull with its panels out, however
## they aim: each joint adds its offset and the reach of what hangs off it, so any
## turn of a radiator or array stays inside.
static func deployed_reach(model: Dictionary) -> float:
	var rig: Dictionary = model["rig"]
	var was := [rig.get("fold", 0.0), rig.get("fold_to", 0.0)]
	set_fold(rig, 0.0, true)
	var root: Node3D = model["node"]
	var r := _reach(root, root.find_child("DrivePlume", true, false))
	set_fold(rig, float(was[0]), true)
	rig["fold_to"] = was[1]
	return r


static func _reach(n: Node, plume: Node) -> float:
	var r := 0.0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var box: AABB = (n as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			r = maxf(r, box.get_endpoint(i).length())
	for c in n.get_children():
		if c == plume or not c is Node3D:
			continue
		var s: Vector3 = (c as Node3D).scale.abs()
		r = maxf(r, (c as Node3D).position.length() + _reach(c, plume) * maxf(s.x, maxf(s.y, s.z)))
	return r


## In transit, deploy over deploy_s game seconds after station clearance, eagerly:
## gathering speed until the panels and mast snap straight (deploy_straight_s), then
## the panels whip round to the Sun. Sites have no automatic docking fold;
## ship.stowed always takes priority over this schedule.
static func transit_fold(location: Dictionary, t: float, ship: Dictionary = {}, from_station: bool = true, clear_after_s: float = DEPLOY_AFTER_S, deploy_s: float = 1.0 / FOLD_RATE) -> float:
	if ship.get("stowed", false):
		return 1.0
	if not from_station:
		return 0.0
	var x := clampf((t - float(location.get("depart_t", -INF)) - clear_after_s) / maxf(deploy_s, 0.01), 0.0, 1.0)
	return 1.0 - x * x


## Game seconds into a transit_fold deployment when the panels and mast are straight.
static func deploy_straight_s(deploy_s: float) -> float:
	return deploy_s * sqrt(1.0 - FLATTEN)


## The bounce as panels and dish snap out (cfg: balance.undock), as a share of the
## fold: since_s game seconds after they snap straight, a damped swing past it.
static func deploy_spring(cfg: Dictionary, since_s: float) -> float:
	if since_s < 0.0:
		return 0.0
	return float(cfg["spring_share"]) * exp(-since_s / float(cfg["spring_damp_s"])) * sin(TAU * float(cfg["spring_hz"]) * since_s)


## Leaving: stowed until after_s game seconds in, then unfolding at FOLD_RATE.
## Driven by game time, so the stroke keeps pace with the ship at any time scale.
static func unfold_after(since_s: float, after_s: float) -> float:
	return clampf(1.0 - maxf(0.0, since_s - after_s) * FOLD_RATE, 0.0, 1.0)


## Arriving: folding at FOLD_RATE so the panels are stowed by_s game seconds before
## the ship gets in (to_go_s from now).
static func stow_before(to_go_s: float, by_s: float) -> float:
	return clampf(1.0 - (to_go_s - by_s) * FOLD_RATE, 0.0, 1.0)


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

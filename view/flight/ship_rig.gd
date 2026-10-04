## Drives a ship model's moving parts (the rig from ship_builder.gd).
##
## Every panel turns about its boom, the ship's X axis. A panel can only face a
## direction in the ship's Y-Z plane, so in transit the ship rolls about its line of
## travel (roll_to_sun) to put the Sun in that plane; then solar wings face it
## square on and radiators turn edge-on to it, so they shed heat instead of
## soaking up sunlight. While docking the pilot owns the roll, and the panels do the
## best a single hinge can.
##
## The high-gain dish turns on azimuth (about the mast, +Y) and elevation, toward
## the comms target, typically the point-ahead direction from sim/light_time.gd.
extends RefCounted

## Slew rates, radians per real second: the hardware is not fast.
const ARRAY_RATE := 0.5
const DISH_RATE := 0.8
## The mast can't look down through the hull.
const DISH_MIN_EL := -0.35


## An attitude with -Z along `forward` and the Sun in the ship's Y-Z plane (on the
## +Y side), so every panel hinge can find it.
static func roll_to_sun(forward: Vector3, sun: Vector3) -> Basis:
	var f := forward.normalized()
	var up := sun - f * sun.dot(f)
	if up.length() < 1e-3:
		# Sun dead ahead or astern: any roll will do.
		up = Vector3.UP if absf(f.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(f, up.normalized())


## Turn the panels and dish. ship_basis: the model's world basis (may be scaled);
## sun and target: world directions from the ship. dt < 0 snaps straight there.
static func aim(rig: Dictionary, ship_basis: Basis, sun: Vector3, target: Vector3, dt: float) -> void:
	if rig.is_empty():
		return
	var to_local := ship_basis.orthonormalized().transposed()
	var s := to_local * sun.normalized()
	# Panel normal (0, cos a, sin a) after turning a about X; face the Sun's Y-Z part.
	var face := atan2(s.z, s.y)
	for a in rig.get("arrays", []):
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			continue
		var want := face if a["kind"] == "solar" else face + PI * 0.5
		node.rotation.x = _slew(node.rotation.x, want, ARRAY_RATE, dt)
	var dish: Dictionary = rig.get("dish", {})
	if dish.is_empty() or not is_instance_valid(dish["az"]):
		return
	var d := to_local * target.normalized()
	var az := atan2(d.x, d.z)
	var el := clampf(atan2(d.y, Vector2(d.x, d.z).length()), DISH_MIN_EL, PI * 0.5)
	var az_node: Node3D = dish["az"]
	var el_node: Node3D = dish["el"]
	az_node.rotation.y = _slew(az_node.rotation.y, az, DISH_RATE, dt)
	el_node.rotation.x = _slew(el_node.rotation.x, -el, DISH_RATE, dt)


static func _slew(from: float, to: float, rate: float, dt: float) -> float:
	if dt < 0.0:
		return wrapf(to, -PI, PI)
	return wrapf(rotate_toward(from, to, rate * dt), -PI, PI)

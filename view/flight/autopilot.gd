## A docking pilot that flies with the same controls a player has (see
## FlightScene.read_controls): thrusters and turn rates only, no teleporting.
## Used to prove approaches are flyable, and as the basis of a docking computer.
##
## Technique, as you would teach a new pilot:
##   1. Turn the nose to point straight down the station's axis (-Z).
##   2. Strafe to null your sideways offset from the axis, so you sit on the
##      amber corridor lights.
##   3. Close along the axis at a speed that falls with range: quick far out,
##      under 1 m/s for the last 20 m.
##   4. Let spin match roll you with the port, so the slot is keyed at capture.
extends RefCounted


static func controls(flight) -> Dictionary:
	var basis: Basis = flight.ship_node.global_transform.basis
	var nose: Vector3 = flight.ship_node.global_transform * Vector3(0, 0, flight.nose_z)
	var port_z: float = flight.station["port_z"]
	var limit: float = float(flight.tune_dock["max_speed_mps"])
	# 1. Attitude: point down the axis.
	var want := basis.inverse() * Vector3(0, 0, -1)
	var stick := Vector3(
		clampf(2.5 * atan2(want.y, -want.z), -1.0, 1.0),
		clampf(-2.5 * atan2(want.x, -want.z), -1.0, 1.0),
		0.0)
	# 2-3. Translation: slide onto the axis, then close at a range-scaled speed.
	var offset := Vector2(nose.x, nose.y)
	var along := nose.z - port_z
	var lateral_v := -offset * 0.08
	if lateral_v.length() > 3.0:
		lateral_v = lateral_v.normalized() * 3.0
	var on_axis := offset.length() < maxf(1.5, along * 0.08)
	var closing := clampf(along * 0.02, limit * 0.5, 6.0) if on_axis else 0.0
	if along < 25.0:
		closing = minf(closing, limit * 0.6)
	var want_v := Vector3(lateral_v.x, lateral_v.y, -closing)
	var err: Vector3 = basis.inverse() * (want_v - flight.velocity)
	var thrust := Vector3.ZERO
	for i in 3:
		if absf(err[i]) > 0.06:
			thrust[i] = signf(err[i])
	return {"thrust": thrust, "stick": stick, "boost": false, "brake": false}

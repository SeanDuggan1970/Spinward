## View-only station exit: lifted from the cradle to the hall's axis while the doors
## open, back out on the axis through the tunnel, then manoeuvre.
## Uses game time, so loading a trip or changing views restores the same exit.
extends RefCounted

const ShipRig := preload("res://view/flight/ship_rig.gd")
const Bay := preload("res://view/flight/bay.gd")
const Undock := preload("res://view/flight/undock.gd")
const Spin := preload("res://sim/spin.gd")

var station := false
var fits_bay := false
var spin_rate := 0.0
var opening_s := 0.0
var clear_after_s := 0.0
var start_gap := 0.0
var clear_gap := 0.0
var motion: Dictionary = {}
## The cradle: how far off the axis the ship starts (0 with no hall), and when the lift
## to the axis starts and ends.
var lift_r := 0.0
var lift_from_s := 0.0
var lift_to_s := 0.0
## Held in the cradle for traffic before anything moves (location.hold_s, set by the
## sim from sim/traffic.gd).
var hold_s := 0.0
## How long the bay doors take to open (bays.door_s), when we leave through them.
var door_s := 0.0


func setup(model: Dictionary, data, location: Dictionary) -> void:
	var geom: Dictionary = data.places.get(location.get("from", ""), {}).get("station", {})
	station = not geom.is_empty()
	if not station:
		return
	spin_rate = float(geom["spin_rpm"]) * TAU / 60.0
	start_gap = -float(model["nose_z"]) + 0.5
	motion = data.balance["undock"].duplicate()
	hold_s = float(location.get("hold_s", 0.0))
	motion["doors_at_s"] = float(motion["doors_at_s"]) + hold_s
	motion["move_at_s"] = float(motion["move_at_s"]) + hold_s
	opening_s = hold_s
	# Clear the whole hull's turning envelope, including its deployed panels.
	var envelope := maxf(absf(float(model["nose_z"])), absf(float(model["nose_z"]) + float(model["length"]))) + float(model["radius"])
	var front := 0.0
	var bays: Dictionary = data.balance.get("bays", {})
	if not bays.is_empty():
		var port_r := float(geom.get("port_radius_m", minf(float(geom["hub_radius_m"]) * 0.45, 8.0)))
		var bay_r := maxf(float(bays["radius_m"]), port_r * float(bays["port_margin"]))
		fits_bay = ShipRig.stowed_radius(model) + float(bays["clearance_m"]) <= bay_r
		if fits_bay:
			door_s = float(bays["door_s"])
			opening_s = maxf(float(motion["move_at_s"]), float(motion["doors_at_s"]) + float(bays["door_s"]))
			# Models.station puts the collar 0.2 m forward of the back wall.
			front = float(bays["depth_m"]) - 0.2 + Bay.IRIS_FLANGE_M
			var hall: Dictionary = bays.get("hall", {})
			if not hall.is_empty():
				# From the cradle at the middle of the hall: lifted to the axis while the
				# doors open, then out through the hall's front half and the tunnel.
				var length := float(hall["length_m"])
				start_gap = length * 0.5 - 0.2
				front += length
				lift_r = Spin.cradle_radius(data, ShipRig.stowed_radius(model))
				lift_from_s = float(hall["lift_start_s"]) + hold_s
				lift_to_s = opening_s - 1.0
	motion["move_at_s"] = opening_s
	clear_gap = front + envelope + float(motion["clear_m"])
	clear_after_s = Undock.clear_t(motion, front + envelope, start_gap)


## How far off the axis, toward the cradle, the ship is at `elapsed` (metres).
func lift(elapsed: float) -> float:
	if lift_r <= 0.0:
		return 0.0
	var x := clampf((elapsed - lift_from_s) / maxf(lift_to_s - lift_from_s, 0.1), 0.0, 1.0)
	return lift_r * (1.0 - x * x * (3.0 - 2.0 * x))


func gap(elapsed: float) -> float:
	return start_gap + Undock.moved(motion, elapsed)


func axis_basis(facing: Basis, t: float) -> Basis:
	return facing * Basis(Vector3.BACK, fposmod(t * spin_rate, TAU))


## Game seconds the panels and dish take to snap out once clear (balance.undock.deploy_s).
func deploy_s() -> float:
	return float(motion.get("deploy_s", 1.0 / ShipRig.FOLD_RATE))


## When (game seconds after departure) the ship is out, deployed and has stopped
## bouncing: alive and ready for the voyage.
func alive_s() -> float:
	if not station:
		return 0.0
	var spring := ShipRig.deploy_straight_s(deploy_s()) + 3.0 * float(motion["spring_damp_s"])
	return clear_after_s + maxf(maxf(deploy_s(), spring), float(motion["roll_stop_s"]) + float(motion["settle_s"]))


## The co-pilot's moments on the way out, [game seconds after departure, key]
## (data/npcs.json chatter.copilot_undock), in order.
func cues() -> Array:
	if not station:
		return []
	var out := [[float(motion["wake_s"]), "wake"]]
	if fits_bay:
		# Half open: the stars show through.
		out.append([float(motion["doors_at_s"]) + door_s * 0.5, "doors"])
	out.append([float(motion["move_at_s"]), "backing"])
	out.append([clear_after_s, "clear"])
	out.append([alive_s(), "free"])
	return out


func in_corridor(elapsed: float) -> bool:
	return station and elapsed < clear_after_s


func aim(rig: Dictionary, basis: Basis, sun: Vector3, target: Vector3, location: Dictionary, t: float, ship: Dictionary) -> void:
	var game_dt := maxf(0.0, t - float(rig.get("transit_t", t)))
	var manual := bool(ship.get("stowed", false))
	var was_manual := bool(rig.get("transit_manual", false))
	var fold := ShipRig.transit_fold(location, t, ship, station, clear_after_s, deploy_s())
	var since := t - float(location.get("depart_t", t)) - clear_after_s - ShipRig.deploy_straight_s(deploy_s())
	rig["spring"] = ShipRig.deploy_spring(motion, since) if station and not manual else 0.0
	if not rig.has("transit_t") or (not manual and not was_manual and not rig.get("manual_unfolding", false)):
		# Automatic deployment has an absolute game-time schedule, including reloads.
		ShipRig.set_fold(rig, fold, true)
	else:
		ShipRig.set_fold(rig, fold)
		if was_manual and not manual:
			rig["manual_unfolding"] = true
	rig["transit_t"] = t
	rig["transit_manual"] = manual
	ShipRig.aim(rig, basis, sun, target, game_dt)
	if is_equal_approx(float(rig.get("fold", 0.0)), fold):
		rig["manual_unfolding"] = false

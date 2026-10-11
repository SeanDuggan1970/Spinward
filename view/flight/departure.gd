## View-only station exit: open the bay, back out on its axis, then manoeuvre.
## Uses game time, so loading a trip or changing views restores the same exit.
extends RefCounted

const ShipRig := preload("res://view/flight/ship_rig.gd")
const Bay := preload("res://view/flight/bay.gd")
const Undock := preload("res://view/flight/undock.gd")

var station := false
var fits_bay := false
var spin_rate := 0.0
var opening_s := 0.0
var clear_after_s := 0.0
var start_gap := 0.0
var clear_gap := 0.0
var motion: Dictionary = {}


func setup(model: Dictionary, data, location: Dictionary) -> void:
	var geom: Dictionary = data.places.get(location.get("from", ""), {}).get("station", {})
	station = not geom.is_empty()
	if not station:
		return
	spin_rate = float(geom["spin_rpm"]) * TAU / 60.0
	start_gap = -float(model["nose_z"]) + 0.5
	motion = data.balance["undock"].duplicate()
	# Clear the whole hull's turning envelope, including its deployed panels.
	var envelope := maxf(absf(float(model["nose_z"])), absf(float(model["nose_z"]) + float(model["length"]))) + float(model["radius"])
	var front := 0.0
	var bays: Dictionary = data.balance.get("bays", {})
	if not bays.is_empty():
		var port_r := float(geom.get("port_radius_m", minf(float(geom["hub_radius_m"]) * 0.45, 8.0)))
		var bay_r := maxf(float(bays["radius_m"]), port_r * float(bays["port_margin"]))
		fits_bay = ShipRig.stowed_radius(model) + float(bays["clearance_m"]) <= bay_r
		if fits_bay:
			opening_s = maxf(float(motion["move_at_s"]), float(motion["doors_at_s"]) + float(bays["door_s"]))
			# Models.station puts the collar 0.2 m forward of the back wall.
			front = float(bays["depth_m"]) - 0.2 + Bay.IRIS_FLANGE_M
	motion["move_at_s"] = opening_s
	clear_gap = front + envelope + float(motion["clear_m"])
	clear_after_s = Undock.clear_t(motion, front + envelope, start_gap)


func gap(elapsed: float) -> float:
	return start_gap + Undock.moved(motion, elapsed)


func axis_basis(facing: Basis, t: float) -> Basis:
	return facing * Basis(Vector3.BACK, fposmod(t * spin_rate, TAU))


func in_corridor(elapsed: float) -> bool:
	return station and elapsed < clear_after_s


func aim(rig: Dictionary, basis: Basis, sun: Vector3, target: Vector3, location: Dictionary, t: float, ship: Dictionary) -> void:
	var game_dt := maxf(0.0, t - float(rig.get("transit_t", t)))
	var manual := bool(ship.get("stowed", false))
	var was_manual := bool(rig.get("transit_manual", false))
	var fold := ShipRig.transit_fold(location, t, ship, station, clear_after_s)
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

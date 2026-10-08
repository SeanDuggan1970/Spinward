## The ship's sounds in transit, whichever view is up (ship, orbit, cockpit, map).
##
## A hidden copy of your ship, so every source sits where its hardware is, does what
## the real one does on its trip:
##   - it turns to its burn attitude at the same rate the views show, so the frame
##     creaks and the attitude jets fire while it swings
##   - its drive burns when the plan does
##   - its panels and dish track the Sun and the destination, so their motors whine
## ship_audio.gd plays it all, heard from the crew section.
extends Node3D

const V := preload("res://sim/v3.gd")
const Navigation := preload("res://sim/navigation.gd")
const Models := preload("res://view/flight/models.gd")
const Livery := preload("res://view/flight/livery.gd")
const ShipRig := preload("res://view/flight/ship_rig.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const ShipAudio := preload("res://view/audio/ship_audio.gd")

const TURN_RATE := 0.9

var sim
var audio: ShipAudio
var _ship: Node3D
var _rig: Dictionary
var _basis := Basis.IDENTITY
var _ready_basis := false


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	var model := Models.ship(sim.state.ship, sim.data, Livery.for_ship(sim.data, "", sim.state.ship.get("name", ""), true))
	_ship = model["node"]
	_rig = model["rig"]
	_ship.visible = false
	# Far below everything else in the scene, out of every camera's way.
	position = Vector3(0, -5.0e6, 0)
	add_child(_ship)
	audio = ShipAudio.new()
	_ship.add_child(audio)
	audio.setup(model)


func _process(dt: float) -> void:
	var s = sim.state
	var loc: Dictionary = s.location
	if loc.get("status") != "transit" or s.paused:
		return
	var eph = sim.ephemeris
	var t: float = s.time_s
	var here: Array = V.add(eph.position(loc["frame"], t), Navigation.transit_position(loc, t))
	var thrust: Array = Navigation.transit_accel(loc, t)
	var thrusting := V.length(thrust) > 1e-6
	var forward := Vector3(thrust[0], thrust[2], -thrust[1]).normalized() if thrusting else -_basis.z
	var want := Basis.looking_at(forward, Vector3.UP if absf(forward.y) < 0.98 else Vector3.RIGHT)
	var turn := 0.0
	if not _ready_basis:
		_basis = want
		_ready_basis = true
	elif dt > 0.0:
		var from := _basis.get_rotation_quaternion()
		var to := want.get_rotation_quaternion()
		var angle := from.angle_to(to)
		var step := minf(angle, TURN_RATE * dt)
		_basis = Basis(from.slerp(to, step / maxf(angle, 1e-6)))
		turn = step / dt
	var sun := SkyKit.dir_between(eph.position("sun", t), here)
	_ship.basis = ShipRig.roll_to_sun(-_basis.z, sun)
	ShipRig.set_fold(_rig, ShipRig.transit_fold(loc, t))
	ShipRig.aim(_rig, _ship.basis, sun, SkyKit.dir_between(eph.position(loc["to"], t), here), dt)
	# Swinging round, the attitude jets fire; burning, the drive does.
	var spin := Vector3(0, 1, 0) * (1.0 if turn > 0.05 else 0.0)
	audio.update(dt, {"thrust": 1.0 if thrusting else 0.0, "spin": spin, "turn": turn, "time_scale": s.time_scale})

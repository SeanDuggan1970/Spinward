## The ship's sounds, heard from the crew section.
##
## In vacuum nothing reaches the crew but what comes through the hull, so the
## listener sits in the cabin, whichever camera is in use, and every source sits on
## its hardware:
##   - the drive at the stern: a rumble through the keel, with ignition and cut-off
##   - the manoeuvring jets in their clusters: a knock and a valve snap per pulse
##   - the motors at each panel hinge and the dish: a servo whine while they turn
##   - the pumps behind the cabin, and the cabin air around you
##   - the frame itself: creaks and groans as the ship turns and loads up
## A source is quieter and duller the further it is from the cabin (inverse distance,
## and a low-pass that closes with distance). The "Hull" bus adds a short metallic
## ring and rolls off the highs, as a frame carries sound.
##
## Add as a child of a ship model's root node and call setup() with the model.
## Feed update() each frame with what the ship is doing.
extends Node3D

const DIR := "res://assets/audio/"
const RCS_SOUNDS := ["rcs_1", "rcs_2", "rcs_3", "rcs_4"]
const CREAKS := ["creak_1", "creak_2", "creak_3", "creak_4", "creak_5", "creak_6"]
## Seconds between pulses from one jet cluster while it keeps firing.
## A jet that starts firing pulses at once; held on, it pulses again only every
## RCS_HOLD_S (more under time compression), and no two jets sound within RCS_GAP_S:
## firm, separate puffs, not a rattle.
const RCS_HOLD_S := 0.75
const RCS_GAP_S := 0.16
const POOL := 10

var listener: AudioListener3D
var _drive: AudioStreamPlayer3D
var _pump: AudioStreamPlayer3D
var _cabin: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _motors: Array = []
var _jets: Array = []
## When a jet last sounded (real seconds).
var _last_jet := -10.0
var _creak_at: Array = []
var _pool: Array = []
var _pool_next := 0
var _drive_level := 0.0
var _drive_on := false
var _strain := 0.0
var _strain_due := 0.4
var _last_turn := 0.0
var _silent := false
var _length := 30.0
var _drive_at := Vector3.ZERO
## One-shots fired so far (jets, creaks, knocks), for tests and tuning.
var sounds_played := 0
## Time compression: above x1 the ship's sounds duck and thin out, or a minute of
## burns, swings and slews squeezed into a second is a cacophony.
var time_scale := 1.0
var _duck_db := 0.0
var _last_shot := -10.0
var _last_drive_change := -10.0
var _loops: Array = []


## Headless runs (tests, the smoke run, captures without a window) have no audio
## device: the sources are built but nothing plays, so no playback outlives them.
static func audible() -> bool:
	return DisplayServer.get_name() != "headless"


static func hull_bus() -> String:
	var name := "Hull"
	if AudioServer.get_bus_index(name) >= 0:
		return name
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, name)
	AudioServer.set_bus_send(i, "Master")
	var ring := AudioEffectReverb.new()
	ring.room_size = 0.22
	ring.damping = 0.55
	ring.spread = 0.6
	ring.wet = 0.16
	ring.dry = 1.0
	ring.predelay_msec = 12.0
	AudioServer.add_bus_effect(i, ring)
	var dull := AudioEffectLowPassFilter.new()
	dull.cutoff_hz = 5200.0
	AudioServer.add_bus_effect(i, dull)
	return name


static func stream(name: String) -> AudioStream:
	return load(DIR + name + ".wav")


func _source(at: Vector3, sound: String, db: float, unit: float = 7.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound) if sound != "" else null
	p.position = at
	p.volume_db = db
	p.bus = hull_bus()
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = unit
	p.max_distance = 0.0
	p.panning_strength = 0.7
	p.attenuation_filter_cutoff_hz = 2800.0
	p.attenuation_filter_db = -18.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	return p


## model: the dictionary from Models.ship (node, nose_z, length, radius, rig).
func setup(model: Dictionary) -> void:
	var nose := float(model["nose_z"])
	_length = float(model["length"])
	var radius := float(model["radius"])
	var rig: Dictionary = model.get("rig", {})
	var root: Node3D = model["node"]
	listener = AudioListener3D.new()
	listener.position = Vector3(0, 0.3, nose + clampf(_length * 0.1, 1.5, 6.0))
	add_child(listener)
	listener.make_current()
	_drive_at = Vector3(0, 0, nose + _length - 1.5)
	_drive = _source(_drive_at, "drive_loop", -80.0, 9.0)
	_pump = _source(listener.position + Vector3(0, -0.8, 2.6), "pump_loop", -9.0, 3.0)
	_cabin = AudioStreamPlayer.new()
	_cabin.stream = stream("cabin_loop")
	_cabin.volume_db = -21.0
	add_child(_cabin)
	_loops = [[_drive, 5.0], [_pump, 5.0], [_cabin, 7.0]]
	_alarm = AudioStreamPlayer.new()
	_alarm.stream = stream("alarm_loop")
	_alarm.volume_db = -14.0
	add_child(_alarm)
	# A whining motor at every hinge that turns.
	var hinges := []
	for a in rig.get("arrays", []):
		hinges.append([a["node"], "rotation:x"])
		# The panel's fold: one motor at its root hinge drives the segments.
		if not a.get("hinges", []).is_empty():
			hinges.append([a["hinges"][0], "rotation:z"])
	var dish: Dictionary = rig.get("dish", {})
	if not dish.is_empty():
		hinges.append([dish["az"], "rotation:y"])
		hinges.append([dish["el"], "rotation:x"])
		if dish.get("fold") != null:
			hinges.append([dish["fold"], "rotation:x"])
	for h in hinges:
		var node: Node3D = h[0]
		if not is_instance_valid(node):
			continue
		var p := _source(_local_of(root, node), "motor_loop", -80.0, 5.0)
		_loops.append([p, 1.9])
		_motors.append({"player": p, "node": node, "prop": h[1], "last": float(node.get_indexed(h[1])), "level": 0.0})
	for j in rig.get("rcs", []):
		var node: Node3D = j["node"]
		if is_instance_valid(node):
			_jets.append({"at": _local_of(root, node), "outward": j["outward"], "next": 0.0})
	if _jets.is_empty():
		# Ships without marked clusters: jets fore and aft, four ways round.
		for z in [nose + _length * 0.2, nose + _length * 0.85]:
			for k in 4:
				var a := TAU * float(k) / 4.0
				var out := Vector3(cos(a), sin(a), 0)
				_jets.append({"at": out * radius * 0.6 + Vector3(0, 0, z), "outward": out, "next": 0.0})
	for k in 8:
		_creak_at.append(Vector3(randf_range(-1, 1) * radius * 0.3, randf_range(-1, 1) * radius * 0.3, nose + _length * randf_range(0.15, 0.9)))
	for k in POOL:
		_pool.append(_source(Vector3.ZERO, "", 0.0, 7.0))
	if is_inside_tree():
		_start_loops()
	else:
		ready.connect(_start_loops, CONNECT_ONE_SHOT)


## Leaving the scene (docked, cut to another view): stop every sound first, so no
## playback is left registered with the audio server for a freed player.
func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			c.stop()


## The loops start at a random point each, so two ships never pulse in step.
func _start_loops() -> void:
	if not audible():
		return
	for l in _loops:
		if l[0].is_inside_tree():
			l[0].play(randf() * float(l[1]))


## A node's position in the model root's frame, walking up the parents (works
## before the model is in the tree).
static func _local_of(root: Node3D, node: Node3D) -> Vector3:
	var xform := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xform = (n as Node3D).transform * xform
		n = n.get_parent()
	return xform.origin


## How far the ship's sounds drop at a time compression (dB): none at x1, about -11
## at x10, -16 at x100, -21 at x1000, never below -24.
static func duck_for(scale: float) -> float:
	if scale <= 1.0:
		return 0.0
	return clampf(-6.0 - 5.0 * log(scale) / log(10.0), -24.0, 0.0)


## One-shot at a point on the ship (model frame). Routine ones (jets, creaks) are
## thinned out under time compression; `important` ones (impacts, the wreck) always play.
func play_at(sound: String, at: Vector3, db: float = 0.0, pitch: float = 1.0, important: bool = false) -> void:
	if _silent:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if not important and time_scale > 1.0:
		if now - _last_shot < 0.3 * (1.0 + log(time_scale) / log(10.0)):
			return
	_last_shot = now
	sounds_played += 1
	var p: AudioStreamPlayer3D = _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.stream = stream(sound)
	p.position = at
	p.volume_db = db
	p.pitch_scale = pitch
	if p.is_inside_tree() and audible():
		p.play()


## Every frame. state:
##   thrust  0..1, the main drive's push
##   move    Vector3, translation jets in ship axes (x right, y up, z back)
##   spin    Vector3, attitude jets (pitch, yaw, roll)
##   turn    rad/s, how fast the ship is turning (the frame takes the strain)
func update(dt: float, state: Dictionary) -> void:
	if _silent or dt <= 0.0:
		return
	time_scale = float(state.get("time_scale", 1.0))
	_duck_db = move_toward(_duck_db, duck_for(time_scale), dt * 20.0)
	var bus := AudioServer.get_bus_index(hull_bus())
	AudioServer.set_bus_volume_db(bus, _duck_db)
	_cabin.volume_db = -21.0 + _duck_db * 0.5
	var thrust := clampf(float(state.get("thrust", 0.0)), 0.0, 1.0)
	var now := Time.get_ticks_msec() / 1000.0
	# Under time compression burns can flick on and off: the rumble follows, but the
	# ignition and cut-off thumps don't repeat within a few seconds.
	var transients := time_scale <= 1.0 or now - _last_drive_change > 4.0
	if thrust > 0.04 and not _drive_on:
		_drive_on = true
		if transients:
			play_at("drive_ignite", _drive_at, -2.0, 1.0, true)
			_last_drive_change = now
		_strain += 0.35
	elif thrust < 0.02 and _drive_on:
		_drive_on = false
		if transients:
			play_at("drive_cutoff", _drive_at, -4.0, 1.0, true)
			_last_drive_change = now
		_strain += 0.25
	_drive_level = move_toward(_drive_level, thrust if _drive_on else 0.0, dt * (0.7 if _drive_on else 1.6))
	_drive.volume_db = linear_to_db(maxf(_drive_level, 1e-4)) + 1.0
	_drive.pitch_scale = 0.85 + 0.25 * _drive_level
	# Jets: each cluster pulses while it is pushing the way asked.
	var move: Vector3 = state.get("move", Vector3.ZERO)
	var spin: Vector3 = state.get("spin", Vector3.ZERO)
	var t := Time.get_ticks_msec() / 1000.0
	var calm := 1.0 + log(maxf(1.0, time_scale)) / log(10.0)
	for j in _jets:
		var fires := false
		if move.length() > 0.05 or spin.length() > 0.05:
			var out: Vector3 = j["outward"]
			# A jet pushes against where it points; rotation fires opposed pairs fore and aft.
			fires = out.dot(-move.normalized()) > 0.5 if move.length() > 0.05 else false
			if spin.length() > 0.05:
				var lever: Vector3 = j["at"]
				var torque := lever.cross(-out)
				fires = fires or torque.normalized().dot(Vector3(spin.x, spin.y, spin.z).normalized()) > 0.4
		var starting := fires and not bool(j.get("on", false))
		j["on"] = fires
		if not fires or (not starting and t < float(j["next"])) or t - _last_jet < RCS_GAP_S * calm:
			continue
		j["next"] = t + RCS_HOLD_S * calm * randf_range(0.8, 1.3)
		_last_jet = t
		play_at(RCS_SOUNDS[randi() % RCS_SOUNDS.size()], j["at"], -6.0 if starting else -9.0, randf_range(0.9, 1.1))
	# The frame: strain builds as the ship turns and changes how hard it turns.
	var turn := float(state.get("turn", 0.0))
	_strain += (absf(turn - _last_turn) / dt * 0.08 + turn * 0.35) * dt
	_last_turn = turn
	if _strain > _strain_due:
		_strain = 0.0
		_strain_due = randf_range(0.35, 0.9)
		var at: Vector3 = _creak_at[randi() % _creak_at.size()]
		play_at(CREAKS[randi() % CREAKS.size()], at, randf_range(-9.0, -3.0), randf_range(0.85, 1.1))
	# Motors whine while their hinges move, a little higher the faster they go.
	for m in _motors:
		var node: Node3D = m["node"]
		if not is_instance_valid(node):
			continue
		var angle := float(node.get_indexed(m["prop"]))
		var rate := absf(wrapf(angle - float(m["last"]), -PI, PI)) / dt
		m["last"] = angle
		m["level"] = lerpf(float(m["level"]), clampf(rate / 0.4, 0.0, 1.0), clampf(dt * 8.0, 0.0, 1.0))
		var p: AudioStreamPlayer3D = m["player"]
		p.volume_db = linear_to_db(maxf(float(m["level"]), 1e-4)) - 8.0
		p.pitch_scale = 0.8 + 0.5 * float(m["level"])


## A collision: a knock or a crunch where it landed.
func impact(speed: float, at: Vector3) -> void:
	if speed < 4.0:
		play_at("impact_light", at, clampf(-14.0 + speed * 3.0, -14.0, 0.0), randf_range(0.9, 1.1), true)
	else:
		play_at("impact_heavy", at, 2.0, randf_range(0.9, 1.05), true)
	_strain += 0.5


func alarm(on: bool) -> void:
	if not _alarm.is_inside_tree() or not audible():
		return
	if on and not _alarm.playing:
		_alarm.play()
	elif not on and _alarm.playing:
		_alarm.stop()


func beep() -> void:
	if not _silent and audible():
		var b := AudioStreamPlayer.new()
		b.stream = stream("beep")
		b.volume_db = -12.0
		add_child(b)
		if b.is_inside_tree():
			b.play()
		b.finished.connect(b.queue_free)


## The end: one last boom felt through what is left, then quiet but for the alarm.
func wreck(at: Vector3) -> void:
	play_at("explosion", at, 4.0, 1.0, true)
	play_at("impact_heavy", at, 0.0, 0.8, true)
	for p in [_drive, _pump]:
		p.stop()
	for m in _motors:
		m["player"].stop()
	_cabin.volume_db = -30.0
	alarm(true)
	_silent = true

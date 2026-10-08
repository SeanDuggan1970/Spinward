## Riding a space elevator: the view from a climber cab, the ribbon running past the
## window and the world below growing (going down) or falling away (going up).
##
## Altitude, speed and the weight you feel are real. Weight fades to nothing at the
## anchor: the spin carries you round with the world, and at the synchronous height
## that is an orbit. On the Luna Line, Earth's pull cancels the Moon's at L1. The near
## ribbon is drawn at its true size (a metre-wide tape, marker plates every 50 m);
## the body beyond is at its true angular size. Arrow keys look around; [ and ] set
## time compression as anywhere else.
extends Node3D

const V := preload("res://sim/v3.gd")
const Kit := preload("res://view/flight/kit.gd")
const Bindings := preload("res://view/bindings.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const UI := preload("res://view/ui/ui_kit.gd")
const ClimberModel := preload("res://view/flight/climber_model.gd")

## The body sits this far below on the sky, whatever the altitude: only its size changes.
const SKY := 50000.0
const NEAR_RIBBON_M := 3000.0
const PLATE_SPACING_M := 50.0
const G0 := 9.80665
## The tape's width (m): narrow at the foot, widest at the anchor where it carries
## the most, narrowing again to the counterweight (after Edwards and ISEC's tapered
## ribbons). Two guard strands run alongside, tied across every 100 m.
const TAPE_FOOT_M := 0.4
const TAPE_ANCHOR_M := 1.6
const TAPE_TIP_M := 0.8
const GUARD_GAP_M := 0.7
const TAPE_SEGMENTS := 60
## A slow wave travels the ribbon (climbing stirs it; paired climbers damp it): metres
## of sway, metres of wavelength, and real seconds to pass.
const WAVE_M := 0.5
const WAVE_LENGTH_M := 2400.0
const WAVE_PERIOD_S := 9.0

var sim
var camera: Camera3D
var look_yaw := 0.6
var look_pitch := -1.05
var _loc: Dictionary
var _line: Dictionary
var _body := ""
var _radius := 1.0
var _top_m := 0.0
## Anchor to counterweight, metres.
var _leg_m := 0.0
var _planet: MeshInstance3D
var _planet_r0 := 1.0
var _plates: Array = []
var _segments: Array = []
var _drive: Dictionary = {}
var _passing: Dictionary = {}
var _beam: Node3D
var _streak: MeshInstance3D
var _other: Node3D
var _hud: Label
var _title: Label
var _last_h := -1.0
## Climbing speed, m/s of game time.
var _speed := 0.0


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	_loc = sim.state.location
	_line = sim.data.places[_loc["line"]]["elevator"]
	_body = _line["body"]
	_radius = float(sim.data.bodies[_body]["radius_m"])
	_top_m = float(_line["km"]) * 1000.0
	_leg_m = float(_line.get("counterweight", {}).get("km", 0.0)) * 1000.0
	add_child(SkyKit.environment())
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	# A frame with +Y straight up the ribbon from the foot.
	var foot: String = _line["foot"]
	var up := SkyKit.dir_between(eph.position(foot, t), eph.position(_body, t))
	var to_local := _up_basis(up).inverse()
	var sun_dir: Vector3 = to_local * SkyKit.dir_between(eph.position("sun", t), eph.position(_body, t))
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	add_child(Kit.sphere(SKY * 0.02, Kit.glow(Color("fff6e0"), 6.0), sun_dir * SKY * 3.0))
	SkyKit.set_eclipse(sun_dir)
	_planet_r0 = SKY * 0.5
	_planet = SkyKit.body_mesh(sim.data, _body, _planet_r0)
	(_planet.mesh as SphereMesh).radial_segments = 128
	(_planet.mesh as SphereMesh).rings = 64
	# The foot is on the equator: turn the pole away from straight down.
	_planet.basis = Basis(Vector3.RIGHT, PI * 0.5)
	SkyKit.update_body(_planet, sun_dir, t)
	add_child(_planet)
	# Earth over the Luna Line, where it always hangs.
	if _body == "moon":
		var earth_dir: Vector3 = to_local * SkyKit.dir_between(eph.position("earth", t), eph.position("moon", t))
		var earth := SkyKit.body_mesh(sim.data, "earth", SKY * 1.6 * tan(asin(6371000.0 / 384400000.0)))
		earth.position = earth_dir * SKY * 1.6
		SkyKit.update_body(earth, sun_dir, t)
		add_child(earth)
	_build_ribbon()
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = SKY * 6.0
	add_child(camera)
	camera.position = Vector3(7.0, 0.0, 0.0)
	camera.make_current()
	_build_hud()
	_update(0.0)


static func _up_basis(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized())


## The ribbon at true size near the cab: a tapered tape between two guard strands,
## marker plates and ties, a streak for when time compression smears them, our own
## traction head and power dish below the window, and a climber coming the other way.
func _build_ribbon() -> void:
	# A carbon-nanotube tape: dark, with a dull sheen.
	var tape := Kit.paint(Color("6a7078"), {"finish": 1, "wear": 0.05, "mismatch": 0.0, "panel_m": 6.0, "metallic": 0.6, "roughness": 0.35})
	var guard := Kit.mat("steel")
	var seg_len := NEAR_RIBBON_M * 2.0 / float(TAPE_SEGMENTS)
	for i in TAPE_SEGMENTS:
		var seg := Node3D.new()
		seg.position = Vector3(0, -NEAR_RIBBON_M + seg_len * (float(i) + 0.5), 0)
		seg.add_child(Kit.box(Vector3(0.03, seg_len, 1.0), tape))
		for side in [-1.0, 1.0]:
			var g := Kit.box(Vector3(0.05, seg_len, 0.05), guard)
			g.set_meta("side", side)
			seg.add_child(g)
		add_child(seg)
		_segments.append(seg)
	# Our own traction head, below the window, its wheels pinching the tape.
	_drive = ClimberModel.build(String(_line.get("power", "beam")), "yellow", 1.0, true)
	_drive["node"].position = Vector3(0.0, -9.0, 0.0)
	add_child(_drive["node"])
	var lamp := Kit.glow(Color("f0a030"), 3.0)
	for i in int(NEAR_RIBBON_M * 2.0 / PLATE_SPACING_M):
		var plate := Node3D.new()
		plate.add_child(Kit.box(Vector3(0.08, 0.25, 0.7), Kit.mat("yellow")))
		plate.add_child(Kit.sphere(0.08, lamp, Vector3(0.06, 0, 0.32)))
		# Every other plate carries a tie across to the guard strands.
		if i % 2 == 0:
			var tie := Kit.box(Vector3(0.04, 0.04, 1.0), guard)
			tie.set_meta("tie", true)
			plate.add_child(tie)
		add_child(plate)
		_plates.append(plate)
	var streak_mat := Kit.glow(Color("f0a030"), 0.6)
	_streak = Kit.box(Vector3(0.06, NEAR_RIBBON_M * 2.0, 0.06), streak_mat, Vector3(0.06, 0, 0.32))
	add_child(_streak)
	# Power beamed up from the foot shows as a faint column below the dish.
	if String(_line.get("power", "beam")) == "beam":
		_beam = Kit.box(Vector3(3.0, NEAR_RIBBON_M, 3.0), Kit.glow(Color(0.55, 0.75, 1.0), 0.25), Vector3(0, -NEAR_RIBBON_M * 0.5 - 20.0, 0))
		add_child(_beam)
	# A climber coming the other way, on the far side of the tape.
	_passing = ClimberModel.build(String(_line.get("power", "beam")), "orange")
	_other = _passing["node"]
	_other.rotation = Vector3(0, PI, 0)
	add_child(_other)


## The tape's width at height h above the foot.
func tape_width(h: float) -> float:
	if h <= _top_m:
		return lerpf(TAPE_FOOT_M, TAPE_ANCHOR_M, clampf(h / maxf(_top_m, 1.0), 0.0, 1.0))
	return lerpf(TAPE_ANCHOR_M, TAPE_TIP_M, clampf((h - _top_m) / maxf(_leg_m, 1.0), 0.0, 1.0))


## The ribbon's sway at a point s metres up it (relative to where we hold it, at the cab).
func _sway(s: float, h: float) -> float:
	var phase := TAU * Time.get_ticks_msec() / 1000.0 / WAVE_PERIOD_S
	return WAVE_M * (sin(TAU * (s + h) / WAVE_LENGTH_M - phase) - sin(TAU * h / WAVE_LENGTH_M - phase))


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	layer.add_child(root)
	_title = UI.label("", UI.AMBER, 18)
	_title.position = Vector2(24, 44)
	root.add_child(_title)
	_hud = UI.label("", UI.TEXT, 14)
	_hud.position = Vector2(24, 76)
	root.add_child(_hud)


## Altitude above the foot now, in metres: steady speed, easing at each end. Out to
## the counterweight (and back in), the ride runs on from the anchor.
func altitude(t: float) -> float:
	var f := clampf((t - float(_loc["depart_t"])) / maxf(float(_loc["arrive_t"]) - float(_loc["depart_t"]), 1.0), 0.0, 1.0)
	var p := lerpf(f, f * f * (3.0 - 2.0 * f), 0.25)
	match _dir():
		"out":
			return _top_m + _leg_m * p
		"in":
			return _top_m + _leg_m * (1.0 - p)
		"down":
			return _top_m * (1.0 - p)
	return _top_m * p


func _dir() -> String:
	return String(_loc.get("dir", "down" if _loc["down"] else "up"))


## What a person weighs here, in gees: gravity less the swing of the spin (or, on the
## Luna Line, less Earth's pull in the turning Earth-Moon frame).
func weight_g(h: float) -> float:
	var r := _radius + h
	var gm := float(sim.data.bodies[_body]["gm"])
	if _body == "moon":
		var eph = sim.ephemeris
		var t: float = sim.state.time_s
		var d := V.distance(eph.position("earth", t), eph.position("moon", t))
		var gme := float(sim.data.bodies["earth"]["gm"])
		var w2 := (gme + gm) / pow(d, 3)
		var moon_from_bary := d * gme / (gme + gm)
		return (gm / (r * r) - gme / pow(d - r, 2) + w2 * (moon_from_bary - r)) / G0
	var day := float(sim.data.places[_line["foot"]]["location"].get("day_s", 86400.0))
	return (gm / (r * r) - pow(TAU / day, 2) * r) / G0


func _process(dt: float) -> void:
	look_yaw += Input.get_axis("climber_look_right", "climber_look_left") * dt * 0.8
	var tilt := Input.get_axis("climber_look_down", "climber_look_up")
	look_pitch = clampf(look_pitch + tilt * dt * 0.8, -1.5, 1.4)
	_update(dt)


func _update(dt: float) -> void:
	if sim.state.location.get("status") != "elevator":
		return
	var t: float = sim.state.time_s
	var h := altitude(t)
	_speed = absf(altitude(t + 30.0) - altitude(t - 30.0)) / 60.0
	var moved := absf(h - _last_h) if _last_h >= 0.0 else 0.0
	_last_h = h
	# The world at its true angular size, straight down the ribbon.
	var dist := _radius + h
	var k := SKY / dist
	_planet.position = Vector3(0, -SKY, 0)
	_planet.scale = Vector3.ONE * (_radius * k / _planet_r0)
	# Plates fixed on the ribbon scroll past; smeared to a streak when time runs fast.
	var fast := moved > PLATE_SPACING_M * 0.4
	var tw := tape_width(h)
	for seg in _segments:
		var y: float = seg.position.y
		seg.position.x = _sway(y, h)
		seg.get_child(0).scale.z = tw
		for g in seg.get_children():
			if g.has_meta("side"):
				g.position.z = float(g.get_meta("side")) * (tw * 0.5 + GUARD_GAP_M)
	for i in _plates.size():
		var y := fposmod(float(i) * PLATE_SPACING_M - h, NEAR_RIBBON_M * 2.0) - NEAR_RIBBON_M
		_plates[i].position = Vector3(0.03 + _sway(y, h), y, 0)
		_plates[i].visible = not fast
		for c in _plates[i].get_children():
			if c.has_meta("tie"):
				c.scale.z = tw + 2.0 * GUARD_GAP_M
	_streak.visible = fast
	# Our wheels roll with the climb (a blur under time compression, so leave them be).
	if not fast and _last_h >= 0.0:
		ClimberModel.roll(_drive, moved * (1.0 if _dir() in ["up", "out"] else -1.0))
	# A climber going the other way passes every so often (at sane time rates).
	var meet := fposmod(h * 2.0 + 1200.0, 40000.0) - 20000.0
	var oy: float = meet if not _loc["down"] else -meet
	_other.position = Vector3(_sway(oy, h), oy, 0)
	_other.visible = not fast and absf(meet) < NEAR_RIBBON_M
	if _other.visible:
		ClimberModel.roll(_passing, 2.0 * moved)
	camera.basis = Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch)
	var left := maxf(float(_loc["arrive_t"]) - t, 0.0)
	var to_name: String = sim.data.places[_loc["to"]]["name"]
	_title.text = "%s  ·  %s TO %s" % [String(_line["name"]).to_upper(), {"down": "DOWN", "up": "UP", "out": "OUT", "in": "IN"}[_dir()], to_name.to_upper()]
	# Past the anchor the spin outweighs the pull: you weigh something again, outward,
	# and the cab's ceiling becomes the floor.
	var w := weight_g(h)
	var lines := [
		"Altitude      %s" % _km(h),
		"Speed         %d km/h" % int(round(_speed * 3.6)),
		"You weigh     %s" % _weight_text(w),
		"%s in       %s" % [to_name, UI.duration(left)],
		"",
		"%s %s  time    %s  pause    %s %s  look" % [Bindings.key_of("time_slower"), Bindings.key_of("time_faster"), Bindings.key_of("pause"), Bindings.key_of("climber_look_left"), Bindings.key_of("climber_look_right")],
	]
	_hud.text = "\n".join(lines)


## Weight in gees, or milligees when slight; past the anchor it points outward.
static func _weight_text(w: float) -> String:
	var a := absf(w)
	var amount := ("%.3f g" % a) if a >= 0.01 else ("%.2f mg" % (a * 1000.0))
	if a < 1.0e-6:
		return "nothing"
	return amount if w > 0.0 else amount + ", outward: the ceiling is the floor"


static func _km(m: float) -> String:
	return "%s km" % String.num(m / 1000.0, 0 if m > 100000.0 else 1)

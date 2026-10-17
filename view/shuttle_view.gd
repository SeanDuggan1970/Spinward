## Flying the shuttle between an up-port and a base on the surface: a chase view of
## the shuttle over the world, the base's domes below.
##
## Down: a wait in orbit for the ground track to come round, a deorbit burn, the fall
## to the top of the air, seven minutes of entry in its own plasma, and a landing on
## the belly retros by the pad. Up: lift-off, the climb to orbit, and the long chase
## up to the port. The phases run to set times from each end of the flight, so a
## longer flight is a longer wait in orbit, not a slower fall. Arrow keys look round
## the shuttle; [ and ] set time compression as anywhere else.
extends Node3D

const V := preload("res://sim/v3.gd")
const Kit := preload("res://view/flight/kit.gd")
const Bindings := preload("res://view/bindings.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const UI := preload("res://view/ui/ui_kit.gd")

## The down profile, in seconds before touchdown: the deorbit burn starts, ends, the
## shuttle meets the air, and the retros take over. The air's top and the height
## where entry hands over to the retros (m), and the speed then (m/s).
const DEORBIT_T := 1500.0
const COAST_T := 1380.0
const ENTRY_T := 600.0
const RETRO_T := 180.0
const AIR_TOP_M := 125000.0
const RETRO_M := 8000.0
const RETRO_V := 450.0
## Downrange (m) at each of those moments, so the base comes up from the horizon.
const RETRO_RANGE_M := 3000.0
const ENTRY_RANGE_M := 1100000.0
const COAST_RANGE_M := 3700000.0
## The up profile, in seconds after lift-off: on the pad, engines cut at the top of
## the climb, coast up to the port's height; the last stretch is docking.
const PAD_T := 30.0
const BURNOUT_T := 450.0
const CLIMB_T := 1800.0
const BURNOUT_M := 100000.0
const DOCK_T := 600.0
## How far round the world the shuttle is drawn at most (rad): beyond, it's just away.
const MAX_ARC := 1.1
## Chase camera distance (m).
const CHASE_M := 70.0

var sim
var camera: Camera3D
var look_yaw := 0.9
var look_pitch := -0.25
var _loc: Dictionary
var _line: Dictionary
var _base := ""
var _body := ""
var _radius := 1.0
var _orbit_m := 400000.0
var _orbit_v := 3000.0
var _planet: MeshInstance3D
var _shuttle: Node3D
var _plasma: MeshInstance3D
var _retros: Array = []
var _main: MeshInstance3D
var _hud: Label
var _title: Label


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	_loc = sim.state.location
	var port: String = _loc["line"]
	_line = sim.data.places[port]["shuttle"]
	_base = _loc["to"] if _loc["down"] else _loc["from"]
	_body = _line["body"]
	_radius = float(sim.data.bodies[_body]["radius_m"])
	var gm := float(sim.data.bodies[_body]["gm"])
	var ring: Dictionary = sim.data.places[port]["location"].get("elements", {})
	_orbit_m = float(ring.get("a_m", _radius + 400000.0)) - _radius
	_orbit_v = sqrt(gm / (_radius + _orbit_m))
	add_child(SkyKit.environment())
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	# A frame with +Y straight up from the base, the world's centre below.
	var up := SkyKit.dir_between(eph.position(_base, t), eph.position(_body, t))
	var to_local := _up_basis(up).inverse()
	var sun_dir: Vector3 = to_local * SkyKit.dir_between(eph.position("sun", t), eph.position(_body, t))
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	SkyKit.set_eclipse(sun_dir)
	# The world at true size, its mesh's pole (a vertex, so exact) under the base.
	_planet = SkyKit.body_mesh(sim.data, _body, _radius)
	(_planet.mesh as SphereMesh).radial_segments = 256
	(_planet.mesh as SphereMesh).rings = 128
	_planet.basis = Basis.IDENTITY
	_planet.position = Vector3(0, -_radius, 0)
	SkyKit.update_body(_planet, sun_dir, t)
	add_child(_planet)
	add_child(_build_base(sim.data.places[_base]))
	_shuttle = _build_shuttle()
	add_child(_shuttle)
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.near = 0.5
	camera.far = _radius * 4.0
	add_child(camera)
	camera.make_current()
	_build_hud()
	_update()


static func _up_basis(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y).normalized())


## The base at the origin: a landing pad with its lights, and glass domes round it
## ("look": domes, dome_m), lit green-gold from within by their fields.
func _build_base(place: Dictionary) -> Node3D:
	var n := Node3D.new()
	var look: Dictionary = place.get("look", {})
	var count := int(look.get("domes", 5))
	var size := float(look.get("dome_m", 70.0))
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 45.0
	disc.bottom_radius = 47.0
	disc.height = 1.0
	disc.radial_segments = 48
	pad.mesh = disc
	pad.material_override = Kit.mat("grey")
	n.add_child(pad)
	for k in 8:
		var a := TAU * float(k) / 8.0
		n.add_child(Kit.beacon(Color("ffb050"), Vector3(cos(a) * 46.0, 0.8, sin(a) * 46.0), 0.6, 1.6, float(k) / 8.0))
	# Domes in a loose ring beside the pad, each its own size (a hash, not the sim's dice).
	var salt := hash(_base)
	var field := StandardMaterial3D.new()
	field.albedo_color = Color("3d5a2a")
	field.emission_enabled = true
	field.emission = Color("b8d070")
	field.emission_energy_multiplier = 0.35
	for k in count:
		var h := absi(hash(salt + k * 7919))
		var r := size * (0.55 + 0.45 * float(h % 1000) / 1000.0)
		var a := TAU * float(k) / float(count) + float((h / 1000) % 100) / 100.0 * 0.5
		var at := Vector3(cos(a), 0.0, sin(a)) * (120.0 + size * 1.6 + float((h / 100000) % 100))
		var dome := MeshInstance3D.new()
		var hemi := SphereMesh.new()
		hemi.radius = r
		hemi.height = r
		hemi.is_hemisphere = true
		hemi.radial_segments = 32
		hemi.rings = 12
		dome.mesh = hemi
		dome.material_override = Kit.glass(0.6)
		dome.position = at
		n.add_child(dome)
		# The fields inside, a disc just under the glass.
		var fields := MeshInstance3D.new()
		var plate := CylinderMesh.new()
		plate.top_radius = r * 0.96
		plate.bottom_radius = r * 0.96
		plate.height = 0.6
		plate.radial_segments = 32
		fields.mesh = plate
		fields.material_override = field
		fields.position = at + Vector3(0, 0.3, 0)
		n.add_child(fields)
	return n


## A blunt lifting body, nose to +X and belly down: a heat-shield belly, stub wings,
## a tail fin, four belly retros and a main engine aft.
func _build_shuttle() -> Node3D:
	var n := Node3D.new()
	var hull := Kit.mat("offwhite")
	var shield := Kit.mat("black")
	var body := Kit.sphere(1.0, hull)
	body.scale = Vector3(14.0, 3.2, 5.0)
	n.add_child(body)
	var belly := Kit.sphere(1.0, shield, Vector3(0.0, -0.6, 0.0))
	belly.scale = Vector3(14.2, 2.8, 5.2)
	n.add_child(belly)
	for side in [-1.0, 1.0]:
		var wing := Kit.box(Vector3(9.0, 0.6, 6.0), hull, Vector3(-4.0, -0.4, side * 6.5))
		wing.rotation = Vector3(side * 0.12, 0.0, 0.0)
		n.add_child(wing)
	n.add_child(Kit.box(Vector3(5.0, 5.0, 0.5), Kit.mat("rust"), Vector3(-10.0, 3.6, 0.0)))
	n.add_child(Kit.box(Vector3(2.6, 0.9, 3.0), Kit.glass(0.5), Vector3(10.0, 1.9, 0.0)))
	for p in [Vector3(6.0, -2.6, 2.2), Vector3(6.0, -2.6, -2.2), Vector3(-6.0, -2.6, 2.2), Vector3(-6.0, -2.6, -2.2)]:
		var jet := Kit.cone(0.9, 0.2, 7.0, Kit.glow(Color("ffd9a0"), 4.0), p + Vector3(0, -3.5, 0), 12)
		jet.rotation_degrees = Vector3(90, 0, 0)
		jet.visible = false
		n.add_child(jet)
		_retros.append(jet)
	_main = Kit.cone(0.4, 2.2, 16.0, Kit.glow(Color("ffe6c0"), 5.0), Vector3(-22.0, 0.0, 0.0), 16)
	_main.rotation_degrees = Vector3(0, 90, 0)
	_main.visible = false
	n.add_child(_main)
	# Entry plasma: a glowing shell round the nose and belly, brightest at peak heating.
	_plasma = Kit.sphere(1.0, _plasma_material())
	_plasma.scale = Vector3(17.0, 6.0, 8.0)
	_plasma.position = Vector3(2.0, -1.5, 0.0)
	_plasma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plasma.visible = false
	n.add_child(_plasma)
	return n


static func _plasma_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.45, 0.15, 0.0)
	return m


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


## Where the flight is at `t`: {phase (a line for the HUD), h (altitude, m), v (speed,
## m/s), range (ground distance to the base, m), pitch (rad, nose up), tail_first
## (bool), plasma (0-1), retro (bool), main (bool)}. Pure arithmetic on the flight's times: no sim state.
static func profile(down: bool, depart_t: float, arrive_t: float, t: float, orbit_m: float, orbit_v: float) -> Dictionary:
	var out := {"plasma": 0.0, "retro": false, "main": false, "pitch": 0.0}
	if down:
		var left := maxf(arrive_t - t, 0.0)
		if left > DEORBIT_T:
			out.merge({"phase": "Waiting in orbit for the ground track", "h": orbit_m, "v": orbit_v, "range": INF}, true)
		elif left > COAST_T:
			out.merge({"phase": "Deorbit burn", "h": orbit_m, "v": orbit_v - 60.0 * (DEORBIT_T - left) / (DEORBIT_T - COAST_T), "range": INF, "main": true, "tail_first": true}, true)
		elif left > ENTRY_T:
			var f := (COAST_T - left) / (COAST_T - ENTRY_T)
			out.merge({"phase": "Falling toward the air", "h": lerpf(orbit_m, AIR_TOP_M, 0.5 - 0.5 * cos(f * PI)),
				"v": lerpf(orbit_v - 60.0, orbit_v + 90.0, f), "range": lerpf(COAST_RANGE_M, ENTRY_RANGE_M, f), "pitch": 0.7 * f}, true)
		elif left > RETRO_T:
			var f := (ENTRY_T - left) / (ENTRY_T - RETRO_T)
			out.merge({"phase": "Entry", "h": lerpf(AIR_TOP_M, RETRO_M, sqrt(f)), "v": lerpf(orbit_v + 90.0, RETRO_V, f),
				"range": lerpf(ENTRY_RANGE_M, RETRO_RANGE_M, pow(f, 0.6)), "pitch": 0.7, "plasma": sin(PI * minf(f * 1.4, 1.0))}, true)
		elif left > 0.0:
			var f := left / RETRO_T
			out.merge({"phase": "Retros: landing", "h": RETRO_M * f * f, "v": RETRO_V * f, "range": RETRO_RANGE_M * f * f,
				"pitch": 0.7 * f, "retro": true}, true)
		else:
			out.merge({"phase": "Down", "h": 0.0, "v": 0.0, "range": 0.0}, true)
		return out
	var gone := maxf(t - depart_t, 0.0)
	var left_up := maxf(arrive_t - t, 0.0)
	if gone < PAD_T:
		out.merge({"phase": "Engines up", "h": 0.0, "v": 0.0, "range": 0.0, "retro": true}, true)
	elif gone < BURNOUT_T:
		var f := (gone - PAD_T) / (BURNOUT_T - PAD_T)
		out.merge({"phase": "Climbing to orbit", "h": BURNOUT_M * (1.0 - pow(1.0 - f, 2.0)), "v": orbit_v * 1.02 * f * f,
			"range": 900000.0 * f * f * f, "pitch": lerpf(1.3, 0.05, f), "main": true, "retro": f < 0.03}, true)
	elif left_up > DOCK_T and gone < CLIMB_T:
		var f := (gone - BURNOUT_T) / (CLIMB_T - BURNOUT_T)
		out.merge({"phase": "Coasting up to the port's height", "h": lerpf(BURNOUT_M, orbit_m, 0.5 - 0.5 * cos(f * PI)), "v": lerpf(orbit_v * 1.02, orbit_v, f), "range": INF}, true)
	elif left_up > DOCK_T:
		out.merge({"phase": "Closing on the port", "h": orbit_m, "v": orbit_v, "range": INF}, true)
	else:
		out.merge({"phase": "Docking", "h": orbit_m, "v": orbit_v, "range": INF}, true)
	return out


func _process(dt: float) -> void:
	look_yaw += Input.get_axis("climber_look_right", "climber_look_left") * dt * 0.8
	var tilt := Input.get_axis("climber_look_down", "climber_look_up")
	look_pitch = clampf(look_pitch + tilt * dt * 0.8, -1.4, 1.2)
	_update()


func _update() -> void:
	if sim.state.location.get("status") != "shuttle":
		return
	var t: float = sim.state.time_s
	var p := profile(_loc["down"], float(_loc["depart_t"]), float(_loc["arrive_t"]), t, _orbit_m, _orbit_v)
	var h: float = p["h"]
	# Down the shuttle comes in from -X toward the base; up it leaves toward +X.
	var arc := minf(float(p["range"]) / _radius, MAX_ARC)
	var side := -1.0 if _loc["down"] else 1.0
	var centre := Vector3(0, -_radius, 0)
	var up := Vector3(side * sin(arc), cos(arc), 0.0)
	var pos := centre + up * (_radius + h + 4.0)
	# Nose along the direction of flight, pitched up from the local horizon (or turned
	# tail-first for the deorbit burn); the model's +X is its nose, +Y its top.
	var ahead := Vector3(cos(arc), -side * sin(arc), 0.0)
	if p.get("tail_first", false):
		ahead = -ahead
	var lateral := ahead.cross(up).normalized()
	var pitch := float(p["pitch"])
	var nose := ahead.rotated(lateral, pitch)
	var top := up.rotated(lateral, pitch)
	_shuttle.basis = Basis(nose, top, nose.cross(top).normalized())
	_shuttle.position = pos
	var plasma: float = p["plasma"]
	_plasma.visible = plasma > 0.01
	(_plasma.material_override as StandardMaterial3D).albedo_color.a = 0.55 * plasma
	var flicker := 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.031)
	for jet in _retros:
		jet.visible = p["retro"]
		jet.scale = Vector3(1.0, flicker, 1.0)
	_main.visible = p["main"]
	_main.scale = Vector3(1.0, 1.0, flicker)
	# The chase camera, turned round the shuttle by the look keys, never under the ground.
	var off := Basis(Vector3.UP, look_yaw) * Basis(Vector3.BACK, look_pitch) * Vector3(-CHASE_M, 0.0, 0.0)
	var cam := pos + _shuttle.basis * off
	if (cam - centre).length() < _radius + 3.0:
		cam = centre + (cam - centre).normalized() * (_radius + 3.0)
	camera.look_at_from_position(cam, pos, up)
	var left := maxf(float(_loc["arrive_t"]) - t, 0.0)
	var to_name: String = sim.data.places[_loc["to"]]["name"]
	_title.text = "%s  ·  %s TO %s" % [String(_line["name"]).to_upper(), "DOWN" if _loc["down"] else "UP", to_name.to_upper()]
	var lines := [
		String(p["phase"]),
		"",
		"Altitude      %s" % _km(h),
		"Speed         %d m/s" % int(round(float(p["v"]))),
		"%s in       %s" % [to_name, UI.duration(left)],
		"",
		"%s %s  time    %s  pause    %s %s  look" % [Bindings.key_of("time_slower"), Bindings.key_of("time_faster"), Bindings.key_of("pause"), Bindings.key_of("climber_look_left"), Bindings.key_of("climber_look_right")],
	]
	_hud.text = "\n".join(lines)


static func _km(m: float) -> String:
	if m < 1000.0:
		return "%d m" % int(round(m))
	return "%s km" % String.num(m / 1000.0, 0 if m > 100000.0 else 1)

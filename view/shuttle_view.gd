## Flying the shuttle between an up-port and a base on the surface: a chase view of
## the shuttle over the world, the base's domes below.
##
## Down: a wait in orbit for the ground track to come round, a deorbit burn, the fall
## to the top of the air, seven minutes of entry in its own plasma, and a landing on
## the belly retros by the pad. Up: lift-off, the climb to orbit, and the long chase
## up to the port. On a world without air (no "atmosphere" in its look) there is no
## entry and no wings: a lander brakes all the way down on its engine. From a port on
## the surface the flight is a hop: a burn up onto a ballistic arc, a coast along the
## exact ellipse (hop_geometry), and the same burn again to land. The phases run to set times from each end of the flight, so a
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
## A hop's burns (s), each end of its ballistic arc: short and hard, as a lander's are.
const HOP_BURN_T := 60.0
## The lowest point of an airless descent from orbit, where the braking burn starts (m).
const PERILUNE_M := 15000.0
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
## Whether the world has air (a lifting body and an entry), and the hop's arc when the
## port is on the surface too (else empty).
var _air := true
var _hop: Dictionary = {}
## The lander's one engine (airless worlds), which is both its "retros" and its main.
var _engine: MeshInstance3D


func _init(owner_sim) -> void:
	sim = owner_sim


func _ready() -> void:
	_loc = sim.state.location
	var port: String = _loc["line"]
	_line = sim.data.places[port]["shuttle"]
	_base = _loc["to"] if _loc["down"] else _loc["from"]
	_body = _line["body"]
	var ground_r := float(sim.data.bodies[_body]["radius_m"])
	var gm := float(sim.data.bodies[_body]["gm"])
	_air = sim.data.bodies[_body].get("look", {}).has("atmosphere")
	add_child(SkyKit.environment())
	var eph = sim.ephemeris
	var t: float = sim.state.time_s
	# The base's own height from the world's centre: the ground for a town, higher for
	# a city that floats (its location's radius_m). Heights in the profile are above it.
	_radius = V.length(eph.relative(_base, _body, t))
	var ring: Dictionary = sim.data.places[port]["location"].get("elements", {})
	var orbit_r := float(ring.get("a_m", ground_r + 400000.0))
	_orbit_m = orbit_r - _radius
	_orbit_v = sqrt(gm / orbit_r)
	if sim.data.places[port]["location"].get("type", "") == "surface":
		var a: Array = eph.relative(port, _body, t)
		var b: Array = eph.relative(_base, _body, t)
		var cosang := clampf(V.dot(a, b) / (V.length(a) * V.length(b)), -1.0, 1.0)
		_hop = hop_geometry(gm, ground_r, acos(cosang))
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
	_planet = SkyKit.body_mesh(sim.data, _body, ground_r)
	(_planet.mesh as SphereMesh).radial_segments = 256
	(_planet.mesh as SphereMesh).rings = 128
	_planet.basis = Basis.IDENTITY
	_planet.position = Vector3(0, -_radius, 0)
	SkyKit.update_body(_planet, sun_dir, t)
	add_child(_planet)
	add_child(_build_base(sim.data.places[_base]))
	_shuttle = _build_shuttle() if _air else _build_lander()
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
## ("look": domes, dome_m), lit green-gold from within by their fields. A town in a
## lava tube ("look": kind "skylight") shows only its skylight and a few shelters.
func _build_base(place: Dictionary) -> Node3D:
	var n := Node3D.new()
	var look: Dictionary = place.get("look", {})
	if look.get("kind", "") == "skylight":
		_build_skylight(n, float(look.get("skylight_m", 65.0)))
		return n
	if look.get("kind", "") == "aerostat":
		_build_aerostat(n, int(look.get("envelopes", 4)), float(look.get("envelope_m", 150.0)))
		return n
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


## A lava tube's skylight beside the pad: a dark pit glazed over, its glass catching
## the Sun, a ring of lamps round the rim, and the low regolith-banked shelters of the
## surface crew. Everyone else lives below.
func _build_skylight(n: Node3D, width: float) -> void:
	var at := Vector3(180.0, 0.0, 40.0)
	var pit := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = width * 0.5
	shaft.bottom_radius = width * 0.5
	shaft.height = 4.0
	shaft.radial_segments = 48
	pit.mesh = shaft
	pit.material_override = Kit.mat("black")
	pit.position = at + Vector3(0, -1.9, 0)
	n.add_child(pit)
	# The rose window: glass over the shaft, lit faintly from the nave below.
	var rose := MeshInstance3D.new()
	var pane := CylinderMesh.new()
	pane.top_radius = width * 0.5 + 1.0
	pane.bottom_radius = width * 0.5 + 1.0
	pane.height = 0.4
	pane.radial_segments = 48
	rose.mesh = pane
	var glass := Kit.glass(0.25)
	glass.emission = Color("ffd9a0")
	rose.material_override = glass
	rose.position = at + Vector3(0, 0.3, 0)
	n.add_child(rose)
	for k in 12:
		var a := TAU * float(k) / 12.0
		n.add_child(Kit.beacon(Color("ffe2b0"), at + Vector3(cos(a), 0.0, sin(a)) * (width * 0.5 + 4.0) + Vector3(0, 0.6, 0), 0.5, 2.4, float(k) / 12.0))
	for k in 4:
		var h := absi(hash(_base + str(k)))
		var shelter := Kit.box(Vector3(14.0, 4.0, 9.0), Kit.mat("grey"), Vector3(-90.0 - 22.0 * k, 2.0, -70.0 + float(h % 40)))
		shelter.rotation.y = float(h % 100) / 100.0
		n.add_child(shelter)


## A city that floats: the landing deck at the origin, and round it the envelopes
## that lift everything (breathable air, which floats in Venus's carbon dioxide), each
## with its gondola of homes and gardens slung beneath, joined to the deck by walkways.
func _build_aerostat(n: Node3D, count: int, size: float) -> void:
	var deck := MeshInstance3D.new()
	var plate := CylinderMesh.new()
	plate.top_radius = 70.0
	plate.bottom_radius = 64.0
	plate.height = 6.0
	plate.radial_segments = 48
	deck.mesh = plate
	deck.material_override = Kit.mat("grey")
	deck.position = Vector3(0, -3.0, 0)
	n.add_child(deck)
	for k in 8:
		var a := TAU * float(k) / 8.0
		n.add_child(Kit.beacon(Color("ffb050"), Vector3(cos(a) * 66.0, 0.8, sin(a) * 66.0), 0.6, 1.6, float(k) / 8.0))
	var envelope := Kit.glass(0.15)
	envelope.albedo_color = Color(0.85, 0.82, 0.72)
	envelope.metallic = 0.1
	envelope.roughness = 0.3
	var homes := StandardMaterial3D.new()
	homes.albedo_color = Color("3d5a2a")
	homes.emission_enabled = true
	homes.emission = Color("ffd9a0")
	homes.emission_energy_multiplier = 0.4
	for k in count:
		var h := absi(hash(_base + str(k)))
		var a := TAU * float(k) / float(count) + float(h % 100) / 100.0 * 0.4
		var r := size * (0.8 + 0.4 * float((h / 100) % 100) / 100.0)
		var at := Vector3(cos(a), 0.0, sin(a)) * (size * 2.2 + 120.0)
		var bag := Kit.sphere(r, envelope, at + Vector3(0, r * 0.9, 0))
		bag.scale = Vector3(1.0, 0.75, 1.0)
		n.add_child(bag)
		# The gondola under it: homes, terraces and greenhouses, lit from within.
		var gondola := Kit.box(Vector3(r * 1.2, 24.0, r * 0.8), homes, at + Vector3(0, -14.0, 0))
		gondola.rotation.y = a
		n.add_child(gondola)
		# The walkway back to the deck.
		var length := at.length() - 70.0 - r * 0.6
		var walk := Kit.box(Vector3(length, 2.0, 5.0), Kit.mat("steel"), at.normalized() * (70.0 + length * 0.5) + Vector3(0, -2.0, 0))
		walk.rotation.y = -a
		n.add_child(walk)


## A lunar lander, nose to +X and engine down: a pressurised cab with its windows
## forward, a cargo cradle under it, four legs, and one throttleable engine. Nothing
## to fly on: it brakes, hovers and lands on that engine alone.
func _build_lander() -> Node3D:
	var n := Node3D.new()
	var hull := Kit.mat("offwhite")
	# Kit's cylinders and cones lie along Z: stand these upright, along Y.
	var cab := Kit.cylinder(3.2, 5.0, hull, Vector3(0.0, 1.6, 0.0), 24)
	cab.rotation_degrees = Vector3.ZERO
	n.add_child(cab)
	n.add_child(Kit.box(Vector3(1.2, 1.2, 3.0), Kit.glass(0.5), Vector3(3.1, 2.2, 0.0)))
	n.add_child(Kit.box(Vector3(7.0, 1.6, 7.0), Kit.mat("foil"), Vector3(0.0, -1.6, 0.0)))
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var foot := Vector3(cos(a) * 5.5, -4.6, sin(a) * 5.5)
		var leg := Kit.box(Vector3(0.35, 4.2, 0.35), Kit.mat("steel"), Vector3(cos(a) * 4.4, -3.1, sin(a) * 4.4))
		leg.rotation = Vector3(sin(a) * 0.35, 0.0, -cos(a) * 0.35)
		n.add_child(leg)
		var pad := Kit.cylinder(0.9, 0.3, Kit.mat("steel"), foot, 12)
		pad.rotation_degrees = Vector3.ZERO
		n.add_child(pad)
	var bell := Kit.cone(0.5, 1.4, 1.8, Kit.mat("dark"), Vector3(0.0, -3.0, 0.0), 16)
	bell.rotation_degrees = Vector3.ZERO
	n.add_child(bell)
	# The plume, widest at the bell and thinning below it.
	_engine = Kit.cone(1.1, 0.2, 12.0, Kit.glow(Color("ffe6c0"), 5.0), Vector3(0.0, -9.6, 0.0), 16)
	_engine.rotation_degrees = Vector3.ZERO
	_engine.visible = false
	n.add_child(_engine)
	_retros = [_engine]
	_main = _engine
	_plasma = Kit.sphere(0.1, _plasma_material())
	_plasma.visible = false
	n.add_child(_plasma)
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
static func profile(down: bool, depart_t: float, arrive_t: float, t: float, orbit_m: float, orbit_v: float, air: bool = true) -> Dictionary:
	if not air:
		return _profile_airless(down, depart_t, arrive_t, t, orbit_m, orbit_v)
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


## From orbit to a world without air: the same deorbit burn and fall, then a long
## braking burn from the low point of the fall, engine first into the direction of
## travel, pitching up to stand on its engine for the last few hundred metres. Up is
## the reverse: a rise, a pitch-over and a burn along the horizon into orbit.
static func _profile_airless(down: bool, depart_t: float, arrive_t: float, t: float, orbit_m: float, orbit_v: float) -> Dictionary:
	var out := {"plasma": 0.0, "retro": false, "main": false, "pitch": 0.0}
	if down:
		var left := maxf(arrive_t - t, 0.0)
		if left > DEORBIT_T:
			out.merge({"phase": "Waiting in orbit for the ground track", "h": orbit_m, "v": orbit_v, "range": INF}, true)
		elif left > COAST_T:
			out.merge({"phase": "Deorbit burn", "h": orbit_m, "v": orbit_v - 20.0 * (DEORBIT_T - left) / (DEORBIT_T - COAST_T), "range": INF, "retro": true, "pitch": PI * 0.5}, true)
		elif left > ENTRY_T:
			var f := (COAST_T - left) / (COAST_T - ENTRY_T)
			out.merge({"phase": "Falling to the low point of the orbit", "h": lerpf(orbit_m, PERILUNE_M, 0.5 - 0.5 * cos(f * PI)),
				"v": lerpf(orbit_v - 20.0, orbit_v + 30.0, f), "range": lerpf(COAST_RANGE_M, ENTRY_RANGE_M * 0.5, f), "pitch": PI * 0.5 * f}, true)
		elif left > 0.0:
			var f := (ENTRY_T - left) / ENTRY_T
			out.merge({"phase": "Braking burn" if f < 0.9 else "Standing on the engine: landing", "h": PERILUNE_M * pow(1.0 - f, 1.5),
				"v": (orbit_v + 30.0) * (1.0 - f), "range": ENTRY_RANGE_M * 0.5 * pow(1.0 - f, 2.0), "pitch": PI * 0.5 * minf(1.0, (1.0 - f) * 10.0), "retro": true}, true)
		else:
			out.merge({"phase": "Down", "h": 0.0, "v": 0.0, "range": 0.0}, true)
		return out
	var gone := maxf(t - depart_t, 0.0)
	var left_up := maxf(arrive_t - t, 0.0)
	if gone < PAD_T:
		out.merge({"phase": "Engine up", "h": 0.0, "v": 0.0, "range": 0.0, "retro": true}, true)
	elif gone < BURNOUT_T:
		var f := (gone - PAD_T) / (BURNOUT_T - PAD_T)
		out.merge({"phase": "Burning for orbit", "h": PERILUNE_M * (1.0 - pow(1.0 - f, 2.0)), "v": orbit_v * f,
			"range": 400000.0 * f * f, "pitch": -PI * 0.5 * minf(1.0, f * 6.0), "retro": true}, true)
	elif left_up > DOCK_T and gone < CLIMB_T:
		var f := (gone - BURNOUT_T) / (CLIMB_T - BURNOUT_T)
		out.merge({"phase": "Coasting up to the port's height", "h": lerpf(PERILUNE_M, orbit_m, 0.5 - 0.5 * cos(f * PI)), "v": orbit_v, "range": INF}, true)
	elif left_up > DOCK_T:
		out.merge({"phase": "Closing on the port", "h": orbit_m, "v": orbit_v, "range": INF}, true)
	else:
		out.merge({"phase": "Docking", "h": orbit_m, "v": orbit_v, "range": INF}, true)
	return out


## A minimum-energy ballistic hop of `angle` (rad) round a world (gm, radius): launch
## speed and angle, the ellipse (a, e, p) and the true anomaly f of the launch point
## (the arc runs from f through apoapsis to TAU - f), its mean motion and time of
## flight, and the apex height (m).
static func hop_geometry(gm: float, radius: float, angle: float) -> Dictionary:
	var g := gm / (radius * radius)
	var s := sin(angle * 0.5)
	var v0 := sqrt(g * radius * 2.0 * s / (1.0 + s))
	var gamma := (PI - angle) * 0.25
	var h := radius * v0 * cos(gamma)
	var energy := v0 * v0 * 0.5 - gm / radius
	var a := -gm / (2.0 * energy)
	var e := sqrt(maxf(0.0, 1.0 + 2.0 * energy * h * h / (gm * gm)))
	var p := h * h / gm
	var f := acos(clampf((p / radius - 1.0) / maxf(e, 1e-9), -1.0, 1.0))
	var n := sqrt(gm / (a * a * a))
	var m0 := _mean_anomaly(f, e)
	return {"gm": gm, "radius": radius, "angle": angle, "v0": v0, "gamma": gamma, "a": a, "e": e, "p": p, "f": f, "n": n,
		"tof": 2.0 * (PI - m0) / n, "apex_m": a * (1.0 + e) - radius}


## Mean anomaly (0..TAU) at true anomaly nu (0..TAU) on an ellipse of eccentricity e.
static func _mean_anomaly(nu: float, e: float) -> float:
	var ecc := 2.0 * atan(sqrt((1.0 - e) / (1.0 + e)) * tan(nu * 0.5))
	return fposmod(ecc - e * sin(ecc), TAU)


## Where a hop is at `tau` seconds after lift-off: {h, v, travelled (ground distance from
## lift-off, m), gamma (flight-path angle, rad), phase, burning}. The arc is the exact
## ellipse, found by bisection on Kepler's equation; the burns at each end take
## HOP_BURN_T and run along the start and end of the same arc.
static func hop_at(hop: Dictionary, tau: float) -> Dictionary:
	var tof: float = hop["tof"]
	var f: float = hop["f"]
	var e: float = hop["e"]
	var m0 := _mean_anomaly(f, e)
	var target := m0 + float(hop["n"]) * clampf(tau, 0.0, tof)
	var lo := f
	var hi := TAU - f
	for _i in 48:
		var mid := (lo + hi) * 0.5
		var m := _mean_anomaly(mid, e)
		if m < m0:
			m += TAU
		if m < target:
			lo = mid
		else:
			hi = mid
	var nu := (lo + hi) * 0.5
	var r: float = float(hop["p"]) / (1.0 + e * cos(nu))
	var radius: float = hop["radius"]
	var v := sqrt(float(hop["gm"]) * (2.0 / r - 1.0 / float(hop["a"])))
	var gamma := atan2(e * sin(nu), 1.0 + e * cos(nu))
	var burning := tau < HOP_BURN_T or tau > tof - HOP_BURN_T
	var phase := "Coasting on the arc, %d km up" % int(round((r - radius) / 1000.0))
	if tau < HOP_BURN_T:
		v *= tau / HOP_BURN_T
		phase = "Burn: up and over"
	elif tau > tof - HOP_BURN_T:
		v *= (tof - tau) / HOP_BURN_T
		phase = "Burn: braking to land"
	return {"h": maxf(r - radius, 0.0), "v": v, "travelled": (nu - f) * radius, "gamma": gamma, "phase": phase, "burning": burning}


## A hop's flight at `t`, in the same shape as profile(). The pilot boards and loads
## first; the flight itself is the arc's time of flight.
static func profile_hop(hop: Dictionary, down: bool, depart_t: float, arrive_t: float, t: float) -> Dictionary:
	var out := {"plasma": 0.0, "retro": false, "main": false, "pitch": 0.0}
	var tof: float = hop["tof"]
	var span: float = float(hop["angle"]) * float(hop["radius"])
	var tau := tof - maxf(arrive_t - t, 0.0)
	if tau <= 0.0:
		out.merge({"phase": "On the pad, loading", "h": 0.0, "v": 0.0, "range": span if down else 0.0}, true)
		return out
	if tau >= tof:
		out.merge({"phase": "Down", "h": 0.0, "v": 0.0, "range": 0.0 if down else span}, true)
		return out
	var at := hop_at(hop, tau)
	# The lander's top points along its thrust: up the arc leaving, back along it
	# landing, turning end over end at the apex.
	var leave := -(PI * 0.5 - float(hop["gamma"]))
	var arrive := PI * 0.5 - float(hop["gamma"])
	var turn := smoothstep(0.35, 0.65, tau / tof)
	var pitch := lerpf(leave, arrive, turn)
	if tau < 8.0:
		pitch *= tau / 8.0
	elif tof - tau < 8.0:
		pitch *= (tof - tau) / 8.0
	var travelled: float = at["travelled"]
	out.merge({"phase": at["phase"], "h": at["h"], "v": at["v"], "range": span - travelled if down else travelled,
		"pitch": pitch, "retro": at["burning"]}, true)
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
	var p := profile_hop(_hop, _loc["down"], float(_loc["depart_t"]), float(_loc["arrive_t"]), t) if not _hop.is_empty() else profile(_loc["down"], float(_loc["depart_t"]), float(_loc["arrive_t"]), t, _orbit_m, _orbit_v, _air)
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
	if _engine:
		# The lander has one engine: it is the retros and the main both.
		_engine.visible = p["retro"] or p["main"]
	else:
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

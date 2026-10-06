## Fly the descent yourself: a short landing on the site's body, from a few hundred
## metres up, already falling and drifting. Real surface gravity (Eros barely tugs;
## Psyche does), a main engine that pushes up, small thrusters for drift. Touch down
## slower than 2.5 m/s down and 1.5 m/s across to land; harder is a bad landing.
## View-only: the result goes to the sim as part of the site_work command.
extends Node3D

const Kit := preload("res://view/flight/kit.gd")
const SkyKit := preload("res://view/flight/sky.gd")
const UI := preload("res://view/ui/ui_kit.gd")

signal finished(landed: bool)

const MAIN_ACCEL := 3.0
const RCS_ACCEL := 0.8
const FUEL_S := 70.0
const LAND_V := 2.5
const LAND_H := 1.5

var sim
var body := ""
var radius := 1000.0
var gm := 1.0
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var fuel := FUEL_S
var done := false
var landed := false
var _lander: Node3D
## The lift thrusters' jets, lit while the engine fires.
var _flame: Node3D
## The lander (a small Kestrel) and how far its legs are pushed in.
var _model: Dictionary = {}
var _squash := 0.0
var _squash_to := 0.0
var _camera: Camera3D
var _hud: Control
var _font: Font
var _result_t := 0.0
## For captures and demos: fly a gentle descent automatically.
var autopilot := false


func _init(owner_sim, site_id: String) -> void:
	sim = owner_sim
	var loc: Dictionary = sim.data.sites[site_id]["location"]
	body = loc.get("parent", "moon")
	radius = float(sim.data.bodies[body]["radius_m"])
	gm = float(sim.data.bodies[body]["gm"])


func _ready() -> void:
	add_child(SkyKit.environment())
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.5
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.5, -0.6, -0.4), Vector3.UP)
	var ground := SkyKit.body_mesh(sim.data, body, radius)
	(ground.mesh as SphereMesh).radial_segments = 256
	(ground.mesh as SphereMesh).rings = 128
	ground.position = Vector3(0, -radius, 0)
	ground.basis = Basis.IDENTITY
	add_child(ground)
	# Start a few hundred metres up, already coming down and drifting.
	pos = Vector3(0.0, 450.0, 0.0)
	vel = Vector3(4.0, -9.0, -2.0)
	_lander = _build_lander()
	add_child(_lander)
	_camera = Camera3D.new()
	_camera.fov = 60.0
	_camera.near = 0.5
	_camera.far = radius * 4.0 + 10000.0
	add_child(_camera)
	_camera.make_current()
	_font = UI.make_theme().default_font
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	add_child(_hud)


## The Bramble: a two-seat Kestrel, a third the size, a cargo pod slung under it.
## It flies on its four lift thrusters, and its legs take the touchdown.
func _build_lander() -> Node3D:
	var n := Node3D.new()
	var livery: Dictionary = preload("res://view/flight/livery.gd").for_ship(sim.data, "", String(sim.state.ship.get("name", "")), true)
	_model = load("res://view/flight/kestrel.gd").build(livery, 0.36, "cargo")
	var craft: Node3D = _model["node"]
	# Feet at the node's origin, so the craft stands where it lands.
	craft.position = Vector3(0, -float(_model["foot_y"]), 0)
	n.add_child(craft)
	_flame = _model["lift"]
	_flame.visible = false
	return n


func _physics_process(dt: float) -> void:
	if done:
		_result_t += dt
		# The springs rebound from the impact and settle under the craft's weight.
		_squash = lerpf(_squash, _squash_to, clampf(dt * 3.0, 0.0, 1.0))
		_set_legs(_squash)
		_flame.visible = false
		return
	var centre := Vector3(0, -radius, 0)
	var up := (pos - centre).normalized()
	var accel := -up * gm / (pos - centre).length_squared()
	var alt_now := (pos - centre).length() - radius
	var sink := -vel.dot(up)
	var firing := fuel > 0.0 and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or (autopilot and sink > clampf(alt_now * 0.04, 1.2, 12.0)))
	if firing:
		accel += up * MAIN_ACCEL
		fuel -= dt
	var side := Vector3.ZERO
	if fuel > 0.0:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			side.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			side.x += 1.0
		if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_UP):
			side.z -= 1.0
		if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_DOWN):
			side.z += 1.0
	if autopilot and fuel > 0.0:
		var drift := vel - up * vel.dot(up)
		if drift.length() > 0.2:
			side = -drift.normalized()
	if side != Vector3.ZERO:
		accel += side.normalized() * RCS_ACCEL
		fuel -= dt * 0.25
	vel += accel * dt
	pos += vel * dt
	_flame.visible = firing
	var alt := (pos - centre).length() - radius
	if alt <= 0.0:
		var down := -vel.dot(up)
		var across := (vel - up * vel.dot(up)).length()
		landed = down <= LAND_V and across <= LAND_H
		done = true
		pos = centre + up * radius
		vel = Vector3.ZERO
		# The legs take it: a soft landing settles onto the springs; a hard one bottoms out.
		_squash = clampf(down / LAND_V, 0.2, 1.6)
		_squash_to = 0.35
	_lander.position = pos
	_lander.basis = Basis.looking_at(up.cross(Vector3.RIGHT).normalized(), up)
	_camera.look_at_from_position(pos + up * 7.0 + Vector3(0, 0, 15.0), pos + up * 1.2, up)
	_hud.queue_redraw()


## Push the legs in by `amount` of their travel (0 extended, 1 fully in).
func _set_legs(amount: float) -> void:
	if _model.is_empty():
		return
	var push := []
	for leg in _model["legs"]:
		push.append(float(leg["travel_max"]) * clampf(amount, 0.0, 1.0))
	load("res://view/flight/kestrel.gd").compress(_model["legs"], push)


func _unhandled_input(event: InputEvent) -> void:
	if done and _result_t > 0.8 and event is InputEventKey and event.pressed and not event.echo:
		finished.emit(landed)


func _draw_hud() -> void:
	var centre := Vector3(0, -radius, 0)
	var up := (pos - centre).normalized()
	var alt := maxf(0.0, (pos - centre).length() - radius)
	var down := -vel.dot(up)
	var across := (vel - up * vel.dot(up)).length()
	var x := 24.0
	var y := 80.0
	_hud.draw_rect(Rect2(12, 56, 330, 200), Color(0.07, 0.08, 0.09, 0.85))
	_hud.draw_rect(Rect2(12, 56, 330, 3), UI.HAZARD)
	_hud.draw_string(_font, Vector2(x, y), "DESCENT  ·  %s" % sim.data.bodies[body]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.AMBER)
	y += 30
	var rows := [
		["ALTITUDE", "%.0f m" % alt, UI.TEXT],
		["DESCENT", "%.1f m/s" % down, UI.GOOD if down <= LAND_V else UI.WARN],
		["DRIFT", "%.1f m/s" % across, UI.GOOD if across <= LAND_H else UI.WARN],
		["GRAVITY", "%.3f m/s²" % (gm / (radius * radius)), UI.DIM],
		["FUEL", "%d s" % int(ceil(fuel)), UI.TEXT if fuel > 15.0 else UI.WARN],
	]
	for r in rows:
		_hud.draw_string(_font, Vector2(x, y), r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)
		_hud.draw_string(_font, Vector2(x + 100, y), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, r[2])
		y += 24
	var h := _hud.size.y
	_hud.draw_string(_font, Vector2(24, h - 60), "W / Space  main engine (up)     A D  drift left/right     Q E  drift fore/aft", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	_hud.draw_string(_font, Vector2(24, h - 38), "Touch down under %.1f m/s down and %.1f m/s across." % [LAND_V, LAND_H], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.DIM)
	if done:
		var text := "DOWN SAFE. Any key to begin work." if landed else "HARD LANDING. The work will go badly. Any key."
		_hud.draw_string(_font, Vector2(_hud.size.x * 0.5 - 260, h * 0.45), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.GOOD if landed else UI.WARN)

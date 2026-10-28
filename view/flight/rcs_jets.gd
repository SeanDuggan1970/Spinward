## Thruster plumes, as cold gas looks in vacuum: a short, faint, flaring cone off a
## thruster quad, gone in a fraction of a second, with a brief flash at its root.
## Shared by the transit view, the docking scene and the traffic pattern. View-only.
##
## Puffs live under `parent`, in its space: gas leaves the ship and stays where it
## was blown. Positions and directions are given in world space.
extends RefCounted

const Kit := preload("res://view/flight/kit.gd")

## How long a puff lasts (real seconds).
const PUFF_S := 0.35
## A sustained push: the cone holds its length a little longer.
const PUSH_S := 0.5

var parent: Node3D
## At most this many puffs alive at once.
var cap := 12
var _puffs: Array = []
var _jet_mat: ShaderMaterial
var _flash_mat: Material


func _init(parent_node: Node3D, max_live := 12) -> void:
	parent = parent_node
	cap = max_live


## How big a ship's jets look: bigger ships carry bigger quads.
static func size_for(length_m: float) -> float:
	return clampf(length_m / 35.0, 0.8, 3.0)


func count() -> int:
	return _puffs.size()


## One plume from `at` along `dir` (world), `size` about 1 for a working quad.
func fire(at: Vector3, dir: Vector3, size: float, life := PUFF_S) -> void:
	if _puffs.size() >= cap or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if _jet_mat == null:
		_jet_mat = ShaderMaterial.new()
		_jet_mat.shader = load("res://view/shaders/rcs_plume.gdshader")
		_flash_mat = Kit.glow(Color(1.0, 0.95, 0.85), 2.5)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03 * size
	mesh.bottom_radius = 0.38 * size
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var cone := MeshInstance3D.new()
	cone.mesh = mesh
	cone.material_override = _jet_mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cone)
	var inv := parent.global_transform.affine_inverse()
	var flash := Kit.sphere(0.12 * size, _flash_mat, inv * at)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	_puffs.append({"node": cone, "flash": flash, "born": _now(), "life": life, "at": inv * at, "dir": (inv.basis * dir).normalized(), "size": size})
	_place(_puffs[-1], 0.0)


## Age the puffs; call every frame.
func update() -> void:
	var clock := _now()
	for k in range(_puffs.size() - 1, -1, -1):
		var p: Dictionary = _puffs[k]
		var age := clock - float(p["born"])
		if age > float(p["life"]) or not is_instance_valid(p["node"]):
			_free(p)
			_puffs.remove_at(k)
			continue
		_place(p, age / float(p["life"]))


func clear() -> void:
	for p in _puffs:
		_free(p)
	_puffs.clear()


## Translation: jets blowing against `accel` (world), from the quads on the side the
## gas leaves by (for a push along the hull, the end it blows toward). At most `most`.
func push(rig: Dictionary, ship: Node3D, centre_local: Vector3, length: float, accel: Vector3, size: float, most := 4, life := PUSH_S) -> int:
	if accel.length() < 1e-6:
		return 0
	var out_local := (ship.global_basis.inverse() * -accel).normalized()
	var scored: Array = []
	for j in rig.get("rcs", []):
		var quad: Node3D = j["node"]
		if not is_instance_valid(quad):
			continue
		var p := ship.to_local(quad.global_position) - centre_local
		scored.append([(j["outward"] as Vector3).dot(out_local) + p.dot(out_local) / maxf(length * 0.5, 1.0), quad])
	scored.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	var fired := 0
	for e in scored.slice(0, most):
		fire((e[1] as Node3D).global_position, ship.global_basis * out_local, size, life)
		fired += 1
	return fired


## Rotation: jets whose push turns the ship the way `alpha` (a world angular
## acceleration) asks. At most `most`.
func turn(rig: Dictionary, ship: Node3D, centre_local: Vector3, alpha: Vector3, size: float, most := 4) -> int:
	if alpha.length() < 1e-6:
		return 0
	var want := (ship.global_basis.inverse() * alpha).normalized()
	var fired := 0
	for j in rig.get("rcs", []):
		var quad: Node3D = j["node"]
		if not is_instance_valid(quad):
			continue
		var lever := ship.to_local(quad.global_position) - centre_local
		# Fire across the lever, the way that pushes the turn: a jet pushes against
		# where it points, so its torque is lever x -out.
		var out := -want.cross(lever)
		if out.length() < 0.2:
			continue
		fire(quad.global_position, ship.global_basis * out.normalized(), size)
		fired += 1
		if fired >= most:
			break
	return fired


func _place(p: Dictionary, u: float) -> void:
	var node: MeshInstance3D = p["node"]
	var d: Vector3 = p["dir"]
	# The cone's narrow top at the nozzle, flaring out along d; it lengthens as the
	# gas leaves and thins away.
	var length := float(p["size"]) * (0.6 + 1.6 * minf(u * 3.0, 1.0))
	var y := -d
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	node.basis = Basis(x, y, z) * Basis.from_scale(Vector3(1.0 + u, length, 1.0 + u))
	node.position = (p["at"] as Vector3) + d * length * 0.5
	node.set_instance_shader_parameter("fade", clampf(u, 0.0, 1.0))
	var flash: MeshInstance3D = p["flash"]
	flash.visible = u < 0.25
	flash.transparency = clampf(u * 4.0, 0.0, 1.0)


func _free(p: Dictionary) -> void:
	for key in ["node", "flash"]:
		if is_instance_valid(p[key]):
			p[key].queue_free()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

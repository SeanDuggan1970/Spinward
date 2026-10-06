## Placeholder kit-bash parts in the workmanlike style: trusses, cages, foil tanks,
## radiator panels, hazard stripes and working lights. Everything is built from
## primitive meshes so art can later replace parts one by one without code changes.
extends RefCounted

const COLOURS := {
	"offwhite": Color("d9d4c7"), "grey": Color("8c9196"), "dark": Color("2b2f33"),
	"yellow": Color("d8b02a"), "rust": Color("9a5a3a"), "orange": Color("d2702c"),
	"foil": Color("c9a24a"), "steel": Color("6d7378"), "black": Color("161718"),
}

## Default finish for each named colour: [finish, roughness, metallic, mismatch].
## Finishes: 0 painted plate, 1 bare metal, 2 foil blanket (view/shaders/hull.gdshader).
const FINISHES := {
	"foil": [2, 0.35, 0.85, 0.0], "steel": [1, 0.5, 0.6, 0.0], "black": [0, 0.85, 0.0, 0.0],
	"dark": [0, 0.75, 0.1, 0.04],
}

const HULL_SHADER := "res://view/shaders/hull.gdshader"

static var _materials: Dictionary = {}


## The house finish in a named colour, panelled and moderately worn.
static func mat(name: String) -> ShaderMaterial:
	if _materials.has(name):
		return _materials[name]
	var f: Array = FINISHES.get(name, [0, 0.8, 0.0, 0.1])
	var m := paint(COLOURS.get(name, Color.MAGENTA), {"finish": f[0], "roughness": f[1], "metallic": f[2], "mismatch": f[3]})
	_materials[name] = m
	return m


## A hull finish. opts: finish (0 paint, 1 metal, 2 foil), wear 0-1, mismatch (share of
## replacement panels), patch (their colour), panel_m, seed, roughness, metallic.
static func paint(colour: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(HULL_SHADER)
	m.set_shader_parameter("paint", colour)
	m.set_shader_parameter("finish", int(opts.get("finish", 0)))
	m.set_shader_parameter("wear", float(opts.get("wear", 0.4)))
	m.set_shader_parameter("mismatch", float(opts.get("mismatch", 0.1)))
	m.set_shader_parameter("patch_colour", opts.get("patch", Color("8c9196")))
	m.set_shader_parameter("panel_m", float(opts.get("panel_m", 1.6)))
	m.set_shader_parameter("seed", float(opts.get("seed", 0.0)))
	m.set_shader_parameter("roughness", float(opts.get("roughness", 0.8)))
	m.set_shader_parameter("metallic", float(opts.get("metallic", 0.0)))
	return m


## The same finish with panels wrapped for a round part (1 cylinder, 2 sphere).
## Variants are kept on the material so each is made once.
static func _wrapped(material: Material, mapping: int) -> Material:
	var sm := material as ShaderMaterial
	if sm == null or sm.shader == null or sm.shader.resource_path != HULL_SHADER:
		return material
	var key := "wrap_%d" % mapping
	if sm.has_meta(key):
		return sm.get_meta(key)
	var w := sm.duplicate() as ShaderMaterial
	w.set_shader_parameter("mapping", mapping)
	sm.set_meta(key, w)
	return w


static func glow(colour: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Window glass: dark and glossy outside, a little warm light from within.
static func glass(warmth: float = 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("0c1218")
	m.metallic = 0.4
	m.roughness = 0.06
	m.emission_enabled = true
	m.emission = Color("ffcf8a")
	m.emission_energy_multiplier = warmth
	return m


static func box(size: Vector3, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	return mi


## Cylinder along Z.
static func cylinder(radius: float, length: float, material: Material, at: Vector3 = Vector3.ZERO, sides: int = 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = sides
	mi.mesh = mesh
	mi.material_override = _wrapped(material, 1)
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = at
	return mi


## Cone or frustum along Z: r_top at +Z, r_bottom at -Z.
static func cone(r_top: float, r_bottom: float, length: float, material: Material, at: Vector3, sides: int = 20) -> MeshInstance3D:
	var mi := cylinder(r_top, length, material, at, sides)
	(mi.mesh as CylinderMesh).bottom_radius = r_bottom
	return mi


static func sphere(radius: float, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = _wrapped(material, 2)
	mi.position = at
	return mi


## Torus around the Z axis.
static func torus(radius: float, tube: float, material: Material, at: Vector3 = Vector3.ZERO, segments: int = 64) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	# TorusMesh: "rings" slice the main circle, "ring_segments" go round the tube.
	mesh.rings = segments
	mesh.ring_segments = 14
	mi.mesh = mesh
	mi.material_override = material
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = at
	return mi


## A surface of revolution about Z, for bells, coil housings and anything else turned
## on a lathe. `strips` is an Array of PackedVector2Array profiles, each point
## (radius, z); a strip is smooth along its length, and a new strip starting where the
## last ended makes a hard edge (a lip, a flange). A profile's front faces the right of
## its direction of travel in the (radius, z) plane: walking aft (+z) along an outer
## wall faces outward, walking forward along an inner wall faces the axis. So a closed
## profile, outer wall aft then inner wall forward, is a solid shell with real
## thickness. UV.x runs round (0 to 1), UV.y is the profile's z, in metres.
static func lathe(strips: Array, material: Material, sides: int = 24, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var ring := []
	for k in sides + 1:
		var a := TAU * float(k) / float(sides)
		ring.append(Vector2(cos(a), sin(a)))
	for strip in strips:
		var p: PackedVector2Array = strip
		var count := p.size()
		if count < 2:
			continue
		# Profile normals: each segment's, averaged where segments meet.
		var seg_n := []
		for i in count - 1:
			var t := (p[i + 1] - p[i]).normalized()
			seg_n.append(Vector2(t.y, -t.x))
		var base := verts.size()
		for i in count:
			var a: Vector2 = seg_n[maxi(i - 1, 0)]
			var b: Vector2 = seg_n[mini(i, count - 2)]
			var nn := (a + b).normalized() if (a + b).length() > 1e-4 else b
			for k in sides + 1:
				var c: Vector2 = ring[k]
				verts.append(Vector3(p[i].x * c.x, p[i].x * c.y, p[i].y))
				norms.append(Vector3(nn.x * c.x, nn.x * c.y, nn.y).normalized())
				uvs.append(Vector2(float(k) / float(sides), p[i].y))
		# Wind every quad the same way; which way follows from the profile's direction
		# (Godot's front faces wind clockwise seen from the front).
		var flip := false
		for i in count - 1:
			var v0 := verts[base + i * (sides + 1)]
			var v1 := verts[base + (i + 1) * (sides + 1)]
			var v2 := verts[base + (i + 1) * (sides + 1) + 1]
			var v3 := verts[base + i * (sides + 1) + 1]
			var face := (v1 - v0).cross(v2 - v0) + (v2 - v0).cross(v3 - v0)
			if face.length_squared() > 1e-12:
				flip = face.dot(norms[base + i * (sides + 1)] + norms[base + (i + 1) * (sides + 1)]) > 0.0
				break
		for i in count - 1:
			for k in sides:
				var i0 := base + i * (sides + 1) + k
				var i1 := i0 + sides + 1
				if flip:
					idx.append_array([i0, i1 + 1, i1, i0, i0 + 1, i1 + 1])
				else:
					idx.append_array([i0, i1, i1 + 1, i0, i1 + 1, i0 + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = at
	return mi


## Open square truss along Z: four longerons with cross frames.
static func truss(length: float, width: float, material: Material, at: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = at
	var h := width * 0.5
	var bar := width * 0.08
	for c in [Vector2(h, h), Vector2(-h, h), Vector2(h, -h), Vector2(-h, -h)]:
		n.add_child(box(Vector3(bar, bar, length), material, Vector3(c.x, c.y, 0)))
	var frames := int(length / maxf(width, 0.5))
	for i in frames + 1:
		var z := -length * 0.5 + length * float(i) / float(maxi(frames, 1))
		n.add_child(box(Vector3(width, bar, bar), material, Vector3(0, h, z)))
		n.add_child(box(Vector3(width, bar, bar), material, Vector3(0, -h, z)))
		n.add_child(box(Vector3(bar, width, bar), material, Vector3(h, 0, z)))
		n.add_child(box(Vector3(bar, width, bar), material, Vector3(-h, 0, z)))
	return n


## Black-and-yellow hazard band wrapped around a cylinder along Z.
static func hazard_band(radius: float, width: float, at: Vector3, stripes: int = 16) -> Node3D:
	var n := Node3D.new()
	n.position = at
	for i in stripes:
		var a := TAU * float(i) / float(stripes)
		var piece := box(Vector3(radius * TAU / stripes * 1.02, 0.12, width), mat("yellow" if i % 2 == 0 else "black"))
		piece.position = Vector3(cos(a) * radius, sin(a) * radius, 0)
		piece.rotation = Vector3(0, 0, a + PI * 0.5)
		n.add_child(piece)
	return n


## A working light: emissive bulb, optionally blinking (period seconds, phase 0-1).
static func beacon(colour: Color, at: Vector3, radius: float = 0.35, period: float = 0.0, phase: float = 0.0) -> MeshInstance3D:
	var b := sphere(radius, glow(colour, 3.0), at)
	if period > 0.0:
		b.set_meta("blink_period", period)
		b.set_meta("blink_phase", phase)
	return b


## Collect blinking lights once; scanning the whole scene every frame is too slow.
static func collect_blinkers(root: Node) -> Array:
	return root.find_children("*", "MeshInstance3D", true, false).filter(func(b): return b.has_meta("blink_period"))


static func update_blinkers(blinkers: Array, t: float) -> void:
	for b in blinkers:
		if is_instance_valid(b):
			b.visible = fposmod(t / float(b.get_meta("blink_period")) + float(b.get_meta("blink_phase")), 1.0) < 0.18


## Merge a model's static meshes that share a material into one mesh each, so a ship
## of hundreds of parts costs a handful of draw calls. Leaves alone anything that
## blinks, is hidden, has children, sits under a node named DrivePlume, or wraps its
## panels round its own axis (wrapped finishes rely on the part's own local space).
static func merge_static(root: Node3D) -> void:
	var groups := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.get_child_count() > 0 or mi.has_meta("blink_period") or not mi.visible or mi.mesh == null:
			continue
		var mat := mi.material_override
		if mat == null:
			continue
		if mat is ShaderMaterial:
			var mapping = (mat as ShaderMaterial).get_shader_parameter("mapping")
			if mapping != null and int(mapping) != 0:
				continue
		var xform := Transform3D.IDENTITY
		var n: Node = mi
		var skip := false
		while n != root and n != null:
			if n.name == "DrivePlume" or n.has_meta("no_merge"):
				skip = true
				break
			xform = (n as Node3D).transform * xform
			n = n.get_parent()
		if skip:
			continue
		if not groups.has(mat):
			groups[mat] = []
		groups[mat].append([mi, xform])
	for mat in groups:
		var list: Array = groups[mat]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		for entry in list:
			st.append_from(entry[0].mesh, 0, entry[1])
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = mat
		root.add_child(merged)
		for entry in list:
			entry[0].get_parent().remove_child(entry[0])
			entry[0].free()

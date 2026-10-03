## Placeholder kit-bash parts in the workmanlike style: trusses, cages, foil tanks,
## radiator panels, hazard stripes and working lights. Everything is built from
## primitive meshes so art can later replace parts one by one without code changes.
extends RefCounted

const COLOURS := {
	"offwhite": Color("d9d4c7"), "grey": Color("8c9196"), "dark": Color("2b2f33"),
	"yellow": Color("d8b02a"), "rust": Color("9a5a3a"), "orange": Color("d2702c"),
	"foil": Color("c9a24a"), "steel": Color("6d7378"), "black": Color("161718"),
}

static var _materials: Dictionary = {}


static func mat(name: String) -> StandardMaterial3D:
	if _materials.has(name):
		return _materials[name]
	var m := StandardMaterial3D.new()
	m.albedo_color = COLOURS.get(name, Color.MAGENTA)
	m.roughness = 0.85
	if name == "foil":
		m.metallic = 0.9
		m.roughness = 0.35
	elif name == "steel":
		m.metallic = 0.6
		m.roughness = 0.5
	_materials[name] = m
	return m


static func glow(colour: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	mi.material_override = material
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = at
	return mi


static func cone(r_top: float, r_bottom: float, length: float, material: Material, at: Vector3) -> MeshInstance3D:
	var mi := cylinder(r_top, length, material, at)
	(mi.mesh as CylinderMesh).bottom_radius = r_bottom
	return mi


static func sphere(radius: float, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = material
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


static func update_blinkers(root: Node, t: float) -> void:
	for b in root.find_children("*", "MeshInstance3D", true, false):
		if b.has_meta("blink_period"):
			var period: float = b.get_meta("blink_period")
			b.visible = fposmod(t / period + float(b.get_meta("blink_phase")), 1.0) < 0.18

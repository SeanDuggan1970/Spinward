## The title screen's belt shot: the hero threads the rocks and never flies through one.
## Flies many shots (a different hull and field each time) and checks every rock's
## true reach against the hull's reach, panels and all, at each moment.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const TitleScreen := preload("res://view/title_screen.gd")

const SHOTS := 40
const STEP_S := 0.05

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


## Furthest any vertex of a rock reaches from its centre, at any tumble.
func rock_reach(mi: MeshInstance3D) -> float:
	var r := 0.0
	for v in (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		r = maxf(r, v.length())
	return r


## Furthest any of the hero's meshes reaches from its origin, as it is posed now.
func hero_reach(hero: Node3D) -> float:
	var plume := hero.find_child("DrivePlume", true, false)
	var r := 0.0
	for m in hero.find_children("*", "MeshInstance3D", true, false):
		if plume and plume.is_ancestor_of(m):
			continue
		var xf: Transform3D = hero.global_transform.affine_inverse() * m.global_transform
		var box: AABB = m.get_aabb()
		for i in 8:
			r = maxf(r, (xf * box.get_endpoint(i)).length())
	return r


func _run() -> void:
	var title = TitleScreen.new(Sim.new().data, false)
	root.add_child(title)
	await process_frame
	title.set_process(false)
	title.force_shot = "belt"
	for shot in SHOTS:
		title.next_shot()
		var rocks := []
		for c in title._stage.get_children():
			if c is MeshInstance3D and c.mesh is ArrayMesh:
				rocks.append([c, rock_reach(c)])
		check(rocks.size() >= 7, "The belt shot has its rocks")
		var worst := INF
		title.clock = 0.0
		while title.clock < TitleScreen.SHOT_S:
			title._update.call(STEP_S)
			var hr := hero_reach(title._hero)
			for r in rocks:
				worst = minf(worst, (r[0].position - title._hero.position).length() - r[1] - hr)
			title.clock += STEP_S
		check(worst > 0.0, "A %s in the belt shot passes every rock clear (closest gap %.1f m)" % [title._hero_hull, worst])
	title.free()
	print("%d checks, %d failures (title belt view)" % [checks, failures])
	quit(1 if failures else 0)

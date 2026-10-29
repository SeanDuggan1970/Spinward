## The title screen's docking shot: the hero matches the station's spin before its
## nose reaches the bay, as a ship must in flight, and works its thrusters on the way.
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const TitleScreen := preload("res://view/title_screen.gd")

const SHOTS := 20
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


func plumes(stage: Node) -> int:
	var n := 0
	for m in stage.find_children("*", "MeshInstance3D", true, false):
		var mat = m.material_override
		if mat is ShaderMaterial and mat.shader and mat.shader.resource_path.ends_with("rcs_plume.gdshader"):
			n += 1
	return n


func _run() -> void:
	var sim := Sim.new()
	var max_err := float(sim.data.balance["docking"]["max_roll_error_deg"])
	var title = TitleScreen.new(sim.data, false)
	root.add_child(title)
	await process_frame
	title.set_process(false)
	title.force_shot = "docking"
	for shot in SHOTS:
		title.next_shot()
		title.clock = 0.0
		var worst := 0.0
		var puffs := 0
		var inside := false
		while title.clock < TitleScreen.SHOT_S - 1.0:
			title._update.call(STEP_S)
			var x: Vector3 = title._hero.basis.x
			var ship_angle := atan2(x.y, x.x)
			var spin: float = title._dock["rotor"].rotation.z
			var err := absf(rad_to_deg(wrapf(ship_angle - spin, -PI * 0.5, PI * 0.5)))
			var nose_z: float = title._hero.position.z + float(title._hero_model.get("nose_z", -title._hero_len * 0.5))
			if nose_z < float(title._dock["mouth"]) + 20.0:
				inside = true
				worst = maxf(worst, err)
			puffs = maxi(puffs, plumes(title._stage))
			title.clock += STEP_S
		check(inside, "A %s in the docking shot reaches the bay" % title._hero_hull)
		check(worst <= max_err * 0.25, "A %s in the docking shot holds the spin into the bay (worst key error %.1f°)" % [title._hero_hull, worst])
		check(puffs > 0, "A %s in the docking shot works its thrusters" % title._hero_hull)
	title.free()
	print("%d checks, %d failures (title docking view)" % [checks, failures])
	quit(1 if failures else 0)

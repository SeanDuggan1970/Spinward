## Headless sim tests: godot --headless --path . --script res://tests/run_tests.gd
extends SceneTree

const Sim := preload("res://sim/sim.gd")
const SaveIO := preload("res://sim/save_io.gd")
const GameState := preload("res://sim/game_state.gd")

var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func run_schedule(commands: Array) -> Dictionary:
	var sim := Sim.new()
	sim.new_game(42)
	for step in commands:
		if step is Dictionary:
			sim.apply(step)
		else:
			sim.tick(float(step))
	return sim.state.to_dict()


func _initialize() -> void:
	var sim := Sim.new()
	sim.new_game(7)
	check(sim.state.date_string() == "2061-03-01T00:00:00", "Start date from balance.json")
	check(sim.state.credits == 5000.0, "Start credits from balance.json")

	check(sim.apply({"type": "nonsense"}) != "", "Unknown command rejected")
	check(sim.apply({"type": "set_time_scale", "scale": 7}) != "", "Disallowed time scale rejected")
	check(sim.apply({"type": "set_time_scale", "scale": 1000}) == "", "Allowed time scale accepted")
	var before := sim.state.time_s
	sim.tick(2.0)
	check(is_equal_approx(sim.state.time_s - before, 2000.0), "Time compression scales the clock")

	sim.apply({"type": "set_paused", "paused": true})
	before = sim.state.time_s
	sim.tick(5.0)
	check(sim.state.time_s == before, "Paused clock does not move")
	check(sim.state.command_count == 2, "Only accepted commands are counted")
	var events := sim.take_events()
	check(events.size() == 3 and events[-1]["type"] == "paused_changed", "Events emitted for the view")
	check(sim.take_events().is_empty(), "Events drain once")

	var text := SaveIO.to_text(sim.state)
	var loaded := SaveIO.from_text(text)
	check(loaded != null and loaded.to_dict() == sim.state.to_dict(), "Save round-trip is lossless")
	check(SaveIO.from_text("{\"schema_version\": 999}") == null, "Future save version refused")
	check(SaveIO.from_text("not json") == null, "Corrupt save refused")

	var schedule := [{"type": "set_time_scale", "scale": 100}, 1.5, {"type": "set_paused", "paused": true}, 3.0,
		{"type": "set_paused", "paused": false}, 0.25]
	check(run_schedule(schedule) == run_schedule(schedule), "Same seed and commands give the same state")

	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

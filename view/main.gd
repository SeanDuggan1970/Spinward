## M0 placeholder screen: shows the game clock and drives it through commands.
## Space toggles pause; [ and ] change time compression.
extends Control

const Sim := preload("res://sim/sim.gd")

var sim: Sim
@onready var _date: Label = %Date
@onready var _status: Label = %Status


func _ready() -> void:
	sim = Sim.new()
	sim.new_game(1)
	if "--smoke" in OS.get_cmdline_user_args():
		_process(0.016)
		print("SMOKE_OK ", sim.state.date_string())
		get_tree().quit(0)


func _process(delta: float) -> void:
	sim.tick(delta)
	sim.take_events()
	_date.text = sim.state.date_string().replace("T", "  ") + " UTC"
	_status.text = "%s   ×%d   %d credits" % [
		"PAUSED" if sim.state.paused else "RUNNING", int(sim.state.time_scale), int(sim.state.credits)]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_SPACE:
			sim.apply({"type": "set_paused", "paused": not sim.state.paused})
		KEY_BRACKETRIGHT, KEY_BRACKETLEFT:
			var scales: Array = sim.data.balance["time"]["scales"]
			var i := scales.find(sim.state.time_scale) + (1 if event.keycode == KEY_BRACKETRIGHT else -1)
			sim.apply({"type": "set_time_scale", "scale": scales[clampi(i, 0, scales.size() - 1)]})

## The control bindings: one source of truth for every gameplay control.
## Actions and their default keyboard and gamepad bindings come from data/controls.json;
## the player's changes sit on top, are saved in user://settings.cfg, and the result is
## built into Godot's InputMap, so views just ask "is_action_pressed". Views never name a key.
##
## A binding is a spec string: "key:W" (a physical key), "pad:a" (a button) or "pad:lx-"
## (an axis pushed one way). An action has a list of keyboard specs and a list of gamepad
## specs, and a rebind replaces the list for whichever kind was pressed.
extends RefCounted

const SETTINGS := "user://settings.cfg"
const SECTION := "controls"
const VERSION := 1

const PAD_BUTTONS := {
	"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X, "y": JOY_BUTTON_Y,
	"lb": JOY_BUTTON_LEFT_SHOULDER, "rb": JOY_BUTTON_RIGHT_SHOULDER,
	"back": JOY_BUTTON_BACK, "start": JOY_BUTTON_START,
	"lstick": JOY_BUTTON_LEFT_STICK, "rstick": JOY_BUTTON_RIGHT_STICK,
	"dpad_up": JOY_BUTTON_DPAD_UP, "dpad_down": JOY_BUTTON_DPAD_DOWN,
	"dpad_left": JOY_BUTTON_DPAD_LEFT, "dpad_right": JOY_BUTTON_DPAD_RIGHT,
}
const PAD_AXES := {
	"lx": JOY_AXIS_LEFT_X, "ly": JOY_AXIS_LEFT_Y, "rx": JOY_AXIS_RIGHT_X, "ry": JOY_AXIS_RIGHT_Y,
	"lt": JOY_AXIS_TRIGGER_LEFT, "rt": JOY_AXIS_TRIGGER_RIGHT,
}
const PAD_TEXT := {
	"a": "A", "b": "B", "x": "X", "y": "Y", "lb": "LB", "rb": "RB", "back": "Back", "start": "Start",
	"lstick": "L-Stick click", "rstick": "R-Stick click",
	"dpad_up": "D-pad up", "dpad_down": "D-pad down", "dpad_left": "D-pad left", "dpad_right": "D-pad right",
	"lx-": "L-Stick left", "lx+": "L-Stick right", "ly-": "L-Stick up", "ly+": "L-Stick down",
	"rx-": "R-Stick left", "rx+": "R-Stick right", "ry-": "R-Stick up", "ry+": "R-Stick down",
	"lt+": "LT", "rt+": "RT", "lt-": "LT (pull back)", "rt-": "RT (pull back)",
}
const KEY_TEXT := {"BracketLeft": "[", "BracketRight": "]", "Escape": "Esc", "Kp Enter": "Num Enter"}

## The bindings the game is running with (set by install); views read key hints from it.
static var current

## id -> {id, label, scope, key: [specs], pad: [specs]}: the defaults from data.
var actions: Dictionary = {}
## The sections as the controls page shows them: {id, name, when, rows: [{action} | {text}, label]}.
var sections: Array = []
## id -> {"key": [...], "pad": [...]}: only what differs from the defaults.
var overrides: Dictionary = {}
var stick_deadzone := 0.25
var trigger_deadzone := 0.1
var capture_threshold := 0.6
var reserved := {"key": [], "pad": []}


func _init(catalog: Dictionary = {}) -> void:
	var pad: Dictionary = catalog.get("gamepad", {})
	stick_deadzone = float(pad.get("deadzone", stick_deadzone))
	trigger_deadzone = float(pad.get("trigger_deadzone", trigger_deadzone))
	capture_threshold = float(pad.get("capture_threshold", capture_threshold))
	var res: Dictionary = catalog.get("reserved", {})
	for kind in ["key", "pad"]:
		for name in res.get(kind, []):
			reserved[kind].append("%s:%s" % [kind, name])
	for section in catalog.get("sections", []):
		sections.append(section)
		for row in section.get("rows", []):
			if not row.has("action"):
				continue
			var entry := {"id": String(row["action"]), "label": String(row.get("label", row["action"])),
				"scope": String(section.get("id", "")), "key": [], "pad": []}
			for kind in ["key", "pad"]:
				for name in row.get(kind, []):
					entry[kind].append(canonical("%s:%s" % [kind, name]))
			actions[entry["id"]] = entry


## Load the saved changes and build the InputMap; what main calls once at startup.
static func install(catalog: Dictionary, path: String = SETTINGS):
	var b = new(catalog)
	b.load_file(path)
	b.apply()
	current = b
	return b


# --- Specs and events -------------------------------------------------------------------

static func kind_of(spec: String) -> String:
	return spec.get_slice(":", 0)


## A key spec under the name the engine gives that key ("KP Enter" is "Kp Enter"), so a spec
## read from data, a file or a key press always compares equal.
static func canonical(spec: String) -> String:
	if kind_of(spec) == "key":
		var code := OS.find_keycode_from_string(spec.substr(4))
		if code != KEY_NONE:
			return "key:" + OS.get_keycode_string(code)
	return spec


static func is_valid(spec: String) -> bool:
	return event_for(spec) != null


## The InputEvent a spec stands for, or null if it is not a real binding.
static func event_for(spec: String) -> InputEvent:
	var body := spec.substr(spec.find(":") + 1)
	match kind_of(spec):
		"key":
			var code := OS.find_keycode_from_string(body)
			if code == KEY_NONE:
				return null
			var ke := InputEventKey.new()
			ke.physical_keycode = code
			return ke
		"pad":
			if PAD_BUTTONS.has(body):
				var jb := InputEventJoypadButton.new()
				jb.device = -1
				jb.button_index = PAD_BUTTONS[body]
				return jb
			if body.length() >= 3 and body[-1] in ["+", "-"] and PAD_AXES.has(body.left(-1)):
				var jm := InputEventJoypadMotion.new()
				jm.device = -1
				jm.axis = PAD_AXES[body.left(-1)]
				jm.axis_value = 1.0 if body[-1] == "+" else -1.0
				return jm
	return null


## The spec for a pressed key, button or pushed stick; "" for anything else (or a stick
## not pushed far enough to mean it).
func spec_of(event: InputEvent, threshold: float = -1.0) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return "key:" + OS.get_keycode_string(code) if code != KEY_NONE else ""
	if event is InputEventJoypadButton and event.pressed:
		for name in PAD_BUTTONS:
			if PAD_BUTTONS[name] == event.button_index:
				return "pad:" + name
	if event is InputEventJoypadMotion and absf(event.axis_value) >= (capture_threshold if threshold < 0.0 else threshold):
		for name in PAD_AXES:
			if PAD_AXES[name] == event.axis:
				return "pad:%s%s" % [name, "+" if event.axis_value > 0.0 else "-"]
	return ""


## What a spec reads like on screen.
static func spec_text(spec: String) -> String:
	var body := spec.substr(spec.find(":") + 1)
	if kind_of(spec) == "pad":
		return PAD_TEXT.get(body, body)
	var code := OS.find_keycode_from_string(body)
	var name := OS.get_keycode_string(code) if code != KEY_NONE else body
	return KEY_TEXT.get(name, name)


# --- Reading ----------------------------------------------------------------------------

func specs(id: String, kind: String) -> Array:
	if overrides.has(id) and overrides[id].has(kind):
		return overrides[id][kind]
	return actions[id][kind] if actions.has(id) else []


func text(id: String, kind: String) -> String:
	var parts := PackedStringArray()
	for s in specs(id, kind):
		parts.append(spec_text(s))
	return " / ".join(parts) if not parts.is_empty() else "unbound"


## A short hint for on-screen text: the first key, and the first pad button if a pad is plugged in.
func hint(id: String) -> String:
	var out := ""
	var keys := specs(id, "key")
	var pad := specs(id, "pad")
	if not keys.is_empty():
		out = spec_text(keys[0])
	if not pad.is_empty() and (out == "" or not Input.get_connected_joypads().is_empty()):
		out += ("  /  " if out != "" else "") + spec_text(pad[0])
	return out if out != "" else "unbound"


## Hint for on-screen text from whatever is installed ("?" if nothing is, as in a bare test).
static func hint_of(id: String) -> String:
	return current.hint(id) if current != null else "?"


## Just the first key, for the small labels on the cockpit panels.
static func key_of(id: String) -> String:
	if current == null or current.specs(id, "key").is_empty():
		return hint_of(id)
	return spec_text(current.specs(id, "key")[0])


func is_changed(id: String) -> bool:
	return overrides.has(id)


func has_changes() -> bool:
	return not overrides.is_empty()


static func scopes_overlap(a: String, b: String) -> bool:
	return a == b or a == "global" or b == "global"


## Other actions that would clash with `spec` on `id`: same kind of binding, same screen.
func clashes(id: String, spec: String, defaults: bool = false) -> Array:
	var out := []
	var kind := kind_of(spec)
	for other in actions:
		if other != id and scopes_overlap(actions[other]["scope"], actions[id]["scope"]) and spec in (actions[other][kind] if defaults else specs(other, kind)):
			out.append(other)
	return out


# --- Changing ---------------------------------------------------------------------------

func _set_list(id: String, kind: String, list: Array) -> void:
	if list == actions[id][kind]:
		if overrides.has(id):
			overrides[id].erase(kind)
			if overrides[id].is_empty():
				overrides.erase(id)
		return
	if not overrides.has(id):
		overrides[id] = {}
	overrides[id][kind] = list


## Bind `spec` to `id`, replacing that action's bindings of the same kind. If another action
## on the same screen has it, the two swap: that one takes what this one had. Refused (and
## nothing changes) for a reserved key, or if the swap would clash somewhere else.
## Returns {"ok": bool, "message": String, "swapped": Array of action ids}.
func rebind(id: String, spec: String) -> Dictionary:
	if not actions.has(id) or not is_valid(spec):
		return {"ok": false, "message": "Not a binding.", "swapped": []}
	var kind := kind_of(spec)
	var name: String = actions[id]["label"]
	if spec in reserved[kind]:
		return {"ok": false, "message": "Refused: %s is kept for the controls page itself." % spec_text(spec), "swapped": []}
	var old := specs(id, kind).duplicate()
	if old == [spec]:
		return {"ok": true, "message": "%s is already on %s." % [spec_text(spec), name], "swapped": []}
	var others := clashes(id, spec)
	# Check the swap before doing it: what this action gives up must fit where it goes.
	for other in others:
		for s in old:
			if s != spec and not can_take(other, s, id):
				return {"ok": false, "message": "Refused: %s is used by %s, and %s could not take %s without a clash." % [
					spec_text(spec), actions[other]["label"], actions[other]["label"], spec_text(s)], "swapped": []}
	_set_list(id, kind, [spec])
	var swapped := []
	for other in others:
		var list := []
		for s in specs(other, kind):
			if s == spec:
				for o in old:
					if not o in list:
						list.append(o)
			elif not s in list:
				list.append(s)
		_set_list(other, kind, list)
		swapped.append(other)
	if swapped.is_empty():
		return {"ok": true, "message": "%s bound to %s." % [name, spec_text(spec)], "swapped": swapped}
	var other_name: String = actions[swapped[0]]["label"]
	var now := text(swapped[0], kind)
	return {"ok": true, "swapped": swapped, "message": "Swapped: %s now has %s." % [other_name, now] if now != "unbound" else "%s was on %s, and is now unbound." % [other_name, spec_text(spec)]}


## Whether `other` could take `spec` (moving off another action `giver`) without clashing.
func can_take(other: String, spec: String, giver: String) -> bool:
	for c in clashes(other, spec):
		if c != giver:
			return false
	return true


func clear(id: String, kind: String) -> void:
	if actions.has(id):
		_set_list(id, kind, [])


func reset_action(id: String) -> void:
	overrides.erase(id)


func reset_all() -> void:
	overrides.clear()


# --- Saving -----------------------------------------------------------------------------

func save(path: String = SETTINGS) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	if not overrides.is_empty():
		cfg.set_value(SECTION, "version", VERSION)
		for id in overrides:
			for kind in overrides[id]:
				cfg.set_value(SECTION, "%s.%s" % [id, kind], PackedStringArray(overrides[id][kind]))
	return cfg.save(path)


## Read the saved changes over the defaults. Unknown actions and bad specs are dropped.
## False if there was no file.
func load_file(path: String = SETTINGS) -> bool:
	overrides.clear()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(SECTION):
		return false
	for key in cfg.get_section_keys(SECTION):
		var id: String = key.get_slice(".", 0)
		var kind: String = key.get_slice(".", 1)
		var raw = cfg.get_value(SECTION, key)
		if not actions.has(id) or not kind in ["key", "pad"] or not (raw is PackedStringArray or raw is Array):
			continue
		var list := []
		for s in raw:
			if s is String and kind_of(s) == kind and is_valid(s) and not canonical(s) in list:
				list.append(canonical(s))
		_set_list(id, kind, list)
	return true


# --- InputMap ---------------------------------------------------------------------------

## Build every action into the InputMap from the current bindings.
func apply() -> void:
	for id in actions:
		if InputMap.has_action(id):
			InputMap.erase_action(id)
		var dead := _deadzone_for(id)
		InputMap.add_action(id, dead)
		for kind in ["key", "pad"]:
			for s in specs(id, kind):
				InputMap.action_add_event(id, event_for(s))


## Sticks get the stick deadzone; an action that only listens to triggers gets the trigger's.
func _deadzone_for(id: String) -> float:
	var dead := trigger_deadzone
	for s in specs(id, "pad"):
		var body: String = s.substr(4)
		if body.length() == 3 and body.left(2) not in ["lt", "rt"]:
			dead = stick_deadzone
	return dead


## Problems with the catalogue, for the tests: a spec that is not real, a repeated action,
## two actions on one screen with the same default.
func problems() -> Array:
	var out := []
	var seen := {}
	for section in sections:
		for row in section.get("rows", []):
			if row.has("action"):
				if seen.has(row["action"]):
					out.append("action %s listed twice" % row["action"])
				seen[row["action"]] = true
	for id in actions:
		for kind in ["key", "pad"]:
			for s in actions[id][kind]:
				if not is_valid(s):
					out.append("%s: %s is not a binding" % [id, s])
		for kind in ["key", "pad"]:
			for s in actions[id][kind]:
				for other in clashes(id, s, true):
					out.append("%s and %s both default to %s" % [id, other, s])
	return out


## The same check on what is bound now, which rebind() should always leave empty.
func conflicts() -> Array:
	var out := []
	for id in actions:
		for kind in ["key", "pad"]:
			for s in specs(id, kind):
				for other in clashes(id, s):
					out.append("%s and %s both have %s" % [id, other, s])
	return out

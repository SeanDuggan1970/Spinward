## Save/load of GameState with schema versioning.
##
## A save is a small readable JSON envelope (version and a summary for save-slot
## lists) around the state encoded with var_to_bytes. The binary payload keeps
## 64-bit floats exact: Godot's JSON and var_to_str both round some doubles, which
## would make a loaded game drift from the one that was saved.
##
## When GameState.SCHEMA_VERSION goes up, add a migration from the previous
## version to MIGRATIONS so older saves keep loading.
extends RefCounted

const GameState := preload("res://sim/game_state.gd")

## version -> Callable(Dictionary) -> Dictionary that upgrades to version + 1.
const MIGRATIONS := {}


static func to_text(state: GameState) -> String:
	var d := state.to_dict()
	return JSON.stringify({
		"schema_version": d["schema_version"],
		"summary": {"date": state.date_string(), "credits": int(state.credits), "location": state.location.get("place", state.location.get("to", ""))},
		"state": Marshalls.raw_to_base64(var_to_bytes(d)),
	}, "\t")


static func from_text(text: String) -> GameState:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var envelope: Dictionary = json.data
	if not envelope.get("state") is String:
		return null
	var d = bytes_to_var(Marshalls.base64_to_raw(envelope["state"]))
	if not d is Dictionary:
		return null
	var version := int(d.get("schema_version", 0))
	while version < GameState.SCHEMA_VERSION:
		if not MIGRATIONS.has(version):
			return null
		d = MIGRATIONS[version].call(d)
		version += 1
	if version != GameState.SCHEMA_VERSION:
		return null
	var state := GameState.new()
	state.load_dict(d)
	return state


static func save(state: GameState, path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_text(state))
	return OK


static func load_file(path: String) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	return from_text(FileAccess.get_file_as_string(path))

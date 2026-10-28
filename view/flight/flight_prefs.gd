## The player's flight preferences, kept beside the controls in user://settings.cfg.
extends RefCounted

const SETTINGS := "user://settings.cfg"
const SECTION := "flight"


## Does the co-pilot fly the approach and dock (on unless the player turned it off)?
static func copilot_docks(path := SETTINGS) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return true
	return bool(cfg.get_value(SECTION, "copilot_docks", true))


static func set_copilot_docks(on: bool, path := SETTINGS) -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value(SECTION, "copilot_docks", on)
	return cfg.save(path)

## The whole serialisable game state. Systems read and write it; nothing else does.
## Times are seconds since J2000 (2000-01-01 12:00 TT, treated as UTC for display).
extends RefCounted

const SCHEMA_VERSION := 1
const J2000_UNIX := 946728000.0

var seed: int = 0
var time_s: float = 0.0
var time_scale: float = 1.0
var paused: bool = false
var credits: float = 0.0
var command_count: int = 0


static func from_unix(unix_seconds: float) -> float:
	return unix_seconds - J2000_UNIX


func date_string() -> String:
	return Time.get_datetime_string_from_unix_time(int(time_s + J2000_UNIX))


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"seed": seed,
		"time_s": time_s,
		"time_scale": time_scale,
		"paused": paused,
		"credits": credits,
		"command_count": command_count,
	}


func load_dict(d: Dictionary) -> void:
	seed = int(d.get("seed", 0))
	time_s = float(d.get("time_s", 0.0))
	time_scale = float(d.get("time_scale", 1.0))
	paused = bool(d.get("paused", false))
	credits = float(d.get("credits", 0.0))
	command_count = int(d.get("command_count", 0))

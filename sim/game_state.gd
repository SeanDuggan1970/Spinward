## The whole serialisable game state. Systems read and write it; nothing else does.
## Times are seconds since J2000 (2000-01-01 12:00 TT, treated as UTC for display).
## Positions are 64-bit [x, y, z] Arrays in metres (see v3.gd).
extends RefCounted

## Pre-release: no saves have shipped, so version 1 still grows freely. Once saves
## exist in players' hands, any change of meaning needs a bump and a migration.
const SCHEMA_VERSION := 1
const J2000_UNIX := 946728000.0

var seed: int = 0
var time_s: float = 0.0
var time_scale: float = 1.0
var paused: bool = false
var credits: float = 0.0
var command_count: int = 0

## {name, hull, modules: {slot: module_id}, cargo: {good: t}, cargo_paid: {good: credits}, fuel_t}
var ship: Dictionary = {}
## {status: "docked", place} | {status: "transit", from, to, depart_t, arrive_t, from_pos, to_pos, distance_m}
## | {status: "approach", place}
var location: Dictionary = {}
## {place_id: {good_id: stock_t}}
var markets: Dictionary = {}
## Game time up to which the economy has been integrated.
var economy_t: float = 0.0
var stats: Dictionary = {"trips": 0, "manual_docks": 0, "auto_docks": 0, "trade_profit": 0.0}


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
		"ship": ship.duplicate(true),
		"location": location.duplicate(true),
		"markets": markets.duplicate(true),
		"economy_t": economy_t,
		"stats": stats.duplicate(true),
	}


func load_dict(d: Dictionary) -> void:
	seed = int(d.get("seed", 0))
	time_s = float(d.get("time_s", 0.0))
	time_scale = float(d.get("time_scale", 1.0))
	paused = bool(d.get("paused", false))
	credits = float(d.get("credits", 0.0))
	command_count = int(d.get("command_count", 0))
	ship = d.get("ship", {}).duplicate(true)
	location = d.get("location", {}).duplicate(true)
	markets = d.get("markets", {}).duplicate(true)
	economy_t = float(d.get("economy_t", time_s))
	stats = d.get("stats", stats).duplicate(true)

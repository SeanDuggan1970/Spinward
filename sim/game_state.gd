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
var stats: Dictionary = {"trips": 0, "manual_docks": 0, "auto_docks": 0, "trade_profit": 0.0, "player_sold": {}, "player_bought": {}}
## NPC ships: [{id, fleet, name, ship, location, next_t, leg, trips}]. See npc_system.gd.
var npcs: Array = []
## Shared random generator state (sim randomness only; the view never draws from it).
var rng_state: int = 0
## Megaprojects: {id: {stage, delivered: {good: t}, player_t, player_total_t, done, seen}}.
var projects: Dictionary = {}
## Lasting changes to place flows from finished projects: {place: {produces_mult, consumes_mult}}.
var place_mods: Dictionary = {}
var project_t: float = 0.0
## Paid tips: [{id, broker, place, good, kind, price, t, expires_t, truthful, verified, ...}].
var tips: Array = []
## Per broker, how their tips have held up for this player: {broker: {good, bad}}.
var broker_record: Dictionary = {}
## The player's own (ageing) price knowledge: {place: {t, prices: {good: [buy, sell]}}}.
var knowledge: Dictionary = {}
var tip_seq: int = 0
## Courier contracts: {board: {place: [offer]}, next_t: {place: t}, active: [job],
## history: [job], seq, last_dock}. See contract_system.gd.
var contracts: Dictionary = {}
## Standing with each operator: {operator: score}. Tiers in data/contracts.json.
var reputation: Dictionary = {}
## The quiet arc: {done: [beat], fired: {beat: {t, offer}}, messages: [{t, from, text}]}.
var story: Dictionary = {}
## Sites: {known: [id], worked: {site: [activity]}, work: {site, activity, start_t, end_t}}.
var sites: Dictionary = {}
## Perks earned by backing projects (sim/perks.gd).
var perks: Dictionary = {}
## When this game began (projects reveal so many days in).
var started_t: float = 0.0
## The Spaceline news feed: {items, posted, projects, ships, seq}.
var news: Dictionary = {}


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
		"npcs": npcs.duplicate(true),
		"rng_state": rng_state,
		"projects": projects.duplicate(true),
		"place_mods": place_mods.duplicate(true),
		"project_t": project_t,
		"tips": tips.duplicate(true),
		"broker_record": broker_record.duplicate(true),
		"knowledge": knowledge.duplicate(true),
		"tip_seq": tip_seq,
		"contracts": contracts.duplicate(true),
		"reputation": reputation.duplicate(true),
		"perks": perks.duplicate(true),
		"sites": sites.duplicate(true),
		"story": story.duplicate(true),
		"started_t": started_t,
		"news": news.duplicate(true),
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
	npcs = d.get("npcs", []).duplicate(true)
	rng_state = int(d.get("rng_state", 0))
	projects = d.get("projects", {}).duplicate(true)
	place_mods = d.get("place_mods", {}).duplicate(true)
	project_t = float(d.get("project_t", time_s))
	tips = d.get("tips", []).duplicate(true)
	broker_record = d.get("broker_record", {}).duplicate(true)
	knowledge = d.get("knowledge", {}).duplicate(true)
	tip_seq = int(d.get("tip_seq", 0))
	contracts = d.get("contracts", {}).duplicate(true)
	reputation = d.get("reputation", {}).duplicate(true)
	perks = d.get("perks", {}).duplicate(true)
	sites = d.get("sites", {}).duplicate(true)
	story = d.get("story", {}).duplicate(true)
	started_t = float(d.get("started_t", time_s))
	news = d.get("news", {}).duplicate(true)

## Loads content and balance from data/. The sim reads rules only from here.
extends RefCounted

const DATA_ROOT := "res://data"

var balance: Dictionary = {}


static func load_default():
	var catalog = load("res://sim/data_catalog.gd").new()
	catalog.balance = catalog.read_json(DATA_ROOT + "/balance.json")
	return catalog


func read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	assert(parsed is Dictionary, "Invalid or missing data file: " + path)
	return parsed

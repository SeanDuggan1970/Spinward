## Times every test_ function of tests/run_tests.gd on its own, to find what is slow:
##   godot --headless --path . --script res://tools/time_tests.gd
## Set ONLY=test_a,test_b to run a few. Prints "TIME <name> <ms>" and a total.
extends "res://tests/run_tests.gd"


func _initialize() -> void:
	var only := OS.get_environment("ONLY")
	var total := 0
	for m in get_script().get_base_script().get_script_method_list():
		var n: String = m["name"]
		if not n.begins_with("test_") or (only != "" and not n in only.split(",")):
			continue
		var t := Time.get_ticks_msec()
		call(n)
		total += Time.get_ticks_msec() - t
		print("TIME %s %d" % [n, Time.get_ticks_msec() - t])
	print("TIME TOTAL %d" % total)
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

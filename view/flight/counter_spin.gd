## Turns the other way to a lead node: the twin of a counter-rotating pair (Concord)
## follows whatever spin a view gives the station's rotor, mirrored, so the pair's
## angular momentum cancels as it would on the real thing.
extends Node3D

var lead: Node3D


func _process(_dt: float) -> void:
	if is_instance_valid(lead):
		rotation.z = -lead.rotation.z

extends Node
## One actual damage event at a chosen physics priority, for tick-order checks.
var receiver: Node

func _physics_process(_delta: float) -> void:
	receiver.take_damage(10000.0)
	set_physics_process(false)
	queue_free()

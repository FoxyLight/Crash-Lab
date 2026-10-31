extends "res://scripts/arena.gd"
## Separate open arena; no training-course actors are instantiated here.
func _ready() -> void:
	_block("Ground", Vector3(160, 1, 160), Vector3(0, -0.5, 0), Color("343e47"))
	for side in [-1.0, 1.0]:
		_block("Boundary", Vector3(1, 3, 160), Vector3(side * 80, 1.5, 0), Color("778591"))
		_block("Boundary", Vector3(160, 3, 1), Vector3(0, 1.5, side * 80), Color("778591"))
	_block("Cover", Vector3(5, 3, 6), Vector3(-8, 1.5, -5), Color("617c85"))
	_block("Cover", Vector3(6, 3, 4), Vector3(18, 1.5, 15), Color("617c85"))
	_block("Cover", Vector3(5, 3, 5), Vector3(-38, 1.5, -32), Color("617c85"))
	_label("CRASH LAB / DUEL", Vector3(0, 0.04, 45))
	var manager := _destruction_manager()
	# Mirrored placements keep both human starts equally clear.
	for side in [-1.0, 1.0]:
		_prop(manager, "breakable_crate", Vector3(side * 42, 0.9, side * 18))
		_prop(manager, "breakable_crate", Vector3(side * 60, 0.9, side * 25))
		_prop(manager, "destructible_barrier", Vector3(0, 1.2, side * 20))
	_prop(manager, "energy_canister", Vector3(0, 1.1, 0))

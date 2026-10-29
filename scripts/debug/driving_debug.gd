extends CanvasLayer
@export var vehicle: RigidBody3D
@onready var readout: Label = $Panel/Margin/Readout

func _process(_delta: float) -> void:
	var direction := "STOPPED"
	if vehicle.signed_speed > 0.5:
		direction = "FORWARD"
	elif vehicle.signed_speed < -0.5:
		direction = "REVERSE"
	readout.text = "CRASH LAB  /  v0.2\n%03d km/h  |  %s\nHandbrake: %s  |  Grounded: %d/4\n\nW / S  Accelerate / Brake / Reverse\nA / D  Steer     SPACE  Handbrake     R  Reset\nController: triggers / left stick / A / D-pad up\n\nBLASTER  /  Unlimited ammo\nHold LMB / F / Right shoulder to fire\nShoots straight from the front barrel\nFiring range: far right lane" % [vehicle.linear_velocity.length() * 3.6, direction, "ON" if vehicle.driver.handbrake else "OFF", vehicle.grounded_wheels]

extends Area3D
## Projectile-only body/roof coverage; never participates in physical contacts.
func take_damage(amount: float) -> void:
	get_parent().get_node("DamageReceiver").take_damage(amount)

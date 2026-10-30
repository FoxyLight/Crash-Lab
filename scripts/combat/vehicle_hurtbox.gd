extends Area3D
## Projectile-only body/roof coverage; never participates in physical contacts.
func take_damage(amount: float) -> void:
	get_parent().get_node("DamageReceiver").take_damage(amount)

func take_damage_from(amount: float, source: Node) -> void:
	get_parent().get_node("DamageReceiver").take_damage_from(amount, source)

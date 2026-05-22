class_name Hurtbox
extends Area2D

## Componente defensivo reutilizável.
## Recebe hits de Hitboxes e repassa o evento pra entidade dona via signal hit_taken.

signal hit_taken(hitbox: Hitbox)

func _ready() -> void:
	monitorable = true
	monitoring = false

func take_hit(hitbox: Hitbox) -> void:
	hit_taken.emit(hitbox)

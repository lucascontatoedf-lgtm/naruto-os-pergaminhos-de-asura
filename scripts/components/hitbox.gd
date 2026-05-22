class_name Hitbox
extends Area2D

## Componente ofensivo reutilizável.
## Desativada por default — chame enable() no início do ataque e disable() ao final.
## Ao colidir com uma Hurtbox, dispara take_hit() nela e emite hit_landed.

@export var damage: int = 1

signal hit_landed(hurtbox: Hurtbox)

func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

func enable() -> void:
	monitoring = true

func disable() -> void:
	monitoring = false

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		var hurtbox: Hurtbox = area
		hurtbox.take_hit(self)
		hit_landed.emit(hurtbox)

class_name Dummy
extends StaticBody2D

## Boneco de testes — alvo para validar o pipeline Hitbox → Hurtbox → damage.
## Recebe hits, flasha branco, atualiza barra de HP, "morre" e respawna após delay.

@export var max_health: int = 3
@export var respawn_delay: float = 1.0
@export var hit_flash_duration: float = 0.15

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Polygon2D = $Visual
@onready var hp_fill: Polygon2D = $HPBar/Fill

var current_health: int = 0

signal damaged(amount: int, remaining: int)
signal died
signal respawned

func _ready() -> void:
	current_health = max_health
	hurtbox.hit_taken.connect(_on_hit_taken)
	_update_hp_visual()

func _on_hit_taken(hitbox: Hitbox) -> void:
	if current_health <= 0:
		return # já morto, ignora hits em sobreposição (belt-and-suspenders, hurtbox.monitorable já foi pra false)
	current_health = maxi(current_health - hitbox.damage, 0)
	damaged.emit(hitbox.damage, current_health)
	_update_hp_visual()
	_flash_hit()
	if current_health <= 0:
		_die()

func _flash_hit() -> void:
	visual.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate", Color(1, 1, 1, 1), hit_flash_duration)

func _update_hp_visual() -> void:
	var ratio: float = float(current_health) / float(max_health)
	hp_fill.scale.x = maxf(ratio, 0.001) # evita scale = 0 que faz Godot reclamar

func _die() -> void:
	died.emit()
	visible = false
	hurtbox.monitorable = false
	await get_tree().create_timer(respawn_delay).timeout
	current_health = max_health
	visible = true
	hurtbox.monitorable = true
	_update_hp_visual()
	respawned.emit()

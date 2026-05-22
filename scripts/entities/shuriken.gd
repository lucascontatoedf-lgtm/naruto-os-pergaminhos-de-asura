class_name Shuriken
extends Hitbox

## Projétil arremessável — ataque Heavy (J).
## Spawnado pelo Player; viaja em `direction` à `speed` px/s.
## Autodestrói após `max_travel_distance` px OU ao atingir uma Hurtbox.

@export var speed: float = 800.0
@export var max_travel_distance: float = 500.0
@export var spin_speed: float = 12.0  ## rad/s — puramente visual

var direction: Vector2 = Vector2.RIGHT  ## setado pelo spawner antes de adicionar à cena

var _distance_traveled: float = 0.0

func _ready() -> void:
	super._ready()  # Hitbox._ready: monitoring=false, monitorable=false, connect area_entered
	enable()  # projétil nasce ativo (caça Hurtboxes desde o frame zero)
	hit_landed.connect(_on_hit_landed)

func _physics_process(delta: float) -> void:
	rotation += spin_speed * delta
	var step: Vector2 = direction * speed * delta
	position += step
	_distance_traveled += step.length()
	if _distance_traveled >= max_travel_distance:
		queue_free()

func _on_hit_landed(_hurtbox: Hurtbox) -> void:
	queue_free()  # shuriken some ao atingir alvo

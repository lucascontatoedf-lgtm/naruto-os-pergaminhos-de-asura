class_name Shuriken
extends Hitbox

## Projétil arremessável — ataque Heavy (J).
## Spawnado pelo Player; viaja em `direction` à `speed` px/s.
## Autodestrói após `max_travel_distance` px OU ao atingir uma Hurtbox.

@export var speed: float = 800.0
@export var max_travel_distance: float = 500.0
@export var spin_speed: float = 12.0  ## rad/s — puramente visual

var direction: Vector2 = Vector2.RIGHT  ## setado pelo spawner antes de adicionar à cena
var wall_normal: int = 0  ## Override pra WALL_SLIDE do Player: != 0 ignora facing e usa wall_normal * -1 como direção X. Convenção do spawner: +1 = parede direita, -1 = parede esquerda. O *-1 inverte pra direção de SAÍDA (away from wall).

var _distance_traveled: float = 0.0

func _ready() -> void:
	super._ready()  # Hitbox._ready: monitoring=false, monitorable=false, connect area_entered
	# Override de direção pra WALL_SLIDE: spawner setou wall_normal != 0 indicando parede.
	# Convertemos pra direção de saída (oposto à parede) via *-1, ignorando facing setado antes.
	if wall_normal != 0:
		direction = Vector2(wall_normal * -1, 0)
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

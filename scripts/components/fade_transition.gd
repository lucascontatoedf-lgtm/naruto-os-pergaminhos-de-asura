class_name FadeTransition
extends CanvasLayer

## FadeTransition — componente genérico de fade out/in.
## Uso: instancia, add_child, chama fade(callback) pra executar a transição.

const DEFAULT_DURATION: float = 0.5
@export var duration: float = DEFAULT_DURATION

signal fade_completed

var _fade_rect: ColorRect

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

func fade(on_midpoint: Callable = Callable()) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, duration)
	if on_midpoint.is_valid():
		tw.tween_callback(on_midpoint)
	tw.tween_property(_fade_rect, "color:a", 0.0, duration)
	tw.tween_callback(func(): fade_completed.emit())

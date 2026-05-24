class_name KamuiTrigger
extends Node

## KamuiTrigger — escuta DialogueManager.kamui_triggered e executa a sequência
## visual de Kamui no fim do akatsuki_encontro:
##   1. Fade out preto (1s, ColorRect via Tween)
##   2. Teleporta player pra exit_position
##   3. Desativa colisor da entrada (entrance_collider) — impede re-entrada
##   4. Fade in (1s)
##   5. Inicia DialogueManager.start_dialogue("akatsuki_saida")
##
## INSTANCIAÇÃO: adicionar como nó filho da cena do esconderijo Akatsuki, com
## exit_position, entrance_collider e player setados no inspector. NÃO existe
## .tscn própria (spec: "script separado (não cena)") — script vira componente
## puro que cria seu próprio CanvasLayer de fade em runtime.

@export var exit_position: Vector2 = Vector2.ZERO
@export var entrance_collider: CollisionShape2D
@export var player: Node2D

const FADE_DURATION: float = 1.0

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	DialogueManager.kamui_triggered.connect(_on_kamui_triggered)
	_setup_fade_layer()

## Cria o CanvasLayer + ColorRect de fade em runtime. layer = 20 garante que
## fica ACIMA do DialogueBox (layer 10) e da HUD (layer 1) — escurece tudo.
func _setup_fade_layer() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 20
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # fade funciona mesmo com paused
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func _on_kamui_triggered() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, FADE_DURATION)
	tw.tween_callback(_teleport_and_close)
	tw.tween_property(_fade_rect, "color:a", 0.0, FADE_DURATION)
	tw.tween_callback(_start_saida_dialogue)

func _teleport_and_close() -> void:
	if player != null and is_instance_valid(player):
		player.global_position = exit_position
	if entrance_collider != null and is_instance_valid(entrance_collider):
		entrance_collider.disabled = true

func _start_saida_dialogue() -> void:
	DialogueManager.start_dialogue("akatsuki_saida")

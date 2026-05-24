class_name DialogueTrigger
extends Area2D

## DialogueTrigger — Area2D que dispara DialogueManager.start_dialogue(dialogue_id).
##
## MODOS:
##   - "AUTO"        — dispara assim que Player entra na área (body_entered)
##   - "INTERACTION" — Player entra → arma flag; aperta ui_accept/attack_light → dispara
##
## one_shot = true (default): só dispara uma vez. false: dispara cada vez que entrar.
## Sem dialogue_id setado: push_error e não dispara.

@export var mode: String = "AUTO"   ## "AUTO" ou "INTERACTION"
@export var dialogue_id: String = ""
@export var one_shot: bool = true

var _triggered: bool = false
var _player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if not body is PlayerController:
		return
	if mode == "AUTO":
		if _triggered and one_shot:
			return
		_fire()
	elif mode == "INTERACTION":
		_player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if not body is PlayerController:
		return
	if mode == "INTERACTION":
		_player_inside = false

func _unhandled_input(event: InputEvent) -> void:
	if mode != "INTERACTION":
		return
	if not _player_inside:
		return
	if _triggered and one_shot:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_light"):
		_fire()
		get_viewport().set_input_as_handled()

func _fire() -> void:
	if dialogue_id == "":
		push_error("DialogueTrigger: dialogue_id está vazio — nada pra disparar.")
		return
	if one_shot:
		_triggered = true
	DialogueManager.start_dialogue(dialogue_id)

extends Node2D

## Ichiraku — cutscene do Ramen no Zona 4 (easter egg SUGESTOES.md #03).
##
## Função única: tocar a animação loop_teuchi (alternância de 3 backgrounds com
## ~8s de loop). DialogueManager.start_dialogue("ichiraku_encontro") deve ser
## chamado por um DialogueTrigger filho da cena ou pelo LevelManager ao entrar.
##
## Fluxo de saída: DialogueTriggerSaida (borda direita) dispara ichiraku_saida →
## dialogue_ended → FadeTransition.fade() → midpoint reposiciona player →
## fade in completa → queue_free() remove a sub-scene.

var _fade: FadeTransition

func _ready() -> void:
	$AnimationPlayer.play("loop_teuchi")
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_fade = preload("res://scenes/components/fade_transition.tscn").instantiate()
	add_child(_fade)
	_fade.fade_completed.connect(_on_fade_completed)

func _on_dialogue_ended(dialogue_id: String) -> void:
	if dialogue_id != "ichiraku_saida":
		return
	_fade.fade(_on_fade_midpoint)

func _on_fade_midpoint() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].global_position = Vector2(-600, 0)  # placeholder — Zona 4 não existe ainda

func _on_fade_completed() -> void:
	queue_free()

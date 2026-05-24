extends Node2D

## Ichiraku — cutscene do Ramen no Zona 4 (easter egg SUGESTOES.md #03).
##
## Função única: tocar a animação loop_teuchi (alternância de 3 backgrounds com
## ~8s de loop). DialogueManager.start_dialogue("ichiraku_encontro") deve ser
## chamado por um DialogueTrigger filho da cena ou pelo LevelManager ao entrar.
##
## Sem lógica de gameplay — só cutscene visual + ganchos pra diálogo.

func _ready() -> void:
	$AnimationPlayer.play("loop_teuchi")

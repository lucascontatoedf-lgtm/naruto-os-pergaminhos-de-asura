extends Node2D

## AkatsukiHideout — cutscene do esconderijo (Zona 2, easter egg SUGESTOES.md #05).
##
## Função única: tocar a animação loop_gedo (alternância de 3 backgrounds com
## Gedo Mazo + Pain + Konan + Tobi, ~8s de loop). DialogueManager.start_dialogue(
## "akatsuki_encontro") deve ser chamado por trigger filho ou pelo LevelManager.
##
## Após "akatsuki_encontro" terminar, KamuiTrigger ouve o signal kamui_triggered
## do DialogueManager e executa fade+teleporte+akatsuki_saida (cadeia já cabreada
## no kamui_trigger.gd — instanciar como filho desta cena quando integrar).
##
## Sem lógica de gameplay — só cutscene visual + ganchos pra diálogo.

func _ready() -> void:
	$AnimationPlayer.play("loop_gedo")

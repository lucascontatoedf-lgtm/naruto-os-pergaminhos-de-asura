extends Node2D

## RasengaBalloon — balão visual "RASENGAAAAAN!!!" world-space.
##
## Component instanciado como filho do Player em player.tscn.
## Chamado por player_controller.gd:_enter_state(SPECIAL) via $RasengaBalloon.show_balloon().
##
## Comportamento: aparece visible=true → aguarda 1.5s → visible=false.
## NÃO pausa o jogo. NÃO emite signal. Spam de Rasengan = múltiplos awaits
## em flight (balão fica visível pelo último 1.5s, sem reset de timer).

func _ready() -> void:
	visible = false

func show_balloon() -> void:
	visible = true
	await get_tree().create_timer(1.5).timeout
	visible = false

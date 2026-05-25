extends Node2D

## Akatsuki Hideout — cutscene do esconderijo (easter egg SUGESTOES.md #05).
##
## Troca de textura acionada pelo diálogo:
## - Abre com frame_a (Pain mão na cabeça)
## - Após Pain: "Inesperado." → troca para frame_b (Pain sentado)
## - Permanece estático até fim do diálogo

const FRAME_A = preload("res://assets/backgrounds/akatsuki/guedomazo_pain_konan_tobi_naruto2.png")
const FRAME_B = preload("res://assets/backgrounds/akatsuki/guedomazo_pain_konan_tobi_naruto3.png")

const TRIGGER_LINE_INDEX = 2  # índice da linha "Pain: Inesperado." no diálogo

@onready var background: TextureRect = $UILayer/Background

func _ready() -> void:
	background.texture = FRAME_A
	DialogueManager.line_advanced.connect(_on_line_advanced)

func _on_line_advanced(index: int) -> void:
	if index == TRIGGER_LINE_INDEX:
		background.texture = FRAME_B

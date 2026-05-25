extends CanvasLayer

## DialogueBox — UI de balão de diálogo. Instanciada por DialogueManager.
##
## process_mode = ALWAYS (definido em _ready) pra continuar respondendo a input
## enquanto get_tree().paused = true durante o diálogo. Sem isso, o player
## ficaria preso na primeira linha sem conseguir avançar.
##
## Style manga: Panel com StyleBoxFlat (fundo branco + borda colorida por
## personagem) e NameLabel com font_color matching. Cores definidas em
## SPEAKER_COLORS, aplicadas em runtime via _apply_speaker_style() —
## adicionar personagem novo só requer entrada nesse dicionário.

## Cores manga-style por personagem. Aplicadas em runtime ao Panel.border_color
## e NameLabel.font_color via _apply_speaker_style(). Speaker desconhecido cai
## pra DEFAULT_COLOR (preto). Adicionar novos personagens só requer entrada aqui.
const SPEAKER_COLORS = {
	"Naruto":  Color(1.0,  0.5,  0.0,  1.0),  # laranja
	"Jiraiya": Color(0.2,  0.75, 0.2,  1.0),  # verde
	"Pain":    Color(0.5,  0.0,  0.75, 1.0),  # roxo
	"Konan":   Color(0.2,  0.4,  0.85, 1.0),  # azul
	"Tobi":    Color(0.75, 0.3,  0.0,  1.0),  # laranja escuro
}
const DEFAULT_COLOR = Color(0.1, 0.1, 0.1, 1.0)  # preto

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var _text_label: Label = $Panel/VBoxContainer/TextLabel
@onready var _prompt_label: Label = $Panel/VBoxContainer/PromptLabel

func _ready() -> void:
	## Crítico: ALWAYS permite o nó processar input/timers mesmo com get_tree().paused = true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_box()

## Mostra uma linha de diálogo. Se speaker vazio, oculta NameLabel e centraliza o texto
## (caso de onomatopeias como "FWOOSH" em akatsuki_encontro).
func show_line(line: Dictionary) -> void:
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	if speaker == "":
		_name_label.visible = false
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
	else:
		_name_label.visible = true
		_name_label.text = speaker
		_apply_speaker_style(speaker)
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.text = text
	_panel.visible = true

## Aplica cores manga-style ao Panel (border) e NameLabel (font) baseadas no speaker.
## Cria StyleBoxFlat novo a cada call — descartável, GC do Godot lida com o anterior.
## Fallback DEFAULT_COLOR pra speakers desconhecidos (não polui o console com warn).
func _apply_speaker_style(speaker: String) -> void:
	var color = SPEAKER_COLORS.get(speaker, DEFAULT_COLOR)
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(1, 1, 1, 1)        # fundo branco
	stylebox.border_color = color
	stylebox.set_border_width_all(3)
	stylebox.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", stylebox)
	_name_label.add_theme_color_override("font_color", color)
	_text_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
	_prompt_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1.0))

## Esconde o balão principal de diálogo.
func hide_box() -> void:
	_panel.visible = false

## Avança o diálogo quando player aperta confirmar/atacar. Só reage se Panel
## está visível (evita interferir com input do jogo durante gameplay normal).
## set_input_as_handled() impede que o mesmo press dispare attack_light no Player
## quando o diálogo termina.
func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack_light"):
		DialogueManager.advance()
		get_viewport().set_input_as_handled()

extends CanvasLayer

## DialogueBox — UI de balão de diálogo. Instanciada por DialogueManager.
##
## process_mode = ALWAYS (definido em _ready) pra continuar respondendo a input
## enquanto get_tree().paused = true durante o diálogo. Sem isso, o player
## ficaria preso na primeira linha sem conseguir avançar.
##
## RasengaLabel é elemento INDEPENDENTE do Panel principal — pode aparecer SEM
## o balão de diálogo estar ativo (Rasengan cast no meio do gameplay normal).
##
## DESVIO INTENCIONAL DA SPEC (aprovado, Bloco 3): a spec colocava RasengaLabel
## como FILHO de Panel, mas Panel é bottom-anchored 600x120 e filho dele não
## consegue alcançar central-topo do viewport. Movido pra SIBLING de Panel pra
## ancoragem livre. Ver dialogue_box.tscn pra justificativa completa.

@onready var _panel: Panel = $Panel
@onready var _name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var _text_label: Label = $Panel/VBoxContainer/TextLabel
@onready var _prompt_label: Label = $Panel/VBoxContainer/PromptLabel
@onready var _rasengan_label: Label = $RasengaLabel
@onready var _rasengan_timer: Timer = $RasengaLabel/Timer

func _ready() -> void:
	## Crítico: ALWAYS permite o nó processar input/timers mesmo com get_tree().paused = true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_box()
	_rasengan_label.visible = false
	_rasengan_timer.timeout.connect(_on_rasengan_timeout)

## Mostra uma linha de diálogo. Se speaker vazio, oculta NameLabel e centraliza o texto
## (caso de onomatopeias como "FWOOSH" em akatsuki_encontro).
func show_line(line: Dictionary) -> void:
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	if speaker == "":
		_name_label.visible = false
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_name_label.visible = true
		_name_label.text = speaker
		_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text_label.text = text
	_panel.visible = true

## Esconde o balão principal de diálogo (NÃO afeta o balão de Rasengan).
func hide_box() -> void:
	_panel.visible = false

## Mostra o balão "RASENGAAAAAA!!!" no centro-topo da tela por 1.5s.
## Independente do Panel — pode ser chamado em qualquer momento, sem pausar.
func show_rasengan_balloon() -> void:
	_rasengan_label.visible = true
	_rasengan_timer.start(1.5)

func _on_rasengan_timeout() -> void:
	_rasengan_label.visible = false

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

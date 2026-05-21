extends CanvasLayer

## Debug HUD da TestStage — mostra estado da FSM do Player e barra de chakra em tempo real.
## Plugado via signals nativos do PlayerController (state_changed, chakra_changed).
## Remover ou desativar quando entrarmos no Polish (Semana 3).

@export var player_path: NodePath = NodePath("../Player")

@onready var state_label: Label = $Root/VBox/StateLabel
@onready var chakra_label: Label = $Root/VBox/ChakraLabel

var _player: PlayerController

func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	if _player == null:
		push_warning("DebugHUD: PlayerController não encontrado em '%s'." % player_path)
		state_label.text = "Estado: (player ausente)"
		chakra_label.text = "Chakra: —"
		return

	_player.state_changed.connect(_on_state_changed)
	_player.chakra_changed.connect(_on_chakra_changed)

	# Sincroniza os valores iniciais sem esperar a primeira emissão.
	_on_state_changed(_player.current_state, _player.current_state)
	_on_chakra_changed(_player.current_chakra, _player.max_chakra)

func _on_state_changed(_previous: int, new_state: int) -> void:
	state_label.text = "Estado: %s" % PlayerController.State.keys()[new_state]

func _on_chakra_changed(current: float, maximum: float) -> void:
	var pct: int = 0
	if maximum > 0.0:
		pct = int(round((current / maximum) * 100.0))
	chakra_label.text = "Chakra: %d / %d  (%d%%)" % [int(round(current)), int(round(maximum)), pct]

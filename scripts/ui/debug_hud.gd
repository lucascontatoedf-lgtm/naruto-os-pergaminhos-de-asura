extends CanvasLayer

## Debug HUD da TestStage — mostra estado da FSM do Player, vida e chakra em tempo real.
## Plugado via signals nativos do PlayerController (state_changed, health_changed, chakra_changed).
## Remover ou desativar quando entrarmos no Polish (Semana 3).

@onready var state_label: Label = $Root/VBox/StateLabel
@onready var health_label: Label = $Root/VBox/HealthLabel
@onready var chakra_label: Label = $Root/VBox/ChakraLabel

var _player: PlayerController

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	await get_tree().process_frame
	_connect_player(get_tree().get_first_node_in_group("Player"))

func _on_node_added(node: Node) -> void:
	if node.is_in_group("Player"):
		_connect_player(node)

func _connect_player(player: Node) -> void:
	if player == null:
		push_warning("DebugHUD: nenhum Player encontrado no grupo 'Player'.")
		return
	_player = player as PlayerController
	if _player.state_changed.is_connected(_on_state_changed):
		_player.state_changed.disconnect(_on_state_changed)
	if _player.health_changed.is_connected(_on_health_changed):
		_player.health_changed.disconnect(_on_health_changed)
	if _player.chakra_changed.is_connected(_on_chakra_changed):
		_player.chakra_changed.disconnect(_on_chakra_changed)
	_player.state_changed.connect(_on_state_changed)
	_player.health_changed.connect(_on_health_changed)
	_player.chakra_changed.connect(_on_chakra_changed)
	_on_state_changed(_player.current_state, _player.current_state)
	_on_health_changed(_player.current_health, _player.max_health)
	_on_chakra_changed(_player.current_chakra, _player.max_chakra)

func _on_state_changed(_previous: int, new_state: int) -> void:
	state_label.text = "Estado: %s" % PlayerController.State.keys()[new_state]

func _on_health_changed(current: int, maximum: int) -> void:
	var pct: int = 0
	if maximum > 0:
		pct = int(round(float(current) / float(maximum) * 100.0))
	health_label.text = "Vida: %d / %d  (%d%%)" % [current, maximum, pct]

func _on_chakra_changed(current: float, maximum: float) -> void:
	var pct: int = 0
	if maximum > 0.0:
		pct = int(round((current / maximum) * 100.0))
	chakra_label.text = "Chakra: %d / %d  (%d%%)" % [int(round(current)), int(round(maximum)), pct]

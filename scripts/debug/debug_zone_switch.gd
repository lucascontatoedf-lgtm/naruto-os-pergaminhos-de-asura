extends Node

func _ready() -> void:
	await get_tree().process_frame

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed): return
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return
	match event.keycode:
		KEY_F1:
			SaveSystem.save(player)
			print("[DEBUG] save() — hp: %d | chakra: %.1f" % [SaveSystem._hp, SaveSystem._chakra])
			LevelManager.change_scene("zona_2")
		KEY_F2:
			# Aplica estado salvo e imprime no console
			SaveSystem.load_into(player)
			print("[DEBUG] load_into() — hp: %d | chakra: %.1f" % [player.current_health, player.current_chakra])
		KEY_F3:
			# Reseta SaveSystem e imprime no console
			SaveSystem.reset()
			print("[DEBUG] reset() — has_data: %s" % SaveSystem.has_data())

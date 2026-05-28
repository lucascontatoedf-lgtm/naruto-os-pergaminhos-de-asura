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
			LevelManager.change_scene("zona_2")
		KEY_F2:
			SaveSystem.load_into(player)
		KEY_F3:
			SaveSystem.reset()

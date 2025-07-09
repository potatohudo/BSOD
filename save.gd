# SaveManager.gd
extends Node

var current_save := {}

func save_game():
	var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(current_save, "\t"))
		file.close()

func load_game():
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed = JSON.parse_string(content)
		if typeof(parsed) == TYPE_DICTIONARY:
			current_save = parsed
			return
	current_save = {}

func get_player_data() -> Dictionary:
	return current_save.get("player", {})

func set_player_data(data: Dictionary):
	current_save["player"] = data

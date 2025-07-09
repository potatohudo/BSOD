extends Node

var current_save := {}

func _ready() -> void:
	save_game()
	_normalize_file_system(file_system["root"])
	load_game()

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

var file_system: Dictionary = {
	"root": {
		"HKEY_CLASSES_ROOT": {
			"txtfile": {
				"example.txt": {
					"filecontent": "lalalalallalalalalall\ndfgdfgdfgdfg\ngdfgdfgdfgdfgdfgdf",
					"editable": true
				}
			},
			"images": {
				"image.png": {
					"filecontent": "res://pc/programs/explorer/image.png",
					"editable": false
				}
			}
		},
		"HKEY_CURRENT_USER": {
			"Software": {
				"MyApp": {
					"config.ini": {
						"filecontent": "placeholder",
						"editable": false
					}
				}
			}
		},
		"HKEY_LOCAL_MACHINE": {
			"System": {
				"kernel.sys": {
					"filecontent": "placeholder",
					"editable": false
				}
			}
		}
	}
}


# Access virtual file save data
func get_file_data(name: String) -> Dictionary:
	return current_save.get("text_files", {}).get(name, {})

func set_file_content(name: String, content: String) -> void:
	var files: Dictionary = current_save.get("text_files", {})
	files[name] = { "content": content }  # ONLY the content string, not the entire file_entry
	current_save["text_files"] = files
	save_game()


# Helper to normalize raw string entries into {"filecontent": ..., "editable": true}
func _normalize_file_system(fs: Dictionary) -> void:
	for key in fs.keys():
		var val = fs[key]
		if typeof(val) == TYPE_DICTIONARY:
			_normalize_file_system(val)
		elif typeof(val) == TYPE_STRING:
			fs[key] = { "filecontent": val, "editable": true }

extends Node

var current_save := {}

func _ready() -> void:
	_normalize_file_system(file_system["root"])
	load_game()

	# Only create default save if it doesn't already exist
	if not current_save.has("text_files"):
		_create_default_save()
		save_game()



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

func _create_default_save() -> void:
	var text_files: Dictionary = {}
	_fill_defaults(file_system["root"], text_files)
	current_save["text_files"] = text_files

func _fill_defaults(fs: Dictionary, text_files: Dictionary) -> void:
	for key in fs.keys():
		var value = fs[key]
		if typeof(value) == TYPE_DICTIONARY:
			if value.has("filecontent"):
				text_files[key] = { "content": value["filecontent"] }
			else:
				_fill_defaults(value, text_files)

# Helper to normalize raw string entries into {"filecontent": ..., "editable": true}
func _normalize_file_system(fs: Dictionary) -> void:
	for key in fs.keys():
		var value = fs[key]
		if typeof(value) == TYPE_DICTIONARY:
			# if it's already a file dictionary (has filecontent), skip it
			if value.has("filecontent"):
				continue
			_normalize_file_system(value)
		elif typeof(value) == TYPE_STRING:
			fs[key] = {
				"filecontent": value,
				"editable": true
			}

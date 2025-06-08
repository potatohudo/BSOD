extends Control

@onready var tree = $HBoxContainer/Tree
@onready var item_list = $VBoxContainer2/ItemList
@onready var rtlabel = $VBoxContainer2/RichTextLabel
@onready var te = $Panel/TextEdit
@onready var cmd = $Panel/RichTextLabel2
@onready var loader = $"Loader"

var file_system = {
	"root": {
		"HKEY_CLASSES_ROOT": {
			"txtfile": { "example.txt": "res://programs/explorer/example.txt" },
			"pngfile": { "image.png": "res://programs/explorer/image.png" }
		},
		"HKEY_CURRENT_USER": {
			"Software": {
				"MyApp": { "config.ini": "res://programs/explorer/config-ini.txt" }
			}
		},
		"HKEY_LOCAL_MACHINE": {
			"System": { "kernel.sys": "res://programs/explorer/kernel-sys.txt" }
		}
	}
}

var current_path = "root"

func _ready():
	populate_tree()
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)

func populate_tree():
	tree.clear()
	var root = tree.create_item()
	root.set_text(0, "root")
	root.set_metadata(0, "root")
	add_folders(root, file_system["root"], "root")

func add_folders(parent, directory, parent_path):
	for name in directory.keys():
		if directory[name] is Dictionary:
			var item = tree.create_item(parent)
			item.set_text(0, name)
			item.set_metadata(0, parent_path + "/" + name)
			add_folders(item, directory[name], parent_path + "/" + name)

func _on_tree_item_selected():
	var selected_item = tree.get_selected()
	if selected_item:
		current_path = selected_item.get_metadata(0)
		update_file_list()

func update_file_list():
	item_list.clear()
	var folder = get_folder_at_path(current_path)
	if folder:
		for item in folder.keys():
			if folder[item] is Dictionary:
				continue
			item_list.add_item(item)

func get_folder_at_path(path_str):
	var keys = path_str.split("/")
	var folder = file_system
	for key in keys:
		if key in folder and folder[key] is Dictionary:
			folder = folder[key]
		else:
			return null
	return folder

func _on_item_selected(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = get_folder_at_path(current_path)
	if folder and file_name in folder:
		rtlabel.text = "[b]File:[/b] " + file_name + "\n" + "[i]Contents:[/i] " + str(folder[file_name])

func _on_item_activated(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = get_folder_at_path(current_path)
	if folder and file_name in folder:
		var file_data = folder[file_name]
		if typeof(file_data) == TYPE_STRING and (
			file_data.begins_with("res://") or
			file_data.ends_with(".tscn") or
			file_data.ends_with(".gd") or
			file_data.ends_with(".txt") 
		):
			open_file_window(file_name, file_data, true)
		else:
			open_file_window(file_name, file_data)

func open_file_window(name: String, content, separate: bool = false):
	var file_window_scene = preload("res://window.tscn")
	var file_window = file_window_scene.instantiate()
	file_window.set_title(name)
	file_window.position = Vector2(100, 100)
	file_window.size = Vector2(600, 400)

	if separate and content is String:
		if content.ends_with(".tscn") and ResourceLoader.exists(content):
			var res = load(content)
			if res is PackedScene:
				file_window.set_content(res.instantiate())
			else:
				file_window.set_content(_make_error_label("Failed to instantiate .tscn."))
		
		elif content.ends_with(".txt") and FileAccess.file_exists(content):
			var file := FileAccess.open(content, FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()

		# Create container to hold text editor and save button
				var vbox = VBoxContainer.new()

		# Text editor
				var text_edit = TextEdit.new()
				text_edit.text = text
				text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
				text_edit.name = "TextEditor"
				vbox.add_child(text_edit)

		# Save button
				var save_button = Button.new()
				save_button.text = "Save"
				save_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				save_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				vbox.add_child(save_button)

		# Connect button to save logic
				save_button.pressed.connect(func():
					var edited_text = text_edit.text
					var save_file := FileAccess.open(content, FileAccess.WRITE)
					if save_file:
						save_file.store_string(edited_text)
						save_file.close()
						print("Saved to: ", content)
					else:
						print("Failed to save to: ", content)
					)

				file_window.set_content(vbox)
			else:
				file_window.set_content(_make_error_label("Failed to open file: " + content))


		elif content.ends_with(".png") and ResourceLoader.exists(content):
			var tex = load(content)
			if tex is Texture2D:
				var tex_rect = TextureRect.new()
				tex_rect.texture = tex
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
				file_window.set_content(tex_rect)
			else:
				file_window.set_content(_make_error_label("Not a valid image texture."))
		
		else:
			file_window.set_content(_make_error_label("File not found or unsupported:\n" + content))

	else:
		var label = RichTextLabel.new()
		label.text = str(content)
		label.scroll_active = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		file_window.set_content(label)

	loader.add_child(file_window)
	file_window.show()

func _make_error_label(msg: String) -> Label:
	var label = Label.new()
	label.text = "[Error]\n" + msg
	return label

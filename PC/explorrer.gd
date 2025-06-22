extends Control

@onready var tree = $HBoxContainer/Tree
@onready var item_list = $VBoxContainer2/ItemList
@onready var rtlabel = $VBoxContainer2/RichTextLabel
@onready var te = $Panel/TextEdit
@onready var cmd = $Panel/RichTextLabel2
@onready var loader = $"Loader"
@onready var task_panel = $TaskPanel/Bar/HBoxContainer

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
	var system_tasks = [
		{ "name": "System", "cpu": 1.5, "usage": Vector2(20, 30) },
		{ "name": "Idle", "cpu": 0.1, "usage": Vector2(0.05, 0.2) },
		{ "name": "Kernel32", "cpu": 2.4, "usage": Vector2(1.0, 3.0) }
	]
	for t in system_tasks:
		t["pid"] = next_pid
		t["window"] = null
		next_pid += 1
		running_tasks[t.name] = t
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
			await get_tree().process_frame
			if res is PackedScene:
				var scene_instance = res.instantiate()
				file_window.set_content(scene_instance)

				var custom_usage := Vector2(1.0, 3.0)

				if scene_instance.has_method("get_usage"):
					custom_usage = scene_instance.get_usage()
				elif scene_instance.has_method("usage") and typeof(scene_instance.get("usage")) == TYPE_VECTOR2:
					custom_usage = scene_instance.get("usage")
				else:
					push_error("No usage found in scene")
				register_task(name, file_window, custom_usage)
					
			else:
				file_window.set_content(_make_error_label("Failed to instantiate .tscn."))
		
		elif content.ends_with(".txt") and FileAccess.file_exists(content):
			var file := FileAccess.open(content, FileAccess.READ)
			if file:
				var text := file.get_as_text()
				file.close()

				var vbox = VBoxContainer.new()

		# Text editor
				var text_edit = TextEdit.new()
				text_edit.text = text
				text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
				text_edit.name = "TextEditor"
				text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
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
	

	var task_button = Button.new()
	#task_button.text = name  # or use only icon if desired

	# Optional: Set an icon (replace with your actual icon path)
	var icon_path = "res://programs/explorer/icons/%s.png" % name.to_lower()
	if ResourceLoader.exists(icon_path):
		task_button.icon = load(icon_path)
	else:
		task_button.icon = load("res://programs/explorer/icons/default.png")
	task_button.custom_minimum_size = Vector2(30, 30)

	# will get removed, dont worry abt it
	task_button.pressed.connect(func():
		file_window.visible = !file_window.visible
	)

	file_window.tree_exiting.connect(func():
		task_button.queue_free()
	)

	task_panel.add_child(task_button)

var running_tasks: Dictionary = {}
var next_pid := 1

func register_task(name: String, window: Control, usage := Vector2(1.0, 3.0)):
	if not running_tasks.has(name):
		var task_info = {
			"name": name,
			"pid": next_pid,
			"window": window,
			"cpu": 0.0,
			"usage": usage
		}
		next_pid += 1
		running_tasks[name] = task_info

	window.tree_exiting.connect(func():
		running_tasks.erase(name)
	)


# TaskMgr calls this
func get_running_tasks() -> Dictionary:
	return running_tasks.duplicate(true)  # return a deep copy


func _make_error_label(msg: String) -> Label:
	var label = Label.new()
	label.text = "[Error]\n" + msg
	return label

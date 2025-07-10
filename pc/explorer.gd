extends Control

#file related stuff

@onready var tree = $HBoxContainer/Tree
@onready var item_list = $VBoxContainer2/ItemList
@onready var rtlabel = $VBoxContainer2/RichTextLabel
@onready var te = $Panel/TextEdit
@onready var cmd = $Panel/RichTextLabel2
@onready var loader = $"Loader"
@onready var task_panel = $TaskPanel/Bar/HBoxContainer






var current_path = "root"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	populate_tree()
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)

func _process(_delta):

	if Input.is_action_just_pressed("fs"):
		match DisplayServer.window_get_mode():
			DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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
	add_folders(root, Save.file_system["root"], "root")

func add_folders(parent, directory, parent_path):
	for name in directory.keys():
		var entry = directory[name]

		# Skip files (dictionaries that have "filecontent")
		if typeof(entry) == TYPE_DICTIONARY and entry.has("filecontent"):
			continue

		# This is a folder (either a nested folder or valid legacy format)
		if typeof(entry) == TYPE_DICTIONARY:
			var item = tree.create_item(parent)
			item.set_text(0, name)
			item.set_metadata(0, parent_path + "/" + name)
			add_folders(item, entry, parent_path + "/" + name)


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
			var entry = folder[item]
			if typeof(entry) == TYPE_DICTIONARY and entry.has("filecontent"):
				item_list.add_item(item)




func get_folder_at_path(path_str):
	var keys = path_str.split("/")
	var folder = Save.file_system
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
		var entry = folder[file_name]
		var saved_data = Save.get_file_data(file_name)
		var content = saved_data.get("content", entry.get("filecontent", ""))
		rtlabel.text = "[b]File:[/b] " + file_name + "\n" + "[i]Contents:[/i] " + str(content)


func _on_item_activated(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = get_folder_at_path(current_path)

	if folder and folder.has(file_name):
		var file_entry = folder[file_name]
		if typeof(file_entry) == TYPE_DICTIONARY and file_entry.has("filecontent"):
			var editable = file_entry.get("editable", true)

			# Program mode if it's a .tscn or .png
			var ext = file_name.get_extension().to_lower()
			var is_program = ext in ["tscn", "png"]

			var content = file_entry["filecontent"] if is_program else Save.get_file_data(file_name).get("content", file_entry["filecontent"])


			open_file_window(file_name, content, is_program, editable)



func open_file_window(name: String, content, program: bool = false, editable: bool = true):
	await get_tree().create_timer(0.1).timeout
	var file_window_scene = preload("res://pc/window.tscn")
	var file_window = file_window_scene.instantiate()
	file_window.set_title(name.get_basename() if program else name)
	file_window.position = Vector2(100, 100)
	file_window.size = Vector2(600, 400)
	file_window.resizable = true
	file_window.scale = Vector2(0.9, 0.9)
	file_window.modulate.a = 0.0

	loader.add_child(file_window)
	file_window.show()
	await get_tree().create_timer(0.2).timeout

	var usage: Vector2 = Vector2(1.0, 3.0)
	var ext = name.get_extension().to_lower()

	if program and typeof(content) == TYPE_STRING and content.begins_with("res://"):
		match ext:
			"tscn":
				if ResourceLoader.exists(content):
					var res = load(content)
					await get_tree().process_frame
					if res is PackedScene:
						var inst = res.instantiate()
						file_window.set_content(inst)
						if inst.has_method("get_usage"):
							usage = inst.get_usage()
						elif inst.has("usage") and typeof(inst.get("usage")) == TYPE_VECTOR2:
							usage = inst.get("usage")
						else:
							push_error("No usage found in scene")
						register_task(name, file_window, usage)
					else:
						file_window.set_content(_make_error_label("Failed to instantiate scene."))
				else:
					file_window.set_content(_make_error_label("Scene not found:\n" + content))

			"png":
				if ResourceLoader.exists(content):
					var tex = load(content)
					if tex is Texture2D:
						var tex_rect = TextureRect.new()
						tex_rect.texture = tex
						tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						tex_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
						file_window.set_content(tex_rect)
					else:
						file_window.set_content(_make_error_label("Not a valid texture."))
				else:
					file_window.set_content(_make_error_label("Image not found:\n" + content))
			_:
				file_window.set_content(_make_error_label("Unsupported or unknown program file type:\n" + name))

	else:
		# Standard text file editor window
		var vbox = VBoxContainer.new()
		var text_edit = TextEdit.new()
		text_edit.text = str(content)
		text_edit.editable = true
		text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		vbox.add_child(text_edit)

		var save_button = Button.new()
		save_button.text = "Save"
		save_button.disabled = not editable
		save_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		save_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		vbox.add_child(save_button)

		save_button.pressed.connect(func():
			var edited_text: String = text_edit.text
			Save.set_file_content(name, edited_text)
			print("Saved virtual file:", name)
		)

		file_window.set_content(vbox)

	#loader.add_child(file_window)
	#file_window.show()

	var task_button = Button.new()
	var icon_path = "res://pc/programs/icons/%s.png" % name.get_basename().to_lower()
	task_button.icon = load(icon_path) if ResourceLoader.exists(icon_path) else load("res://pc/programs/icons/default.png")
	task_button.custom_minimum_size = Vector2(30, 30)

	task_button.pressed.connect(func(): file_window.visible = !file_window.visible)
	file_window.tree_exiting.connect(func(): task_button.queue_free())
	task_panel.add_child(task_button)




var running_tasks: Dictionary = {}
var next_pid := 1

#adds task to the list, so taskmgr can grab and visualize it later on
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


# taskmgr calls this
func get_running_tasks() -> Dictionary:
	return running_tasks.duplicate(true)  # return a deep copy

##other ig
func _make_error_label(msg: String) -> Label:
	var label = Label.new()
	label.text = "[Error]\n" + msg
	return label

#teleporter button
func _on_tp_button_pressed() -> void:
	# Path to the scene for comparison


	# Look through all windows already in loader
	for window in loader.get_children():
		if window.has_node("NPR/Content"):
			var content = window.get_node("NPR/Content")
			for child in content.get_children():
				# Check if this child is an instance of the teleporter scene
				if child.get_script() and child.get_scene_file_path() == "res://pc/teleporter.tscn":
					window.queue_free()
					return 

	# Otherwise, add new teleporter window
	var tp_scene = preload("res://pc/teleporter.tscn")
	var instance = tp_scene.instantiate()

	var file_window_scene = preload("res://pc/window.tscn")
	var file_window = file_window_scene.instantiate()

	file_window.set_title("TELEPORT?")
	file_window.position = Vector2(100, 100)
	file_window.size = Vector2(550, 220)
	file_window.set_content(instance)
	file_window.resizable = false

	loader.add_child(file_window)
	file_window.show()
	register_task(" ", file_window, Vector2(0, -1))

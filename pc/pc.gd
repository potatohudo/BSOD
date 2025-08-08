extends Control

@onready var freaky = $SubViewportContainer/SubViewport/Freaky
@onready var dm = $SubViewportContainer/SubViewport/Freaky/Datamoshing
@onready var loader = $SubViewportContainer/SubViewport/Explorer/Loader
@onready var task_panel = $SubViewportContainer/SubViewport/Explorer/TaskPanel/Bar/HBoxContainer

func _process(delta: float) -> void:
	if Global.just_teleported:
		start_shader_tween()
		Global.just_teleported = false
	if Input.is_action_just_pressed("tab"):
		freaky.visible = !freaky.visible


func start_shader_tween():
	freaky.visible = true
	dm.visible = true

	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(freaky.material, "shader_parameter/strength", 5.0, 5.0).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(dm.material, "shader_parameter/strength", 1.0, 3.0).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func ():
		await get_tree().create_timer(1.0).timeout
		freaky.visible = false
		dm.visible = false
	)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Global.system_node = self

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
		text_edit.editable = editable
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

##other ig
func _make_error_label(msg: String) -> Label:
	var label = Label.new()
	label.text = "[Error]\n" + msg
	return label


func get_folder_at_path(path_str: String) -> Dictionary:
	var keys = path_str.split("/")
	var folder = Save.file_system
	for key in keys:
		if key in folder and folder[key] is Dictionary:
			folder = folder[key]
		else:
			return {}
	return folder

var running_tasks: Dictionary = {}
var next_pid := 1

#adds task to the list, so taskmgr can grab and visualize it later on
func register_task(name: String, window: Control, usage := Vector2(1.0, 3.0)):
	var task_name = name.get_basename()  # <- This removes the .tscn or other extensions

	if not running_tasks.has(task_name):
		var task_info = {
			"name": task_name,
			"pid": next_pid,
			"window": window,
			"cpu": 0.0,
			"usage": usage
		}
		next_pid += 1
		running_tasks[task_name] = task_info

	window.tree_exiting.connect(func():
		running_tasks.erase(task_name)
	)


func get_running_tasks() -> Dictionary:
	return running_tasks.duplicate(true)  

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

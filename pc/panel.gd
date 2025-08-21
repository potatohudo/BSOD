extends Panel  

#console logic. it handles commands and stuff

@onready var button = $"../TaskPanel/Button"
@onready var te = $TextEdit
@onready var cmd = $RichTextLabel2
@onready var console = self





func _process(_delta):
	if Input.is_action_pressed("ui_cmd"):
		if console.visible:
			console.hide()
		else:
			console.visible = true
			console.position.y = get_viewport().get_visible_rect().size.y - 200
			te.grab_focus()
	if te.has_focus() and Input.is_action_just_pressed("ui_accept"):
		var command = te.text.strip_edges()
		te.clear()
		handle_command(command, cmd)


func handle_command(command: String, cmd_output: RichTextLabel):
	var main = $"../../../../"
	cmd_output.append_text("\n> " + command)

	var parts = command.split(" ", false)

	if parts.size() == 2 and parts[0].to_lower() == "open":
		var program_name = parts[1] + ".tscn"
		var level_path = "res://pc/programs/" + program_name
		if ResourceLoader.exists(level_path):
			cmd_output.append_text("\nLoading %s..." % parts[1])
			main.open_file_window(program_name, level_path, true)
		else:
			cmd_output.append_text("\nError: Wrong path (%s)" % level_path)
		return


	match command.to_lower():
		"reset":
			cmd_output.append_text("\n>Are you sure? (y/n)")

		"settings":
			cmd_output.append_text("\n>")

		"save":
			Save.save_game()
		
		_:
			cmd_output.append_text("\n>learn how to type")


	# Populate file list from Save.file_system
	#var folder = $"../../../../".get_folder_at_path("root")  # Change if needed
	#if folder:
		#for file_name in folder.keys():
			#var entry = folder[file_name]
			#if typeof(entry) == TYPE_DICTIONARY and entry.has("filecontent") and entry.get("display", true):
				#file_list.add_item(file_name)

	# Add taskbar button (optional)
	#var task_button = Button.new()
	#task_button.text = "."
	#task_button.custom_minimum_size = Vector2(30, 30)
	#task_button.pressed.connect(func(): file_window.visible = !file_window.visible)
	#file_window.tree_exiting.connect(func(): task_button.queue_free())
	#$"../TaskPanel/Bar/HBoxContainer".add_child(task_button)

extends Panel  

@onready var button = $"../HBoxContainer2/Button"
@onready var te = $TextEdit
@onready var cmd = $RichTextLabel2
@onready var console = self


@onready var window = $"../../Browser/Control"
@onready var npr = $"../../Browser/Control/NPR"

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
	cmd_output.append_text("\n> " + command)

	var parts = command.split(" ", false)

	if command.to_lower() == "open browser":
		
		window.visible = true
		npr.visible = true
		window.grab_focus()
		window.set_process(true)
		cmd_output.append_text("\n Browser opened.")
		return

	# 🔎 Handle generic `open [program]`
	elif parts.size() == 2 and parts[0].to_lower() == "open":
		var level_path = "res://programs/" + parts[1] + ".tscn"
		if ResourceLoader.exists(level_path):
			cmd_output.append_text("\nLoading %s..." % parts[1])
			$"../".open_file_window(parts[1], level_path, true)
		else:
			cmd_output.append_text("\nError: Wrong path (%s)" % level_path)
		return


	match command.to_lower():

		"reset":
			cmd_output.append_text("\n>Are you sure? (y/n)")
		"settings":
			cmd_output.append_text("\n>")
			

		_:
			cmd_output.append_text("\n>learn how to type dumbass")
			
func _on_button_pressed() -> void:
	if console.visible:
		console.hide()
	else:
		console.visible = true
		console.position.y = get_viewport().get_visible_rect().size.y - 200
		te.grab_focus()

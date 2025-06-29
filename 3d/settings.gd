extends Node

var master_volume := 100
var music_volume := 100
var sound_volume := 100
var main_reference: Node = null


var resolutions := [
	{ "scale": 2, "label": "1280x800" },
	{ "scale": 3, "label": "1024x768" },
	{ "scale": 4, "label": "800x600" }
]

var active_menu := ""         # Current active menu
var awaiting_input_for := ""  # For tracking expected user input (volume type, etc.)

# Displays the main settings menu
func show_settings_menu(output: RichTextLabel) -> void:
	active_menu = "main"
	awaiting_input_for = ""
	output.clear()
	output.append_text("\nSettings Menu:\n1. Graphical\n2. Volume\n3. Extra\n4. Exit")
	output.append_text("\nType a number or the corresponding keyword.")

# Handles generic user input depending on current menu
func handle_settings_command(command: String, output: RichTextLabel) -> void:
	command = command.strip_edges()
	if awaiting_input_for != "":
		handle_value_input(command, output)
		return

	match active_menu:
		"main": handle_main_menu(command, output)
		"graphical": handle_graphical_settings(command, output)
		"resolution": handle_resolution_selection(command, output)
		"volume": handle_volume_settings(command, output)
		_:
			output.append_text("\nUnknown state. Returning to main menu.")
			show_settings_menu(output)

# Parses a number input and applies it to the expected field
func handle_value_input(value: String, output: RichTextLabel) -> void:
	var input_value := value.to_int()
	if active_menu == "volume" and awaiting_input_for != "":
		set_volume(awaiting_input_for, input_value, output)
	awaiting_input_for = ""

# Main menu input handler
func handle_main_menu(command: String, output: RichTextLabel) -> void:
	match command.to_lower():
		"1", "graphical": show_graphical_settings(output)
		"2", "volume": show_volume_settings(output)
		"4", "exit":
			active_menu = ""
			output.append_text("\nExiting settings.")
		_:
			output.append_text("\nInvalid option. Please try again.")

# Shows the graphical settings submenu
func show_graphical_settings(output: RichTextLabel) -> void:
	active_menu = "graphical"
	output.clear()
	output.append_text("\nGraphical Settings:\n1. Resolution\n2. Fullscreen\n3. Back")

# Graphical submenu handler
func handle_graphical_settings(command: String, output: RichTextLabel) -> void:
	match command.to_lower():
		"1", "resolution": show_resolution_options(output)
		"2", "fullscreen": toggle_fullscreen(output)
		"3", "back": show_settings_menu(output)
		_:
			output.append_text("\nInvalid graphical command.")

# Lists resolution options
func show_resolution_options(output: RichTextLabel) -> void:
	active_menu = "resolution"
	output.clear()
	output.append_text("\nResolution Options:")
	for i in range(resolutions.size()):
		output.append_text("\n%d. %s" % [i + 1, resolutions[i]["label"]])
	output.append_text("\nType the number of your desired resolution, or 'back'.")

# Handles resolution selection input
func handle_resolution_selection(command: String, output: RichTextLabel) -> void:
	if command.to_lower() == "back":
		show_graphical_settings(output)
		return

	var option := command.to_int() - 1
	if option >= 0 and option < resolutions.size():
		set_resolution(resolutions[option]["scale"], output)
	else:
		output.append_text("\nInvalid selection. Try again.")

# Sets the scale factor (not actual res) using SubViewportContainer's stretch_shrink
func set_resolution(scale: int, output: RichTextLabel) -> void:
	if main_reference == null or not main_reference.has_method("get_subviewport_container"):
		output.append_text("\nMain reference or viewport method missing.")
		return

	var container: SubViewportContainer = main_reference.get_subviewport_container()

	if container:
		container.stretch_shrink = scale
		output.append_text("\nRender scale set to shrink factor %d." % scale)
	else:
		output.append_text("\nCould not apply resolution.")

# Toggles fullscreen/windowed mode
func toggle_fullscreen(output: RichTextLabel) -> void:
	var current_mode := DisplayServer.window_get_mode()
	var new_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if current_mode == DisplayServer.WINDOW_MODE_WINDOWED else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(new_mode)
	output.append_text("\nFullscreen %s." % (["disabled", "enabled"])[int(new_mode == DisplayServer.WINDOW_MODE_FULLSCREEN)])

# Shows the volume settings menu
func show_volume_settings(output: RichTextLabel) -> void:
	active_menu = "volume"
	awaiting_input_for = ""
	output.clear()
	output.append_text("\nVolume Settings:")
	output.append_text("\nMaster: %d | Music: %d | Sound: %d" % [master_volume, music_volume, sound_volume])
	output.append_text("\nUse format: 'master 80', or type 'back' to return.")

# Handles volume input like "music 30"
func handle_volume_settings(command: String, output: RichTextLabel) -> void:
	var parts := command.strip_edges().split(" ")
	if parts.size() == 1 and parts[0].to_lower() == "back":
		show_settings_menu(output)
		return
	elif parts.size() == 2:
		var volume_type := parts[0].to_lower()
		var value := parts[1].to_int()
		if volume_type in ["master", "music", "sound"]:
			set_volume(volume_type, value, output)
		else:
			output.append_text("\nUnknown volume type.")
	else:
		output.append_text("\nInvalid format. Use: '<type> <value>'.")

# Actually sets the volume value and applies it to the audio bus
func set_volume(volume_type: String, value: int, output: RichTextLabel) -> void:
	match volume_type:
		"master": master_volume = value
		"music": music_volume = value
		"sound": sound_volume = value
		_: output.append_text("\nUnknown volume type."); return

	var db_value: float = linear_to_db(clamp(value / 100.0, 0.0, 1.0))

	var bus_index := AudioServer.get_bus_index(volume_type.capitalize())
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, db_value)
		output.append_text("\nSet %s volume to %d." % [volume_type, value])
	else:
		output.append_text("\nCould not set volume. Bus missing?")

# Used to assign the main node that provides viewport access
func set_main_reference(main_node) -> void:
	main_reference = main_node

# Utility to check if this menu is currently being interacted with
func is_active() -> bool:
	return active_menu != ""

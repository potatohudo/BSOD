extends Node

# Volume settings
var master_volume = 100
var music_volume = 100
var sound_volume = 100
var main_reference 

# Fixed resolution options
var resolutions = [
	{"width": 1280, "height": 800},
	{"width": 1024, "height": 768},
	{"width": 800, "height": 600}
]

var active_menu = ""  # Tracks current menu
var awaiting_input_for = ""  # Tracks setting waiting for input

func show_settings_menu(output: RichTextLabel):
	active_menu = "main"
	output.clear()
	output.append_text("\nSettings Menu:\n1. Graphical\n2. Volume\n3. Extra\n4. Exit")
	output.append_text("\nType a number or the corresponding word.")

func handle_value_input(value: String, output: RichTextLabel):
	var input_value = value.to_int()
	if active_menu == "volume":
		set_volume(awaiting_input_for, input_value, output)
	awaiting_input_for = ""  # Reset input state

func handle_settings_command(command: String, output: RichTextLabel):
	if awaiting_input_for != "":
		handle_value_input(command, output)
		return

	match active_menu:
		"main": handle_main_menu(command, output)
		"graphical": handle_graphical_settings(command, output)
		"resolution": handle_resolution_selection(command, output)
		"volume": handle_volume_settings(command, output)
		_:
			output.append_text("\nExiting settings.")
			active_menu = ""

func handle_main_menu(command: String, output: RichTextLabel):
	match command.to_lower():
		"1", "graphical": show_graphical_settings(output)
		"2", "volume": show_volume_settings(output)
		"4", "exit":
			active_menu = ""
			output.append_text("\nExiting settings.")
		_:
			output.append_text("\nInvalid option. Please type a number or word.")

func show_graphical_settings(output: RichTextLabel):
	active_menu = "graphical"
	output.clear()
	output.append_text("\nGraphical Settings:\n1. Resolution\n2. Fullscreen\n3. Back")

func handle_graphical_settings(command: String, output: RichTextLabel):
	match command.to_lower():
		"1", "resolution": show_resolution_options(output)
		"2", "fullscreen": toggle_fullscreen(output)
		"3", "back": show_settings_menu(output)
		_:
			output.append_text("\nInvalid graphical command.")

func show_resolution_options(output: RichTextLabel):
	active_menu = "resolution"
	output.clear()
	output.append_text("\nResolution Options: (the resolution is not true, but i dont remember how to remove it without breaking everything lmao)")
	for i in range(resolutions.size()):
		var res = resolutions[i]
		output.append_text("\n%d. %dx%d" % [i + 1, res["width"], res["height"]])
	output.append_text("\n4. Done")
	output.append_text("\nType the number of your desired resolution or '4' to return.")

func handle_resolution_selection(command: String, output: RichTextLabel):  
	var option = command.to_int()
	if option in [1, 2, 3]:  
		set_resolution(option, output)  
	elif option == 4:
		show_graphical_settings(output)  
	else:
		output.append_text("\nInvalid resolution option. Please type a valid number.")  

func set_main_reference(main_node):
	main_reference = main_node 

func set_resolution(option: int, output: RichTextLabel):
	if main_reference == null:
		output.append_text("\nError: Main reference is missing.")
		return

	if not main_reference.has_method("get_subviewport_container"):
		output.append_text("\nError: Main does not have get_subviewport_container().")
		return

	var subviewport_container = main_reference.get_subviewport_container()
	if subviewport_container == null:
		output.append_text("\nError: SubViewportContainer not found.")
		return

	match option:
		1:
			subviewport_container.stretch_shrink = 2
			output.append_text("\nRender scale set to 50%.")
		2:
			subviewport_container.stretch_shrink = 3
			output.append_text("\nRender scale set to 33%.")
		3:
			subviewport_container.stretch_shrink = 4
			output.append_text("\nRender scale set to 25%.")
		_:
			output.append_text("\nInvalid resolution option. Please type a valid number.")





func toggle_fullscreen(output: RichTextLabel):
	match DisplayServer.window_get_mode():
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			output.append_text("\nFullscreen disabled.")
		DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			output.append_text("\nFullscreen enabled.")

func show_volume_settings(output: RichTextLabel):
	active_menu = "volume"
	output.clear()
	output.append_text("\nVolume Settings:")
	output.append_text("\nMaster: %d\nMusic: %d\nSound: %d" % [master_volume, music_volume, sound_volume])
	output.append_text("\nType 'master 50' to set master volume to 50")
	output.append_text("\nOr type 'back' to return.")

func handle_volume_settings(command: String, output: RichTextLabel):
	var parts = command.split(" ")
	match parts[0].to_lower():
		"back":
			show_settings_menu(output)
		"master", "music", "sound":
			if parts.size() == 2:
				set_volume(parts[0], parts[1].to_int(), output)
			else:
				output.append_text("\nInvalid command. Use '<type> <value>'.")
		_:
			output.append_text("\nInvalid volume command.")

func set_volume(type: String, value: int, output: RichTextLabel):
	match type:
		"master": master_volume = value
		"music": music_volume = value
		"sound": sound_volume = value
		_: output.append_text("\nUnknown volume type."); return

	# Apply the change
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(type.capitalize()), value)
	output.append_text("\nSet %s volume to %d." % [type, value])

func is_active() -> bool:
	return active_menu != ""

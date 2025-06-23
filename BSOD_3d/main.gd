extends Node

var pause_menu
var command_input
var command_output
var is_confirming_reset = false  
var glitch_timer = 2.0  
var bonus_menu_active = false  


var subviewport_container
@onready var settings_manager = preload("res://settings.gd").new() 
@onready var camera = $"SubViewportContainer/SubViewport/Node3D/CharacterBody3D/Marker3D/Camera3D"
@onready var health = $SubViewportContainer/SubViewport/Node3D/CharacterBody3D.health
@onready var freaky = $SubViewportContainer/SubViewport/Freaky
@onready var datamoshing = $SubViewportContainer/SubViewport/Freaky/Datamoshing
@onready var freaky2 = $SubViewportContainer/SubViewport/Freaky/Freaky2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	$LevelManager.load_level("res://levels/track.tscn")
	pause_menu = $PauseMenu
	command_input = $PauseMenu/TextEdit
	command_output = $PauseMenu/RichTextLabel

	
	pause_menu.visible = false
	
	await get_tree().process_frame
	subviewport_container = get_node_or_null("SubViewportContainer")
	if subviewport_container == null:
		print("Error: SubViewportContainer not found in Main!")
	else:
		print("SubViewportContainer successfully stored in Main.")
	settings_manager.set_main_reference(self)
	

func get_subviewport_container():
	return subviewport_container

func _input(event):
	if not get_tree().paused and camera:
		camera._custom_mouse_input(event)  

	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	get_tree().paused = not get_tree().paused
	pause_menu.visible = get_tree().paused
	if get_tree().paused:
		command_input.grab_focus()

func _process(_delta):
	if command_input.has_focus() and Input.is_action_just_pressed("ui_accept"):
		var command = command_input.text.strip_edges()
		command_input.clear()
		
		if is_confirming_reset:
			handle_reset_confirmation(command)
		elif bonus_menu_active:
			handle_bonus_command(command)
		else:
			handle_command(command)
	if command_input.has_focus() and Input.is_action_just_pressed("fs"):
		match DisplayServer.window_get_mode():
			DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		

##Command Handling
func handle_command(command: String):
	var parts = command.split(" ", false) 
	if parts.size() == 2 and parts[0].to_lower() == "load":
		var level_path = "res://levels/" + parts[1] + ".tscn"
		if ResourceLoader.exists(level_path):  
			command_output.append_text("\nLoading level: %s..." % parts[1])
			$LevelManager.load_level(level_path)
			get_tree().paused = false  
		else:
			command_output.append_text("\nError: Wrong path (%s)" % level_path)
	match command.to_lower():
		"save game":
			save_game()
		"reset":
			command_output.append_text("\n>Are you sure? (y/n)")
			is_confirming_reset = true
		"settings":
			settings_manager.show_settings_menu(command_output)
		"dbg":
			debug_mode()
		"return":
			command_output.append_text("\nReturning to main...")
			$LevelManager.return_to_main()
		_:
			if settings_manager.is_active():
				settings_manager.handle_settings_command(command, command_output)
			else:
				command_output.append_text("\nUnknown command: %s" % command)

func handle_reset_confirmation(command: String):
	command = command.to_lower()
	match command:
		"y", "yes":
			command_output.append_text("\nResetting...")
			is_confirming_reset = false
			health = 0
			get_tree().paused = false
		"n", "no":
			command_output.append_text("\nReset canceled.")
			is_confirming_reset = false
		_:
			command_output.append_text("\nPlease type 'y' or 'n'.")

##Bonus Menu
func debug_mode():
	bonus_menu_active = true
	command_output.append_text("\n :-) ")

func handle_bonus_command(command: String):
	command = command.to_lower()
	var command_parts = command.split(" ")
	match command:
		"ups":
			get_tree().paused = false
		"mouse", "ms":
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				command_output.append_text("\nMouse hidden.")
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				command_output.append_text("\nMouse visible.")
		"cheatc":
			command_output.append_text("\nCheat activated! (does nothing for now)")
		"cat":
			play_cat_animation()
			$SubViewportContainer/SubViewport/Node3D/CharacterBody3D.die()
		"dmg": 
			toggle_pause()
			$SubViewportContainer/SubViewport/Node3D/CharacterBody3D.apply_damage(15)
			await get_tree().create_timer(3).timeout
			$SubViewportContainer/SubViewport/Node3D/CharacterBody3D.apply_damage(30)
			await get_tree().create_timer(3).timeout
			$SubViewportContainer/SubViewport/Node3D/CharacterBody3D.apply_damage(40)
		"heal":
			$SubViewportContainer/SubViewport/Node3D/CharacterBody3D.apply_damage(-30)
			
		
		"exit":
			bonus_menu_active = false
			command_output.append_text("\nExiting Debug.")
		_:
			command_output.append_text("\nUnknown bonus command.")
			bonus_menu_active = false
			command_output.append_text("\nExiting Bonus Menu.")

func play_cat_animation():
	var cat_sprite = $cat  
	if cat_sprite:
		cat_sprite.visible = true
		if cat_sprite.has_method("play"):
			cat_sprite.play()  
		else:
			print("Error: Cat node does not support animations.")
	health = 0
	get_tree().paused = false

# **Other Functions**
func save_game():
	command_output.append_text("\nGame saved!")

##glitch effects and shader logic

func death_glitch():
	get_tree().paused = true
	await get_tree().create_timer(glitch_timer).timeout
	get_tree().paused = false

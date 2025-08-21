extends Node2D

var bsod_timer = 3.0  # Time in seconds to show BSOD screen
var current_option_index = 0

func _ready() -> void:
	$BSODPanel.visible = true
	$OptionsPanel.visible = false
	hide_cursor()
	# Show BSOD for a few seconds, then display options
	await get_tree().create_timer(bsod_timer).timeout
	$BSODPanel.visible = false
	$OptionsPanel.visible = true

func _input(event):
	if $OptionsPanel.visible:
		if event.is_action_pressed("ui_down"):
			select_next_option(1)
		elif event.is_action_pressed("ui_up"):
			select_next_option(-1)
		elif event.is_action_pressed("ui_accept"):
			confirm_option()

func select_next_option(direction: int):
	current_option_index = (current_option_index + direction) % 3  # 3 options
	if current_option_index < 0:
		current_option_index = 2
	highlight_option(current_option_index)

func highlight_option(index: int):
	for i in range(3):
		var button = $OptionsPanel.get_child(i + 1)  # Skip label
		button.grab_focus() if i == index else button.release_focus()

func confirm_option():
	match current_option_index:
		0:
			restart_game()
		1:
			quit_game()
		2:
			return_to_game()

func restart_game():
	get_tree().change_scene_to_file("res://Main.tscn")  # Corrected function call

func quit_game():
	get_tree().quit()

func return_to_game():
	get_tree().change_scene_to_file("res://Main.tscn")  # Corrected function call

func hide_cursor():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

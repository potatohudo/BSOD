extends Node2D

var bsod_timer = 0.0  # Initialize bsod_timer
var bsod_active = false  # Tracks if the BSOD is currently active

func _ready() -> void:
	$BSODPanel.visible = true
	$BS.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	bsod_active = true

func _input(event):
	if bsod_active and event.is_action_pressed("ui_accept"): 
		_return()

func _return():
	bsod_timer = randf_range(0.8, 3.0)  
	await get_tree().create_timer(bsod_timer).timeout 
	$BSODPanel.visible = false
	$BS.visible = true
	bsod_active = false  
	await get_tree().create_timer(1).timeout  
	get_tree().change_scene_to_file("res://pc/pc.tscn")  
#yeah there will be a different gameover screen

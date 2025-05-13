extends Control

@onready var title_bar = $NPR/TitleBar
@onready var close_button = $NPR/TitleBar/Close
@onready var hide_button = $NPR/TitleBar/Hide


var resizing := false
var resize_start := Vector2.ZERO
var original_size := Vector2.ZERO

var dragging := false
var drag_offset := Vector2.ZERO

func _ready():
	await get_tree().process_frame
	close_button.pressed.connect(queue_free)
	hide_button.pressed.connect(func(): visible = false)
	title_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	
	title_bar.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
			else:
				dragging = false
		elif event is InputEventMouseMotion and dragging:
			global_position = get_global_mouse_position() - drag_offset
	)
	var resize_handle = $NinePatchRect/ResizeHandle
	resize_handle.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				resizing = true
				resize_start = get_global_mouse_position()
				original_size = size
			else:
				resizing = false
		elif event is InputEventMouseMotion and resizing:
			var delta = get_global_mouse_position() - resize_start
			size = original_size + delta)
	
func set_title(text: String):
	var title = $NPR/TitleBar/Label
	title.text = text

func set_content(node: Control):
	var content_container = $NPR/Content
	content_container.add_child(node)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()

extends Control

#just don't touch this.

@onready var title_bar = $NPR/TitleBar
@onready var close_button = $NPR/TitleBar/Close
@onready var hide_button = $NPR/TitleBar/Hide
@onready var resize_handle = $NPR/ResizeHandle

var dragging := false
var drag_offset := Vector2.ZERO

var resizable: bool = true
var resizing := false
var resize_start := Vector2.ZERO
var original_size := Vector2.ZERO
var original_position := Vector2.ZERO
var resize_dir := Vector2.ZERO

var edge_margin := 8
var corner_margin := 16

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



	resize_handle.gui_input.connect(func(event):
		if not resizable:
			return  
		
		var local_pos = event.position
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				resize_dir = _get_resize_direction(local_pos)
				if resize_dir != Vector2.ZERO:
					resizing = true
					resize_start = get_global_mouse_position()
					original_size = size
					original_position = global_position
					get_viewport().set_input_as_handled()
			else:
				resizing = false

		elif event is InputEventMouseMotion and resizing:
			var delta = get_global_mouse_position() - resize_start
			var new_size = original_size
			var new_pos = original_position

			if resize_dir.x != 0:
				new_size.x += delta.x * resize_dir.x
				if resize_dir.x == -1:
					new_pos.x -= delta.x
			if resize_dir.y != 0:
				new_size.y += delta.y * resize_dir.y
				if resize_dir.y == -1:
					new_pos.y -= delta.y

			new_size.x = max(new_size.x, 200)
			new_size.y = max(new_size.y, 150)

			size = new_size
			global_position = new_pos
	)

func _process(delta):
	if not resizable:
		resize_handle.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	
	var local_mouse = resize_handle.get_local_mouse_position()
	var dir = _get_resize_direction(local_mouse)

	if dir == Vector2(1, 1) or dir == Vector2(-1, -1):
		resize_handle.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
	elif dir == Vector2(1, -1) or dir == Vector2(-1, 1):
		resize_handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	elif dir.x != 0:
		resize_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	elif dir.y != 0:
		resize_handle.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	else:
		resize_handle.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _get_resize_direction(pos: Vector2) -> Vector2:
	var size = resize_handle.size
	var dir = Vector2.ZERO

	# Corners first (take priority)

	if pos.x <= corner_margin and pos.y >= size.y - corner_margin:
		dir = Vector2(-1, 1)  # bottom-left
	elif pos.x >= size.x - corner_margin and pos.y >= size.y - corner_margin:
		dir = Vector2(1, 1)  # bottom-right

	# Edges
	elif pos.x <= edge_margin:
		dir = Vector2(-1, 0)  # left
	elif pos.x >= size.x - edge_margin:
		dir = Vector2(1, 0)  # right
	elif pos.y >= size.y - edge_margin:
		dir = Vector2(0, 1)  # bottom

	return dir

func set_title(text: String):
	var title = $NPR/TitleBar/Label
	title.text = text

func set_content(node: Control):
	var content_container = $NPR/Content
	content_container.add_child(node)
	#node.wrap_mode = "boundary"
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()

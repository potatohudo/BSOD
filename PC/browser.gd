extends Control

# === Browser Window Nodes ===
@onready var window = $Control/NPR
@onready var loader = $Control/NPR/SubViewportContainer/SubViewport/Loader
@onready var te = $Control/NPR/SubViewportContainer/SubViewport/Control1/Panel2/TextEdit


# === Window Components ===
@onready var title_bar = $Control/NPR/TitleBar
@onready var close_button = $Control/NPR/TitleBar/Close
@onready var hide_button = $Control/NPR/TitleBar/Hide
@onready var resize_handle = $Control/NPR/ResizeHandle

# === State ===
var dragging := false
var drag_offset := Vector2.ZERO

var resizing := false
var resize_start := Vector2.ZERO
var original_size := Vector2.ZERO
var original_position := Vector2.ZERO
var resize_dir := Vector2.ZERO

var edge_margin := 8
var corner_margin := 16

var original_window_size := Vector2.ZERO

var site_registry = {
	"home": "res://browser.tscn",
	"meow.com": "res://sites/s1.tscn",
	"void.net": "res://sites/s2.tscn"
}

func _ready():
	await get_tree().process_frame
	original_window_size = window.size

	close_button.pressed.connect(func(): window.hide())
	hide_button.pressed.connect(func(): window.hide())

	title_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	title_bar.gui_input.connect(_on_title_bar_input)
	resize_handle.gui_input.connect(_on_resize_input)

func _process(_delta):
	if resize_handle:
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
	if te.has_focus() and Input.is_action_just_pressed("ui_accept"):
		var url = te.text.strip_edges()
		te.clear()
		load_site(url)

func _on_title_bar_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

func _on_resize_input(event):
	var local_pos = event.position

	# Declare these at the top so they're always available
	var new_size := Vector2.ZERO
	var new_pos := Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			resize_dir = _get_resize_direction(local_pos)
			if resize_dir != Vector2.ZERO:
				resizing = true
				resize_start = get_global_mouse_position()
				original_size = window.size
				original_position = window.global_position
				get_viewport().set_input_as_handled()
		else:
			resizing = false

	elif event is InputEventMouseMotion and resizing:
		var delta = get_global_mouse_position() - resize_start
		new_size = original_size
		new_pos = original_position

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

		window.size = new_size
		window.global_position = new_pos



func _get_resize_direction(pos: Vector2) -> Vector2:
	var size = resize_handle.size
	var dir = Vector2.ZERO
	if pos.x <= corner_margin and pos.y >= size.y - corner_margin:
		dir = Vector2(-1, 1)
	elif pos.x >= size.x - corner_margin and pos.y >= size.y - corner_margin:
		dir = Vector2(1, 1)
	elif pos.x <= edge_margin:
		dir = Vector2(-1, 0)
	elif pos.x >= size.x - edge_margin:
		dir = Vector2(1, 0)
	elif pos.y >= size.y - edge_margin:
		dir = Vector2(0, 1)
	return dir

func _on_TE_text_submitted(new_text: String) -> void:
	load_site(new_text.strip_edges().to_lower())

func load_site(url: String):
	if not url in site_registry:
		push_error("Unknown site: %s" % url)
		return

	var site_path = site_registry[url]
	if not ResourceLoader.exists(site_path):
		push_error("Scene does not exist at: %s" % site_path)
		return

	# Clean loader
	for child in loader.get_children():
		child.queue_free()

	await get_tree().process_frame  # wait for cleanup to finish

	# Load and add
	var site_scene = load(site_path)
	if site_scene:
		var site_instance = site_scene.instantiate()
		loader.add_child(site_instance)
		print("Loaded site:", url)
	else:
		push_error("Failed to instantiate scene at: %s" % site_path)

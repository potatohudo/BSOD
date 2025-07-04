extends Control

# === Browser Window Nodes ===
@onready var loader = $ScrollContainer/Loader
@onready var te = $Control/Panel2/TextEdit
@onready var scrollbar = $ScrollContainer/VScrollBar


var usage: Vector2 = Vector2(18.0, 22.0)

func get_usage() -> Vector2:
	return usage

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
	"home": "res://pc/browser.tscn",
	"meow.com": "res://pc/sites/s1.tscn",
	"void.net": "res://pc/sites/s2.tscn",
	"8chan.org": "res://pc/sites/forum.tscn"
}

func _ready():
	await get_tree().process_frame
	
	scrollbar.value_changed.connect(func(value):
		if loader.get_child_count() == 0:
			return
		var site = loader.get_child(0)
		if site:
			site.position.y = -value
	)
	

func _unhandled_input(event):
	if loader.get_child_count() == 0:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scrollbar.value -= 30
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scrollbar.value += 30
			


var previous_height := 0.0
func _process(_delta):

	if te.has_focus() and Input.is_action_just_pressed("ui_accept"):
		var url = te.text.strip_edges()
		te.clear()
		load_site(url)
	if loader.get_child_count() > 0:
		var site = loader.get_child(0)
		if site:
			var content_height = site.size.y
			if content_height != previous_height:
				previous_height = content_height
				

func _on_title_bar_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

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

	await get_tree().process_frame  
	# Load and add
	var site_scene = load(site_path)
	if site_scene:
		var site_instance = site_scene.instantiate()
		loader.add_child(site_instance)
		
		loader.anchor_left = 0
		loader.anchor_top = 0
		loader.anchor_right = 1
		loader.anchor_bottom = 1
		loader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		loader.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var site_scroll := 1500  

		if "scroll" in site_instance:
			site_scroll = site_instance.scroll
			scrollbar.max_value = max(site_scroll - loader.size.y, 0)
			scrollbar.value = 0  # Reset to top
		else:
			scrollbar.max_value = 0
			scrollbar.value = 0

		site_instance.position.y = -scrollbar.value

extends Control

@onready var window = $Window
@onready var loader = $Window/SubViewportContainer/SubViewport/Loader
@onready var te = $Window/SubViewportContainer/SubViewport/Control/Panel2/TextEdit


var site_registry = {
	"home": "res://browser.tscn",
	"meow.com": "res://sites/s1.tscn",
	"void.net": "res://sites/s2.tscn",

}




func _process(_delta):
	if te.has_focus() and Input.is_action_just_pressed("ui_accept"):
		var url = te.text.strip_edges()
		te.clear()
		load_site(url)

func _on_TE_text_submitted(new_text: String) -> void:
	load_site(new_text.strip_edges().to_lower())


func load_site(url: String):
	if url in site_registry:
		var site_path = site_registry[url]
		if ResourceLoader.exists(site_path):
			for child in loader.get_children():
				child.queue_free()
				

			var scene = load(site_path).instantiate()
			loader.add_child(scene)
			$"Window/SubViewportContainer/SubViewport/ScrollCamera".update_scroll_limits()
		else:
			print("Error: Scene at %s does not exist!" % site_path)
			
	else:
		print("Unknown site:", url)


var original_window_size := Vector2.ZERO

func _ready():
	original_window_size = window.size
	window.close_requested.connect(_on_close_requested)



func _on_close_requested():
	window.hide()
	window.set_process(false)
	window.size = original_window_size  

	for child in loader.get_children():
		child.queue_free()

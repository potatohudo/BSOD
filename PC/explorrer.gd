extends Control

@onready var tree = $HBoxContainer/Tree
@onready var item_list = $VBoxContainer2/ItemList
@onready var rtlabel = $VBoxContainer2/RichTextLabel
@onready var te = $Panel/TextEdit
@onready var cmd = $Panel/RichTextLabel2
@onready var loader = $"Loader"


var file_system = {
	"root": {
		"HKEY_CLASSES_ROOT": {
			"txtfile": { "example.txt": "wawawa" },
			"pngfile": { "image.png": "PNG Image Data" }
		},
		"HKEY_CURRENT_USER": {
			"Software": {
				"MyApp": { "config.ini": "user_settings = true" }
			}
		},
		"HKEY_LOCAL_MACHINE": {
			"System": { "kernel.sys": "System File Data" }
		}
	}
}

var current_path = "root"

func _ready():
	populate_tree()
	item_list.item_selected.connect(_on_item_selected)  # Single-click event
	item_list.item_activated.connect(_on_item_activated)  # Double-click event
	

func populate_tree():
	tree.clear()
	var root = tree.create_item()
	root.set_text(0, "root")
	root.set_metadata(0, "root")
	add_folders(root, file_system["root"], "root")

func add_folders(parent, directory, parent_path):
	for name in directory.keys():
		if directory[name] is Dictionary:
			var item = tree.create_item(parent)
			item.set_text(0, name)  
			item.set_metadata(0, parent_path + "/" + name)
			add_folders(item, directory[name], parent_path + "/" + name)


func _on_tree_item_selected():
	var selected_item = tree.get_selected()
	if selected_item:
		current_path = selected_item.get_metadata(0)
		update_file_list()


func update_file_list():
	item_list.clear()
	var folder = get_folder_at_path(current_path)
	if folder:
		for item in folder.keys():
			if folder[item] is Dictionary:
				continue
			item_list.add_item(item)

func get_folder_at_path(path_str):
	var keys = path_str.split("/")
	var folder = file_system
	for key in keys:
		if key in folder and folder[key] is Dictionary:
			folder = folder[key]
		else:
			return null
	return folder
	

func _on_item_selected(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = get_folder_at_path(current_path)
	if folder and file_name in folder:
		rtlabel.text = "[b]File:[/b] " + file_name + "\n" + "[i]Contents:[/i] " + folder[file_name]

func _on_item_activated(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = get_folder_at_path(current_path)
	if folder and file_name in folder:
		open_file_window(file_name, folder[file_name])




func open_file_window(name: String, content, separate: bool = false):
	var file_window_scene = preload("res://window.tscn")
	var file_window = file_window_scene.instantiate()

	file_window.set_title(name)
	file_window.position = Vector2(100, 100)
	file_window.size = Vector2(600, 400)

	if separate and content is String:
		if ResourceLoader.exists(content):
			var scene_instance = load(content).instantiate()
			file_window.set_content(scene_instance)
		else:
			var error_label = Label.new()
			error_label.text = "Error: Could not load scene at path:\n" + content
			file_window.set_content(error_label)
	else:
		var text_label = RichTextLabel.new()
		text_label.text = str(content)
		text_label.scroll_active = true
		text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		file_window.set_content(text_label)

	loader.add_child(file_window)
	file_window.show()

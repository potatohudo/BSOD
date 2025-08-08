extends Control

@onready var tree = $HBoxContainer/Tree
@onready var item_list = $AspectRatioContainer/VBoxContainer2/ItemList
@onready var rtlabel = $AspectRatioContainer/VBoxContainer2/RichTextLabel

var current_path: String = "root"
var usage: Vector2 = Vector2(18.0, 22.0)

func get_usage() -> Vector2:
	return usage

func _ready():
	populate_tree()
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	tree.item_selected.connect(_on_tree_item_selected)

# Build the Tree: only folders go here
func populate_tree():
	tree.clear()
	var root_item = tree.create_item()
	root_item.set_text(0, "root")
	root_item.set_metadata(0, "root")
	add_folders(root_item, Global.get_folder_at_path("root"), "root")

func add_folders(parent_item, directory: Dictionary, parent_path: String):
	for name in directory.keys():
		var entry = directory[name]

		# Skip files (have "filecontent")
		if typeof(entry) == TYPE_DICTIONARY and entry.has("filecontent"):
			continue

		# Folder: add to tree
		if typeof(entry) == TYPE_DICTIONARY:
			var item = tree.create_item(parent_item)
			item.set_text(0, name)
			item.set_metadata(0, parent_path + "/" + name)
			add_folders(item, entry, parent_path + "/" + name)

# When user selects a folder in the tree
func _on_tree_item_selected():
	var selected_item = tree.get_selected()
	if selected_item:
		current_path = selected_item.get_metadata(0)
		update_file_list()

# Populate ItemList: only files from selected folder
func update_file_list():
	item_list.clear()
	var folder = Global.get_folder_at_path(current_path)
	if folder:
		for name in folder.keys():
			var entry = folder[name]
			if typeof(entry) == TYPE_DICTIONARY and entry.has("filecontent") and entry.get("display", true):
				item_list.add_item(name)

# When a file is selected in the ItemList (just preview)
func _on_item_selected(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = Global.get_folder_at_path(current_path)
	if folder and file_name in folder:
		var entry = folder[file_name]
		var saved_data = Save.get_file_data(file_name)
		var content = saved_data.get("content", entry.get("filecontent", ""))
		rtlabel.text = "[b]File:[/b] " + file_name + "\n[i]Contents:[/i]\n" + str(content)

# When a file is double-clicked or activated (open in window)
func _on_item_activated(index: int):
	var file_name = item_list.get_item_text(index)
	var folder = Global.get_folder_at_path(current_path)
	if folder and folder.has(file_name):
		var file_entry = folder[file_name]
		if typeof(file_entry) == TYPE_DICTIONARY and file_entry.has("filecontent"):
			var editable = file_entry.get("editable", true)
			var ext = file_name.get_extension().to_lower()
			var is_program = ext in ["tscn", "png"]
			var content = file_entry["filecontent"] if is_program else Save.get_file_data(file_name).get("content", file_entry["filecontent"])
			Global.open_file_window(file_name, content, is_program, editable)

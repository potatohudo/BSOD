extends Node



var target_level_path: String = ""
var just_teleported := false

@onready var player := CharacterBody2D 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	print(player)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


var system_node: Node = null

func get_folder_at_path(path_str: String) -> Dictionary:
	if system_node and system_node.has_method("get_folder_at_path"):
		return system_node.get_folder_at_path(path_str)
	return {}

func open_file_window(name: String, content, program := false, editable := true):
	if system_node and system_node.has_method("open_file_window"):
		system_node.open_file_window(name, content, program, editable)

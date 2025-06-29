extends Node

@onready var level_holder: Node3D = get_node_or_null("/root/Main/SubViewportContainer/SubViewport/Node3D/LevelHolder")
@onready var subviewport_container: SubViewportContainer = get_node_or_null("/root/Main/SubViewportContainer")

func _ready():
	# Load the level after this scene is fully in the tree
	await get_tree().process_frame

	if Global.target_level_path != "":
		load_level(Global.target_level_path)
		Global.target_level_path = ""  # Reset after loading


func load_level(level_path: String):
	if not level_holder or not subviewport_container:
		return  
	call_deferred("_load_level", level_path)

func _load_level(level_path: String):
	for child in level_holder.get_children():
		child.queue_free()

	var level_scene = ResourceLoader.load(level_path)
	if level_scene:
		var new_level = level_scene.instantiate()
		if new_level:
			level_holder.add_child(new_level, true)
			new_level.visible = true

	subviewport_container.queue_redraw()
	

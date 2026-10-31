extends Node3D

@export var min_spawn_radius: float = 2.0 # Minimum distance from fountain
@export var spawn_radius: float = 5.0
@export var spawn_height: float = 3.0
@export var jellyfish_count_per_fountain: int = 10

func _ready():
	await get_tree().process_frame
	call_deferred("_spawn_all_fountains")

func _spawn_all_fountains():
	var fountains = get_tree().get_nodes_in_group("Fountain")
	for fountain in fountains:
		_spawn_jellyfish_around(fountain)

func _spawn_jellyfish_around(fountain: Node3D):
	await get_tree().process_frame
	var jellyfish_scene: PackedScene = preload("res://3d/models/LES/les.tscn")
	for i in range(jellyfish_count_per_fountain):
		var jellyfish = jellyfish_scene.instantiate()
		add_child(jellyfish)

		var angle = randf() * TAU
		var dist = randf_range(min_spawn_radius, spawn_radius)
		var offset = Vector3(
			cos(angle) * dist,
			randf_range(-spawn_height / 2.0, spawn_height / 2.0), # vertical scatter
			sin(angle) * dist
		)
		jellyfish.global_transform.origin = fountain.global_transform.origin + offset
		jellyfish.rotation.y = randf() * TAU

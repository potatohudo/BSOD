extends Node3D

# -------- Customizable distances and counts --------
@export var inner_spawn_distance: float = 25.0
@export var outer_spawn_distance: float = 50.0

@export var inner_min_vines: int = 20
@export var inner_max_vines: int = 40
@export var outer_min_vines: int = 5
@export var outer_max_vines: int = 15

# -------- Vine look --------
@export var min_length: float = 0.5
@export var max_length: float = 2.0
@export var min_thickness: float = 0.05
@export var max_thickness: float = 0.2
@export var surface_epsilon: float = 0.01

# Material + texture
@export var vine_material: Material
@export var vine_texture: Texture2D

var player: CharacterBody3D
var fungi_nodes: Array = []

enum SpawnTier { NONE, OUTER, INNER }
var spawn_state: Dictionary = {}	# fungi -> SpawnTier
var spawn_node: Dictionary = {}		# fungi -> MultiMeshInstance3D

func _ready():
	randomize()
	player = get_node_or_null("../../CharacterBody3D")
	if not player:
		push_error("Could not find player at ../../CharacterBody3D")

	# Ensure inner <= outer to avoid dead zones
	if inner_spawn_distance > outer_spawn_distance:
		push_warning("inner_spawn_distance > outer_spawn_distance; swapping.")
		var t = inner_spawn_distance
		inner_spawn_distance = outer_spawn_distance
		outer_spawn_distance = t
	
	# Collect fungi nodes
	for fungi in get_tree().get_nodes_in_group("fungi"):
		if fungi is MeshInstance3D:
			fungi_nodes.append(fungi)
			spawn_state[fungi] = SpawnTier.NONE

func _process(_delta):
	if not player:
		return
	
	for fungi in fungi_nodes:
		var dist = fungi.global_transform.origin.distance_to(player.global_transform.origin)

		if dist <= inner_spawn_distance:
			if spawn_state.get(fungi, SpawnTier.NONE) != SpawnTier.INNER:
				_respawn_for_tier(fungi, true)	# inner
		elif dist <= outer_spawn_distance:
			if spawn_state.get(fungi, SpawnTier.NONE) != SpawnTier.OUTER:
				_respawn_for_tier(fungi, false)	# outer
		else:
			if spawn_state.get(fungi, SpawnTier.NONE) != SpawnTier.NONE:
				_clear_vines(fungi)

func _respawn_for_tier(fungi: MeshInstance3D, is_inner: bool) -> void:
	_clear_vines(fungi)

	var count = randi_range(inner_min_vines, inner_max_vines) if is_inner else randi_range(outer_min_vines, outer_max_vines)
	var label = "VinesInner" if is_inner else "VinesOuter"

	var node = _spawn_vines(fungi, count, label)
	spawn_node[fungi] = node
	spawn_state[fungi] = SpawnTier.INNER if is_inner else SpawnTier.OUTER


func _clear_vines(fungi: MeshInstance3D) -> void:
	if spawn_node.has(fungi):
		var mm: MultiMeshInstance3D = spawn_node[fungi]
		if is_instance_valid(mm):
			mm.queue_free()
	spawn_node.erase(fungi)
	spawn_state[fungi] = SpawnTier.NONE

func _spawn_vines(fungi: MeshInstance3D, count: int, label: String) -> MultiMeshInstance3D:
	var aabb := fungi.get_aabb()

	var mm_instance := MultiMeshInstance3D.new()
	mm_instance.name = label
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	# Vine mesh primitive (capsule-as-segment)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.05
	capsule.height = 0.5
	mm.mesh = capsule
	mm.instance_count = count
	mm_instance.multimesh = mm

	# Material + texture
	if vine_material:
		var mat_to_use := vine_material
		if vine_texture and vine_material is ShaderMaterial:
			mat_to_use = vine_material.duplicate()
			mat_to_use.set_shader_parameter("albedo_texture", vine_texture)
		mm_instance.material_override = mat_to_use

	fungi.add_child(mm_instance)

	for i in range(count):
		var thickness := randf_range(min_thickness, max_thickness)
		var length := randf_range(min_length, max_length)

		var total_len = (capsule.height + capsule.radius * 2.0) * length
		var half_len = total_len * 0.5

		var lx := 0.0
		var lz := 0.0
		var bottom_y := 0.0

		if fungi.mesh is CylinderMesh:
			var cyl: CylinderMesh = fungi.mesh
			# Use bottom_radius since we place at the base (y = -height/2)
			var radius = cyl.bottom_radius
			var height = cyl.height
			var angle = randf() * TAU
			var r = sqrt(randf()) * radius	# uniform in disk
			lx = cos(angle) * r
			lz = sin(angle) * r
			bottom_y = -height * 0.5
		else:
			# Fallback: spawn within the AABB footprint
			lx = randf_range(aabb.position.x, aabb.position.x + aabb.size.x)
			lz = randf_range(aabb.position.z, aabb.position.z + aabb.size.z)
			bottom_y = aabb.position.y

		var local_pos = Vector3(lx, bottom_y - surface_epsilon, lz)
		var world_pos = fungi.global_transform * local_pos

		var vine_xform = Transform3D()
		vine_xform.origin = world_pos - Vector3(0, half_len, 0)
		vine_xform.basis = Basis().scaled(Vector3(thickness, length, thickness))
		vine_xform = fungi.global_transform.affine_inverse() * vine_xform

		mm.set_instance_transform(i, vine_xform)

	return mm_instance

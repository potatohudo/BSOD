extends Node3D

@export var min_vines: int = 10
@export var max_vines: int = 20
@export var min_length: float = 0.5
@export var max_length: float = 2.0
@export var min_thickness: float = 0.05
@export var max_thickness: float = 0.2
@export var surface_epsilon: float = 0.01
@export var vine_material: Material

func _ready():
	for fungi in get_tree().get_nodes_in_group("fungi"):
		if fungi is MeshInstance3D:
			_spawn_vines(fungi)
			

func _spawn_vines(fungi: MeshInstance3D):
	var aabb := fungi.get_aabb()
	var count := randi_range(min_vines, max_vines)

	var mm_instance := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.05
	capsule.height = 0.5
	mm.mesh = capsule
	mm.instance_count = count
	mm_instance.multimesh = mm

	if vine_material:
		mm_instance.material_override = vine_material

	fungi.add_child(mm_instance)

	for i in range(count):
		var thickness := randf_range(min_thickness, max_thickness)
		var length := randf_range(min_length, max_length)

		var source_total: float = capsule.height + capsule.radius * 2.0
		var total_len: float = source_total * length
		var half_len: float = total_len * 0.5

		var lx := randf_range(aabb.position.x, aabb.position.x + aabb.size.x)
		var lz := randf_range(aabb.position.z, aabb.position.z + aabb.size.z)
		var bottom_y := aabb.position.y

		var local_pos = Vector3(lx, bottom_y - surface_epsilon, lz)

		# Build a transform where Y axis points down globally
		var world_pos = fungi.global_transform * local_pos
		var vine_xform = Transform3D()
		vine_xform.origin = world_pos - Vector3(0, half_len, 0)
		vine_xform.basis = Basis().scaled(Vector3(thickness, length, thickness))

		# Convert back into fungi-local space so MultiMeshInstance3D can use it
		vine_xform = fungi.global_transform.affine_inverse() * vine_xform

		mm.set_instance_transform(i, vine_xform)



	print("Spawned vines:", count, "for", fungi.name)

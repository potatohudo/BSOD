extends Node3D

@export var base_material: ShaderMaterial
@export var core_slice_count: int = 3
@export var field_radius: float = 3.0
@export var slice_scale: float = 1.0
@export var rotation_speed_deg: float = 10.0
@export var shrink_amount: float = 1.0
@export var face_camera := true
@export var u_zturn := true
@export var camera_path: NodePath

var camera: Camera3D = null


func _ready() -> void:
	_resolve_camera()
	_build_slices()
	set_process(true)


# -----------------------------------------------------
# Camera
# -----------------------------------------------------
func _resolve_camera() -> void:
	if camera_path != NodePath(""):
		camera = get_node_or_null(camera_path) as Camera3D
	if camera == null:
		camera = get_viewport().get_camera_3d()


func _face_camera() -> void:
	if camera == null:
		_resolve_camera()
	if camera == null:
		return
	look_at(camera.global_transform.origin, Vector3.UP)


func _process(delta: float) -> void:
	_update_zrot()

	if face_camera:
		_face_camera()


# -----------------------------------------------------
# Update u_zrot
# -----------------------------------------------------
func _update_zrot() -> void:
	var rot_y: float = global_transform.basis.get_euler().y

	for c in get_children():
		if not (c is MeshInstance3D):
			continue

		var q := c as MeshInstance3D
		var mat := q.material_override as ShaderMaterial
		if mat == null:
			continue

		var rot_val: float = rot_y

		if not face_camera and u_zturn:
			if camera == null:
				_resolve_camera()
			if camera != null:
				var p: Vector3 = global_transform.origin
				var cam_pos: Vector3 = camera.global_transform.origin
				rot_val = atan2(cam_pos.x - p.x, cam_pos.z - p.z)

		mat.set_shader_parameter("u_zrot", rot_val * rotation_speed_deg)


# -----------------------------------------------------
# Build slices
# -----------------------------------------------------
func _build_slices() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.queue_free()

	if base_material == null:
		return

	var total: int = core_slice_count

	for i in range(total):
		var t: float = float(i) / float(max(1, total - 1))
		_create_slice(t)


# -----------------------------------------------------
# Create a single slice
# -----------------------------------------------------
func _create_slice(t: float) -> void:
	var q := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	q.mesh = mesh

	var mat := base_material.duplicate() as ShaderMaterial
	q.material_override = mat

	add_child(q)
	if Engine.is_editor_hint():
		q.owner = get_tree().edited_scene_root

	q.rotate_x(-PI/2)
	q.rotation_degrees = Vector3(180, 0, 0)

	var z: float = (t - 0.5) * 2.0 * field_radius
	q.transform.origin = Vector3(0, 0, z)

	var overlap: float = 1.25
	var edge: float = abs(t - 0.5) * 2.0
	var s: float = max(1.0 - edge * shrink_amount, 0.001) * overlap
	q.scale = Vector3(s, s, s)

	mat.set_shader_parameter("u_slice_t", t)
	mat.set_shader_parameter("u_field_radius", field_radius)

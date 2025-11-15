@tool
extends Node3D

@export var base_material: ShaderMaterial
@export var quad_count: int = 5
@export var field_radius: float = 3.0
@export var slice_scale: float = 1.0
@export var rotation_speed_deg: float = 10.0
@export var face_camera := true

@export_enum("Stack","Grid","Sphere","Cube")
var layout_mode := "Stack"

@export var camera_path: NodePath

var camera: Camera3D


func _ready():
	_resolve_camera()
	_build_quads()
	set_process(true)


func _resolve_camera():
	if camera_path:
		camera = get_node_or_null(camera_path)
	if camera == null:
		camera = get_viewport().get_camera_3d()


var rot_acc := 0.0

func _process(delta):
	if rotation_speed_deg != 0.0:
		rot_acc += deg_to_rad(rotation_speed_deg) * delta

		# apply to each quad's material
		for q in get_children():
			if q is MeshInstance3D:
				var mat = q.material_override
				if mat:
					mat.set_shader_parameter("u_global_rot", rot_acc)

	if face_camera:
		_face_camera()

func _build_quads():
	# remove old
	for c in get_children():
		c.queue_free()

	if base_material == null:
		return

	for i in range(quad_count):
		var q = MeshInstance3D.new()
		var mesh = QuadMesh.new()
		mesh.size = Vector2(1,1)
		q.mesh = mesh

		var mat = base_material.duplicate()
		q.material_override = mat

		add_child(q)
		if Engine.is_editor_hint():
			q.owner = get_tree().edited_scene_root

		_set_quad_transform(i, q)
		_set_quad_params(i, mat)


func _set_quad_transform(i: int, q: MeshInstance3D):
	var t = float(i) / max(1, quad_count - 1)   # 0..1

	if layout_mode == "Stack":
		var offset = (t - 0.5) * 2.0 * field_radius
		q.transform.origin = Vector3(0, 0, offset)

	elif layout_mode == "Grid":
		q.transform.origin = Vector3((i%2 - 0.5)*2, (i/2 - 0.5)*2, 0) * field_radius

	elif layout_mode == "Sphere":
		q.transform.origin = Vector3(randf()*2-1, randf()*2-1, randf()*2-1).normalized() * field_radius

	elif layout_mode == "Cube":
		q.transform.origin = Vector3(randf()*2-1, randf()*2-1, randf()*2-1) * field_radius


func _set_quad_params(i: int, mat: ShaderMaterial):
	var t = float(i) / max(1, quad_count - 1)
	var z = (t - 0.5) * 2.0

	mat.set_shader_parameter("u_zrot", z * slice_scale)
	mat.set_shader_parameter("u_krot", abs(z) * slice_scale)
	#mat.set_shader_parameter("u_bonusStar", 0.3 * z)
	#mat.set_shader_parameter("u_bonusM", 0.2 * z)


func _face_camera():
	if camera == null:
		_resolve_camera()
		if camera == null:
			return

	for q in get_children():
		if not (q is MeshInstance3D):
			continue
		self.look_at(-camera.global_transform.origin, Vector3.UP)

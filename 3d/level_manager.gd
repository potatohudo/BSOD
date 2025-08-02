extends Node

@onready var level_holder: Node3D = get_node_or_null("/root/Main/SubViewportContainer/SubViewport/Node3D/LevelHolder")
@onready var subviewport_container: SubViewportContainer = get_node_or_null("/root/Main/SubViewportContainer")
@onready var indicator: AnimatedSprite2D = get_node_or_null("/root/Main/SubViewportContainer/SubViewport/POR_Full")
@onready var indicator1: AnimatedSprite2D = get_node_or_null("/root/Main/SubViewportContainer/SubViewport/POR_Idle")
@onready var player_camera: Camera3D = get_node("/root/Main/SubViewportContainer/SubViewport/Node3D/CharacterBody3D/Marker3D/Camera3D")

# Morph data
var map1
var map2
var collider
var mdt1 = MeshDataTool.new()
var mdt2 = MeshDataTool.new()
var original_vertices := PackedVector3Array()
var original_arrays = []
var vertex_map = {}
var t := 0.0
var hidden_points: Array = []

func _ready():
	await get_tree().process_frame

	if Global.target_level_path != "":
		load_level(Global.target_level_path)
		Global.target_level_path = ""
	indicator1.play()
	


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

			# 🔹 Find morph targets in the new map
			map1 = new_level.get_node_or_null("Map1")
			map2 = new_level.get_node_or_null("Map2")
			hidden_points = map2.get_tree().get_nodes_in_group("hidden")

			collider = new_level.get_node_or_null("StaticBody3D/Collision")
			if map1 and map2 and collider:
				init_morph()
				collider.global_transform = map1.global_transform
				update_collision()
			

	subviewport_container.queue_redraw()

# --------------------------------
# Morph setup & logic
# --------------------------------



func init_morph():
	var mesh1 = map1.mesh
	var mesh2 = map2.mesh

	mdt1.create_from_surface(mesh1, 0)
	mdt2.create_from_surface(mesh2, 0)

	original_vertices.clear()
	for i in mdt1.get_vertex_count():
		original_vertices.append(mdt1.get_vertex(i))

	vertex_map = generate_vertex_map(mesh1, mesh2)
	original_arrays = mesh1.surface_get_arrays(0)

	update_collision()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			t = clamp(t + 0.03, 0.0, 1.0)
			morph()
			morph_timer = morph_display_time
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			t = clamp(t - 0.03, 0.0, 1.0)
			morph()
			morph_timer = morph_display_time


func morph():
	var new_mesh := ArrayMesh.new()
	var new_arrays = original_arrays.duplicate(true)
	var vertices = new_arrays[Mesh.ARRAY_VERTEX]

	for i in vertices.size():
		var base = original_vertices[i]
		var target = mdt2.get_vertex(vertex_map[i][0])
		vertices[i] = base.lerp(target, t)

	new_arrays[Mesh.ARRAY_VERTEX] = vertices
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
	map1.mesh = new_mesh
	update_collision()

func generate_vertex_map(mesh1, mesh2):
	var m1 = MeshDataTool.new()
	var m2 = MeshDataTool.new()
	m1.create_from_surface(mesh1, 0)
	m2.create_from_surface(mesh2, 0)

	var map = {}
	for i in m1.get_vertex_count():
		var closest_idx = -1
		var closest_dist = INF
		var v1 = m1.get_vertex(i)
		for j in m2.get_vertex_count():
			var v2 = m2.get_vertex(j)
			var dist = v1.distance_squared_to(v2)
			if dist < closest_dist:
				closest_dist = dist
				closest_idx = j
		map[i] = [closest_idx]
	return map

func update_collision():
	var indices = original_arrays[Mesh.ARRAY_INDEX]
	if indices == null or indices.is_empty():
		push_error("Original mesh has no index data.")
		return

	var new_data = PackedVector3Array()
	var mesh_global_xform = map1.global_transform
	var collider_global_xform = collider.global_transform
	var mesh_to_collider = collider_global_xform.affine_inverse() * mesh_global_xform

	for i in indices:
		var base = original_vertices[i]
		var target = mdt2.get_vertex(vertex_map[i][0])
		var morphed = base.lerp(target, t)
		var local_vert = mesh_to_collider * morphed
		new_data.append(local_vert)

	var shape := ConcavePolygonShape3D.new()
	shape.data = new_data
	collider.shape = shape
	collider.global_transform = mesh_global_xform
	
# -------------------
# Sprite logic
# -------------------

var morph_display_time := 0.0 # seconds to show morph indicator after scrolling
var morph_timer := 0.0

func show_idle_indicator():
	if indicator1:
		indicator1.visible = true
		indicator1.play() # plays its own idle animation
	if indicator:
		indicator.visible = false
		indicator.stop()

func show_morph_indicator():
	if indicator:
		indicator.visible = true
		indicator.play() # plays the morph animation
	if indicator1:
		indicator1.visible = false
		indicator1.stop()

func _process(delta):
	# Rotate indicator based on t (0 → 0°, 1 → 45°)
	if indicator:
		indicator.rotation_degrees = t * 45.0
	if indicator1:
		indicator1.rotation_degrees = t * 45.0

	var hidden_on_screen = false
	var hidden_in_center = false

	var cam_pos = player_camera.global_transform.origin
	var cam_dir = -player_camera.global_transform.basis.z.normalized()

	for point in hidden_points:
		var to_point = (point.global_transform.origin - cam_pos).normalized()
		var dot = cam_dir.dot(to_point)

		# Is it on screen? (about 90° FOV check)
		if dot > 0.8:
			hidden_on_screen = true
		# Is it directly in front? (~11° cone)
		if dot > 0.98:
			hidden_in_center = true

	# Control indicator
	if hidden_on_screen:
		indicator.visible = true
		indicator1.visible = false
		if not indicator.is_playing():
			indicator.play()
		indicator.speed_scale = 1.3 if hidden_in_center else 1.0
	else:
		indicator.visible = false
		indicator1.visible = true
		if not indicator1.is_playing():
			indicator1.play()


		
func is_looking_at_hidden() -> bool:
	var cam_pos = player_camera.global_transform.origin
	var cam_dir = -player_camera.global_transform.basis.z.normalized()

	for point in hidden_points:
		var to_point = (point.global_transform.origin - cam_pos).normalized()
		var dot = cam_dir.dot(to_point)
		if dot > 0.98: # ~cos(11°), tweak for detection cone
			return true
	return false

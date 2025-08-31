extends Node3D

@export var mesh_instance: MeshInstance3D
@export var lat_segments: int = 8
@export var lon_segments: int = 16
@export var box_thickness: float = 0.3
@export var padding: float = 0.1
@export var overlap_factor: float = 1.05
@export var pole_thickness_mult: float = 3.0
@export var upper_thickness_mult: float = 1.5
@export var inner_scale: float = 0.8
@export var debug_material_outer: ShaderMaterial
@export var debug_material_inner: ShaderMaterial

# Columns
@export var num_columns: int = 20
@export var column_min_height: float = 3.0
@export var column_max_height: float = 7.0
@export var column_width: float = 1.0
@export var column_material: ShaderMaterial

# Rotation stuff (no gravity anywhere)
@onready var player = get_node_or_null("../../CharacterBody3D")
var sphere_center: Vector3 = Vector3.ZERO
var last_player_pos: Vector3
var _have_last := false
@export var rotation_speed_mult: float = 1.0
@onready var player_spawn = $Marker3D 
@onready var pivot = $Pivot




func _ready():
	# Find the player by path
	#player = get_node_or_null("../../CharacterBody3D")
	if not player:
		push_error("Could not find player at SubViewportContainer/SubViewport/Node3D/CharacterBody3D")

	# Sphere center: true geometric center from the mesh AABB (world space)
	if mesh_instance and mesh_instance.mesh:
		var aabb := mesh_instance.mesh.get_aabb()
		sphere_center = mesh_instance.to_global(aabb.get_center())
	else:
		sphere_center = global_transform.origin
	
	# Viewport / materials hookup (unchanged)
	var vp := _find_viewport()
	var vp_tex := (vp.get_texture() if vp else null)
	if not vp:
		push_error("No viewport found in scene tree.")
	elif vp_tex == null:
		push_warning("Viewport found but has no texture. Ensure the Viewport is rendering to a texture.")

	if vp_tex:
		_assign_texture_to_material_resources(vp_tex)

	# --- generate geometry (unchanged) ---
	if not mesh_instance:
		push_error("mesh_instance is not assigned!")
		return
	mesh_instance.visible = false

	var aabb := mesh_instance.mesh.get_aabb()
	if aabb.size == Vector3.ZERO:
		push_error("Mesh AABB is zero!")
		return

	var radius_outer := aabb.size.x / 2.0
	var radius_inner := radius_outer * inner_scale

	var center_local := aabb.position + aabb.size * 0.5
	var mesh_xform := mesh_instance.global_transform
	var base_box_mesh := SphereMesh.new()

	_generate_tiled_sphere(radius_outer, center_local, mesh_xform, base_box_mesh, debug_material_outer, false, true)
	_generate_tiled_sphere(radius_inner, center_local, mesh_xform, base_box_mesh, debug_material_inner, true, false)

	_generate_outer_columns(radius_outer, center_local, mesh_xform)
	_generate_inner_columns(radius_inner, center_local, mesh_xform)

	if vp_tex:
		_assign_texture_to_scene_materials(vp_tex, "matcap")

	# init last position AFTER everything is placed
	if player:
		last_player_pos = player.global_transform.origin
		_have_last = true


func _physics_process(delta: float) -> void:
	if not player:
		return

	var move_dir: Vector3 = player.get_movement_direction()
	var move_speed: float = player.speed
	if move_dir == Vector3.ZERO or move_speed <= 0.01:
		# Keep only XZ fixed, let Y float
		var player_pos = player.global_transform.origin
		var spawn_pos = player_spawn.global_transform.origin
		player.global_transform.origin = Vector3(spawn_pos.x, player_pos.y, spawn_pos.z)
		return

	# FIX: flip axis direction
	var axis := Vector3.UP.cross(move_dir).normalized()
	if axis.length() < 0.001:
		return

	# Optionally scale down here
	var angle := move_speed * rotation_speed_mult * delta
	var rot := Basis(Quaternion(axis, angle))

	# Rotate sphere content
	pivot.global_transform = Transform3D(
		(rot * pivot.global_transform.basis).orthonormalized(),
		rot * (pivot.global_transform.origin - sphere_center) + sphere_center
	)

	# Keep player anchored in XZ, free in Y
	var player_pos = player.global_transform.origin
	var spawn_pos = player_spawn.global_transform.origin
	player.global_transform.origin = Vector3(spawn_pos.x, player_pos.y, spawn_pos.z)


# ---------------- helpers for viewport / assignment ----------------

func _find_viewport() -> Viewport:
	# Prefer the viewport this node is in
	var vp := get_viewport()
	if vp:
		return vp
	# Fallback: BFS search from the scene root for a Viewport node
	var root = get_tree().get_root()
	var queue := [root]
	while queue.size() > 0:
		var n = queue.pop_front()
		if n is Viewport:
			return n
		for c in n.get_children():
			if c is Node:
				queue.append(c)
	return null


func _assign_texture_to_material_resources(vp_tex: Texture2D):
	# assign to common exported ShaderMaterial resources (so new mesh instances using them already show it)
	var mats := [debug_material_outer, debug_material_inner, column_material]
	for mat in mats:
		if mat and mat is ShaderMaterial:
			mat.set_shader_parameter("matcap", vp_tex)


func _assign_texture_to_scene_materials(vp_tex: Texture2D, uniform_name := "matcap"):
	_assign_texture_to_node_and_children(self, vp_tex, uniform_name)


func _assign_texture_to_node_and_children(node: Node, vp_tex: Texture2D, uniform_name: String):
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D

		# material_override
		if mi.material_override and mi.material_override is ShaderMaterial:
			var mat := mi.material_override as ShaderMaterial
			if mat.shader:
				for u in mat.shader.get_shader_uniform_list():
					if u.name == uniform_name:
						mat.set_shader_parameter(uniform_name, vp_tex)
						break

		# surface materials
		if mi.mesh:
			var scount := mi.mesh.get_surface_count()
			for i in range(scount):
				var surf_mat = mi.mesh.surface_get_material(i)
				if surf_mat and surf_mat is ShaderMaterial:
					var smat := surf_mat as ShaderMaterial
					if smat.shader:
						for u in smat.shader.get_shader_uniform_list():
							if u.name == uniform_name:
								smat.set_shader_parameter(uniform_name, vp_tex)
								break

	# recurse
	for child in node.get_children():
		if child is Node:
			_assign_texture_to_node_and_children(child, vp_tex, uniform_name)


	# Recurse children
	for child in node.get_children():
		if child is Node:
			_assign_texture_to_node_and_children(child, vp_tex, uniform_name)



# ---------------- sphere / column generation (same as before) ----------------

func _generate_tiled_sphere(
	radius: float,
	center_local: Vector3,
	mesh_xform: Transform3D,
	box_mesh: SphereMesh,
	mat: ShaderMaterial,
	invert: bool,
	watertight: bool
):
	# One StaticBody for all collisions
	var static_body := StaticBody3D.new()
	pivot.add_child(static_body)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D   
	mm.mesh = box_mesh

	var mm_inst := MultiMeshInstance3D.new()
	mm_inst.multimesh = mm
	mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(mm_inst)

	# Duplicate the material so each MultiMesh can have its own shader params
	if mat:
		var mat_copy := mat.duplicate() as ShaderMaterial
		mm_inst.material_override = mat_copy

		# Assign the viewport texture immediately if available
		var vp := _find_viewport()
		if vp and vp.get_texture():
			mat_copy.set_shader_parameter("matcap", vp.get_texture())


	var transforms: Array[Transform3D] = []

	for lat in range(lat_segments):
		var lat0 = deg_to_rad(-90.0 + lat * (180.0 / lat_segments))
		var lat1 = deg_to_rad(-90.0 + (lat + 1.0) * (180.0 / lat_segments))

		for lon in range(lon_segments):
			var lon0 = deg_to_rad(lon * (360.0 / lon_segments))
			var lon1 = deg_to_rad((lon + 1.0) * (360.0 / lon_segments))

			var lat_mid = (lat0 + lat1) * 0.5
			var lon_mid = (lon0 + lon1) * 0.5

			var local_center = Vector3(
				radius * cos(lat_mid) * cos(lon_mid),
				radius * sin(lat_mid),
				radius * cos(lat_mid) * sin(lon_mid)
			) + center_local

			var tile_center = mesh_xform * local_center

			var up = (tile_center - (mesh_xform * center_local)).normalized()
			if invert:
				up = -up

			var right = Vector3.UP.cross(up).normalized()
			if right.length() < 0.001:
				right = Vector3.FORWARD
			var forward = up.cross(right).normalized()
			var basis = Basis(right, up, forward)

			var lat_arc = radius * abs(lat1 - lat0)
			var lon_arc = radius * cos(lat_mid) * abs(lon1 - lon0)

			var thickness = box_thickness
			if lat == 0 or lat == lat_segments - 1:
				thickness *= pole_thickness_mult
			if watertight and lat == lat_segments - 1:
				thickness *= upper_thickness_mult

			var lat_size = (lat_arc + padding) * (overlap_factor if watertight else 1.05)
			var lon_size = (lon_arc + padding) * (overlap_factor if watertight else 1.05)

			var size = Vector3(lon_size, thickness, lat_size)

			# --- CollisionShape ---
			var shape = BoxShape3D.new()
			shape.size = size * 2.0
			var col_shape = CollisionShape3D.new()
			col_shape.shape = shape
			col_shape.transform = Transform3D(basis, tile_center)
			static_body.add_child(col_shape)

			# --- MultiMesh transform ---
			var xf = Transform3D(basis, tile_center)
			var sc = size
			if not watertight:
				sc.x *= 1.2
				sc.z *= 1.2
			xf.basis *= Basis().scaled(sc)
			transforms.append(xf)

	# Push all transforms into MultiMesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])


# ----- Outer Columns -----
func _generate_outer_columns(radius: float, center_local: Vector3, mesh_xform: Transform3D):
	for i in range(num_columns):
		var lat = randf_range(-80.0, 80.0)
		var lon = randf_range(0.0, 360.0)
		var lat_r = deg_to_rad(lat)
		var lon_r = deg_to_rad(lon)
		_place_outer_column(radius, center_local, mesh_xform, lat_r, lon_r, false)
		_place_outer_column(radius, center_local, mesh_xform, lat_r, lon_r, true)


func _place_outer_column(radius: float, center_local: Vector3, mesh_xform: Transform3D, lat_r: float, lon_r: float, ceiling: bool):
	var height = randf_range(column_min_height, column_max_height)

	var local_pos = Vector3(
		radius * cos(lat_r) * cos(lon_r),
		radius * sin(lat_r),
		radius * cos(lat_r) * sin(lon_r)
	) + center_local

	var world_pos = mesh_xform * local_pos
	var up = (world_pos - (mesh_xform * center_local)).normalized()
	if ceiling:
		up = -up

	var right = Vector3.UP.cross(up).normalized()
	if right.length() < 0.001:
		right = Vector3.FORWARD
	var forward = up.cross(right).normalized()
	var basis = Basis(right, up, forward)

	var col_transform = Transform3D(basis, world_pos - up * (height / 2.0))

	# Collision
	var shape = BoxShape3D.new()
	shape.size = Vector3(column_width, height, column_width)
	var body = StaticBody3D.new()
	var col_shape = CollisionShape3D.new()
	col_shape.shape = shape
	col_shape.transform = col_transform
	body.add_child(col_shape)
	pivot.add_child(body)

	# Mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(column_width, height, column_width)
	var vis = MeshInstance3D.new()
	vis.mesh = box_mesh
	vis.material_override = column_material
	vis.transform = col_transform
	pivot.add_child(vis)


# ----- Inner Columns -----
func _generate_inner_columns(radius_inner: float, center_local: Vector3, mesh_xform: Transform3D):
	for i in range(num_columns):
		var lat = randf_range(-80.0, 80.0)
		var lon = randf_range(0.0, 360.0)
		var lat_r = deg_to_rad(lat)
		var lon_r = deg_to_rad(lon)
		_place_inner_column(radius_inner, center_local, mesh_xform, lat_r, lon_r, false)
		_place_inner_column(radius_inner, center_local, mesh_xform, lat_r, lon_r, true)


func _place_inner_column(radius_inner: float, center_local: Vector3, mesh_xform: Transform3D, lat_r: float, lon_r: float, ceiling: bool):
	var height = randf_range(column_min_height, column_max_height)

	var local_pos = Vector3(
		radius_inner * cos(lat_r) * cos(lon_r),
		radius_inner * sin(lat_r),
		radius_inner * cos(lat_r) * sin(lon_r)
	) + center_local

	var world_pos = mesh_xform * local_pos
	var up = (world_pos - (mesh_xform * center_local)).normalized()
	if ceiling:
		up = -up

	# Push toward outer wall (tunnel space)
	world_pos += -up * (column_width * 0.5 + 0.05)

	var right = Vector3.UP.cross(up).normalized()
	if right.length() < 0.001:
		right = Vector3.FORWARD
	var forward = up.cross(right).normalized()
	var basis = Basis(right, up, forward)

	var col_transform = Transform3D(basis, world_pos - up * (height / 2.0))

	# Collision
	var shape = BoxShape3D.new()
	shape.size = Vector3(column_width, height, column_width)
	var body = StaticBody3D.new()
	var col_shape = CollisionShape3D.new()
	col_shape.shape = shape
	col_shape.transform = col_transform
	body.add_child(col_shape)
	pivot.add_child(body)

	# Mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(column_width, height, column_width)
	var vis = MeshInstance3D.new()
	vis.mesh = box_mesh
	vis.material_override = column_material
	vis.transform = col_transform
	pivot.add_child(vis)


## Case 1: Player has an Area3D detector (we receive AREA signals)
#func _on_player_detector_area_shape_entered(_area_rid: RID, area: Area3D, _area_shape_idx: int, _local_shape_idx: int) -> void:
	#if area and area.is_in_group("0g"):
		#_enter_0g()
#
#func _on_player_detector_area_shape_exited(_area_rid: RID, area: Area3D, _area_shape_idx: int, _local_shape_idx: int) -> void:
	#if area and area.is_in_group("0g"):
		#_exit_0g()
#
## Case 2: No detector; each "0g" Area watches for BODY signals and tells us when the player enters/exits
#func _on_0g_body_shape_entered(_body_rid: RID, body: Node, _body_shape_idx: int, _local_shape_idx: int, area: Area3D) -> void:
	#if body == player:
		#_enter_0g()
#
#func _on_0g_body_shape_exited(_body_rid: RID, body: Node, _body_shape_idx: int, _local_shape_idx: int, area: Area3D) -> void:
	#if body == player:
		#_exit_0g()

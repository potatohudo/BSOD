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

func _ready():
	# Locate viewport (tries get_viewport() first, then searches scene)
	var vp := _find_viewport()
	var vp_tex = null
	if vp:
		vp_tex = vp.get_texture()
		if vp_tex == null:
			push_warning("Viewport found but has no texture. Ensure the Viewport is rendering to a texture (render_target).")
	else:
		push_error("No viewport found in scene tree.")

	# Assign to exported ShaderMaterial resources first (so generated meshes using them already have the texture)
	if vp_tex:
		_assign_texture_to_material_resources(vp_tex)

	# --- now generate geometry (unchanged) ---
	if not mesh_instance:
		push_error("mesh_instance is not assigned!")
		return

	mesh_instance.visible = false

	var aabb = mesh_instance.mesh.get_aabb()
	if aabb.size == Vector3.ZERO:
		push_error("Mesh AABB is zero!")
		return

	var radius_outer = aabb.size.x / 2.0
	var radius_inner = radius_outer * inner_scale

	var center_local = aabb.position + aabb.size * 0.5
	var mesh_xform = mesh_instance.global_transform
	var base_box_mesh = BoxMesh.new()

	# Outer sphere — watertight
	_generate_tiled_sphere(radius_outer, center_local, mesh_xform, base_box_mesh, debug_material_outer, false, true)

	# Inner sphere — collisions flush, meshes extended to overlap visually
	_generate_tiled_sphere(radius_inner, center_local, mesh_xform, base_box_mesh, debug_material_inner, true, false)

	# Columns
	_generate_outer_columns(radius_outer, center_local, mesh_xform)
	_generate_inner_columns(radius_inner, center_local, mesh_xform)

	# After generation, scan the subtree and assign the viewport texture to all ShaderMaterials found.
	# This covers materials attached to generated MeshInstance3D nodes or mesh surface materials.
	if vp_tex:
		_assign_texture_to_scene_materials(vp_tex, "matcap")


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
	# If it's a MeshInstance3D, handle material_override and surface materials
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		# material_override
		if mi.material_override and mi.material_override is ShaderMaterial:
			(mi.material_override as ShaderMaterial).set_shader_parameter(uniform_name, vp_tex)
		# surface materials
		if mi.mesh:
			var scount := mi.mesh.get_surface_count()
			for i in range(scount):
				var surf_mat = mi.mesh.surface_get_material(i)
				if surf_mat and surf_mat is ShaderMaterial:
					(surf_mat as ShaderMaterial).set_shader_parameter(uniform_name, vp_tex)

	# Recurse children
	for child in node.get_children():
		if child is Node:
			_assign_texture_to_node_and_children(child, vp_tex, uniform_name)


# ---------------- sphere / column generation (same as before) ----------------

func _generate_tiled_sphere(
	radius: float,
	center_local: Vector3,
	mesh_xform: Transform3D,
	box_mesh: BoxMesh,
	mat: ShaderMaterial,
	invert: bool,
	watertight: bool
):
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

			var size = Vector3(
				lon_size,
				thickness,
				lat_size
			)

			# Collision
			var shape = BoxShape3D.new()
			shape.size = size * 2.0
			var body = StaticBody3D.new()
			var col_shape = CollisionShape3D.new()
			col_shape.shape = shape
			col_shape.transform = Transform3D(basis, tile_center)
			body.add_child(col_shape)
			add_child(body)

			# Debug mesh — inner sphere gets extra stretch for no gaps
			var vis = MeshInstance3D.new()
			vis.mesh = box_mesh
			vis.material_override = mat
			vis.transform = col_shape.transform
			if watertight:
				vis.scale = size
			else:
				vis.scale = size
				vis.scale.x *= 1.2 # stretch sideways
				vis.scale.z *= 1.2 # stretch sideways
			add_child(vis)


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
	add_child(body)

	# Mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(column_width, height, column_width)
	var vis = MeshInstance3D.new()
	vis.mesh = box_mesh
	vis.material_override = column_material
	vis.transform = col_transform
	add_child(vis)


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
	add_child(body)

	# Mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(column_width, height, column_width)
	var vis = MeshInstance3D.new()
	vis.mesh = box_mesh
	vis.material_override = column_material
	vis.transform = col_transform
	add_child(vis)

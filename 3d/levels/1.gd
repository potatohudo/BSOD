extends Node3D

@export var mesh_instance: MeshInstance3D
@export var lat_segments: int = 8
@export var lon_segments: int = 16
@export var box_thickness: float = 0.3
@export var padding: float = 0.1

func _ready():
	if mesh_instance and mesh_instance.mesh:
		generate_sphere_tiles(mesh_instance.mesh)


func generate_sphere_tiles(mesh: Mesh):
	var aabb: AABB = mesh.get_aabb()
	var radius = aabb.size.x / 2.0
	var center_local = aabb.position + aabb.size * 0.5

	var mesh_transform = mesh_instance.global_transform

	for lat in range(lat_segments):
		var lat0 = deg_to_rad(-90.0 + lat * (180.0 / lat_segments))
		var lat1 = deg_to_rad(-90.0 + (lat + 1.0) * (180.0 / lat_segments))

		for lon in range(lon_segments):
			var lon0 = deg_to_rad(lon * (360.0 / lon_segments))
			var lon1 = deg_to_rad((lon + 1.0) * (360.0 / lon_segments))

			var lat_mid = (lat0 + lat1) * 0.5
			var lon_mid = (lon0 + lon1) * 0.5

			var local_tile_center = Vector3(
				radius * cos(lat_mid) * cos(lon_mid),
				radius * sin(lat_mid),
				radius * cos(lat_mid) * sin(lon_mid)
			) + center_local

			var tile_center = mesh_transform * local_tile_center

			var up = (tile_center - (mesh_transform * center_local)).normalized()
			var right = Vector3.UP.cross(up).normalized()
			if right.length() < 0.001:
				right = Vector3.FORWARD
			var forward = up.cross(right).normalized()

			var basis = Basis(right, up, forward)

			var lat_arc = radius * abs(lat1 - lat0)
			var lon_arc = radius * cos(lat_mid) * abs(lon1 - lon0)
			var size = Vector3(lon_arc + padding, box_thickness, lat_arc + padding)

			var shape = BoxShape3D.new()
			shape.size = size * 2.0

			var body = StaticBody3D.new()
			var col_shape = CollisionShape3D.new()
			col_shape.shape = shape
			col_shape.transform = Transform3D(basis, tile_center)

			body.add_child(col_shape)
			add_child(body)

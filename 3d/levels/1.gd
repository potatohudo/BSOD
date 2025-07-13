extends Node3D

@onready var map1 = $Map1
@onready var map2 = $Map2
@onready var collider = $StaticBody3D/Collision
@onready var original_arrays = []


var mdt1 = MeshDataTool.new()
var mdt2 = MeshDataTool.new()
var original_vertices := PackedVector3Array()
var vertex_map = {}
var t := 0.0  

func _ready():
	var mesh1 = map1.mesh
	var mesh2 = map2.mesh

	mdt1.create_from_surface(mesh1, 0)
	mdt2.create_from_surface(mesh2, 0)

	# Store the original vertex positions from map1
	for i in mdt1.get_vertex_count():
		original_vertices.append(mdt1.get_vertex(i))

	vertex_map = generate_vertex_map(mesh1, mesh2)
	
	original_arrays = map1.mesh.surface_get_arrays(0)



func _unhandled_input(event):
	if Input.is_action_pressed("wheel_up"):
		t = clamp(t + 0.05, 0.0, 1.0)
		morph()
	elif Input.is_action_pressed("wheel_down"):
		t = clamp(t - 0.05, 0.0, 1.0)
		morph()

func morph():
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, original_arrays)

	mdt1.clear()
	mdt1.create_from_surface(new_mesh, 0)

	for i in mdt1.get_vertex_count():
		var base = original_vertices[i]
		var target = mdt2.get_vertex(vertex_map[i][0])
		var morphed = base.lerp(target, t)
		mdt1.set_vertex(i, morphed)

	mdt1.commit_to_surface(new_mesh)

	map1.mesh = null
	await get_tree().process_frame  

	map1.mesh = new_mesh 
	update_collision()



func generate_vertex_map(mesh1, mesh2):
	var mdt1 = MeshDataTool.new()
	var mdt2 = MeshDataTool.new()
	mdt1.create_from_surface(mesh1, 0)
	mdt2.create_from_surface(mesh2, 0)

	var map = {}
	for i in mdt1.get_vertex_count():
		var closest_idx = -1
		var closest_dist = INF
		var v1 = mdt1.get_vertex(i)
		for j in mdt2.get_vertex_count():
			var v2 = mdt2.get_vertex(j)
			var dist = v1.distance_squared_to(v2)
			if dist < closest_dist:
				closest_dist = dist
				closest_idx = j
		map[i] = [closest_idx]
	return map

func update_collision():
	var arrays = map1.mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var indices = arrays[Mesh.ARRAY_INDEX]

	if indices.is_empty():
		push_error("Mesh has no index array! Collision shape may not work properly.")
		return

	var new_data = PackedVector3Array()
	for i in indices:
		new_data.append(vertices[i])

	var shape := ConcavePolygonShape3D.new()
	shape.data = new_data
	collider.shape = shape

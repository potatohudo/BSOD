extends  Node3D


#var map1 : MeshInstance3D
#var map2 : MeshInstance3D
#var collider : CollisionShape3D
#
#var mdt1 = MeshDataTool.new()
#var mdt2 = MeshDataTool.new()
#var original_vertices := PackedVector3Array()
#var vertex_map = {}
#var original_arrays = []
#var t := 0.0
#
#func init_morph():
	#map1 = get_node("SubViewportContainer/SubViewport/Node3D/LevelHolder/Node3D/Map1")
	#map2 = get_node("SubViewportContainer/SubViewport/Node3D/LevelHolder/Node3D/Map2")
	#collider = get_node("SubViewportContainer/SubViewport/Node3D/LevelHolder/Node3D/StaticBody3D")
#
	#if not map1 or not map2 or not collider:
		#push_error("Maps or collision shape not found!")
		#return
	#
	#if map1.mesh.get_surface_count() == 0 or map2.mesh.get_surface_count() == 0:
		#push_error("Meshes not ready yet.")
		#return
#
	#mdt1.clear()
	#mdt2.clear()
	#original_vertices.clear()
	#vertex_map.clear()
#
	#mdt1.create_from_surface(map1.mesh, 0)
	#mdt2.create_from_surface(map2.mesh, 0)
#
	#for i in mdt1.get_vertex_count():
		#original_vertices.append(mdt1.get_vertex(i))
#
	#vertex_map = generate_vertex_map(map1.mesh, map2.mesh)
	#original_arrays = map1.mesh.surface_get_arrays(0)
#
	#print("Morph system initialized.")
#
	#
#
#
#func _unhandled_input(event):
	#if Input.is_action_pressed("wheel_up"):
		#t = clamp(t + 0.05, 0.0, 1.0)
		#morph()
	#elif Input.is_action_pressed("wheel_down"):
		#t = clamp(t - 0.05, 0.0, 1.0)
		#morph()
#
#
#
#func morph():
	#await get_tree().process_frame
	## Create a fresh mesh
	#var new_mesh := ArrayMesh.new()
#
	## Copy original arrays (otherwise you'll lose data like UVs, normals, etc.)
	#var new_arrays = original_arrays.duplicate(true)  # deep copy
#
	#var vertices = new_arrays[Mesh.ARRAY_VERTEX]
#
	#for i in vertices.size():
		#var base = original_vertices[i]
		#var target = mdt2.get_vertex(vertex_map[i][0])
		#vertices[i] = base.lerp(target, t)
#
	#new_arrays[Mesh.ARRAY_VERTEX] = vertices
#
	## Add the morphed surface to the new mesh
	#new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, new_arrays)
#
	## Assign the new mesh to the MeshInstance3D
	#map1.mesh = new_mesh
#
	## Update collision shape
	#update_collision()
#
#
#
#
#func generate_vertex_map(mesh1, mesh2):
	#var mdt1 = MeshDataTool.new()
	#var mdt2 = MeshDataTool.new()
	#mdt1.create_from_surface(mesh1, 0)
	#mdt2.create_from_surface(mesh2, 0)
#
	#var map = {}
	#for i in mdt1.get_vertex_count():
		#var closest_idx = -1
		#var closest_dist = INF
		#var v1 = mdt1.get_vertex(i)
		#for j in mdt2.get_vertex_count():
			#var v2 = mdt2.get_vertex(j)
			#var dist = v1.distance_squared_to(v2)
			#if dist < closest_dist:
				#closest_dist = dist
				#closest_idx = j
		#map[i] = [closest_idx]
	#return map
#
#func update_collision():
	#var arrays = map1.mesh.surface_get_arrays(0)
	#var vertices = arrays[Mesh.ARRAY_VERTEX]
	#var indices = arrays[Mesh.ARRAY_INDEX]
#
	#if indices.is_empty():
		#push_error("Mesh has no index array! Collision shape may not work properly.")
		#return
#
	#var new_data = PackedVector3Array()
	#for i in indices:
		#new_data.append(vertices[i])
#
	#var shape := ConcavePolygonShape3D.new()
	#shape.data = new_data
	#collider.shape = shape

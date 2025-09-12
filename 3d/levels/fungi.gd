extends Node3D

# -------- Distances (meters) --------
@export var inner_spawn_distance: float = 25.0
@export var outer_spawn_distance: float = 50.0
@export var far_lod_distance: float   = 75.0

# -------- Counts (keep silhouette identical across LODs) --------
@export var inner_count: int = 120
@export var outer_count: int = 120
@export var impostor_count: int = 120

# -------- Vine look --------
@export var min_length: float = 0.6
@export var max_length: float = 1.9
@export var min_thickness: float = 0.05
@export var max_thickness: float = 0.16
@export var surface_epsilon: float = 0.01

# -------- Performance knobs --------
@export var check_interval: float = 0.3
@export var cylinder_radial_segments: int = 6

# -------- Shared materials (keep shared to avoid dups) --------
@export var vine_material: Material
@export var impostor_material: Material

var player: CharacterBody3D

enum SpawnTier { NONE, FAR, OUTER, INNER }
var fungi_nodes: Array = []
var spawn_state: Dictionary = {}
var mm_vines: Dictionary = {}
var mm_impostor: Dictionary = {}

# Stored per-fungus data so placement & count are identical across LODs
var data_pos: Dictionary = {}
var data_len: Dictionary = {}
var data_thk: Dictionary = {}
var data_ang: Dictionary = {}

const GOLDEN_ANGLE: float = 2.39996323
var _accum: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	player = get_node_or_null("../../CharacterBody3D") as CharacterBody3D
	if player == null:
		push_error("Could not find player at ../../CharacterBody3D")

	# Clamp & enforce identical counts across LODs (no popping by density)
	inner_count = max(inner_count, 0)
	outer_count = inner_count
	impostor_count = inner_count

	# Distances monotonic
	if !(inner_spawn_distance <= outer_spawn_distance && outer_spawn_distance <= far_lod_distance):
		push_warning("Distances not monotonic; fixing ordering.")
		inner_spawn_distance = min(inner_spawn_distance, outer_spawn_distance)
		outer_spawn_distance = max(inner_spawn_distance, outer_spawn_distance)
		far_lod_distance = max(outer_spawn_distance, far_lod_distance)

	# Collect fungi and build once
	for n in get_tree().get_nodes_in_group("fungi"):
		var fungi: MeshInstance3D = n as MeshInstance3D
		if fungi != null:
			fungi_nodes.append(fungi)
			spawn_state[fungi] = SpawnTier.NONE
			_build_once_for_fungus(fungi)
	$Node3D.call_nearest_whale(player)

func _process(delta: float) -> void:
	if player == null:
		return

	_accum += delta
	if _accum < check_interval:
		return
	_accum = 0.0

	var player_pos: Vector3 = player.global_transform.origin
	for fungi in fungi_nodes:
		var dist: float = fungi.global_transform.origin.distance_to(player_pos)
		var wanted: int = _tier_for_distance(dist)
		if wanted != spawn_state[fungi]:
			_apply_tier(fungi, wanted)

func _tier_for_distance(d: float) -> int:
	if d <= inner_spawn_distance:
		return SpawnTier.INNER
	elif d <= outer_spawn_distance:
		return SpawnTier.OUTER
	elif d <= far_lod_distance:
		return SpawnTier.FAR
	else:
		return SpawnTier.NONE

func _apply_tier(fungi: MeshInstance3D, tier: int) -> void:
	var mm_main: MultiMeshInstance3D = mm_vines[fungi]
	var mm_far: MultiMeshInstance3D = mm_impostor[fungi]

	match tier:
		SpawnTier.INNER:
			if is_instance_valid(mm_main):
				mm_main.multimesh.mesh = _make_inner_mesh()
				mm_main.multimesh.visible_instance_count = inner_count
				mm_main.visible = true
			if is_instance_valid(mm_far):
				mm_far.visible = false

		SpawnTier.OUTER:
			if is_instance_valid(mm_main):
				mm_main.multimesh.mesh = _make_outer_mesh()
				mm_main.multimesh.visible_instance_count = inner_count
				mm_main.visible = true
			if is_instance_valid(mm_far):
				mm_far.visible = false

		SpawnTier.FAR:
			if is_instance_valid(mm_main):
				mm_main.visible = false
			if is_instance_valid(mm_far):
				# impostors use same positions/count
				mm_far.multimesh.visible_instance_count = inner_count
				mm_far.visible = true

		SpawnTier.NONE:
			if is_instance_valid(mm_main):
				mm_main.visible = false
			if is_instance_valid(mm_far):
				mm_far.visible = false

	spawn_state[fungi] = tier

# ---------- One-time build per fungus ----------
func _build_once_for_fungus(fungi: MeshInstance3D) -> void:
	var mm_main: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_main.name = "Vines_MAIN"
	mm_main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mm1: MultiMesh = MultiMesh.new()
	mm1.transform_format = MultiMesh.TRANSFORM_3D
	mm1.instance_count = inner_count
	mm1.mesh = _make_inner_mesh()
	mm_main.multimesh = mm1

	if vine_material != null:
		mm_main.material_override = vine_material

	fungi.add_child(mm_main)
	mm_vines[fungi] = mm_main

	_place_vines_for_fungus(fungi, mm_main)

	# FAR impostors (crossed quads), identical placement/count
	var mm_far: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_far.name = "Vines_FAR"
	mm_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mm2: MultiMesh = MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.instance_count = inner_count
	mm2.mesh = _make_impostor_mesh()
	mm_far.multimesh = mm2

	if impostor_material != null:
		mm_far.material_override = impostor_material

	mm_far.visible = false
	fungi.add_child(mm_far)
	mm_impostor[fungi] = mm_far

	_place_impostors_for_fungus(fungi, mm_far)

# -------- Mesh builders --------
func _make_inner_mesh() -> PrimitiveMesh:
	var cap := CapsuleMesh.new()
	cap.radius = 0.045
	cap.height = 0.5
	cap.radial_segments = 8
	return cap

func _make_outer_mesh() -> PrimitiveMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 0.5
	cyl.radial_segments = max(cylinder_radial_segments, 4)
	return cyl

func _make_impostor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Quad size (x by y)
	var hw := 0.10
	var h  := 1.40

	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-hw, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3( hw, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3( hw, h,   0.0))
	# tri 2
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3( hw, h,   0.0))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-hw, h,   0.0))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-hw, 0.0, 0.0))

	# Quad 2 (YZ plane, rotated 90°)
	# tri 1
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(0.0, 0.0, -hw))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(0.0, 0.0,  hw))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(0.0, h,    hw))
	# tri 2
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(0.0, h,    hw))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(0.0, h,   -hw))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(0.0, 0.0, -hw))

	return st.commit()

# -------- Placement helpers --------
func _get_cylinder_params(fungi: MeshInstance3D) -> Vector3:
	var aabb: AABB = fungi.get_aabb()
	var height: float = aabb.size.y
	var radius: float = min(aabb.size.x, aabb.size.z) * 0.5
	if fungi.mesh is CylinderMesh:
		var cm: CylinderMesh = fungi.mesh
		height = cm.height
		radius = cm.bottom_radius
	var bottom_y: float = -height * 0.5
	return Vector3(radius, height, bottom_y)

func _place_vines_for_fungus(fungi: MeshInstance3D, mm_inst: MultiMeshInstance3D) -> void:
	var p: Vector3 = _get_cylinder_params(fungi)
	var radius: float = p.x
	var bottom_y: float = p.z

	var n: int = inner_count
	if n <= 0:
		return

	var pos_arr := PackedVector3Array()
	var len_arr := PackedFloat32Array()
	var thk_arr := PackedFloat32Array()
	var ang_arr := PackedFloat32Array()

	var src_h: float = 0.5
	for i in range(n):
		var len: float = randf_range(min_length, max_length)
		var thk: float = randf_range(min_thickness, max_thickness)
		var r: float = radius * sqrt(randf())
		var ang: float = randf() * TAU

		var lx: float = cos(ang) * r
		var lz: float = sin(ang) * r

		pos_arr.append(Vector3(lx, bottom_y - surface_epsilon, lz))
		len_arr.append(len)
		thk_arr.append(thk)
		ang_arr.append(ang)

		var total_len: float = src_h * len
		var half_len: float = total_len * 0.5

		var world_pos: Vector3 = fungi.global_transform * pos_arr[i]

		var xform: Transform3D = Transform3D()
		xform.origin = world_pos - Vector3(0.0, half_len, 0.0)
		xform.basis = Basis().scaled(Vector3(thk, len, thk))
		xform = fungi.global_transform.affine_inverse() * xform

		mm_inst.multimesh.set_instance_transform(i, xform)

	# store per-fungus data for impostors (same placement/count)
	data_pos[fungi] = pos_arr
	data_len[fungi] = len_arr
	data_thk[fungi] = thk_arr
	data_ang[fungi] = ang_arr

	mm_inst.visible = false
	mm_inst.multimesh.visible_instance_count = 0

func _place_impostors_for_fungus(fungi: MeshInstance3D, mm_far: MultiMeshInstance3D) -> void:
	# Build transforms using the SAME local positions/lengths/thickness/angles
	if !data_pos.has(fungi):
		return

	var pos_arr: PackedVector3Array = data_pos[fungi]
	var len_arr: PackedFloat32Array = data_len[fungi]
	var thk_arr: PackedFloat32Array = data_thk[fungi]
	var ang_arr: PackedFloat32Array = data_ang[fungi]

	var n: int = pos_arr.size()
	var src_h: float = 1.4	# impostor mesh height used in _make_impostor_mesh()

	for i in range(n):
		var local_pos: Vector3 = pos_arr[i]
		var len: float = len_arr[i]
		var thk: float = max(0.015, thk_arr[i] * 0.6)
		var yaw: float = ang_arr[i] * 0.5

		var height_f: float = clamp(len * src_h, 0.25, 3.0)
		var world_pos: Vector3 = fungi.global_transform * local_pos

		var xf: Transform3D = Transform3D()
		xf.origin = world_pos - Vector3(0.0, height_f * 0.5, 0.0)
		xf.basis = Basis().rotated(Vector3.UP, yaw).scaled(Vector3(thk, height_f, thk))
		xf = fungi.global_transform.affine_inverse() * xf

		mm_far.multimesh.set_instance_transform(i, xf)

	mm_far.multimesh.visible_instance_count = 0
	mm_far.visible = false

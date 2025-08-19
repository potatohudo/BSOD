extends Node3D

# -------- Distances (meters) --------
@export var inner_spawn_distance: float = 25.0	# high detail
@export var outer_spawn_distance: float = 50.0	# low detail
@export var far_lod_distance: float   = 75.0	# impostor only; beyond = culled

# -------- Counts (deterministic; no RNG) --------
@export var inner_count: int = 120				# max instances allocated once
@export var outer_count: int = 32				# shown in outer tier
@export var impostor_count: int = 8				# super cheap far impostors

# -------- Vine look --------
@export var min_length: float = 0.6
@export var max_length: float = 1.9
@export var min_thickness: float = 0.05
@export var max_thickness: float = 0.16
@export var surface_epsilon: float = 0.01

# -------- Performance knobs --------
@export var check_interval: float = 0.3			# seconds between distance checks
@export var use_lowpoly_cylinder: bool = true
@export var cylinder_radial_segments: int = 6	# very low-poly

# -------- Shared materials (keep shared to avoid dups) --------
@export var vine_material: Material				# sway in vertex shader
@export var impostor_material: Material			# lighter shader (can be same)

var player: CharacterBody3D

enum SpawnTier { NONE, FAR, OUTER, INNER }
var fungi_nodes: Array = []					# holds MeshInstance3D
var spawn_state: Dictionary = {}			# MeshInstance3D -> SpawnTier (int)
var mm_vines: Dictionary = {}				# MeshInstance3D -> MultiMeshInstance3D
var mm_impostor: Dictionary = {}			# MeshInstance3D -> MultiMeshInstance3D


const GOLDEN_ANGLE: float = 2.39996323
var _accum: float = 0.0

func _ready() -> void:
	player = get_node_or_null("../../CharacterBody3D") as CharacterBody3D
	if player == null:
		push_error("Could not find player at ../../CharacterBody3D")

	# Clamp & order distances
	inner_count = max(inner_count, 0)
	outer_count = clamp(outer_count, 0, inner_count)
	impostor_count = max(impostor_count, 0)

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
				mm_main.visible = true
				mm_main.multimesh.visible_instance_count = inner_count
			if is_instance_valid(mm_far):
				mm_far.visible = false

		SpawnTier.OUTER:
			if is_instance_valid(mm_main):
				mm_main.visible = true
				mm_main.multimesh.visible_instance_count = outer_count
			if is_instance_valid(mm_far):
				mm_far.visible = false

		SpawnTier.FAR:
			if is_instance_valid(mm_main):
				mm_main.visible = false
			if is_instance_valid(mm_far):
				mm_far.visible = true

		SpawnTier.NONE:
			if is_instance_valid(mm_main):
				mm_main.visible = false
			if is_instance_valid(mm_far):
				mm_far.visible = false

	spawn_state[fungi] = tier

# ---------- One-time build per fungus ----------
func _build_once_for_fungus(fungi: MeshInstance3D) -> void:
	# MAIN vines
	var mm_main: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_main.name = "Vines_MAIN"
	mm_main.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mm1: MultiMesh = MultiMesh.new()
	mm1.transform_format = MultiMesh.TRANSFORM_3D
	mm1.instance_count = inner_count		# allocate max once
	mm_main.multimesh = mm1

	var vine_mesh: PrimitiveMesh = _make_vine_mesh()
	mm1.mesh = vine_mesh

	if vine_material != null:
		mm_main.material_override = vine_material

	fungi.add_child(mm_main)
	mm_vines[fungi] = mm_main

	_place_vines_for_fungus(fungi, mm_main)

	# FAR impostor
	var mm_far: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_far.name = "Vines_FAR"
	mm_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mm2: MultiMesh = MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.instance_count = impostor_count
	mm_far.multimesh = mm2
	mm2.mesh = _make_impostor_mesh()

	if impostor_material != null:
		mm_far.material_override = impostor_material

	mm_far.visible = false
	fungi.add_child(mm_far)
	mm_impostor[fungi] = mm_far

	_place_impostors_for_fungus(fungi, mm_far)
	
func _make_vine_mesh() -> PrimitiveMesh:
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.045
	cap.height = 0.5
	return cap

func _make_impostor_mesh() -> PrimitiveMesh:
	# Single quad (you can swap to crossed quads for thicker look)
	var plane: QuadMesh = QuadMesh.new()
	plane.size = Vector2(0.25, 1.4)
	return plane

# Returns (x=radius, y=height, z=bottom_y) in local space
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
	var height: float = p.y
	var bottom_y: float = p.z

	var n: int = inner_count
	if n <= 0:
		return

	var src_h: float = 0.5		# capsule height from _make_vine_mesh()
	for i in range(n):
		# 🔹 randomized per vine
		var len: float = randf_range(min_length, max_length)
		var thk: float = randf_range(min_thickness, max_thickness)

		var r: float = radius * sqrt(randf())			# uniform disk
		var ang: float = randf() * TAU
		var lx: float = cos(ang) * r
		var lz: float = sin(ang) * r

		var total_len: float = src_h * len
		var half_len: float = total_len * 0.5

		var local_pos: Vector3 = Vector3(lx, bottom_y - surface_epsilon, lz)
		var world_pos: Vector3 = fungi.global_transform * local_pos

		var xform: Transform3D = Transform3D()
		xform.origin = world_pos - Vector3(0.0, half_len, 0.0)
		xform.basis = Basis().scaled(Vector3(thk, len, thk))
		xform = fungi.global_transform.affine_inverse() * xform

		mm_inst.multimesh.set_instance_transform(i, xform)

	# start hidden; shown via _apply_tier
	mm_inst.visible = false
	mm_inst.multimesh.visible_instance_count = 0

func _place_impostors_for_fungus(fungi: MeshInstance3D, mm_far: MultiMeshInstance3D) -> void:
	var p: Vector3 = _get_cylinder_params(fungi)
	var radius: float = p.x
	var bottom_y: float = p.z

	var n: int = impostor_count
	if n <= 0:
		return

	for i in range(n):
		var ang: float = float(i) * GOLDEN_ANGLE
		var r: float = radius * 0.85
		var lx: float = cos(ang) * r
		var lz: float = sin(ang) * r

		var height_f: float = lerp(min_length, max_length, 0.5) * 1.2
		var thk: float = 0.02

		var local_pos: Vector3 = Vector3(lx, bottom_y - surface_epsilon, lz)
		var world_pos: Vector3 = fungi.global_transform * local_pos

		var xf: Transform3D = Transform3D()
		xf.origin = world_pos - Vector3(0.0, height_f * 0.5, 0.0)
		xf.basis = Basis().rotated(Vector3.UP, ang * 0.5).scaled(Vector3(thk, height_f, thk))
		xf = fungi.global_transform.affine_inverse() * xf

		mm_far.multimesh.set_instance_transform(i, xf)

	mm_far.visible = false

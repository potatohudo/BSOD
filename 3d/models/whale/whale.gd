extends Node3D

@onready var player: CharacterBody3D = get_node_or_null("../../CharacterBody3D")
@onready var audio: Node = $Audio
@onready var whale: Node3D = $whale
@onready var anim: AnimationPlayer = $AnimationPlayer

var rng := RandomNumberGenerator.new()
var time_accum: float = 0.0
var next_interval: float = 1.0
var players_cache: Array[AudioStreamPlayer3D] = []

# Movement
@export var move_speed: float = 2.0
@export var turn_duration: float = 2.0
@export var turn_interval_min: float = 3.0
@export var turn_interval_max: float = 7.0
var current_dir: Vector3 = Vector3.FORWARD
var start_dir: Vector3 = Vector3.FORWARD
var target_dir: Vector3 = Vector3.FORWARD
var turn_time: float = 0.0
var next_turn_timer: float = 0.0

# Modes
enum Mode { MOVING, RESTING, STOP, NAVIGATING }
var mode: Mode = Mode.MOVING
var rest_timer: float = 0.0

@export var rest_interval_min: float = 10.0
@export var rest_interval_max: float = 20.0
@export var rest_duration_min: float = 5.0
@export var rest_duration_max: float = 15.0

# Navigation
var target_queue: Array[Node3D] = []
var target_node: Node3D = null
@export var arrival_distance: float = 20.0
var navigation_reached: bool = false
@export var park_time: float = 5.0
var park_timer: float = 0.0

# Smooth transitions
var anim_speed_target: float = 1.0
var anim_speed_current: float = 1.0
var movement_factor_target: float = 1.0
var movement_factor_current: float = 1.0
@export var transition_speed: float = 1.5  # higher = faster transition
@export var rotation_smooth_speed: float = 6.0

# Sound settings
@export var base_interval: float = 1.0
@export var extra_pause_min: float = 1.0
@export var extra_pause_max: float = 2.0

func _ready() -> void:
	await get_tree().process_frame
	add_to_group("bloop")
	await get_tree().process_frame
	rng.randomize()
	_update_players_cache()
	_pick_new_direction()
	_set_next_interval()
	_reset_rest_timer()

	# force whale to actually start moving
	mode = Mode.MOVING
	current_dir = target_dir
	anim_speed_target = 1.0
	movement_factor_target = 1.0



func _update_players_cache() -> void:
	players_cache.clear()
	if audio == null:
		return
	for c in audio.get_children():
		if c is AudioStreamPlayer3D:
			players_cache.append(c)

func _process(delta: float) -> void:
	time_accum += delta
	if time_accum >= next_interval:
		time_accum = 0.0
		_play_random_sound()
		_set_next_interval()

	if mode != Mode.NAVIGATING:
		_update_mode(delta)

	_update_flight(delta)

	# Smooth animation speed + movement blending
	anim_speed_current = lerp(anim_speed_current, anim_speed_target, transition_speed * delta)
	movement_factor_current = lerp(movement_factor_current, movement_factor_target, transition_speed * delta)
	if anim: anim.speed_scale = anim_speed_current

func _play_random_sound() -> void:
	if players_cache.is_empty():
		_update_players_cache()
		if players_cache.is_empty():
			return
	var sound: AudioStreamPlayer3D = players_cache[rng.randi_range(0, players_cache.size() - 1)]
	sound.play()

func _set_next_interval() -> void:
	next_interval = base_interval + rng.randf_range(extra_pause_min, extra_pause_max)

# -------------------
# Rest/move/stop cycle
# -------------------
func _update_mode(delta: float) -> void:
	rest_timer -= delta
	if rest_timer <= 0.0:
		if mode == Mode.MOVING:
			mode = Mode.RESTING
			rest_timer = rng.randf_range(rest_duration_min, rest_duration_max)
			anim_speed_target = 0.5
			movement_factor_target = 0.1
		elif mode == Mode.RESTING:
			mode = Mode.STOP
			rest_timer = rng.randf_range(3.0, 6.0) # stop duration
			anim_speed_target = 0.25
			movement_factor_target = 0.0
		else:
			mode = Mode.MOVING
			rest_timer = rng.randf_range(rest_interval_min, rest_interval_max)
			anim_speed_target = 1.0
			movement_factor_target = 1.0

func _reset_rest_timer() -> void:
	rest_timer = rng.randf_range(rest_interval_min, rest_interval_max)

# -------------------
# Movement & turning
# -------------------

func _face_direction_smooth(direction: Vector3, delta: float, speed: float) -> void:
	# stable, Euler-based smooth facing (avoids basis/quaternion instability)
	if direction.length() < 0.001:
		return
	var dir := direction.normalized()
	var yaw := atan2(dir.x, dir.z)
	var flat_len := sqrt(dir.x * dir.x + dir.z * dir.z)
	var pitch := 0.0
	if flat_len > 0.0001:
		pitch = -atan2(dir.y, flat_len) # negative to match look_at tilt direction
	var cur := whale.rotation
	var blend = clamp(speed * delta, 0.0, 1.0)
	cur.x = lerp_angle(cur.x, pitch, blend)
	cur.y = lerp_angle(cur.y, yaw, blend)
	cur.z = lerp_angle(cur.z, 0.0, blend) # roll -> 0 smoothly
	whale.rotation = cur

func _update_flight(delta: float) -> void:
	match mode:
		Mode.MOVING:
			next_turn_timer -= delta
			if next_turn_timer <= 0.0:
				_pick_new_direction()

			turn_time += delta
			var t = clamp(turn_time / turn_duration, 0.0, 1.0)
			var eased_t = 0.5 - 0.5 * cos(t * PI)

			current_dir = start_dir.slerp(target_dir, eased_t).normalized()
			global_position += current_dir * (move_speed * movement_factor_current) * delta
			look_at(global_position + current_dir, Vector3.UP)

		Mode.RESTING:
			global_position += current_dir * (move_speed * movement_factor_current) * delta
			look_at(global_position + current_dir, Vector3.UP)

		Mode.STOP:
			# drift if needed
			if movement_factor_current > 0.001:
				global_position += current_dir * (move_speed * movement_factor_current) * delta
			# keep looking in current_dir, but slowly flatten horizontal
			var flat_dir = current_dir
			flat_dir.y = 0.0
			if flat_dir.length() < 0.001:
				flat_dir = Vector3.FORWARD
			look_at(global_position + flat_dir.normalized(), Vector3.UP)

		Mode.NAVIGATING:
			if target_node and not navigation_reached:
				var dir = (target_node.global_position - global_position)
				if dir.length() > 0.001:
					dir = dir.normalized()
					current_dir = current_dir.slerp(dir, 0.8 * delta).normalized()
				global_position += current_dir * (move_speed * movement_factor_current) * delta
				look_at(global_position + current_dir, Vector3.UP)

				if global_position.distance_to(target_node.global_position) <= arrival_distance:
					navigation_reached = true
					mode = Mode.STOP
					anim_speed_target = 0.25
					movement_factor_target = 0.0
					park_timer = park_time

	# parking countdown handled only while actually parked
	if mode == Mode.STOP and navigation_reached:
		park_timer -= delta
		if park_timer <= 0.0:
			_go_to_next_target()


func _pick_new_direction() -> void:
	start_dir = current_dir
	target_dir = Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-0.3, 0.3),
		rng.randf_range(-1.0, 1.0)
	).normalized()
	turn_time = 0.0
	next_turn_timer = rng.randf_range(turn_interval_min, turn_interval_max)

# -------------------
# Navigation helpers
# -------------------
func call_whale(target) -> void:
	mode = Mode.NAVIGATING
	target_node = target
	navigation_reached = false
	anim_speed_target = 1.0
	movement_factor_target = 1.0
	

func call_nearest_whale(target: Node3D) -> void:
	var nearest: Node = null
	var nearest_dist: float = INF

	for whale in get_tree().get_nodes_in_group("bloop"):
		var d = whale.global_position.distance_to(target.global_position)
		if d < nearest_dist:
			nearest = whale
			nearest_dist = d

	if nearest:
		nearest.call_whale(target)
		
func navigate_to_points(points: Array[Node3D]) -> void:
	target_queue = points.duplicate()
	_go_to_next_target()
	
func _go_to_next_target() -> void:
	if target_queue.is_empty():
		mode = Mode.MOVING
		anim_speed_target = 1.0
		movement_factor_target = 1.0
		return

	target_node = target_queue.pop_front()
	mode = Mode.NAVIGATING
	navigation_reached = false
	anim_speed_target = 1.0
	movement_factor_target = 1.0
	park_timer = 0.0

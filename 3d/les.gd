extends CharacterBody3D

@export var base_drift_speed := -0.5
@export var boost_speed := -2.5
@export var panic_boost_speed := -4.0
@export var boost_interval_range := Vector2(2.0, 4.0)
@export var panic_boost_interval := 0.4
@export var turn_speed := 1.2
@export var rotation_interval_range := Vector2(3.0, 6.0)
@export var drag := 0.9
@export var orbit_bias := 0.7  # 0 = pure random, 1 = always orbit
@export var max_turn_angle_deg := 45.0
@export var max_pitch_angle_deg := 15.0
@export var patrol_radius := 10.0
@export var gravity_pull_speed := 1.5
@export var floor_height: float = 0.5    # how close to floor before they rise
@export var rise_boost: float = 1.5      # upward boost when near floor
@export var column_half_height: float = 5.0 # half-height of the allowed vertical column

var target_rotation := Basis.IDENTITY
var fountain_position: Vector3
var panic_mode := false

# Timing
var time_since_boost := 0.0
var next_boost_time := 3.0
var time_since_turn := 0.0
var next_turn_time := 5.0

func _ready():
	randomize()
	_find_nearest_fountain()
	_set_next_boost_time()
	_set_next_turn_time()
	_pick_new_direction(true)

func _physics_process(delta):
	if fountain_position == Vector3.ZERO:
		_find_nearest_fountain()

	# Horizontal distance (ignores Y)
	var horizontal_dist = Vector2(
		global_transform.origin.x - fountain_position.x,
		global_transform.origin.z - fountain_position.z
	).length()

	var vertical_offset = global_transform.origin.y - fountain_position.y

	if horizontal_dist > patrol_radius or abs(vertical_offset) > column_half_height:
		# Panic mode when outside horizontal or vertical range
		panic_mode = true
		var dir_to_fountain = (fountain_position - global_transform.origin).normalized()
		dir_to_fountain.y = clamp(dir_to_fountain.y + 0.4, -1.0, 1.0)
		target_rotation = Basis.looking_at(dir_to_fountain, Vector3.UP)
		velocity.y -= gravity_pull_speed * delta
	else:
		# Inside patrol area
		panic_mode = false
		time_since_turn += delta
		if time_since_turn >= next_turn_time:
			_pick_new_direction()
			_set_next_turn_time()
			time_since_turn = 0.0

	# Floor avoidance
	if global_transform.origin.y <= floor_height:
		var up_dir = transform.basis.y.normalized()
		velocity += up_dir * rise_boost
		var tilt_up_dir = -transform.basis.z
		tilt_up_dir.y += 0.4
		target_rotation = Basis.looking_at(tilt_up_dir.normalized(), Vector3.UP)

	# Apply drag
	velocity *= drag

	# Boost
	time_since_boost += delta
	if panic_mode:
		if time_since_boost >= panic_boost_interval:
			velocity += -transform.basis.z.normalized() * panic_boost_speed
			time_since_boost = 0.0
	else:
		if time_since_boost >= next_boost_time:
			velocity += -transform.basis.z.normalized() * boost_speed
			_set_next_boost_time()
			time_since_boost = 0.0

	# Gentle drift
	velocity += -transform.basis.z.normalized() * base_drift_speed * delta

	# Move
	move_and_slide()

	# Smooth rotation toward target
	var current_quat = transform.basis.get_rotation_quaternion()
	var target_quat = target_rotation.get_rotation_quaternion()
	var new_quat = current_quat.slerp(target_quat, delta * turn_speed)
	transform.basis = Basis(new_quat).orthonormalized()

func _pick_new_direction(initial := false):
	if fountain_position == Vector3.ZERO:
		return

	var new_dir: Vector3
	if initial:
		new_dir = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.3, 0.3),
			randf_range(-1.0, 1.0)
		).normalized()
	else:
		# Orbit tangent
		var to_self = global_transform.origin - fountain_position
		var up = Vector3.UP
		var orbit_dir = up.cross(to_self).normalized()

		# Random direction
		var random_dir = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.3, 0.3),
			randf_range(-1.0, 1.0)
		).normalized()

		# Blend between orbit_dir and random_dir based on orbit_bias
		new_dir = (orbit_dir * orbit_bias + random_dir * (1.0 - orbit_bias)).normalized()

	target_rotation = Basis.looking_at(new_dir, Vector3.UP)

func _find_nearest_fountain():
	var nearest_dist = INF
	for fountain in get_tree().get_nodes_in_group("Fountain"):
		if fountain is Node3D:
			var d = global_transform.origin.distance_to(fountain.global_transform.origin)
			if d < nearest_dist:
				nearest_dist = d
				fountain_position = fountain.global_transform.origin

func _set_next_boost_time():
	next_boost_time = randf_range(boost_interval_range.x, boost_interval_range.y)

func _set_next_turn_time():
	next_turn_time = randf_range(rotation_interval_range.x, rotation_interval_range.y)
 

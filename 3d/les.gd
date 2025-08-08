extends CharacterBody3D

@export var base_drift_speed := -0.5
@export var boost_speed := -2.5
@export var boost_interval_range := Vector2(2.0, 4.0)
@export var turn_speed := 2.0
@export var rotation_interval_range := Vector2(3.0, 6.0)
@export var drag := 0.9
@export var orbit_bias := 0.7  # 0 = pure random, 1 = always orbit
@export var patrol_radius := 10.0
@export var column_half_height := 5.0
@export var floor_height: float = 0.5
@export var return_speed := 3.0
@export var fountain_bias_inside := 0.2

# Vertical pull settings
@export var vertical_force := 1.5          # strength of vertical pull
@export var vertical_pull_duration := 2.0  # seconds of upward pull after returning

@onready var agent: NavigationAgent3D = $NavigationAgent3D

var target_rotation := Basis.IDENTITY
var fountain_position: Vector3

# Timing
var time_since_boost := 0.0
var next_boost_time := 3.0
var time_since_turn := 0.0
var next_turn_time := 5.0

# Vertical pull state
var vertical_pull := 0.0
var vertical_pull_timer := 0.0
var was_outside := false

func _ready():
	randomize()
	_find_nearest_fountain()

	# Randomize starting timers
	time_since_boost = randf_range(0.0, boost_interval_range.y)
	time_since_turn = randf_range(0.0, rotation_interval_range.y)

	_set_next_boost_time()
	_set_next_turn_time()
	_pick_new_direction(true)

	agent.max_speed = abs(return_speed)
	agent.path_max_distance = 100.0
	agent.target_desired_distance = 0.5

func _physics_process(delta):
	if fountain_position == Vector3.ZERO:
		_find_nearest_fountain()

	var pos = global_transform.origin
	var horizontal_dist = Vector2(pos.x - fountain_position.x, pos.z - fountain_position.z).length()
	var vertical_offset = pos.y - fountain_position.y

	var outside_radius = horizontal_dist > patrol_radius or abs(vertical_offset) > column_half_height

	# Vertical pull logic
	if outside_radius:
		vertical_pull = -1.0
		vertical_pull_timer = 0.0
		was_outside = true
	elif was_outside:
		vertical_pull = 1.0
		vertical_pull_timer = vertical_pull_duration
		was_outside = false

	# If we are inside but upward pull is active, count it down
	if vertical_pull_timer > 0.0:
		vertical_pull_timer -= delta
		if vertical_pull_timer <= 0.0:
			vertical_pull = 0.0

	# Movement logic
	if outside_radius or (horizontal_dist <= patrol_radius and pos.y < floor_height):
		# Direction toward fountain
		var dir_to_fountain = (fountain_position - pos).normalized()

		# Face away from fountain
		target_rotation = Basis.looking_at(-dir_to_fountain, Vector3.UP)
		_rotate_toward_target(delta)

		# Move toward fountain
		velocity = dir_to_fountain * return_speed
	else:
		# Inside patrol zone — wander
		agent.set_target_position(pos)

		time_since_turn += delta
		if time_since_turn >= next_turn_time:
			var to_self = global_transform.origin - fountain_position
			var orbit_dir = Vector3.UP.cross(to_self).normalized()
			var random_dir = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.3, 0.3),
				randf_range(-1.0, 1.0)
			).normalized()
			var to_fountain = (fountain_position - pos).normalized()
			var blend_dir = (orbit_dir * orbit_bias + random_dir * (1.0 - orbit_bias)).normalized()
			blend_dir = (blend_dir * (1.0 - fountain_bias_inside) + to_fountain * fountain_bias_inside).normalized()
			target_rotation = Basis.looking_at(blend_dir, Vector3.UP)

			_set_next_turn_time()
			time_since_turn = 0.0

		velocity *= drag

		time_since_boost += delta
		if time_since_boost >= next_boost_time:
			velocity += (-transform.basis.z.normalized()) * boost_speed
			_set_next_boost_time()
			time_since_boost = 0.0

		velocity += (-transform.basis.z.normalized()) * base_drift_speed * delta

		_rotate_toward_target(delta)

	# Apply vertical pull if active
	if vertical_pull != 0.0:
		velocity.y += vertical_pull * vertical_force * delta

	move_and_slide()

func _rotate_toward_target(delta):
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
		var to_self = global_transform.origin - fountain_position
		var up = Vector3.UP
		var orbit_dir = up.cross(to_self).normalized()
		var random_dir = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.3, 0.3),
			randf_range(-1.0, 1.0)
		).normalized()
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

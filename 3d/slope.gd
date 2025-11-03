extends Node3D
# Slope controller: self-driven velocity + dynamic drift physics.

@export var slope_accel: float = 25.0
@export var max_speed: float = 100.0
@export var stick_force: float = 30.0
@export var brake_decel: float = 28.0

# Turning & visual lag
@export var turn_speed_ground: float = 2.0
@export var turn_speed_air: float = 0.5
@export var yaw_smooth_ground: float = 3.0
@export var yaw_smooth_air: float = 6.0

# Drift physics thresholds (degrees)
@export var drift_start_angle: float = 70.0
@export var drift_break_angle: float = 100.0

@export var facing_delay_strength: float = 4.0 # smaller = tighter, larger = slower follow
@export var air_turn_influence: float = 1.0 # 0 = frozen velocity, 1 = full ground control

var current_velocity: Vector3 = Vector3.ZERO
var facing_dir: Vector3 = Vector3.FORWARD


func reset_slide_velocity() -> void:
	current_velocity = Vector3.ZERO


func start_slide(initial_dir: Vector3, initial_speed: float) -> void:
	if initial_dir.length() == 0.0:
		return
	var flat: Vector3 = initial_dir
	flat.y = 0.0
	if flat.length() > 0.001:
		facing_dir = flat.normalized()
	current_velocity = facing_dir * clamp(initial_speed, 0.0, max_speed)


func get_slide_velocity(player: CharacterBody3D, delta: float) -> Vector3:
	var input_vec: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var turn_input: float = input_vec.x
	var braking: bool = input_vec.y < 0.0

	var on_ground: bool = player != null and player.is_on_floor()

	var turn_rate: float = turn_speed_ground if on_ground else turn_speed_air
	var yaw_rate: float = yaw_smooth_ground if on_ground else yaw_smooth_air
	var ground_normal: Vector3 = Vector3.UP

	# --- Find ground normal if on floor ---
	if on_ground:
		var space_state = player.get_world_3d().direct_space_state
		var origin: Vector3 = player.global_transform.origin
		var target: Vector3 = origin - Vector3.UP * 1.6
		var query := PhysicsRayQueryParameters3D.create(origin, target)
		query.exclude = [player]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var result: Dictionary = space_state.intersect_ray(query)
		if result.size() > 0:
			ground_normal = (result["normal"] as Vector3).normalized()

	# --- Turning input ---
	if abs(turn_input) > 0.001:
		if on_ground:
			facing_dir = facing_dir.rotated(ground_normal, -turn_input * turn_rate * delta).normalized()
		else:
			facing_dir = facing_dir.rotated(Vector3.UP, -turn_input * (turn_rate * air_turn_influence) * delta).normalized()

	# --- Acceleration & physics ---
	if on_ground:
		var slope_tangent: Vector3 = (facing_dir - ground_normal * facing_dir.dot(ground_normal)).normalized()
		var slope_angle: float = acos(clamp(ground_normal.dot(Vector3.UP), -1.0, 1.0))
		var downhill_factor: float = max(slope_angle, 0.1)
		var accel_amount: float = slope_accel * downhill_factor * delta
		current_velocity += slope_tangent * accel_amount

		if braking:
			current_velocity = current_velocity.move_toward(Vector3.ZERO, brake_decel * delta)

		current_velocity -= ground_normal * (current_velocity.dot(ground_normal))
		current_velocity -= ground_normal * stick_force * slope_angle * delta
		current_velocity = current_velocity.limit_length(max_speed)
	else:
		current_velocity += Vector3.DOWN * 9.8 * delta

	# --- DRIFT & ANGLE CORRECTION ---
	var vel_dir: Vector3 = current_velocity.normalized() if current_velocity.length() > 0.001 else facing_dir
	var angle_diff: float = rad_to_deg(facing_dir.angle_to(vel_dir))

	if angle_diff > drift_break_angle:
		current_velocity = Vector3.ZERO
	elif angle_diff > drift_start_angle:
		var correction_strength: float = clamp((angle_diff - drift_start_angle) / 45.0, 0.0, 1.0)
		var lerp_factor: float = delta * (6.0 / facing_delay_strength) * (1.0 + correction_strength * 3.0)
		var new_dir: Vector3 = vel_dir.lerp(facing_dir, lerp_factor).normalized()
		current_velocity = new_dir * current_velocity.length()
	else:
		var correction: float = clamp(angle_diff / 80.0, 0.0, 1.0)
		var lerp_factor: float = delta * (2.0 / facing_delay_strength) * (1.0 + correction * 2.0)
		var new_dir: Vector3 = vel_dir.lerp(facing_dir, lerp_factor).normalized()
		current_velocity = new_dir * current_velocity.length()

	# --- Visual yaw (runs always, slight lag) ---
	var flat_dir: Vector3 = facing_dir
	flat_dir.y = 0.0
	if flat_dir.length() > 0.001:
		var target_basis: Basis = Basis().looking_at(flat_dir.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, clamp(yaw_rate * delta, 0.0, 1.0))

	return current_velocity

extends Node3D
# Slope controller: self-driven velocity + smooth yaw.
# It reads player input (A/D/S) but ignores camera entirely.
@export var slope_accel: float = 25.0
@export var slope_decel: float = 6.0
@export var max_speed: float = 40.0
@export var stick_force: float = 30.0
@export var turn_speed: float = 2.8        # how quickly input turns the facing direction
@export var brake_decel: float = 28.0
@export var friction: float = 0.5          # passive friction when not accelerating downhill
@export var yaw_smooth: float = 8.0        # visual yaw smoothing

var current_velocity: Vector3 = Vector3.ZERO
var facing_dir: Vector3 = Vector3.FORWARD  # persistent direction used for turning

func reset_slide_velocity() -> void:
	current_velocity = Vector3.ZERO

# Called once when player starts sliding to align slope to player's direction
func start_slide(initial_dir: Vector3, initial_speed: float) -> void:
	if initial_dir.length() == 0.0:
		return
	# make sure facing_dir is horizontal normalized
	var flat := initial_dir
	flat.y = 0.0
	if flat.length() > 0.001:
		facing_dir = flat.normalized()
	# project initial velocity onto slope plane later; for now set magnitude
	current_velocity = facing_dir * clamp(initial_speed, 0.0, max_speed)


# Main API used by player: returns the slope's world velocity for this frame
func get_slide_velocity(player: CharacterBody3D, delta: float) -> Vector3:
	# --- Handle input (always active, even midair) ---
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var turn_input := input_vec.x
	var braking := input_vec.y < 0.0

	if abs(turn_input) > 0.001:
		# Rotate around world-up while airborne
		facing_dir = facing_dir.rotated(Vector3.UP, -turn_input * turn_speed * delta).normalized()

	# --- Airborne behavior ---
	if player == null or not player.is_on_floor():
		# Apply gravity only (no friction in air)
		current_velocity += Vector3.DOWN * 9.8 * delta
		return current_velocity

	# --- Ground detection ---
	var space_state := player.get_world_3d().direct_space_state
	var origin := player.global_transform.origin
	var target := origin - Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [player]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(query)

	if result.size() == 0:
		# No ground found → keep momentum + gravity
		current_velocity += Vector3.DOWN * 9.8 * delta
		return current_velocity

	var ground_normal: Vector3 = (result["normal"] as Vector3).normalized()

	# --- Turning on ground (rotate around slope normal) ---
	if abs(turn_input) > 0.001:
		facing_dir = facing_dir.rotated(ground_normal, -turn_input * turn_speed * delta).normalized()

	# --- Tangent + acceleration ---
	var slope_tangent := (facing_dir - ground_normal * facing_dir.dot(ground_normal)).normalized()
	var slope_angle := acos(clamp(ground_normal.dot(Vector3.UP), -1.0, 1.0))
	var downhill_factor = max(slope_angle, 0.1)
	var accel_amount = slope_accel * downhill_factor * delta
	current_velocity += slope_tangent * accel_amount

	# --- Braking & deceleration ---
	if braking:
		current_velocity = current_velocity.move_toward(Vector3.ZERO, brake_decel * delta)

	# --- Remove velocity into ground (stay glued) ---
	current_velocity -= ground_normal * (current_velocity.dot(ground_normal))
	current_velocity -= ground_normal * stick_force * slope_angle * delta

	current_velocity = current_velocity.limit_length(max_speed)

	# --- Visual yaw follows facing direction ---
	var flat_dir := facing_dir
	flat_dir.y = 0.0
	if flat_dir.length() > 0.001:
		var target_basis := Basis().looking_at(flat_dir.normalized(), Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_basis, clamp(yaw_smooth * delta, 0.0, 1.0))

	return current_velocity

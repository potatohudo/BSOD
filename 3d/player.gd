extends CharacterBody3D
#movement and player related stuff.


const BASE_SPEED = 3.0  
const SPRINT_MUL = 1.5  
const CROUCH_MUL = 0.5
const SLIDE_JUMP_ACCEL = 10.0  
const SLIDE_BOOST = 1.2
const TRICK_ACCEL_GAIN = 1.5  
const ACCELERATION = 0.3  
const DEFAULT_MAX_CHAIN_SPEED = 20.0  
const CAMERA_SLIDE_OFFSET = -0.5
const SLIDE_FRICTION = 0.992  
const SLIDE_CANCEL_SPEED = 3.0  
const SLIDE_DURATION = 1.0  
const SLIDE_THRESHOLD = 15
const MOMENTUM_DECAY = 2.0
const WALL_IMPACT_KNOCKBACK = 40.0 
const WALL_IMPACT_DECAY = 0.08

const JUMP_VELOCITY = 6.5  
const WALL_JUMP_VELOCITY = 4.0  
const WALL_JUMP_PUSH = 10.0  
const GRAVITY = -9.8

const DASH_FORCE = 22.0  
const DASH_COOLDOWN = 3.0  
const DASH_EFX = 1
var can_dash = true  
var dash_efx = false

var speed = BASE_SPEED
var health = 100
var is_sliding = false
var can_wall_jump = false  
var slide_timer = 0.0  
var slide_cooldown_timer = 0.0
var movement_points = 0
var max_speed_cap = DEFAULT_MAX_CHAIN_SPEED  

var momentum = Vector3.ZERO
var active = false

@onready var marker: Node3D = $Marker3D  
@onready var camera: Camera3D = $Marker3D/Camera3D  
@onready var main_node = get_node("/root/Main")  
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 
@onready var dash_sprite = get_node("/root/Main/DashSprite") 
@onready var health_bar: Slider = get_node("/root/Main/health")  
@onready var freaky = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky") 
@onready var freaky2 = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky/Freaky2")
@onready var dm = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky/Datamoshing")
@onready var LH = get_node("/root/Main/SubViewportContainer/SubViewport/LowHealth")
@onready var hurt_sound_0: AudioStreamPlayer = get_node("/root/Main/Hurt0")
@onready var hurt_sound_1: AudioStreamPlayer = get_node("/root/Main/Hurt1")
@onready var hurt_sound_2: AudioStreamPlayer = get_node("/root/Main/Hurt2")
@onready var por = get_node("/root/Main/POR")
@onready var flashlight = $Marker3D/Camera3D/SpotLight3D

var is_game_over = false  
var crouching = false
var camera_locked = false 

func update_camera():
	if is_sliding or crouching:
		_apply_crouch_collision()
		marker.position.y = -1
	elif not is_sliding and not crouching:
		_reset_collision_size()
		marker.position.y = 0
	#it does not work any other way :(



func update_dash_sprite():
	if dash_efx == true:
		dash_sprite.visible = true
	else:
		dash_sprite.visible = false

func _physics_process(delta: float) -> void:
	if is_game_over:
		return

	var up := _up()
	up_direction = up  

	if momentum.length() > 0.1:
		momentum = momentum.lerp(Vector3.ZERO, MOMENTUM_DECAY * delta)
	else:
		momentum = Vector3.ZERO

	var direction := get_movement_direction()  # already planar to local up
	var is_sprinting := Input.is_action_pressed("sprint") and not is_sliding and direction.length() > 0.0

	if is_sprinting:
		speed = min(speed + ACCELERATION, max_speed_cap)
	else:
		var decay_rate := ACCELERATION * 0.5
		if not is_on_floor():
			decay_rate *= 0.25
		speed = move_toward(speed, BASE_SPEED, decay_rate)

	# Slide
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			speed *= SLIDE_FRICTION
			if speed < SLIDE_CANCEL_SPEED:
				exit_slide()

	# Apply gravity along local down (note: GRAVITY is negative in your script)
	if not is_on_floor():
		velocity += up * GRAVITY * delta  # GRAVITY is -9.8 → accelerates toward -up
		if is_sliding:
			exit_slide()

	# Idle-on-floor resets (unchanged logic)
	if not is_sprinting and direction.length() == 0.0 and is_on_floor():
		momentum = momentum.lerp(Vector3.ZERO, MOMENTUM_DECAY * delta)
		if momentum.length() < 0.1:
			momentum = Vector3.ZERO
			speed = BASE_SPEED
			movement_points = 0

	max_speed_cap = DEFAULT_MAX_CHAIN_SPEED + (movement_points * TRICK_ACCEL_GAIN)

	if Input.is_action_just_pressed("attack") and can_dash:
		perform_dash()

	# Jump along local up
	if Input.is_action_just_pressed("jump"):
		if is_sliding and is_on_floor():
			exit_slide_with_jump()
		elif is_on_floor():
			# clear any downward component then add jump along up
			var vert := up * velocity.dot(up)
			if vert.dot(up) < 0.0:
				velocity -= vert
			velocity += up * JUMP_VELOCITY

	# Crouch (unchanged)
	if Input.is_action_pressed("crouch") and not is_sliding:
		if is_on_floor():
			_apply_crouch_collision()
			crouching = true
	else:
		_reset_collision_size()
		crouching = false

	# High-speed wall impact checks (uses local up internally now)
	if speed >= SLIDE_THRESHOLD:
		check_wall_impact()

	var vert_comp := up * velocity.dot(up) 
	var current_tangent := velocity - vert_comp      
	var target_tangent: Vector3

	if direction.length() > 0.0:
		# move on the local ground plane; momentum is also planarized
		target_tangent = direction * speed + _project_on_plane(momentum, up)
	else:
		# no input → just coast on momentum on the plane
		target_tangent = _project_on_plane(momentum, up)

	# When no input, gently move toward target_tangent; with input we snap to target for responsiveness
	if direction.length() > 0.0:
		current_tangent = target_tangent
	else:
		current_tangent = current_tangent.move_toward(target_tangent, BASE_SPEED)

	velocity = vert_comp + current_tangent

	move_and_slide()

	# Kill condition (kept as-is; if your world rotates a lot, consider a distance-based fail instead)
	if health <= 0 or global_transform.origin.y < -20000.0:
		die()

	update_camera()
	update_dash_sprite()
	LH.visible = health < 20

	if Input.is_action_just_pressed("f"):
		flashlight.visible = not flashlight.visible
		por.visible = not por.visible
		active = not active


# Returns the player's current local up (normalized).
func _up() -> Vector3:
	return global_transform.basis.y.normalized()

# Projects v onto the plane perpendicular to n (i.e., removes the component along n).
func _project_on_plane(v: Vector3, n: Vector3) -> Vector3:
	return v - n * v.dot(n)


func perform_dash():
	if not can_dash:
		return

	can_dash = false
	dash_efx = true

	if not is_on_floor():
		movement_points += 1

	var up := _up()

	var dash_direction := get_movement_direction()
	if dash_direction.length() == 0.0:
		# default to camera forward but flattened to the local ground plane
		var cam_fwd := -camera.global_transform.basis.z
		dash_direction = _project_on_plane(cam_fwd, up).normalized()

	dash_direction = _project_on_plane(dash_direction, up).normalized()

	var dash_force := DASH_FORCE
	if not is_on_floor():
		dash_force *= 2.0
	else:
		dash_force *= 1.0

	momentum = dash_direction * dash_force
	velocity += momentum
	speed = max(speed, speed + dash_force * 0.5)

	await get_tree().create_timer(DASH_EFX).timeout
	dash_efx = false
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true

var input_locked = false  

func apply_knockback(force: Vector3):
	momentum += force 
	velocity += force
#throw the player basically

func check_wall_impact():
	if speed < SLIDE_THRESHOLD or input_locked:
		return

	var up := _up()
	var space_state := get_world_3d().direct_space_state
	var origin := global_transform.origin

	var camera_facing := -camera.global_transform.basis.z
	camera_facing = _project_on_plane(camera_facing, up).normalized()

	var check_distance := 1.5
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera_facing * check_distance)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space_state.intersect_ray(query)
	if result:
		var normal: Vector3 = result.normal.normalized()
		# angle between hit normal and our local up: >45° → treat as wall
		var angle := rad_to_deg(acos(clamp(normal.dot(up), -1.0, 1.0)))
		if angle > 45.0:
			handle_wall_collision(camera_facing)



func handle_wall_collision(direction: Vector3):
	if dash_efx == true:
		var knockback_force = -direction * WALL_IMPACT_KNOCKBACK  
		apply_knockback(knockback_force)  
		movement_points += 1  
	else: 
		if speed >= 20:
			var damage_taken = min(speed / 2, 100)  
			apply_damage(damage_taken)
		speed = 0
		velocity = Vector3.ZERO
		momentum = Vector3.ZERO  

	await get_tree().create_timer(0.3).timeout  
	momentum = momentum.lerp(Vector3.ZERO, WALL_IMPACT_DECAY)  

func start_slide(): 
	if not is_on_floor() or speed < SLIDE_THRESHOLD:
		pass
	else:
		is_sliding = true
		slide_timer = SLIDE_DURATION  
		speed = max(speed, SLIDE_THRESHOLD) * SLIDE_BOOST  
		velocity = get_movement_direction() * speed  
		movement_points += 1

func exit_slide():
	is_sliding = false
	movement_points = 0
	momentum = Vector3.ZERO 

func exit_slide_with_jump():
	is_sliding = false
	exit_slide()
	var up := _up()
	velocity += up * (JUMP_VELOCITY * 1.5)
	speed = speed * 20.0
	movement_points += 1


func get_movement_direction() -> Vector3:
	var up := _up()

	# Camera forward/right, then remove any component along local up
	var cam_fwd := -camera.global_transform.basis.z
	var cam_right := camera.global_transform.basis.x
	cam_fwd = _project_on_plane(cam_fwd, up).normalized()
	cam_right = _project_on_plane(cam_right, up).normalized()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_down", "ui_up")
	var dir := (cam_fwd * input_dir.y + cam_right * input_dir.x)
	return dir.normalized() if dir.length() > 0.0 else Vector3.ZERO


func _apply_crouch_collision():
	collision_shape.shape.height = 0.8  
	collision_shape.position.y = 0.4  

func _reset_collision_size():
	collision_shape.shape.height = 1.6  
	collision_shape.position.y = 0.8

func apply_damage(amount: int):
	if amount >= 15 and amount <= 29:
		hurt_sound_0.play()
	elif amount >= 30 and amount <= 39:
		hurt_sound_1.play()
	elif amount >= 40:
		hurt_sound_2.play()

	health -= amount
	health = max(health, 0)
	health_bar.value = health
	
#shader logic
	var freaky_intensity = clamp(amount / 50.0, 0.1, 1.0)
	var freaky2_intensity = clamp(amount / 50.0, 0.01, 1.0)
	var dm_intensity = clamp(amount / 50.0, 0.1, 1.0)

	freaky.visible = true
	freaky2.visible = true
	dm.visible = true

	freaky.material.set_shader_parameter("strength", freaky_intensity)
	freaky2.material.set_shader_parameter("strength", freaky2_intensity)
	dm.material.set_shader_parameter("strength", dm_intensity)

	var tween = get_tree().create_tween().set_parallel(true)

	tween.tween_property(freaky.material, "shader_parameter/strength", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(freaky2.material, "shader_parameter/strength", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(dm.material, "shader_parameter/strength", 0.0, 2.0).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func():
		freaky.visible = false
		freaky2.visible = false
		dm.visible = false
	)


func die():
	print("died!")
	is_game_over = true  
	main_node.death_glitch()  
	await get_tree().create_timer(2).timeout
	get_tree().change_scene_to_file("res://3d/GameOver.tscn")

func respawn():
	health = 100
	global_transform.origin = Vector3(0, 1, 0)
	is_game_over = false

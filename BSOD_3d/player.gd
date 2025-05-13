extends CharacterBody3D

const BASE_SPEED = 4.0  
const SPRINT_MUL = 1.5  
const CROUCH_MUL = 0.5
const SLIDE_JUMP_ACCEL = 5.0  
const SLIDE_BOOST = 1.2
const TRICK_ACCEL_GAIN = 1.5  
const ACCELERATION = 0.3  
const DEFAULT_MAX_CHAIN_SPEED = 20.0  
const SLIDE_THRESHOLD = 15.0  
const CAMERA_SLIDE_OFFSET = -0.5
const SLIDE_FRICTION = 0.992  
const SLIDE_CANCEL_SPEED = 3.0  
const SLIDE_DURATION = 1.0  
const MOMENTUM_DECAY = 2.0
const WALL_IMPACT_KNOCKBACK = 40.0 
const WALL_IMPACT_DECAY = 0.08

const JUMP_VELOCITY = 6.5  
const WALL_JUMP_VELOCITY = 4.0  
const WALL_JUMP_PUSH = 10.0  
const GRAVITY = -9.8

const DASH_FORCE = 20.0  
const DASH_COOLDOWN = 1.0  
var can_dash = true  

var speed = BASE_SPEED
var health = 100
var is_sliding = false
var is_in_air = false  
var can_wall_jump = false  
var slide_timer = 0.0  
var movement_points = 0
var max_speed_cap = DEFAULT_MAX_CHAIN_SPEED  
var should_slide_on_landing = false  
var momentum = Vector3.ZERO

@onready var marker: Node3D = $Marker3D  
@onready var camera: Camera3D = $Marker3D/Camera3D  
@onready var main_node = get_node("/root/Main")  
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 
@onready var dash_sprite = get_node("/root/Main/DashSprite") 
@onready var health_bar: Slider = get_node("/root/Main/health")  
@onready var freaky = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky") 
@onready var freaky2 = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky2")
@onready var LH = get_node("/root/Main/SubViewportContainer/SubViewport/LowHealth")
@onready var hurt_sound_0: AudioStreamPlayer = get_node("/root/Main/Hurt0")
@onready var hurt_sound_1: AudioStreamPlayer = get_node("/root/Main/Hurt1")
@onready var hurt_sound_2: AudioStreamPlayer = get_node("/root/Main/Hurt2")

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

func show_dash_sprite(visible: bool):
	if dash_sprite:
		dash_sprite.visible = visible  

func update_dash_sprite():
	if not can_dash and is_in_air:
		show_dash_sprite(true)  
	else:
		show_dash_sprite(false)  

func _physics_process(delta: float) -> void:
	if is_game_over:
		return  
		
	if momentum.length() > 0.1:
		momentum = momentum.lerp(Vector3.ZERO, MOMENTUM_DECAY * delta) 
	else:
		momentum = Vector3.ZERO  

	var movement_override = momentum.length() > 0.1  
	var direction = get_movement_direction()
	
	if not movement_override and direction.length() > 0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = momentum.x  # Allows momentum to carry the player
		velocity.z = momentum.z

	if not is_on_floor():
		velocity += Vector3(0, GRAVITY, 0) * delta
		is_in_air = true

		# Reset movement points & speed when stopping sprint
		if not Input.is_action_pressed("sprint") or get_movement_direction().length() == 0 and is_on_floor():
			momentum = momentum.lerp(Vector3.ZERO, MOMENTUM_DECAY * delta)
			if momentum.length() < 0.1:
				momentum = Vector3.ZERO  
				speed = BASE_SPEED  
				movement_points = 0  # Reset movement chain

	# Update max speed cap based on movement points
	max_speed_cap = DEFAULT_MAX_CHAIN_SPEED + (movement_points * TRICK_ACCEL_GAIN)


	# Sprinting & Acceleration (Only when moving)
	if Input.is_action_pressed("sprint") and not is_sliding and direction.length() > 0:
		speed = min(speed + ACCELERATION, max_speed_cap)  


	# Sliding Mechanics
	if is_sliding:
		slide_timer -= delta
		speed *= SLIDE_FRICTION  

		# Exit slide when speed is too low or off the ground
		if speed < SLIDE_CANCEL_SPEED and is_on_floor():  
			exit_slide()

	# **Dash Mechanic**
	if Input.is_action_just_pressed("attack") and can_dash:
		perform_dash()

	# Jumping Mechanics
	if Input.is_action_just_pressed("jump"):
		if is_sliding:  
			exit_slide_with_jump()
		elif is_on_floor():
			velocity.y = JUMP_VELOCITY  

	# Crouch Handling
	if Input.is_action_pressed("crouch") and not is_sliding:
		_apply_crouch_collision()
		crouching = true
	else:
		_reset_collision_size()
		crouching = false
	if speed >= SLIDE_THRESHOLD:
		check_wall_impact()

	# Movement Handling
	if direction.length() > 0:
		velocity.x = direction.x * speed + momentum.x 
		velocity.z = direction.z * speed + momentum.z
	else:
		velocity.x = move_toward(velocity.x, 0, BASE_SPEED)
		velocity.z = move_toward(velocity.z, 0, BASE_SPEED)

	move_and_slide()

	# Death Check
	if health <= 0 or global_transform.origin.y < -20:
		die()

	update_camera()
	update_dash_sprite()
	
	if health < 20:
		LH.visible = true
	else:
		LH.visible = false

func perform_dash():
	if not can_dash:
		return  

	can_dash = false
	
	if not is_on_floor():  
		movement_points += 1  

	var dash_direction = get_movement_direction()
	if dash_direction.length() == 0:
		dash_direction = -camera.global_transform.basis.z
	dash_direction.y = 0  
	dash_direction = dash_direction.normalized()

	var dash_force = DASH_FORCE
	var dashing_in_air = not is_on_floor()

	if speed >= SLIDE_THRESHOLD and dashing_in_air:
		dash_force *= 1.5  

	else:
		dash_force *= 1.2  

	momentum = dash_direction * dash_force

	velocity += momentum    
	speed = max(speed, speed + dash_force)  

	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true  

var input_locked = false  

func apply_knockback(force: Vector3):
	momentum += force 
	velocity += force

func check_wall_impact():
	if speed < SLIDE_THRESHOLD or input_locked:
		return  

	var space_state = get_world_3d().direct_space_state
	var origin = global_transform.origin
	var camera_facing = -camera.global_transform.basis.z  
	camera_facing.y = 0  
	camera_facing = camera_facing.normalized()

	var check_distance = 1.5  
	var query = PhysicsRayQueryParameters3D.create(origin, origin + camera_facing * check_distance)
	query.exclude = [self] 
	query.collide_with_areas = false  
	query.collide_with_bodies = true  

	var result = space_state.intersect_ray(query)

	if result:  
		handle_wall_collision(camera_facing)

func handle_wall_collision(direction: Vector3):
	if not can_dash:
		var knockback_force = -direction * WALL_IMPACT_KNOCKBACK  

		apply_knockback(knockback_force)  
		should_slide_on_landing = true  
		movement_points += 1  

	else: 
		if speed >= 20:
			var damage_taken = min(speed / 2, 100)  
			apply_damage(damage_taken)
		speed = 0
		velocity = Vector3.ZERO
		momentum = Vector3.ZERO  

	# 🚀 Gradually regain control
	await get_tree().create_timer(0.3).timeout  
	momentum = momentum.lerp(Vector3.ZERO, WALL_IMPACT_DECAY)  

# **Sliding Functions**
func start_slide():
	if not should_slide_on_landing:
		return 
	
	is_sliding = true
	slide_timer = SLIDE_DURATION  
	speed = max(speed, SLIDE_THRESHOLD) * SLIDE_BOOST  
	velocity = get_movement_direction() * speed  
	should_slide_on_landing = false  

func exit_slide():
	is_sliding = false
	speed = move_toward(speed, BASE_SPEED, ACCELERATION * 5)
	should_slide_on_landing = false 
	movement_points = 0
	momentum = Vector3.ZERO 

func exit_slide_with_jump():
	exit_slide()  
	velocity.y = JUMP_VELOCITY * 1.5 
	speed = max(speed, SLIDE_THRESHOLD) * 2.0
	should_slide_on_landing = false
	movement_points += 1 
	 
 

	if is_sliding and not Input.is_action_pressed("sprint"):
		exit_slide()



# **Movement Helper**
func get_movement_direction() -> Vector3:
	
	
	var forward_direction = camera.global_transform.basis.z 
	forward_direction.y = 0
	forward_direction = forward_direction.normalized()

	var right_direction = camera.global_transform.basis.x
	right_direction.y = 0
	right_direction = right_direction.normalized()


	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return (forward_direction * input_dir.y + right_direction * input_dir.x).normalized()

# **Crouch Mechanics**
func _apply_crouch_collision():
	collision_shape.shape.height = 0.8  
	collision_shape.position.y = 0.4  

func _reset_collision_size():
	collision_shape.shape.height = 1.6  
	collision_shape.position.y = 0.8

func apply_damage(amount: int):
	# Play appropriate hurt sound based on damage amount
	if amount >= 15 and amount <= 29:
		hurt_sound_0.play()
	elif amount >= 30 and amount <= 39:
		hurt_sound_1.play()
	elif amount >= 40:
		hurt_sound_2.play()

	health -= amount
	health = max(health, 0)
	health_bar.value = health

	var glitch_intensity = clamp(amount / 50.0, 0.1, 1.0)
	var freaky_intensity = clamp (amount / 50.0, 0.01, 1.0)

	freaky.visible = true
	freaky2.visible = true
	
	freaky.material.set_shader_parameter("strength", glitch_intensity)
	freaky2.material.set_shader_parameter("strength", freaky_intensity)

	var tween = get_tree().create_tween()
	tween.tween_property(freaky.material, "shader_parameter/strength", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	tween.finished.connect(func(): freaky.visible = false)
	
	tween.set_parallel(true)
	
	#var tween2 = get_tree().create_tween()
	#tween2.tween_property(freaky2.material, "shader_parameter/strength", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
	#tween2.finished.connect(func(): freaky2.visible = false)
	##god how the fuck do i make them parallel

# Death & Respawn
func die():
	is_game_over = true  
	main_node.death_glitch()  
	await get_tree().create_timer(2).timeout
	get_tree().change_scene_to_file("res://GameOver.tscn")

func respawn():
	health = 100
	global_transform.origin = Vector3(0, 1, 0)
	is_game_over = false  

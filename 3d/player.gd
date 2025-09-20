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
var atk_mode = false
enum PlayerMode { PEACEFUL, FIGHTING }
var current_mode: PlayerMode = PlayerMode.PEACEFUL


@onready var marker: Node3D = $Marker3D  
@onready var camera: Camera3D = $Marker3D/Camera3D  
@onready var main_node = get_node("/root/Main")  
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 
@onready var dash_sprite = get_node("/root/Main/Sprites/DashSprite") 
@onready var health_bar: Slider = get_node("/root/Main/health")  
@onready var freaky = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky") 
@onready var freaky2 = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky/Freaky2")
@onready var dm = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky/Datamoshing")
@onready var LH = get_node("/root/Main/SubViewportContainer/SubViewport/LowHealth")
@onready var hurt_sound_0: AudioStreamPlayer = get_node("/root/Main/Hurt0")
@onready var hurt_sound_1: AudioStreamPlayer = get_node("/root/Main/Hurt1")
@onready var hurt_sound_2: AudioStreamPlayer = get_node("/root/Main/Hurt2")
@onready var por = get_node("/root/Main/Sprites/POR")
@onready var flashlight = $Marker3D/Camera3D/SpotLight3D

var is_game_over = false  
var crouching = false
var camera_locked = false 

func toggle_mode():
	current_mode = PlayerMode.FIGHTING if current_mode == PlayerMode.PEACEFUL else PlayerMode.PEACEFUL
	atk_mode = (current_mode == PlayerMode.FIGHTING)
	flashlight.visible = not flashlight.visible
	por.visible = not por.visible
	print(current_mode)
	

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

	_update_momentum(delta)
	var direction := get_movement_direction()
	var is_sprinting := Input.is_action_pressed("sprint") and not is_sliding and direction.length() > 0.0 and current_mode == PlayerMode.PEACEFUL

	_compute_speed(delta, is_sprinting)
	_update_sliding(delta)
	_apply_gravity_if_needed(delta, up)
	_idle_on_floor_reset(delta, is_sprinting, direction)

	max_speed_cap = DEFAULT_MAX_CHAIN_SPEED + (movement_points * TRICK_ACCEL_GAIN)

	_handle_attack_and_jump(up)
	_handle_crouch_or_slide()

	if speed >= SLIDE_THRESHOLD:
		check_wall_impact()

	_compose_velocity(direction, up)

	move_and_slide()

	if health <= 0 or global_transform.origin.y < -20000.0:
		die()

	if Input.is_action_just_pressed("f"):
		toggle_mode()

	update_camera()
	update_dash_sprite()
	LH.visible = health < 20


func _update_momentum(delta: float) -> void:
	if momentum.length() > 0.1:
		momentum = momentum.lerp(Vector3.ZERO, MOMENTUM_DECAY * delta)
	else:
		momentum = Vector3.ZERO


func _compute_speed(delta: float, is_sprinting: bool) -> void:
	if is_sprinting:
		speed = min(speed + ACCELERATION, max_speed_cap)
	else:
		var decay_rate := ACCELERATION * 0.5
		if not is_on_floor():
			decay_rate *= 0.25
		speed = move_toward(speed, BASE_SPEED, decay_rate)


func _update_sliding(delta: float) -> void:
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			speed *= SLIDE_FRICTION
			if speed < SLIDE_CANCEL_SPEED:
				exit_slide()


func _apply_gravity_if_needed(delta: float, up: Vector3) -> void:
	if not is_on_floor():
		velocity += up * GRAVITY * delta
		if is_sliding:
			exit_slide()


func _idle_on_floor_reset(delta: float, is_sprinting: bool, direction: Vector3) -> void:
	if not is_sprinting and direction.length() == 0.0 and is_on_floor():
		momentum = momentum.lerp(Vector3.ZERO, MOMENTUM_DECAY * delta)
		if momentum.length() < 0.1:
			momentum = Vector3.ZERO
			speed = BASE_SPEED
			movement_points = 0


func _handle_attack_and_jump(up: Vector3) -> void:
	if Input.is_action_just_pressed("attack"):
		if current_mode == PlayerMode.FIGHTING:
			if can_dash:
				perform_dash()
		else:
			perform_grab()

	if Input.is_action_just_pressed("jump"):
		if is_sliding and is_on_floor():
			exit_slide_with_jump()
		elif is_on_floor():
			var vert := up * velocity.dot(up)
			if vert.dot(up) < 0.0:
				velocity -= vert
			velocity += up * JUMP_VELOCITY


func _handle_crouch_or_slide() -> void:
	if current_mode == PlayerMode.PEACEFUL:
		if Input.is_action_pressed("crouch") and not is_sliding and is_on_floor():
			_apply_crouch_collision()
			crouching = true
		else:
			_reset_collision_size()
			crouching = false
	else:
		var decay_rate2 := ACCELERATION * 0.5
		if not is_on_floor():
			decay_rate2 *= 0.25
		speed = move_toward(speed, BASE_SPEED, decay_rate2)
		if Input.is_action_pressed("crouch"):
			start_slide()


func _compose_velocity(direction: Vector3, up: Vector3) -> void:
	var vert_comp := up * velocity.dot(up)
	var current_tangent := velocity - vert_comp
	var target_tangent: Vector3

	if direction.length() > 0.0:
		target_tangent = direction * speed + _project_on_plane(momentum, up)
	else:
		target_tangent = _project_on_plane(momentum, up)

	if direction.length() > 0.0:
		current_tangent = target_tangent
	else:
		current_tangent = current_tangent.move_toward(target_tangent, BASE_SPEED)

	velocity = vert_comp + current_tangent



func _up() -> Vector3:
	return global_transform.basis.y.normalized()

func _project_on_plane(v: Vector3, n: Vector3) -> Vector3:
	return v - n * v.dot(n)

func perform_grab():
	print("perform_grab() called (peaceful)")

func perform_wall_run():
	print("perform_wall_run() called (peaceful)")


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
	if dash_efx == true and current_mode == PlayerMode.FIGHTING:
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

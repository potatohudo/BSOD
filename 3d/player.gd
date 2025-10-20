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
const WALL_JUMP_VELOCITY = 10.0  
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
const SLIDE_GRAVITY = -2.5  # weaker gravity while sliding down a wall

var crouch_parent: Node3D = null
var crouch_offset: Vector3 = Vector3.ZERO

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
#@onready var sword = get_node("/root/Main/Sprites/POR_Transition")
#@onready var sword1 = get_node("/root/Main/Sprites/POR_Sword/Idle")
@onready var flashlight = $Marker3D/Camera3D/SpotLight3D
@onready var slope_node: Node3D = $slope


var is_game_over = false  
var crouching = false
var camera_locked = false 

@onready var sprite_handler = get_node("/root/Main/Sprites") 

func _ready() -> void:
	sprite_handler.mode_toggled.connect(_on_mode_toggled)

func _on_mode_toggled(new_mode: int):
	current_mode = new_mode
	atk_mode = (new_mode == PlayerMode.FIGHTING)
	flashlight.visible = not flashlight.visible
	crouching = false
	mode_locked = false

var mode_locked = false

func toggle_mode():
	if mode_locked:
		return
	mode_locked = true
	sprite_handler.request_toggle_mode(current_mode)
	
	#current_mode = PlayerMode.FIGHTING if current_mode == PlayerMode.PEACEFUL else PlayerMode.PEACEFUL
	#atk_mode = (current_mode == PlayerMode.FIGHTING)
	#flashlight.visible = not flashlight.visible
	#por.visible = not por.visible
	#print(current_mode)
	

func update_camera():
	if is_sliding or crouching:
		_apply_crouch_collision()
		marker.position.y = -1
	elif not is_sliding and not crouching:
		_reset_collision_size()
		marker.position.y = 0
	#it does not work any other way :(

func update_dash_sprite():
	if is_grabbing == true:
		dash_sprite.visible = true
	else:
		dash_sprite.visible = false

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
	if is_grabbing:
		# cancel immediately if key is released
		if not Input.is_action_pressed("attack"):
			_release_grab()
		elif grabbed_body:
			var target_pos = grabbed_body.to_global(grab_offset)
			
			if grab_timer > 0.0:
				# fully locked: stick in place
				global_transform.origin = target_pos
				velocity = Vector3.ZERO
				momentum = Vector3.ZERO
				grab_timer -= delta
				# allow jump while locked
				if Input.is_action_just_pressed("jump"):
					_perform_grab_jump()
				return
			else:
				# timer ran out: horizontal locked, vertical slides
				global_transform.origin.x = target_pos.x
				global_transform.origin.z = target_pos.z
				
				var up := _up()
				# apply weaker gravity so slide is slower
				velocity += up * SLIDE_GRAVITY * delta  
				velocity = up * velocity.dot(up)
				move_and_slide()
				
				# allow jump while sliding
				if Input.is_action_just_pressed("jump"):
					_perform_grab_jump()
				return
	var up := _up()
	up_direction = up

	_update_momentum(delta)
	var direction := Vector3.ZERO
	if not is_sliding:
		direction = get_movement_direction()

	var is_sprinting := Input.is_action_pressed("sprint") and not is_sliding and direction.length() > 0.0 and current_mode == PlayerMode.PEACEFUL

	_compute_speed(delta, is_sprinting)
	_update_sliding(delta)
	_apply_gravity_if_needed(delta, up)
	_idle_on_floor_reset(delta, is_sprinting, direction)

	max_speed_cap = DEFAULT_MAX_CHAIN_SPEED + (movement_points * TRICK_ACCEL_GAIN)

	_handle_attack_and_jump(up)
	_handle_crouch_or_slide(delta)

	if speed >= SLIDE_THRESHOLD:
		check_wall_impact()

	_compose_velocity(direction, up)

	move_and_slide()

	if health <= 0 or global_transform.origin.y < -20000.0:
		die()

	if Input.is_action_just_pressed("f"):
		toggle_mode()

	update_camera()
	#_apply_slide_tilt(delta)
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
		return
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			speed *= SLIDE_FRICTION
			if speed < SLIDE_CANCEL_SPEED:
				exit_slide()


func _apply_gravity_if_needed(delta: float, up: Vector3) -> void:
	if not is_on_floor():
		velocity += up * GRAVITY * delta
		#if is_sliding:
			#exit_slide()


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


var is_grabbing = false
var grabbed_body: Node3D = null
var grab_offset: Vector3 = Vector3.ZERO
var grab_timer: float = 0.0
const MAX_GRAB_TIME = 2.0   # how long to stay locked before sliding

func perform_grab():
	if current_mode != PlayerMode.PEACEFUL:
		return
	dash_efx = true
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_transform.origin
	var dir = -camera.global_transform.basis.z.normalized()
	var target = origin + dir * 3.0  # grab range
	
	var query = PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		is_grabbing = true
		grabbed_body = result.collider
		grab_offset = grabbed_body.to_local(global_transform.origin)
		grab_timer = MAX_GRAB_TIME
		velocity = Vector3.ZERO
		momentum = Vector3.ZERO
func _release_grab():
	is_grabbing = false
	grabbed_body = null
	grab_timer = 0.0
	dash_efx = false

func _perform_grab_jump():
	var up := _up()
	var forward := -camera.global_transform.basis.z
	# push away from wall + upward force
	velocity = _project_on_plane(forward, up).normalized() * WALL_JUMP_PUSH
	velocity += up * WALL_JUMP_VELOCITY
	_release_grab()

# uuh slide slope stuff

var slide_speed: float = 0.0
var slide_dir: Vector3 = Vector3.ZERO
const SLOPE_SPEED_DECAY = 6.0      # speed loss per slope angle FOR LATER

var slope_tilt_current := 0.0
func _get_floor_normal() -> Vector3:
	if get_slide_collision_count() == 0:
		return _up()
	for i in range(get_slide_collision_count()):
		var c = get_slide_collision(i)
		if c.get_normal().dot(_up()) > 0.4:
			return c.get_normal().normalized()
	return _up()

func _start_slide_from_player() -> void:
	# called when player initiates slide (presses crouch in fighting mode)
	if not is_on_floor():
		return
	is_sliding = true
	_apply_crouch_collision()
	crouching = true
	momentum = Vector3.ZERO
	slide_speed = max(speed, BASE_SPEED)
	# determine initial_dir from player's movement intent (not camera yaw). Use get_movement_direction()
	var initial_dir := get_movement_direction()
	if initial_dir.length() == 0.0:
		# fallback to camera forward flattened to local up
		initial_dir = -camera.global_transform.basis.z
		initial_dir = _project_on_plane(initial_dir, _up()).normalized()
	# ensure slope faces player's current direction and initialize slope velocity
	if slope_node and slope_node.has_method("start_slide"):
		slope_node.start_slide(initial_dir, slide_speed)
	slope_node.visible = true

# --- the handler function where slide is maintained (replace previous slide block) ---
func _handle_crouch_or_slide(delta: float) -> void:
	var crouch_pressed := Input.is_action_pressed("crouch")

	if current_mode == PlayerMode.PEACEFUL:
		if crouch_pressed and not crouching:
			_apply_crouch_collision()
			crouching = true
			crouch_parent = null
			momentum = Vector3.ZERO
			speed = BASE_SPEED
		elif not crouch_pressed and crouching:
			_reset_collision_size()
			crouching = false
		return

	# Fighting mode = slope-based slide
	if crouch_pressed:
		if not is_sliding and is_on_floor():
			_start_slide_from_player()

		if is_sliding:
			# entirely inherit slope velocity; player input only influences the slope node
			if slope_node and slope_node.has_method("get_slide_velocity"):
				var slope_velocity: Vector3 = slope_node.get_slide_velocity(self, delta)
				# if slope node returns a valid velocity, follow it exactly
				if slope_velocity.length() > 0.001:
					velocity = slope_velocity
					speed = slope_velocity.length()
				else:
					# fallback if slope returned zero
					var up := _up()
					var planar := velocity - up * velocity.dot(up)
					if planar.length() < 0.01:
						planar = -camera.global_transform.basis.z
						planar = _project_on_plane(planar, up)
					velocity = planar.normalized() * max(speed, BASE_SPEED)
					speed = velocity.length()
			else:
				# no slope node available: keep previous slide_dir speed
				velocity = slide_dir * slide_speed
				speed = slide_speed

	else:
		# release slide
		if is_sliding:
			exit_slide()
			if slope_node and slope_node.has_method("reset_slide_velocity"):
				slope_node.reset_slide_velocity()
			if slope_node:
				slope_node.visible = false
		crouching = false
		_reset_collision_size()


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


func perform_wall_run():
	print("perform_wall_run() called (peaceful)")


func perform_dash() -> void:
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
	else:
		dash_direction = _project_on_plane(dash_direction, up).normalized()

	var dash_force := DASH_FORCE
	if not is_on_floor():
		dash_force *= 2.0

	momentum = dash_direction * dash_force
	velocity += momentum
	speed = max(speed, speed + dash_force * 0.5)

	# always reset effect and cooldown, even if interrupted
	await get_tree().create_timer(DASH_EFX).timeout
	dash_efx = false

	var cooldown_timer = get_tree().create_timer(DASH_COOLDOWN)
	await cooldown_timer.timeout
	if is_instance_valid(self): # ensure player still exists
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
	elif amount >= 30:
		hurt_sound_1.play()
	#elif amount >= 40:
		#hurt_sound_2.play()

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

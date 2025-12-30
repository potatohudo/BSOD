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
const SLIDE_GRAVITY = -2.5  


# COMBAT
const SLASH_COOLDOWN: float = 0.8
const COMBO_WINDOW: float = 0.35
const BASE_DAMAGE: float = 10.0
const SUPERDASH_MULT: float = 2.2
const SUPERDASH_EXTRA_COOLDOWN: float = 2.0

var can_slash: bool = true
var slash_chain_timer: float = 0.0
var combo_stage: int = 0
var combo_buffered: bool = false

# Slash / stored-dash state
var attack_hold_time: float = 0.0
const ATTACK_HOLD_THRESHOLD: float = 1.0  # how long you must hold to consider "stored"
const LONG_DASH_DURATION: float = 0.5
const LONG_DASH_SPEED_MULT: float = 1.6  # how much stronger the stored dash speed is
const LONG_DASH_DAMAGE_MULT: float = 2.0  # stored dash deals more damage

var slash_buffered: bool = false        # player is holding attack (buffered)
var in_long_dash: bool = false
var long_dash_time_left: float = 0.0
var long_dash_direction: Vector3 = Vector3.ZERO
var long_dash_speed: float = 0.0


var crouch_parent: Node3D = null
var crouch_offset: Vector3 = Vector3.ZERO

@onready var marker: Node3D = $Marker3D  
@onready var camera: Camera3D = $Marker3D/Camera3D  
@onready var main_node = get_node("/root/Main")  
@onready var collision_shape: CollisionShape3D = $CollisionShape3D 
@onready var dash_sprite = $Marker3D/Camera3D/Sprites/DashSprite
@onready var health_bar: Slider = get_node("/root/Main/health")  
@onready var freaky = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky") 
@onready var freaky2 = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky/Freaky2")
@onready var dm = get_node("/root/Main/SubViewportContainer/SubViewport/Freaky/Datamoshing")
@onready var LH = get_node("/root/Main/SubViewportContainer/SubViewport/LowHealth")
@onready var hurt_sound_0: AudioStreamPlayer = get_node("/root/Main/Hurt0")
@onready var hurt_sound_1: AudioStreamPlayer = get_node("/root/Main/Hurt1")
@onready var hurt_sound_2: AudioStreamPlayer = get_node("/root/Main/Hurt2")
@onready var por = $Marker3D/Camera3D/Sprites/POR
#@onready var sword = get_node("/root/Main/Sprites/POR_Transition")
#@onready var sword1 = get_node("/root/Main/Sprites/POR_Sword/Idle")
@onready var flashlight = $Marker3D/Camera3D/SpotLight3D
@onready var slope_node: Node3D = $slope



var is_game_over = false  
var crouching = false
var camera_locked = false 
var invincible = false

@onready var sprite_handler = $Marker3D/Camera3D/Sprites

func _ready() -> void:
	sprite_handler.mode_toggled.connect(_on_mode_toggled)

func _on_mode_toggled(new_mode: int):
	current_mode = new_mode
	atk_mode = (new_mode == PlayerMode.FIGHTING)
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
				global_transform.origin = target_pos
				velocity = Vector3.ZERO
				momentum = Vector3.ZERO
				grab_timer -= delta

				if Input.is_action_just_pressed("jump"):
					_perform_grab_jump()
				return
			else:
				global_transform.origin.x = target_pos.x
				global_transform.origin.z = target_pos.z
				
				var up := _up()
				velocity += up * SLIDE_GRAVITY * delta  
				velocity = up * velocity.dot(up)
				move_and_slide()
				
				if Input.is_action_just_pressed("jump"):
					_perform_grab_jump()
				return
	var up := _up()
	up_direction = up
	
	if in_long_dash:
		long_dash_time_left -= delta
		if long_dash_time_left <= 0.0:
			in_long_dash = false
		else:
			# Player can steer with movement input
			var steer := get_movement_direction()
			if steer.length() > 0.1:
				long_dash_direction = long_dash_direction.lerp(steer, delta * 6.0).normalized()

			velocity = long_dash_direction * long_dash_speed


	_update_momentum(delta)
	var direction := Vector3.ZERO
	if not is_sliding:
		direction = get_movement_direction()

	var is_sprinting: bool = false
	if Input.is_action_pressed("sprint") and not is_sliding and direction.length() > 0.0:
		if current_mode == PlayerMode.PEACEFUL:
			is_sprinting = true
		elif current_mode == PlayerMode.FIGHTING:
			if can_dash:
				perform_dash()


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
# Combo reset countdown
	if combo_reset_timer > 0.0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0.0:
			combo_count = 0
	
	if current_mode == 0:
		flashlight.visible = true
	else:
		flashlight.visible = false
		
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

var slash_airdash_used := false


var attack_was_pressed: bool = false

func _handle_attack_and_jump(up: Vector3) -> void:
	var dash_pressed := Input.is_action_just_pressed("sprint")
# Track attack hold
		
	if Input.is_action_just_pressed("attack"):
		if current_mode == PlayerMode.PEACEFUL:
			return
		attack_was_pressed = true
		slash_buffered = false
		attack_hold_time = 0.0

	# Holding
	if attack_was_pressed and Input.is_action_pressed("attack"):
		if current_mode == PlayerMode.PEACEFUL:
			return
		attack_hold_time += get_physics_process_delta_time()
		slash_buffered = true
		#return

	# On release → fire slash
	if attack_was_pressed and Input.is_action_just_released("attack"):
		if current_mode == PlayerMode.PEACEFUL:
			return
		attack_was_pressed = false

		if current_mode == PlayerMode.FIGHTING and can_slash:
			var is_long := attack_hold_time >= ATTACK_HOLD_THRESHOLD
			perform_slash(is_long)
			slash_buffered = false
		return
	if Input.is_action_just_pressed("grab"):
		perform_grab()
		return
	if Input.is_action_just_pressed("jump"):
		if is_sliding and is_on_floor():
			#exit_slide_with_jump()
			pass
		elif is_on_floor():
			var vert := up * velocity.dot(up)
			if vert.dot(up) < 0.0:
				velocity -= vert
			velocity += up * JUMP_VELOCITY


var combo_count: int = 0
var combo_reset_timer: float = 0.0
const COMBO_RESET_TIME: float = 5.0

signal hit(target, damage)

func perform_slash(is_long: bool) -> void:
	if not can_slash:
		return

	can_slash = false
	sprite_handler.slash_play()

	var dash_force := DASH_FORCE * (LONG_DASH_SPEED_MULT if is_long else 0.8)

	# Direction 
	var cam_forward := -camera.global_transform.basis.z
	cam_forward.y = clamp(cam_forward.y, -1.0, 0.3) # prevent upward yeet
	cam_forward = cam_forward.normalized()

	var slash_dir := cam_forward

	if is_on_floor():
		dash_force *= 1.5

	if is_long:
		invincible = true
		
		if not is_on_floor():
			movement_points += 1

		momentum = cam_forward * dash_force
		velocity += momentum
		speed = max(speed, speed + dash_force * 0.5)

		get_tree().create_timer(0.5).timeout.connect(func():
			invincible = false
		)
		raycast_dmg(slash_dir, BASE_DAMAGE * 1.5, 10)
	else:
		velocity += momentum
		speed = max(speed, speed + dash_force * 0.3)
		
		raycast_dmg(slash_dir, BASE_DAMAGE, 10)
		
	await get_tree().create_timer(SLASH_COOLDOWN).timeout #cooldown
	can_slash = true
	in_long_dash = false



var is_grabbing = false
var grabbed_body: Node3D = null
var grab_offset: Vector3 = Vector3.ZERO
var grab_timer: float = 0.0
const MAX_GRAB_TIME = 2.0  

func perform_grab():
	if current_mode != PlayerMode.PEACEFUL:
		return
	dash_efx = true
	var space_state = get_world_3d().direct_space_state
	var origin = camera.global_transform.origin
	var dir = -camera.global_transform.basis.z.normalized()
	var target = origin + dir * 3.0 
	
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
		initial_dir = -camera.global_transform.basis.z
		initial_dir = _project_on_plane(initial_dir, _up()).normalized()
	if slope_node and slope_node.has_method("start_slide"):
		slope_node.start_slide(initial_dir, slide_speed)
	slope_node.visible = true
	$Marker3D/Camera3D/Sprites/POR_Sword/Idle.visible = false
	$Marker3D/Camera3D/Sprites/POR_Sword.visible = false

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

	if crouch_pressed:
		if not is_sliding and is_on_floor():
			_start_slide_from_player()

		if is_sliding:
			if slope_node and slope_node.has_method("get_slide_velocity"):
				var slope_velocity: Vector3 = slope_node.get_slide_velocity(self, delta)
				if slope_velocity.length() > 0.001:
					velocity = slope_velocity
					speed = slope_velocity.length()
				else:
					var up := _up()
					var planar := velocity - up * velocity.dot(up)
					if planar.length() < 0.01:
						planar = -camera.global_transform.basis.z
						planar = _project_on_plane(planar, up)
					velocity = planar.normalized() * max(speed, BASE_SPEED)
					speed = velocity.length()
			else:
				velocity = slide_dir * slide_speed
				speed = slide_speed

	else:
		if is_sliding:
			exit_slide()
			if slope_node and slope_node.has_method("reset_slide_velocity"):
				slope_node.reset_slide_velocity()
			if slope_node:
				slope_node.visible = false
				$Marker3D/Camera3D/Sprites/POR_Sword/Idle.visible = true
				$Marker3D/Camera3D/Sprites/POR_Sword.visible = true
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


var dash_added_velocity := Vector3.ZERO
var dash_active := false
var dash_added_speed := 0.0

func perform_dash() -> void:
	if not can_dash:
		return
		
	can_dash = false
	dash_active = true
	invincible = true

	dash_added_speed = 20.0
	speed += dash_added_speed

	dash_efx = true
	
	await get_tree().create_timer(0.2).timeout
	
	# remove exactly the speed we added, no matter what happened meanwhile
	speed -= dash_added_speed
	dash_added_speed = 0.0
	dash_active = false
	dash_efx = false
	invincible = false
	
	# cooldown
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true



# -------- Smooth Dash Loss for Long Dash --------
func _start_smooth_dash_loss():
	var loss_time := 0.001   # duration of smooth fade-out
	var t := 0.0
	var original := dash_added_velocity

	while t < loss_time:
		var alpha := t / loss_time
		# Lerp out the velocity smoothly
		var current := original.lerp(Vector3.ZERO, alpha)
		velocity -= (dash_added_velocity - current)
		dash_added_velocity = current

		t += get_physics_process_delta_time()
		await get_tree().process_frame

	# Ensure no leftovers
	velocity -= dash_added_velocity
	dash_added_velocity = Vector3.ZERO


	# Dash cooldown
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	if is_instance_valid(self):
		can_dash = true




func apply_knockback(force: Vector3):
	momentum += force 
	velocity += force
	
#throw the player basically

const SLIDE_WALL_BOUNCE_SPEED = 15.0
const SLIDE_WALL_KNOCKBACK_FORCE = 25.0
var is_invincible: bool = false
const INVINCIBILITY_DURATION = 0.1


func check_wall_impact():
	if is_invincible:
		return

	if speed < SLIDE_THRESHOLD:
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
		var angle := rad_to_deg(acos(clamp(normal.dot(up), -1.0, 1.0)))
		if angle > 45.0:
			handle_wall_collision(camera_facing, normal)

func handle_wall_collision(direction: Vector3, wall_normal: Vector3):
	if is_sliding:
		# Invincible to wall damage during slide
		if speed >= SLIDE_WALL_BOUNCE_SPEED:
			$slope/Fail.play()
			$Marker3D/Camera3D/Sprites/POR_Sword/Idle.visible = true
			$Marker3D/Camera3D/Sprites/POR_Sword.visible = true

			var knockback_dir := (wall_normal + Vector3.UP).normalized()
			var knockback_force := knockback_dir * SLIDE_WALL_KNOCKBACK_FORCE

			velocity += knockback_force
			momentum += knockback_force

			# Cancel the slide
			exit_slide()
			if slope_node and slope_node.has_method("reset_slide_velocity"):
				slope_node.reset_slide_velocity()
			if slope_node:
				slope_node.visible = false

			# --- Temporary invincibility after crash ---
			is_invincible = true
			await get_tree().create_timer(INVINCIBILITY_DURATION).timeout
			is_invincible = false

		# Even if below threshold, no damage taken while sliding
		return

	if dash_efx == true and current_mode == PlayerMode.FIGHTING:
		var knockback_force = -direction * WALL_IMPACT_KNOCKBACK
		apply_knockback(knockback_force)
		movement_points += 1
	else:
		if speed >= 30:
			var damage_taken = min(speed / 2, 100)
			apply_damage(damage_taken)
		speed = 0
		velocity = Vector3.ZERO
		momentum = Vector3.ZERO

	await get_tree().create_timer(0.3).timeout
	momentum = momentum.lerp(Vector3.ZERO, WALL_IMPACT_DECAY)

func exit_slide():
	is_sliding = false
	$Marker3D/Camera3D/Sprites/POR_Sword/Idle.visible = true
	$Marker3D/Camera3D/Sprites/POR_Sword.visible = true
	var planar_velocity := velocity - _up() * velocity.dot(_up())
	if planar_velocity.length() > 0.01:
		speed = planar_velocity.length()


func exit_slide_with_jump():
	is_sliding = false
	exit_slide()
	var up := _up()
	velocity += up * (JUMP_VELOCITY * 1.5)
	#speed = speed * 20.0
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


# --to/from player damage--

func raycast_dmg(dir, dmg, dist):
	#add how long the raycast is performed
	#add raycast delay (projectile stuff)
	var origin := camera.global_transform.origin
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * dist)
	query.exclude = [self]
	query.collide_with_bodies = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var hit_node := result.collider as Node
		while hit_node and not hit_node.is_in_group("enemy"):
			hit_node = hit_node.get_parent()

		if hit_node and hit_node.has_method("apply_damage"):
			hit_node.apply_damage(dmg)
			emit_signal("hit", hit_node, dmg)
		print(hit_node, dmg)

func apply_damage(amount: int):
	#applies damage TO the player
	if invincible == true:
		return
	if amount >= 15 and amount <= 29:
		hurt_sound_0.play()
	elif amount >= 30:
		hurt_sound_1.play()
	#elif amount >= 40:
		#hurt_sound_2.play()
		
	#the whole sound thing is kinda ass but whatever we'll figure it out later
	
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
	
	

extends CharacterBody3D

const SPEED = 5.0
var speed = SPEED
const JUMP_VELOCITY = 4.5
var jump_velocity = JUMP_VELOCITY
var health = 100

var invincible = false
@onready var health_bar: HSlider = $"../../SubViewportContainer/SubViewport/Camera3D/HealthBar"
@onready var freaky: TextureRect = $"../../SubViewportContainer/SubViewport/Freaky"
@onready var dm: ColorRect = $"../../SubViewportContainer/SubViewport/Freaky/Datamoshing"
@onready var freaky2: TextureRect = $"../../SubViewportContainer/SubViewport/Freaky/Freaky2"
@onready var low_health: TextureRect = $"../../SubViewportContainer/SubViewport/LowHealth"
@onready var ground_ray: RayCast3D = $GroundRay

@onready var sword: RigidBody3D = $POR2

@onready var camera = $Marker3D/Camera3D

const SLIDE_TURN_SPEED: float = 0.1


func _physics_process(delta: float) -> void:
	_update_sword_input()

	if Input.is_action_just_pressed("throw") and not sword.is_sliding:
		sword.launch(camera)

	if sword.is_sliding:
		_follow_sword_slide()
	else:
		# Gravity and jumping.
		if not is_on_floor():
			velocity += get_gravity() * delta

		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_velocity

		_move_player()

	move_and_slide()

var turn_input: float = 0.0

func _update_sword_input() -> void:
	var attack_down: bool = Input.is_action_pressed("attack")
	var attack_just_pressed: bool = Input.is_action_just_pressed("attack")
	var attack_just_released: bool = Input.is_action_just_released("attack")

	var crouch_down: bool = Input.is_action_pressed("crouch")
	var crouch_just_pressed: bool = Input.is_action_just_pressed("crouch")

	if sword.is_sliding:
		if not attack_down:
			sword.release()
		elif not crouch_down:
			sword.end_slide()
		elif $POR2/RayCast3D.is_colliding() and speed > 10:
			sword.end_slide()
			velocity += Vector3.UP * 5

		return

	if attack_just_released:
		sword.release()
		return

	if not attack_down:
		return

	if crouch_just_pressed and not attack_just_pressed:
		sword.global_rotation.x = -PI/2 + 0.2
		
		sword.axis_lock_angular_x = true
		sword.axis_lock_angular_z = true
		turn_input = 0
		sword.slide()
	else:
		sword.attack()


func _follow_sword_slide() -> void:
	velocity = Vector3.ZERO
	global_position = sword.global_position 
	if ground_ray.is_colliding():
		var normal = ground_ray.get_collision_normal()
		var slope_angle = rad_to_deg(
			acos(clamp(normal.dot(Vector3.UP), -1.0, 1.0))
		)
		var downhill = Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
		downhill = downhill.normalized()
		speed = clamp(
			SPEED +  sword.front.dot(downhill) * 10 * slope_angle / 45.0,
			SPEED,
			30
		)

	if Input.is_action_pressed("ui_left"):
		turn_input += 1.0

	if Input.is_action_pressed("ui_right"):
		turn_input -= 1.0
	sword.angular_velocity.y = turn_input * SLIDE_TURN_SPEED

	sword.linear_velocity.x = sword.front.x * speed * 10
	sword.linear_velocity.z = sword.front.z * speed * 10
	turn_input *= 0.98
	print($POR2/RayCast3D.get_collision_normal())


func _move_player() -> void:
	var input_dir: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
        "ui_down"
	)

	var direction: Vector3 = global_transform.basis * Vector3(
		input_dir.x,
		0.0,
		input_dir.y
	)

	direction.y = 0.0

	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

func apply_damage(amount: int):
	if invincible:
		return
	#if amount >= 15 and amount <= 29:
		#hurt_sound_0.play()
	#elif amount >= 30:
		#hurt_sound_1.play()
	##elif amount >= 40:
		##hurt_sound_2.play()
		
	#the whole sound thing is kinda ass but whatever we'll figure it out later
	
	health -= amount
	health = max(health, 0)
	health_bar.value = health
	$"../../SubViewportContainer/SubViewport/Camera3D/PauseMenu/Panel2/player/HSlider3".value = health
	low_health.visible = health < 20



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

	tween.tween_property(freaky.material, "shader_parameter/strength", 0.0 if health > 20 else 1.5/health, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(freaky2.material, "shader_parameter/strength", 0.0 if health > 20 else 1.5/health, 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(dm.material, "shader_parameter/strength", 0.0 if health > 20 else 1.5/health, 2.0).set_trans(Tween.TRANS_SINE)
	


func die():
	print("died!")


	await get_tree().create_timer(2).timeout
	get_tree().change_scene_to_file("res://3d/GameOver.tscn")

func respawn():
	health = 100
	global_transform.origin = Vector3(0, 1, 0)

	
	


func _on_h_slider_2_value_changed(value: float) -> void:
	speed = SPEED * value


func _on_h_slider_3_value_changed(value: float) -> void:
	apply_damage(100-value)
	health = value


func _on_h_slider_4_value_changed(value: float) -> void:
	jump_velocity = JUMP_VELOCITY*value

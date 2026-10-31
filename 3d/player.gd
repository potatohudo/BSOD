extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var health = 100
var speed =SPEED
var invincible = false
@onready var health_bar: HSlider = $"../../SubViewportContainer/SubViewport/Camera3D/HealthBar"
@onready var freaky: TextureRect = $"../../SubViewportContainer/SubViewport/Freaky"
@onready var dm: ColorRect = $"../../SubViewportContainer/SubViewport/Freaky/Datamoshing"
@onready var freaky2: TextureRect = $"../../SubViewportContainer/SubViewport/Freaky/Freaky2"
@onready var low_health: TextureRect = $"../../SubViewportContainer/SubViewport/LowHealth"




@onready var sword: RigidBody3D = $POR2

@onready var camera = $Marker3D/Camera3D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if Input.is_action_just_pressed("throw"):
		sword.launch(camera)
	if Input.is_action_pressed("attack"):
		sword.attack()

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	low_health.visible = health < 20
func throw():
	#sword.apply_central_impulse
	pass
	

func apply_damage(amount: int):
	#applies damage TO the player
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


	await get_tree().create_timer(2).timeout
	get_tree().change_scene_to_file("res://3d/GameOver.tscn")

func respawn():
	health = 100
	global_transform.origin = Vector3(0, 1, 0)

	
	

extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


	
func set_emotion(emotion: String) -> void:
	match emotion:
		"happy":
			$AnimationPlayer.play("smile")
		"neutral":
			$AnimationPlayer.play("neutral")
		"ba":
			$AnimatedSprite3D2.visible = true
			$AnimatedSprite3D2.play()

func start_speaking():
	$AnimationPlayer.play()

func stop_speaking():
	$AnimationPlayer.stop()

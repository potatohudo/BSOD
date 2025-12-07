extends Node3D

func _ready() -> void:
	await get_tree().process_frame


func _process(delta: float) -> void:
	pass


	
func set_emotion(emotion: String) -> void:
	match emotion:
		"happy":
			$AnimationPlayer.play("smile")
		"neutral":
			$AnimationPlayer.play("neutral")
		"sad":
			$AnimationPlayer.play("sad")
		"ba":
			$AnimatedSprite3D2.visible = true
			$AnimatedSprite3D2.play()

func start_speaking():
	$AnimationPlayer.play()

func stop_speaking():
	$AnimationPlayer.stop()

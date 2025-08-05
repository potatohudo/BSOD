extends Node3D

@export var move_speed = 1.5
@export var wander_radius = 3.0
@export var wander_time = 2.0

var direction := Vector3.ZERO
var time_accum := 0.0

func _ready() -> void:
	$AnimatedSprite3D.play()

func _process(delta):
	time_accum += delta
	if time_accum > wander_time:
		direction = Vector3(
			randf_range(-1, 1),
			randf_range(-0.5, 0.5),
			randf_range(-1, 1)
		).normalized()
		time_accum = 0.0
	
	global_position += direction * move_speed * delta

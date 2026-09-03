extends Node3D
var moving = false
var dragging = false

const SPEED := 1
@onready var speed := 2
@onready var dragging_speed := 1
@onready var dir := Vector3.BACK #flipped because the model is turned around

@onready var markers_global := $Markers
@onready var markers_local := $bloop/Markers

func _ready() -> void:
	for child in markers_global.get_children():
		var copy := child.duplicate()
		markers_local.add_child(copy)
	
	await get_tree().create_timer(5).timeout
	move()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for i in range(markers_global.get_child_count()):
		var local_child = markers_local.get_child(i)
		var global_child = markers_global.get_child(i)
		
		global_child.global_position = global_child.global_position.lerp(
			local_child.global_position, 
			delta * dragging_speed
		)
	if not moving: return
	$bloop.position += dir * speed * delta
	#$bloop/LookAt2.position += dir * speed * delta #if is not commented, moves just fine; but without it, LookAt refuses to follow LookAt2
	

func move(boo = true):
	moving = boo
	await get_tree().create_timer(5).timeout
	moving = false
	

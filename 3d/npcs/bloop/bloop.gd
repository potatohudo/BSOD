extends Node3D
var moving = false
var markermoving = false
#move lookatmodifier by z axis 
#check if its tied to the body
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(10).timeout
	moving = true
	await get_tree().create_timer(1).timeout
	markermoving = true


var t = 0.0
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not moving: return
	t += delta * 0.00001
	$bloop.position = $bloop.position.lerp($Marker3D.position, t)
	if markermoving:$MarkerOrgy/Marker3D2.position = $MarkerOrgy/Marker3D2.position.lerp($Marker3D.position, t)

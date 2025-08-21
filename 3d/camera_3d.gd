extends Camera3D

@onready var marker: Node3D = $".."  
@onready var character = $"../.."  

var mouse_sens = 0.3
var camera_anglev = 0
var is_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _custom_mouse_input(event):
	if event is InputEventMouseMotion:
		marker.rotate_y(deg_to_rad(-event.relative.x * mouse_sens)) 
		camera_anglev = clamp(camera_anglev - event.relative.y * mouse_sens, -50, 50) 
		rotation_degrees.x = camera_anglev  

func toggle_pause() -> void:
	is_paused = !is_paused
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED)

extends Camera3D

@onready var marker: Node3D = $".."
@onready var character = $"../.."

signal yes
signal no

@export var mouse_sens := 0.3
@export var cooldown := 1.0
@export var shake_angle_threshold := 10.0	# degrees per direction flip
@export var nod_angle_threshold := 8.0
@export var min_flips := 2					# number of direction changes to trigger
@export var max_gesture_time := 1.2			# seconds before gesture expires

var camera_anglev := 0.0
var is_paused: bool = false

# Internal tracking
var _last_rotation := Vector3.ZERO
var _last_shake_time := 0.0
var _last_nod_time := 0.0
var _yaw_dir := 0
var _pitch_dir := 0
var _yaw_flips := 0
var _pitch_flips := 0
var _gesture_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_last_rotation = rotation_degrees

func _custom_mouse_input(event: InputEvent) -> void:
	if is_paused:
		return

	if event is InputEventMouseMotion:
		# Horizontal rotation affects marker (yaw)
		marker.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))

		# Vertical rotation affects camera (pitch)
		camera_anglev = clamp(camera_anglev - event.relative.y * mouse_sens, -70, 80)
		rotation_degrees.x = camera_anglev

func toggle_pause() -> void:
	is_paused = !is_paused
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_paused else Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	var rot_delta := rotation_degrees - _last_rotation
	_last_rotation = rotation_degrees

	# Normalize wraparound
	rot_delta.x = fposmod(rot_delta.x + 180.0, 360.0) - 180.0
	rot_delta.y = fposmod(rot_delta.y + 180.0, 360.0) - 180.0

	var time_now := Time.get_ticks_msec() / 1000.0
	_gesture_timer += delta

	# Reset gesture if too long
	if _gesture_timer > max_gesture_time:
		_yaw_flips = 0
		_pitch_flips = 0
		_yaw_dir = 0
		_pitch_dir = 0
		_gesture_timer = 0.0

	# Horizontal (shake = "no")
	if abs(rot_delta.y) > shake_angle_threshold:
		var dir = sign(rot_delta.y)
		if dir != 0 and dir != _yaw_dir:
			_yaw_dir = dir
			_yaw_flips += 1
			_gesture_timer = 0.0	# reset timer on motion

			if _yaw_flips >= min_flips and (time_now - _last_shake_time) > cooldown:
				emit_signal("no")
				print("no")
				_last_shake_time = time_now
				_yaw_flips = 0
				_yaw_dir = 0
				_gesture_timer = 0.0

	# Vertical (nod = "yes")
	if abs(rot_delta.x) > nod_angle_threshold:
		var dir = sign(rot_delta.x)
		if dir != 0 and dir != _pitch_dir:
			_pitch_dir = dir
			_pitch_flips += 1
			_gesture_timer = 0.0	# reset timer on motion

			if _pitch_flips >= min_flips and (time_now - _last_nod_time) > cooldown:
				emit_signal("yes")
				print("yes")
				_last_nod_time = time_now
				_pitch_flips = 0
				_pitch_dir = 0
				_gesture_timer = 0.0

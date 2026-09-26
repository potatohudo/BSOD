extends CharacterBody3D

#direction
@onready var dir := Vector3.MODEL_FRONT
@onready var hig := Vector3.ZERO

#rays
@onready var rays_front: Node3D = $Armature/Head/RaysFront
@onready var front_left: ShapeCast3D = $Armature/Head/RaysFront/FrontLeft
@onready var front_right: ShapeCast3D = $Armature/Head/RaysFront/FrontRight

@onready var rays_vertical: Node3D = $Armature/Head/RaysVertical
@onready var bottom: RayCast3D = $Armature/Head/RaysVertical/Bottom
@onready var top: RayCast3D = $Armature/Head/RaysVertical/Top


#body parts
@onready var tail: MeshInstance3D = $Armature/Tail
@onready var legs: Node3D = $Armature/Legs
@onready var leg: MeshInstance3D = $Armature/Legs2/Leg
@onready var flute_long: MeshInstance3D = $Armature/FluteLong
@onready var flute_mid: MeshInstance3D = $Armature/FluteMid
@onready var flute_short: MeshInstance3D = $Armature/FluteShort
@onready var head: MeshInstance3D = $Armature/Head
@onready var body: MeshInstance3D = $Armature/Body
@onready var collision: CollisionShape3D = $CollisionShape3D

var rng = RandomNumberGenerator.new()

@onready var wiggle_enabled: bool = true

@onready var skeleton: Skeleton3D = $Armature/Skeleton3D
@onready var wiggle_speed = 3.0
var wiggle_phase = 0.0

const SPEED = 5.0
var speed = SPEED

var rot_speed = 0.0


var move = false
var body_size 
var ray_scale
var ray_position
var rest_rotation
var wiggle_base_body: Quaternion
var wiggle_base_tail: Quaternion
var wiggle_base_leg: Quaternion
func _ready():
	body_size = rng.randf_range(0.5, 9.0)
	randomize_body_parts(body_size)
	ray_scale = rays_front.scale
	ray_position = front_left.position.z
	wiggle_base_body = skeleton.get_bone_pose_rotation(1)
	wiggle_base_tail = skeleton.get_bone_pose_rotation(4)
	wiggle_base_leg = skeleton.get_bone_pose_rotation(8)
	
func randomize_body_parts(size):
	tail.set_scale(Vector3(size,size,size))
	legs.set_scale(Vector3(size,size,size))
	head.set_scale(Vector3(size,size,size))
	body.set_scale(Vector3(size,size,size))
	collision.set_scale(body.scale)
	#eughhhhh
	flute_long.set_scale(Vector3(size,size,size))
	flute_mid.set_scale(Vector3(size,size,size))
	flute_short.set_scale(Vector3(size,size,size))

	
func _physics_process(delta: float) -> void:
	check_raycast(delta)
	behaviour(1, wiggle_base_body, 5.0)
	behaviour(4, wiggle_base_tail, 40.0)
	#behaviour(8, wiggle_base_leg, 40) legs are for later
	
	dir = dir.rotated(Vector3.UP, rot_speed * delta)
	

	rotate_y(rot_speed * delta)
	
	
	
	# Apply velocity in the direction the node is facing
	velocity = (dir + hig) * speed
	wiggle_phase += wiggle_speed * delta
	move_and_slide()
	
var left_hit 
var right_hit
var top_hit
var bottom_hit

var side_obstacle
var vert_obstackle
func check_raycast(delta: float) -> void:
	left_hit = front_left.is_colliding()
	right_hit = front_right.is_colliding()
	top_hit = top.is_colliding()
	bottom_hit = bottom.is_colliding()
	side_obstacle = left_hit or right_hit
	vert_obstackle = top_hit or bottom_hit

	if side_obstacle:
		rot_speed += (-1.0 if left_hit else 1.0) * delta / 3.0
		speed = lerp(speed, SPEED * 0.5, delta / 3.0)
		rays_front.scale = lerp(rays_front.scale, ray_scale/3.0, delta*0.1)
		if not vert_obstackle: change_wiggle_speed(1.0, delta/2)
		

	else:
		rot_speed = lerp(rot_speed, 0.0, delta * 2.0)
		speed = lerp(speed, SPEED, delta)
		rays_front.scale = lerp(rays_front.scale, ray_scale, delta*0.5)
		
	if vert_obstackle:
		hig = hig.lerp(Vector3(0, 1.0 if bottom_hit else -1.0,0), delta) 
		change_wiggle_speed(0.0 if bottom_hit else 5.0, delta)
		
		
	else:
		hig = hig.lerp(Vector3.ZERO, delta)
		if not side_obstacle: change_wiggle_speed(3.0, delta)

func change_wiggle_speed(to, delta):
	wiggle_speed = wiggle_speed + (to - wiggle_speed) * delta

func behaviour(wiggle_bone: int, wiggle_base: Quaternion, wiggle_limit: float) -> void:
	var angle := deg_to_rad(
		sin(wiggle_phase) * wiggle_limit
	)
	wiggle_phase = fmod(wiggle_phase, TAU)
	skeleton.set_bone_pose_rotation(
		wiggle_bone,
		wiggle_base * Quaternion(Vector3.RIGHT, angle)
		)

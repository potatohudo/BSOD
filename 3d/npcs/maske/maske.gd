extends Node3D

@onready var suffix: Node3D = $maske/Armature
@onready var sface = $maske/Armature/Skeleton3D/Cube_005
@onready var prefix: Node3D = $maske/Armature_001
@onready var pface = $maske/Armature_001/Skeleton3D/Cube_004



@export var prefix_radius := 1.0
@export var suffix_radius := 1.0

@export var vertical_bias := 2.0
@export var self_no_go_radius := 0.5
@export var min_target_distance := 0.05

@export var move_speed := 3.0
@export var return_speed := 2.5

@export var min_move_interval := 0.5
@export var max_move_interval := 10.0

@onready var greeting := [
	preload("res://3d/npcs/maske/voices/bonjour.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_0.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_1.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_2.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_3.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_4.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_5.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_6.wav-lipsync.tres"),
	preload("res://3d/npcs/maske/voices/bonjour_7.wav-lipsync.tres"),
]

@onready var voicelines := {
	"greeting": greeting,
}

@onready var pAup = load("res://3d/npcs/maske/PREFIX_1.png")
@onready var pIup = load("res://3d/npcs/maske/PREFIX_5.png")
@onready var pSup = load("res://3d/npcs/maske/PREFIX_6.png") 
@onready var pUH = load("res://3d/npcs/maske/PREFIX_7.png") #uhhhhhhhh
@onready var pEup = load("res://3d/npcs/maske/PREFIX_2.png")
@onready var pAneutral = load("res://3d/npcs/maske/PREFIX_3.png")
@onready var pOup = load("res://3d/npcs/maske/PREFIX_4.png")
@onready var pOdown = load("res://3d/npcs/maske/PREFIX_11.png")
@onready var pIdown = load("res://3d/npcs/maske/PREFIX_22.png")
@onready var pEdown = load("res://3d/npcs/maske/PREFIX_33.png")
@onready var pAdown = load("res://3d/npcs/maske/PREFIX_44.png")

var rng := RandomNumberGenerator.new()
var objects := {}

func _ready() -> void:
	await get_tree().process_frame
	rng.randomize()
	_register_object(prefix, prefix_radius)
	_register_object(suffix, suffix_radius)

func play_voiceline(line: String) -> void:
	if not voicelines.has(line):
		push_warning("unknown voiceline: %s" % line)
		return

	var lines: Array = voicelines[line]
	if lines.is_empty():
		return

	$PrefixLipsync.play_lipsync(lines.pick_random()) #play the line


func set_emotion(emotion: String) -> void:
	pass
	#the emotion is set through the lipsync


func _register_object(node: Node3D, radius: float) -> void:
	objects[node] = {
		"radius": radius,
		"origin": node.position,
		"target": node.position,
		"timer": _random_interval()
	}


func _process(delta: float) -> void:
	for node in objects.keys():
		_update_object(node, delta)


func _update_object(node: Node3D, delta: float) -> void:
	var data = objects[node]

	data.timer -= delta
	if data.timer <= 0.0:
		data.target = data.origin + _random_point(data.radius)

		if data.target.length() < self_no_go_radius:
			data.target = data.target.normalized() * self_no_go_radius

		if node.position.distance_to(data.target) < min_target_distance:
			data.target = data.origin + _random_point(data.radius)

		data.timer = _random_interval()

	var offset = node.position - data.origin
	var distance = offset.length()

	if distance > data.radius:
		node.position = node.position.lerp(
			data.origin + offset.normalized() * data.radius,
			return_speed * delta
		)
	else:
		node.position = node.position.lerp(
			data.target,
			move_speed * delta
		)


func _random_point(radius: float) -> Vector3:
	var dir := Vector3(
		rng.randf_range(-2.0, 2.0),
		rng.randf_range(-2.0, 2.0) * vertical_bias,
		rng.randf_range(-2.0, 2.0)
	).normalized()

	var dist := rng.randf() * radius
	return dir * dist


func _random_interval() -> float:
	return rng.randf_range(min_move_interval, max_move_interval)
	
##--- faces and uh.lipcyncc logic ---
#these functions can be just separated into 2 parts end connected to the corresponding signals

func set_mouth(texture: Texture2D) -> void:
	if not pface:
		return

	var mesh = pface.get_mesh()
	if not mesh:
		return

	var mat = mesh.surface_get_material(0)
	if not mat:
		return

	if mat is StandardMaterial3D:
		mat = mat.duplicate()
		mat.albedo_texture = texture
		mesh.surface_set_material(0, mat)


var up = true

func _on_prefix_lipsync_mouth_shape_changed(mouth_shape: int) -> void:
	print(mouth_shape)
	if up == true:
		match mouth_shape:
			0: # Rest position
				set_mouth(pSup)
			1: # Very closed 
				set_mouth(pSup)
			2: # Slightly open (e.g. EE sound)
				set_mouth(pIup)
			3: # Open (e.g. AE sound)
				set_mouth(pEup)
			4: # Wide open
				set_mouth(pAup)
			5: # Slightly rounded (e.g. the i in bird)
				set_mouth(pEup)
			6: # O
				set_mouth(pOup)
			7: # F
				set_mouth(pUH)
			8: # Tongue on top of mouth (L sound)
				# The model doesn't move the tongue. girl whatever
				set_mouth(pSup)
	else:
		match mouth_shape:
			0: # Rest position
				set_mouth(pSup)
			1: # Very closed 
				set_mouth(pEdown)
			2: # Slightly open (e.g. EE sound)
				set_mouth(pIdown)
			3: # Open (e.g. AE sound)
				set_mouth(pEdown)
			4: # Wide open
				set_mouth(pAdown)
			5: # Slightly rounded (e.g. the i in bird)
				set_mouth(pEdown)
			6: # O
				set_mouth(pOdown)
			7: # F
				set_mouth(pUH)
			8: # L
				set_mouth(pEdown)
		


func _on_prefix_lipsync_expression_changed(expression: String) -> void:
	if expression == up:
		up = true
	else:
		up = false
		
#yanderesim ahh code i'll figure out how to shorten it later ok


func _on_suffix_lipsync_mouth_shape_changed(mouth_shape: int) -> void:
	pass # Replace with function body.


func _on_suffix_lipsync_expression_changed(expression: String) -> void:
	pass # Replace with function body.

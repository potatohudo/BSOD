extends Node3D

@onready var player: CharacterBody3D = get_node_or_null("../../CharacterBody3D")
@onready var audio: Node = $Audio
@onready var whale: Node3D = $whale
@onready var anim: AnimationPlayer = $whale/AnimationPlayer

var rng := RandomNumberGenerator.new()
var time_accum: float = 0.0
var next_interval: float = 1.0
var players_cache: Array[AudioStreamPlayer3D] = []

# Movement
@export var move_speed: float = 2.0
@export var turn_speed: float = 0.3
var current_dir: Vector3 = Vector3.FORWARD
var target_dir: Vector3 = Vector3.FORWARD
var change_dir_timer: float = 0.0

# Settings
@export var base_interval: float = 1.0          # minimum time before playing again
@export var extra_pause_min: float = 1.0        # extra pause min
@export var extra_pause_max: float = 2.0        # extra pause max

func _ready() -> void:
	await get_tree().process_frame
	rng.randomize()
	_update_players_cache()
	_pick_new_direction()
	_set_next_interval()

func _update_players_cache() -> void:
	players_cache.clear()
	if audio == null:
		return
	for c in audio.get_children():
		if c is AudioStreamPlayer3D:
			players_cache.append(c)

func _process(delta: float) -> void:
	if player == null or audio == null:
		return
	time_accum += delta
	if time_accum >= next_interval:
		time_accum = 0.0
		_play_random_sound()
		_set_next_interval()

	_update_flight(delta)

func _play_random_sound() -> void:
	if players_cache.is_empty():
		_update_players_cache()
		if players_cache.is_empty():
			return

	var sound: AudioStreamPlayer3D = players_cache[rng.randi_range(0, players_cache.size() - 1)]
	sound.play()

func _set_next_interval() -> void:
	# Always base interval + random extra pause
	next_interval = base_interval + rng.randf_range(extra_pause_min, extra_pause_max)

func _update_flight(delta: float) -> void:
	change_dir_timer -= delta
	if change_dir_timer <= 0.0:
		_pick_new_direction()

	current_dir = current_dir.slerp(target_dir, turn_speed * delta).normalized()
	global_position += current_dir * move_speed * delta
	look_at(global_position + current_dir, Vector3.UP)

func _pick_new_direction() -> void:
	target_dir = Vector3(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-0.3, 0.3),
		rng.randf_range(-1.0, 1.0)
	).normalized()
	change_dir_timer = rng.randf_range(3.0, 7.0)

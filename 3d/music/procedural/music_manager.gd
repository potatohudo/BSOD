extends Node

@export var loop_length: float = 8.0
var active: bool = false
const PREWARM_DISTANCE := 200.0
var sample_nodes: Array = []
var time_in_loop := 0.0
var playing := true

var nearest_enemy_distance := INF
var player: Node = null

var fighting_timer: float = 0.0
@export var fight_duration := 10.0
signal done

func _ready():
	await get_tree().process_frame
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] #i dont know why this is made for multipelayer
	player.connect("hit", Callable(self, "_on_player_hit"))

	for child in get_children():
		if child.has_method("is_music_sample"):
			sample_nodes.append(child)

func _process(delta):
	if not active:
		return

	if fighting_timer > 0.0:
		fighting_timer -= delta

	time_in_loop += delta
	if time_in_loop >= loop_length:
		time_in_loop = fmod(time_in_loop, loop_length)
		done.emit()

	_update_enemy_distance()

	for sample in sample_nodes:
		_process_sample(sample, delta)

func _process_sample(sample, delta):
	var sample_active = sample.should_play(self)
	var became_active = sample_active and not sample.active_last_frame
	var now := Time.get_ticks_msec() / 1000.0
	var interval = loop_length * sample.play_at

	if became_active:
		sample.next_trigger_time = ceil(now / interval) * interval

	if now >= sample.next_trigger_time:
		sample.trigger_play(sample_active)
		sample.next_trigger_time += interval

	sample.update_volume(sample_active, delta)
	sample.active_last_frame = sample_active
	
# DISTANCE

func _update_enemy_distance():
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
		else:
			nearest_enemy_distance = INF
			return

	var min_dist := INF

	for e in get_tree().get_nodes_in_group("threat"):
		var d = player.global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d

	nearest_enemy_distance = min_dist

 #HELPERS

func get_enemy_distance() -> float:
	return nearest_enemy_distance

func get_player_health_normalized() -> float:
	return player.health if player else 1.0

func _on_player_hit(target, damage): #ill maybe use those later
	fighting_timer = fight_duration

func is_fighting() -> bool:
	return fighting_timer > 0.0

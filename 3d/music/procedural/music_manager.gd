extends Node

@export var loop_length: float = 8.0
const PREWARM_DISTANCE := 200.0

var sample_nodes: Array = []
var time_in_loop := 0.0
var playing := true

var nearest_enemy_distance := INF
var player: Node = null

var fighting_timer: float = 0.0
const FIGHT_DURATION := 10.0


func _ready():
	await get_tree().process_frame
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	player.connect("hit", Callable(self, "_on_player_hit"))


	for child in get_children():
		if child.has_method("is_music_sample"):
			sample_nodes.append(child)

#  PROCESS

func _process(delta):
	if not playing:
		return
	if fighting_timer > 0.0:
		fighting_timer -= delta
	# Update musical loop timer
	time_in_loop += delta
	if time_in_loop >= loop_length:
		time_in_loop = fmod(time_in_loop, loop_length)

	_update_enemy_distance()

	for sample in sample_nodes:
		_process_sample(sample, delta)


func _process_sample(sample, delta):
	# Handle the interval 
	var interval = loop_length * sample.play_at

	var active = sample.should_play(self)
	var became_active = active and not sample.active_last_frame

	var gtime = float(Time.get_ticks_msec()) / 1000.0

	if sample.play_at == 1.0:
		interval = loop_length

		if became_active:
			var loops_passed = floor(gtime / loop_length)
			sample.next_trigger_time = (loops_passed + 1) * loop_length

	else:
		if became_active:
			var next = ceil(gtime / interval) * interval
			sample.next_trigger_time = next

	if gtime >= sample.next_trigger_time:
		# Only restart if conditions are met
		sample.trigger_play(sample.should_play(self))
		sample.next_trigger_time += interval


	# Update fading and volume
	sample.update_volume(active, delta)

	# Remember state transition
	sample.active_last_frame = active

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


func _on_player_hit(target, damage):
	fighting_timer = FIGHT_DURATION

func is_fighting() -> bool:
	return fighting_timer > 0.0

extends AudioStreamPlayer

@export var play_at: float = 1.0

@export var range: float = 0.0
@export var require_fight: bool = false
@export var max_player_health: float = 100.0

@export var fade_in: bool = true
@export var fade_out: bool = true
@export var fade_speed: float = 1.2

@export_enum("Always", "Fight Only", "Peace Only")
var fight_mode: int = 0


var next_trigger_time := 0.0
var active_last_frame := false

var target_volume := 0.0
var current_volume := -80.0


func is_music_sample() -> bool:
	return true


func should_play(manager) -> bool:
	if range > 0.0 and manager.get_enemy_distance() > range:
		return false


	if manager.get_player_health_normalized() > max_player_health:
		return false
		
	if fight_mode == 1 and not manager.is_fighting():
		return false
	if fight_mode == 2 and manager.is_fighting():
		return false

	return true


func trigger_play(active: bool):
	if not active:
		return
	stop()
	play()




func update_volume(active: bool, delta: float):
	if fade_in or fade_out:
		if active:
			target_volume = 0.0
		else:
			target_volume = -80.0

		current_volume = lerp(current_volume, target_volume, fade_speed * delta)
		volume_db = current_volume

	else:
		if active:
			volume_db = 0.0

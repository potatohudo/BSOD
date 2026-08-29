extends AudioStreamPlayer

@export var play_at: float = 1.0

@export var play_range: float = 0.0
@export var max_player_health: int = 100
@export var min_player_health: int = 0

@export var fade_in: bool = false
@export var fade_out: bool = false
@export var fade_speed: float = 1.2

@export_enum("Always", "Fight Only", "Peace Only")
var fight_mode: int = 0

@export var one_shot: bool = false

var next_trigger_time := 0.0
var active_last_frame := false

var target_volume := 0.0
var current_volume := -80.0

func is_music_sample() -> bool:
	return true

func should_play(manager) -> bool:
	
	
	if play_range > 0.0 and manager.get_enemy_distance() > play_range:
		return false

	if manager.get_player_health_normalized() > max_player_health:
		return false
		
	if manager.get_player_health_normalized() < min_player_health:
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


func _on_finished() -> void:
	if one_shot:
		play_at = 0.0

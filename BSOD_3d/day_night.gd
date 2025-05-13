extends Node

@export var environment: WorldEnvironment
@export var day_duration: float = 60.0
@export var night_duration: float = 60.0
@onready var ambient: AudioStreamPlayer = $Ambient
@onready var pulsar: AudioStreamPlayer = $Pulsar

var sky_mat: ProceduralSkyMaterial
var flicker_timer: Timer
var is_day: bool = true  

func _ready():
	if environment and environment.environment and environment.environment.sky:
		sky_mat = environment.environment.sky.get_material()

	if not sky_mat:
		push_error("No ProceduralSkyMaterial found in WorldEnvironment!")
		return

	# Create a timer for sun flickering (only works during the day)
	flicker_timer = Timer.new()
	flicker_timer.wait_time = 0.1
	flicker_timer.autostart = true
	flicker_timer.timeout.connect(_flicker_sun)
	add_child(flicker_timer)

	# Start with daytime
	trigger_day()

func trigger_day():
	if not sky_mat:
		return
	ambient.play()
	pulsar.play()
	
	# Play all effects first
	sky_mat.set_sun_angle_max(360)
	environment.environment.set_tonemap_exposure(3)

	# Play all effects first
	var tween = get_tree().create_tween()
	tween.tween_property(sky_mat, "sun_angle_max", 30.0, 1.0).set_trans(Tween.TRANS_SINE)
	var tween1 = get_tree().create_tween()
	tween1.tween_property(environment.environment,"tonemap_exposure", 1, 2.0).set_trans(Tween.TRANS_SINE)
	var tween2 = get_tree().create_tween()
	tween2.tween_property(pulsar,"volume_db", -100, day_duration * 2).set_trans(Tween.TRANS_LINEAR)
	
	# Adjust brightness & contrast for day
	environment.environment.adjustment_brightness = 1.0
	environment.environment.adjustment_contrast = 1.0
	
	ambient.volume_db = -10.0
	pulsar.volume_db = 0.0
	
	is_day = true  

	# Wait until the day duration ends, then switch to night
	await get_tree().create_timer(day_duration).timeout
	trigger_night()

func trigger_night():
	if not sky_mat:
		return


	var tween = get_tree().create_tween()
	tween.tween_property(sky_mat, "sun_angle_max", 4.0, 3.0).set_trans(Tween.TRANS_SINE)
	var tween1 = get_tree().create_tween()
	tween1.tween_property(environment.environment, "adjustment_contrast", 2.0, 3.6).set_trans(Tween.TRANS_SINE)
	var tween2 = get_tree().create_tween()
	tween2.tween_property(environment.environment, "adjustment_brightness", 0.4, 4.0).set_trans(Tween.TRANS_SINE)
	var tween3 = get_tree().create_tween()
	tween3.tween_property(ambient, "volume_db", -100, 10.0).set_trans(Tween.TRANS_SINE)

	is_day = false

	# Wait until the night duration ends, then switch to day
	await get_tree().create_timer(night_duration).timeout
	trigger_day()

func _flicker_sun():
	if is_day:
		sky_mat.set_sun_angle_max(randf_range(40.0, 55.0))
	else:
		sky_mat.set_sun_angle_max(4.0)  # Ensure sun stays at 4 at night

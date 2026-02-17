extends Control

@onready var freaky = $SubViewportContainer/SubViewport/Freaky
@onready var dm = $SubViewportContainer/SubViewport/Freaky/Datamoshing
@onready var timer = $Timer

@onready var info2 = $SubViewportContainer/SubViewport/Control/Info/Label2
@onready var blackout = $SubViewportContainer/SubViewport/Control2


func _ready():
	await get_tree().process_frame
	blackout.modulate.a = 0.0

	# Start your other shader tween
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(freaky.material, "shader_parameter/strength", 0.00, 1.4).set_trans(Tween.TRANS_CIRC)

	timer.timeout.connect(_on_randomize_timer_timeout)
	timer.start(randf_range(0.2, 0.6))

	# Character reveal sequence
	var tween1 = get_tree().create_tween()
	tween1.tween_property(info2, "visible_characters", 162, 1.0)
	tween1.tween_interval(1.0)

	tween1.tween_property(info2, "visible_characters", 192, 0.3)
	tween1.tween_interval(0.2)

	tween1.tween_property(info2, "visible_characters", 195, 0.15)
	tween1.tween_interval(0.4)

	tween1.tween_property(info2, "visible_characters", 225, 0.1)
	tween1.tween_interval(0.2)

	tween1.tween_property(info2, "visible_characters", 228, 0.2)
	tween1.tween_interval(0.4)

	tween1.tween_property(info2, "visible_characters", 253, 0.2)
	tween1.tween_interval(1.0)

	tween1.tween_property(info2, "visible_characters", 257, 0.2)
	tween1.tween_interval(1.5)

	tween1.tween_property(info2, "visible_characters", 288, 0.3)

	await get_tree().create_timer(3.0).timeout



	

func _on_randomize_timer_timeout():
	var r = randf_range(-0.006, 0.006)

	# Restart with a new randomized wait time
	timer.start(randf_range(0.2, 0.6))

	if freaky.material and freaky.material is ShaderMaterial:
		freaky.material.set_shader_parameter("strength", r)

	if dm.material and dm.material is ShaderMaterial:
		dm.material.set_shader_parameter("strength", r)


func _on_button_pressed() -> void:
	await get_tree().create_timer(0.5).timeout
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(freaky.material, "shader_parameter/strength", 3.0, 3.0).set_trans(Tween.TRANS_QUART)
	
	
	transanim()
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://pc/pc.tscn")


func _on_button_2_pressed() -> void:
	await get_tree().create_timer(0.2).timeout
	transanim()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://bios.tscn")

func transanim():
	var tween2 := create_tween().set_parallel(true)
	tween2.tween_property(blackout, "modulate:a", 1.0, 0.3)


func _on_button_3_pressed() -> void:
	await get_tree().create_timer(0.2).timeout
	transanim()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://credits.tscn")

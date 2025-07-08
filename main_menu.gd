extends Control

@onready var freaky = $SubViewportContainer/SubViewport/Freaky
@onready var dm = $SubViewportContainer/SubViewport/Freaky/Datamoshing
@onready var timer = $Timer

func _ready() -> void:
	timer.timeout.connect(_on_randomize_timer_timeout)

func _on_randomize_timer_timeout():
	var r = randf_range(0.0, 0.010)

	if freaky.material and freaky.material is ShaderMaterial:
		freaky.material.set_shader_parameter("strength", r)

	if dm.material and dm.material is ShaderMaterial:
		dm.material.set_shader_parameter("strength", r)


func _on_button_pressed() -> void:
	await get_tree().create_timer(0.5).timeout
	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(freaky.material, "shader_parameter/strength", 3.0, 3.0).set_trans(Tween.TRANS_QUART)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://pc/pc.tscn")

extends Control

@onready var freaky = $SubViewportContainer/SubViewport/Freaky
@onready var dm = $SubViewportContainer/SubViewport/Freaky/Datamoshing

func _process(delta: float) -> void:
	if Global.just_teleported:
		start_shader_tween()
		Global.just_teleported = false


func start_shader_tween():
	freaky.visible = true
	dm.visible = true

	var tween = get_tree().create_tween().set_parallel(true)
	tween.tween_property(freaky.material, "shader_parameter/strength", 5.0, 5.0).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(dm.material, "shader_parameter/strength", 1.0, 3.0).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(func ():
		await get_tree().create_timer(1.0).timeout
		freaky.visible = false
		dm.visible = false
	)

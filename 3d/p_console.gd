extends Panel
@onready var player: CharacterBody3D = $"../../../../Node3D/Player"
@onready var por: RigidBody3D = $"../../../../Node3D/Player/POR2"


func _on_check_box_toggled(toggled_on: bool) -> void:
	por.continuous_cd = toggled_on


func _on_check_box_2_toggled(toggled_on: bool) -> void:
	por.stick_to_surfaces = toggled_on
	

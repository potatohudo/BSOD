extends Node3D

@onready var decoy: Sprite3D = $Decoy
@onready var hill = $MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_area_3d_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	$MultiMeshInstance3D.visible = true
	decoy.visible = false
	hill.visible = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	$MultiMeshInstance3D.visible = false
	decoy.visible = true
	hill.visible = false

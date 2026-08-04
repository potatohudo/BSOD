extends Node3D

@onready var agony = $DialogBubble
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	DialogManager.register_character(self, $DialogBubble)
	DialogManager.connect("dialog_finished", _on_dialog_finished)


func apply_damage(dmg):
	DialogManager.quit()
	DialogManager.play("OW OW OW OW AHHHHHHHHHHHHH!!!!!!!!! 
AHHHHHHHHHHHHHHHHHH!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", self, 400001)
	$RaytracedAudioPlayer3D.play()

func _on_dialog_finished(id: int) -> void:
	match id:
		400001:
			DialogManager.play("AAAAAAAAAAAAAAAAAAAAHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH", self, 400002)
			$RaytracedAudioPlayer3D.play()
		400002:
			DialogManager.play("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", self, 400003)
			$RaytracedAudioPlayer3D.play()
		400003:
			DialogManager.play("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", self, 400001)
			$RaytracedAudioPlayer3D.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends Node3D

@onready var agony = $DialogBubble
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().process_frame
	DialogManager.register_character(self, $DialogBubble)


func apply_damage(dmg):
	DialogManager.quit()
	DialogManager.play(["AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHHHHHHHHHHHHHHH AAAAHHHHHHHHHHHHHH AHHHH", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHHHHHHHHHHHHHHHHHHHHH AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"], self, 4)
	$RaytracedAudioPlayer3D.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

extends Node3D

@onready var por_icon = $POR/POR_Idle
@onready var sword_idle = $POR_Sword/Idle
@onready var sword_anim = $POR_Sword/AnimationPlayer
@onready var sword_transition = $POR_Transition
@onready var slash_anim = $POR_Sword/Slash


signal mode_toggled(new_mode: int)

var is_animating = false

func request_toggle_mode(current_mode: int) -> void:
	if is_animating:
		return
	is_animating = true

	if current_mode == 0: 
		por_icon.visible = false
		sword_transition.visible = true
		sword_transition.play()
	else: 
		sword_idle.visible = false
		sword_anim.stop()
		por_icon.visible = true
		is_animating = false
		emit_signal("mode_toggled", 0) 

func slash_play():
	is_animating = true
	sword_idle.visible = false
	sword_idle.frame = 0
	slash_anim.visible = true
	slash_anim.play()

func _on_por_transition_animation_finished() -> void:
	sword_transition.visible = false
	sword_idle.visible = true
	sword_anim.play("POR_sword_transition")
	is_animating = false
	emit_signal("mode_toggled", 1) # switched to fighting

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "POR_sword_transition":
		sword_idle.play()


func _on_slash_animation_finished() -> void:
	slash_anim.visible = false
	sword_transition.play()

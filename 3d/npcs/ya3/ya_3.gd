extends Node3D

@onready var example := $DialogBubble

enum Mode { NONE, MAIN, WALKAWAY, RETURN }

var mode: Mode = Mode.NONE

var main_index := 0
var walkaway_index := 0
var return_index := 0

var main_played := false
var walkaway_played := []
var return_played := []

var player_inside := false
var needs_return := false


var main_dialogs := [
	["[emotion=0:happy]Oh, hey! I didn't expect anyone to visit me."],
		["[emotion=0:neutral] Uhm, sorry I would've cleaned up if I knew someone was coming. [emotion=0:happy] I'm Я3VOЯ, but just call me Ya3."],
		["[emotion=0:neutral] You remind me of something... [emotion=0:happy]Right! Like ferrofluid!  
		It is a dark liquid that is attracted to the poles of a magnet. It is a colloidal liquid made of nanoscale ferromagnetic or ferrimagnetic particles suspended inside a carrier fluid (usually an organic solvent or water). Each magnetic particle is thoroughly coated with a surfactant to inhibit clumping."],
		["[emotion=0:happy]Large ferromagnetic particles can be ripped out of the homogeneous colloidal mixture, forming a separate clump of magnetic dust when exposed to strong magnetic fields. The magnetic attraction of tiny nanoparticles is weak enough that the surfactant's Van der Waals force is sufficient to prevent magnetic clumping or agglomeration. Ferrofluids usually do not retain magnetization in the absence of an externally applied field and thus are often classified as 'superparamagnets' rather than ferromagnets."],
		["[emotion=0:neutral] But I'm just rambling at this point...sorry..."],
		["[emotion=0:neutral] ..."],
		["[emotion=0:neutral] ..."],
		["[emotion=0:happy]You know, when I don't have anything to do, I just re-read the Lorem Ipsum text. It's a dummy or placeholder text commonly used in graphic design, publishing, and web development. 
		Its purpose is to permit a page layout to be designed, independently of the copy that will subsequently populate it, or to demonstrate various fonts of a typeface without meaningful text that could be distracting. Lorem ipsum is typically a corrupted version of De finibus bonorum et malorum, a 1st-century BC text by the Roman statesman and philosopher Cicero, with words altered, added, and removed to make it nonsensical and improper Latin. The first two words are the truncation of dolorem ipsum which means 'pain itself'"],
		["[emotion=0:neutral]Ahhh, I got a bit carried away. Sorry I don't mean it."]
]

var walkaway_dialogs := [
	["[emotion=0:sad]Wait- No- please don't leave just yet! I- I promise I can do better! Please don't leave me here!"],
	["[emotion=0:sad]No- no- no where are you going? I thought we had something here. I thought you were connecting with me! Please don't leave me alone!"],
	["[emotion=0:sad]Okay... I get it..."]
]

var return_dialogs := [
	["[emotion=0:happy]Oh, you're back! [emotion=0:sad] Look- I won't bore you again! I swear I can do better... please... Don't leave me like you did last time..."]
]

func _ready() -> void:
	await get_tree().process_frame
	DialogManager.register_character(self, example)
	DialogManager.connect("dialog_finished", _on_dialog_finished)

func apply_damage(dmg):
	print(dmg, "ouchies")
	DialogManager.interrupt()
	$AnimationPlayer.play("RESET")
	$AudioStreamPlayer3D.play()
	await get_tree().create_timer(2.0).timeout
	set_emotion("ba")

	
func set_emotion(emotion: String) -> void:
	match emotion:
		"happy":
			$AnimationPlayer.play("smile")
		"neutral":
			$AnimationPlayer.play("neutral")
		"sad":
			$AnimationPlayer.play("sad")
		"ba":
			$AnimatedSprite3D2.visible = true
			$RaytracedAudioPlayer3D.play(4.0)
			$AnimatedSprite3D2.play()
			$AnimationPlayer.play("RESET")
		"s":
			$AnimationPlayer.pause()
		


# -------------------------
# AREA EVENTS
# -------------------------
var started = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if not started:
		DialogManager.play("AAAAAAAAAAAAAAAAAAAAHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhhhhhhhhhhhhhhhhhhhhhhhhHHHHH", self, 743)
		started = true
	else:
		DialogManager.resume()


func _on_area_3d_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player")or not started:
		return
	DialogManager.interrupt()




# -------------------------
# PLAY HELPERS
# -------------------------


# -------------------------
# DIALOG FLOW
# -------------------------

func _on_dialog_finished(id: int) -> void:
	match id:
		743:
			DialogManager.play("bbebebebbebebbebebebebebbebebebbbbbbbbeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeebeb", self, 743)

func start_speaking():
	$AnimationPlayer.play()

func stop_speaking():
	$AnimationPlayer.stop()

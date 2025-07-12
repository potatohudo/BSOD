extends Control

@onready var textedit = $AspectRatioContainer/TextEdit


var level_lookup: Dictionary = {
	"12.42.0": "track",
	"00.00.1": "level_test",
	"11.11.1": "ARCHIVE",
	"00.00.2": "level_test_2"
	#"00.00.5": "corridor_w5" 
}
var usage: Vector2 = Vector2(0, -2)
func get_usage() -> Vector2:
	return usage

func _ready() -> void:
	await get_tree().process_frame

func _process(_delta):

	if textedit.has_focus() and Input.is_action_just_pressed("ui_accept"):
		var coordinates = textedit.text.strip_edges()
		textedit.clear()
		tp(coordinates)


func tp(coordinates: String) -> void:
	if level_lookup.has(coordinates):
		var level_name = level_lookup[coordinates]
		var level_path = "res://3d/levels/%s.tscn" % level_name
		print("Teleporting to: ", level_path)
		await get_tree().create_timer(0.5).timeout
		$AudioStreamPlayer.play()

		
		Global.target_level_path = level_path
		Global.just_teleported = true
		get_tree().get_root().set_transparent_background(true)

		await get_tree().create_timer(2.0).timeout
		DisplayServer.window_set_size(Vector2i(1, 1))
		await get_tree().create_timer(0.5).timeout

		get_tree().change_scene_to_file("res://3d/main.tscn")
	else:
		print("Invalid coordinates: '%s'" % coordinates)

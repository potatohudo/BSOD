extends Control

@onready var textedit = $AspectRatioContainer/TextEdit
var usage: Vector2 = Vector2(0, -2)

# Dictionary of coordinates and their level names
var level_lookup: Dictionary = {
	"12.42.0": "track",
	"00.00.1": "level_test",
	"11.11.1": "ARCHIVE",
	"00.00.2": "level_test_2"
}

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

		# Save it for the next scene
		Global.target_level_path = level_path

		# Then go to Main
		DisplayServer.window_set_size(Vector2i(1280, 800))
		get_tree().change_scene_to_file("res://3d/Main.tscn")
	else:
		print("Invalid coordinates: '%s'" % coordinates)

extends Panel

var initial_size = Vector2(804, 539)  # Initial size of the panel
var initial_positionn = Vector2(66, 55)  # Example initial position

func _ready():
	size = initial_size
	position = initial_positionn

func expand_to_fullscreen():
	var window_size = DisplayServer.window_get_size()
	position = Vector2.ZERO
	size = window_size

func reset_to_initial_size():
	size = initial_size
	position = initial_positionn


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	

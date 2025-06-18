extends Camera2D

@onready var viewport_content = $"../Loader/.." 
@onready var viewport = $"../" 

var scroll_speed = 40  
var min_scroll = 0  
var max_scroll = 0  

func _ready():
	await get_tree().process_frame 
	position = Vector2(viewport.size.x / 2, viewport.size.y / 2) 

func update_scroll_limits():
	await get_tree().process_frame

	var loader = $"../Loader"
	var site = loader.get_node_or_null("Site")

	# Fallback: look inside any wrapper node that starts with "@"
	if site == null:
		for child in loader.get_children():
			if child.name.begins_with("@"):
				if child.has_node("Site"):
					site = child.get_node("Site")
					break
				elif child is Control:
					
					site = child
					break

	await get_tree().process_frame

	if site:
		var current_width = site.size.x if site.size.x > 0 else 1
		var percent_x = viewport.size.x / current_width
		var scaled_y = site.scroll * percent_x if "scroll" in site else site.size.y

		limit_left = 0
		limit_right = viewport.size.x
		limit_top = 0
		limit_bottom = scaled_y
		position = Vector2(viewport.size.x / 2, viewport.size.y / 2)
	else:
		limit_bottom = 0





func _input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		position.y -= event.relative.y  # Move camera based on drag

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position.y = max(limit_top, position.y - scroll_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position.y = min(limit_bottom, position.y + scroll_speed)

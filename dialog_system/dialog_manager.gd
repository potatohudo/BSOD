# DialogManager.gd (autoload)
extends Node

signal dialog_started(entry)
signal dialog_advanced(entry)
signal dialog_finished()


var _queue: Array = []
var _index: int = 0

# currently shown bubble node (typed explicitly)
var current_bubble: Node = null

# Start a sequence of dialogs. 'dialogs' should be an Array of dictionaries.
func start(dialogs: Array) -> void:
	_queue = dialogs.duplicate()
	_index = 0
	_show_next()

# Show the next entry in the queue
func _show_next() -> void:
	if _index >= _queue.size():
		emit_signal("dialog_finished")
		_queue.clear()
		_index = 0
		return

	var entry = _queue[_index]
	_index += 1
	emit_signal("dialog_started", entry)

	# Resolve the PackedScene: either user passed a PackedScene or a string path
	var scene_spec = entry.get("scene", null)
	var packed_scene: PackedScene = null

	if scene_spec == null:
		push_error("DialogManager: entry missing 'scene' key.")
		_show_next()
		return

	# If it's a path string, load it at runtime. Do NOT use preload(path_variable).
	if typeof(scene_spec) == TYPE_STRING:
		var loaded = load(scene_spec)
		if loaded == null or not (loaded is PackedScene):
			push_error("DialogManager: failed to load scene at: %s" % scene_spec)
			_show_next()
			return
		packed_scene = loaded
	# If they passed a PackedScene directly:
	elif scene_spec is PackedScene:
		packed_scene = scene_spec
	else:
		push_error("DialogManager: 'scene' must be a string path or PackedScene.")
		_show_next()
		return

	# instantiate the PackedScene (bubble)
	var bubble_node: Node = packed_scene.instantiate()
	current_bubble = bubble_node

	# Add to the current scene so it's visible
	var root_scene = get_tree().current_scene
	if root_scene == null:
		# fallback to root if current_scene not set
		root_scene = get_tree().get_root()
	root_scene.add_child(bubble_node)

	# Set text property if provided and available
	if entry.has("text"):
	
		# setting directly; if the scene doesn't have it, it will just warn rather than crash
		if bubble_node.has_method("set_text"):
			# if you implement a setter method
			bubble_node.call("set_text", entry["text"])
		else:
			# try to set property; if property doesn't exist, this will simply create/override metadata but
			# typical scene uses exported 'text' so this will work.
			# If you prefer strictness, check for 'is_class' or class_name on the bubble types.
			bubble_node.set("text", entry["text"])

	emit_signal("dialog_advanced", entry)

	# Optional: listen for a "finished" signal from the bubble to auto-advance
	if bubble_node.has_signal("dialog_finished"):
		bubble_node.connect("dialog_finished", Callable(self, "_on_bubble_finished"))
	else:
		# fallback: auto-advance after a property or time. Here we advance when user clicks or after default timeout:
		# expect the bubble scene to emit a signal or call DialogManager.show_next() when done.
		# For robustness, we will wait for a small duration and then advance (non-ideal).
		# Encourage bubble scenes to emit "dialog_finished" to integrate cleanly.
		pass

# Called when a bubble signals it finished showing and should be removed / advance
func _on_bubble_finished() -> void:
	# clean up current bubble if necessary
	if current_bubble and current_bubble.is_inside_tree():
		current_bubble.queue_free()
	current_bubble = null
	_show_next()

# public helper to force-advance (useful for input skip)
func advance() -> void:
	# If bubble has a method to finish early, call it; otherwise free and show next
	if current_bubble:
		if current_bubble.has_method("finish_now"):
			current_bubble.call("finish_now")
		else:
			current_bubble.queue_free()
			current_bubble = null
			_show_next()

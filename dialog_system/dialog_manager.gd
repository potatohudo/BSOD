extends Node

signal dialog_started(id: int)
signal dialog_finished(id: int)
signal dialog_interrupted(id: int)

enum State { INACTIVE, PLAYING, PAUSED }

@export var active := true

var state: State = State.INACTIVE
var _current_bubble: Control = null
var _stored_bubble: Control = null
var _stored_id: int = -1

var _characters: Dictionary = {}


func register_character(character: Node, example_bubble: Control) -> void:
	if not is_instance_valid(character):
		return
	if not is_instance_valid(example_bubble):
		return

	var id := _character_id(character)
	_characters[id] = {
		"node": character,
		"example": example_bubble
	}

func unregister_character(character: Node) -> void:
	var id := _character_id(character)
	_characters.erase(id)

func _character_id(c: Node) -> String:
	return str(c.get_path())

# PUBLIC API
func play(
	text: String,
	character: Node,
	id: int,
	example_override: Control = null
) -> void:
	if not active:
		return
	quit()

	var char_id := _character_id(character)
	if not _characters.has(char_id):
		push_warning("Character not registered: %s" % char_id)
		return

	var entry = _characters[char_id]
	var example: Control = example_override if example_override else entry.example
	if not is_instance_valid(example):
		return

	# Duplicate bubble
	var bubble: Control = example.duplicate()
	example.get_parent().add_child(bubble)

	bubble.visible = true

	# replace text BEFORE playing

	bubble.text = String(text)
	#else:
		#push_warning("Bubble has no 'text' variable")
		#return

	state = State.PLAYING
	_current_bubble = bubble

	emit_signal("dialog_started", id)

	# Run playback ONCE
	call_deferred("_run_bubble", bubble, id)
	
func is_playing() -> bool:
	return state == State.PLAYING

func interrupt() -> void:
	if state != State.PLAYING:
		return


	if not is_instance_valid(_current_bubble):
		return

	_stored_bubble = _current_bubble
	_stored_id = -1

	if _current_bubble.has_method("pause_dialog"):
		_current_bubble.pause_dialog()

	#_current_bubble.visible = false
	_current_bubble = null
	state = State.PAUSED


func resume() -> void:
	if state != State.PAUSED:
		return

	if not is_instance_valid(_stored_bubble):
		state = State.INACTIVE
		return

	_current_bubble = _stored_bubble
	_stored_bubble = null

	_current_bubble.visible = true

	if _current_bubble.has_method("resume_dialog"):
		_current_bubble.resume_dialog()

	state = State.PLAYING


func quit(free_stored = true) -> void:
	var bubble := _current_bubble if is_instance_valid(_current_bubble) else _stored_bubble

	if is_instance_valid(bubble):
		if bubble.has_method("force_stop"):
			bubble.force_stop()
		bubble.queue_free()

	_current_bubble = null
	if free_stored:
		_stored_bubble = null
		_stored_id = -1
	state = State.INACTIVE

	emit_signal("dialog_interrupted", -1)

#HIDE.
func hide(characters: Array) -> void:
	for id in _characters.keys():
		var entry = _characters[id]
		if entry.node in characters:
			for c in entry.node.get_children():
				if c is Control:
					c.visible = false

func show(characters: Array) -> void:
	for id in _characters.keys():
		var entry = _characters[id]
		if entry.node in characters:
			for c in entry.node.get_children():
				if c is Control:
					c.visible = true



#flow
func _run_bubble(bubble: Control, id: int) -> void:
	if not is_instance_valid(bubble):
		_finish(id)
		return

	if not bubble.has_method("play"):
		push_warning("Bubble has no play()")
		_finish(id)
		return
	while state == State.PLAYING:
		await bubble.play()
		_finish(id)
	print(state)

func _finish(id: int) -> void:
	if is_instance_valid(_current_bubble):
		_current_bubble.queue_free()

	_current_bubble = null
	state = State.INACTIVE
	emit_signal("dialog_finished", id)
	print(state)

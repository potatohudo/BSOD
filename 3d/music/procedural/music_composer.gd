extends Node

@export var intro: Array[NodePath] = []
@export var main: Array[NodePath] = [] #main should alsways be set, otherwise it crashes
@export var outro: Array[NodePath] = []

@export var cut: bool = false #isnt used yet. 
@export var enable_intro: bool = true
@export var enable_outro: bool = true
@export var outro_dist: float = 40.0 #not used yet


@export var end_timer: float = 10.0

var _current: Node = null
var _end_timer := 0.0
var index := 0
var state: Array
var state_index = 0


func _ready():
	await get_tree().process_frame
	state = [main]
	if (enable_intro):
		state.push_front(intro)
	if (enable_outro):
		state.push_back(outro)
	_reset_all()
	_play(state[state_index])
	for child in get_children():
		if child.has_signal("done"):
			child.done.connect(_on_done)

#flow.question mark

func _on_done():
	index += 1 
	if index >= state[state_index].size():
		index = 0
		state_index += 1 
		if state_index >= state.size():
			state_index = 0
	_play(state[state_index])
	print(index, state_index, _current.active)

func _play(arr: Array ):
	_deactivate_current()
	_current = get_node(arr[index])
	_current.active = true

func _deactivate_current():
	if _current:
		_current.active = false
	_current = null

func _reset_all():
	_deactivate_current()
	_end_timer = 0.0
	index = 0
	state_index = 0

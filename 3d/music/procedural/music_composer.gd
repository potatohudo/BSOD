extends Node

enum State { INTRO, MAIN, OUTRO, NONE }

@export var intro: Array[NodePath] = []
@export var main: Array[NodePath] = []
@export var outro: Array[NodePath] = []
@export var require_fight: bool = false
@export var cut: bool = false
@export var enable_intro: bool = true
@export var enable_outro: bool = true
@export var outro_dist: float = 40.0

@export var end_timer: float = 10.0

var _state: State = State.INTRO
var _current: Node = null
var _timer := Timer.new()
var _end_timer := 0.0
var _index := 0


func _ready():
	add_child(_timer)
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	_reset_all()
	_play_intro()


# -------------------------------------------------
# CORE FLOW
# -------------------------------------------------

func _on_timer_timeout():
	match _state:
		State.INTRO:
			_try_intro_to_main()
		State.MAIN:
			_play_next(main)
		State.OUTRO:
			_reset_all()


func _process(delta):
	if not _current:
		return

	var dist = _current.get_enemy_distance()

	if dist < outro_dist:
		_end_timer = 0.0
		return

	_end_timer += delta
	if _end_timer >= end_timer:
		_reset_all()


# -------------------------------------------------
# INTRO
# -------------------------------------------------

func _play_intro():
	if not enable_intro or intro.is_empty():
		_play_main()
		return

	_state = State.INTRO
	_play_from_array(intro)


func _try_intro_to_main():
	if not enable_intro:
		_play_intro()
		return

	if require_fight and not _current.is_fighting():
		_play_intro()
		return

	if cut:
		_play_main()
	else:
		_play_intro()


# -------------------------------------------------
# MAIN
# -------------------------------------------------

func _play_main():
	if main.is_empty():
		return

	_state = State.MAIN
	_play_from_array(main)


# -------------------------------------------------
# OUTRO
# -------------------------------------------------

func _play_outro():
	if not enable_outro or outro.is_empty():
		_reset_all()
		return

	_state = State.OUTRO
	_index = 0
	_play_specific(outro[_index])


# -------------------------------------------------
# HELPERS
# -------------------------------------------------

func _play_from_array(arr: Array):
	_play_specific(arr[_index % arr.size()])
	_index += 1


func _play_specific(path: NodePath):
	_deactivate_current()

	_current = get_node(path)
	_current.active = true

	var wait_time = _current.loop_length * _current.times
	_timer.start(wait_time)


func _deactivate_current():
	if _current:
		_current.active = false
	_current = null


func _play_next(arr: Array):
	if _state == State.MAIN and enable_outro:
		if _current.get_enemy_distance() > outro_dist:
			_play_outro()
			return

	_play_from_array(arr)


func _reset_all():
	_deactivate_current()
	_timer.stop()
	_end_timer = 0.0
	_index = 0
	_state = State.INTRO
	_play_intro()

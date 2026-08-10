extends Control


@onready var label: RichTextLabel = %RichTextLabel
@onready var name_label: Label = %NameLabel
@onready var panel: PanelContainer = %PanelContainer
@onready var anim: AnimationPlayer = %AnimationPlayer

@export_multiline var text: String = ""
@export var speaker_name: String = ""
@export var style: Dictionary = {}

@export var character_nodes: Array[NodePath] = []# nodes to call start/stop speaking and set_emotion on



@export var typing_speed := 0.03
@export_range(0.0, 10.0, 0.01) var wait_time := 0.0

# Effects / styling 
@export_group("Effects: Shake")
@export_range(0.0, 40.0, 0.1) var global_shake_intensity := 2.0
@export_range(0.0, 1.0, 0.01) var global_shake_amount := 1.0

@export_group("Effects: Random Scale (Paper Cut)")
@export var global_random_scale := false
@export_range(0.0, 1.0, 0.01) var global_random_scale_amount := 0.2

@export_group("Effects: Wave")
@export_range(0.0, 20.0, 0.1) var global_wave_amplitude := 6.0
@export_range(0.0, 40.0, 0.1) var global_wave_speed := 8.0
@export var global_wave_randomness := false
@export_range(0.0, 1.0, 0.01) var global_wave_randomness_amount := 0.2
@export_range(0.0, 1.0, 0.01) var global_wave_amount := 1.0

@export_group("Fade")
@export var fade_in := true
@export var fade_out := true
@export_range(0.1, 5.0, 0.1) var fade_duration := 0.5
 
var _active_character: Node = null


var _current_segment: int = 0
var _stored_char: int = 0

var _is_showing := false
var _skip_requested := false
var _typing_done := false
var _paused := false

signal dialog_resumed

# { "segment": int, "pos": int, "type": "emotion"|"speech", "index": int, "value": String }
var _trigger_queue := []

var _wave_effect
var _shake_effect
var _rand_effect

# --- inline text stuff---
class WaveEffect:
	extends RichTextEffect
	var bbcode := "wave"
	var amplitude := 6.0
	var speed := 8.0
	var randomness := 0.0
	var enabled_amount := 1.0
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		if enabled_amount < 1.0 and randf() > enabled_amount:
			return true
		var t = float(Time.get_ticks_msec()) / 1000.0
		var random_phase = 0.0
		if randomness > 0.0:
			random_phase = (randf() - 0.5) * randomness * PI * 2.0
		char_fx.offset.y = sin(t * speed + char_fx.relative_index * 0.3 + random_phase) * amplitude
		return true

class ShakeEffect:
	extends RichTextEffect
	var bbcode := "shake"
	var intensity := 2.0
	var enabled_amount := 1.0
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		if enabled_amount < 1.0 and randf() > enabled_amount:
			return true
		char_fx.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		return true

class RandScaleEffect:
	extends RichTextEffect
	var bbcode := "rand"
	var scale_amount := 0.2
	func _process_custom_fx(char_fx: CharFXTransform) -> bool:
		var s = clamp(1.0 + randf_range(-scale_amount, scale_amount), 0.8, 1.2)
		char_fx.transform = Transform2D().scaled(Vector2(s, s))
		return true

func _ready() -> void:
	_install_inline_effects()

# Start showing this dialog node. Awaitable -> returns "finished" or "paused".
func play() -> String:
	print(_stored_char, _is_showing)
	if _is_showing:
		# already showing: don't re-enter
		return "finished"
	
	_is_showing = true
	_skip_requested = false
	_typing_done = false
	_paused = false

	self.visible = true
	_update_effect_params()

	# set name label
	if name_label:
		name_label.visible = speaker_name != ""
		name_label.text = speaker_name

	# parse triggers and split into segments
	var combined := text

	var result = _process_triggers_and_split(combined)
	var segments = result[0]
	var triggers = result[1]

	_trigger_queue = triggers

	for segment_index in range(segments.size()):
		#if _paused:
			#break
		_current_segment = segment_index
		var seg_text = segments[segment_index]
		var res_seg = await _show_segment(segment_index, seg_text)

	if _skip_requested:
		_fire_all_remaining_triggers(_current_segment)

	_is_showing = false

	#if _paused:
		#_paused = false
		#_is_showing = false
		#return "paused"

	var read_buffer := 0.6  
	if "wait_time" in self and float(wait_time) > 0.0:
		read_buffer = float(wait_time)

	# Wait a little so player can read 
	if read_buffer > 0.0:
		await get_tree().create_timer(read_buffer).timeout

	# hide bubble after display
	
	return "finished"
	
func _unhandled_input(event):
	#dialog skip
	if event.is_action_pressed("ui_accept"):
		if not _typing_done:
			_skip_requested = true
		elif _typing_done and _is_showing:
			_skip_requested = true
			_typing_done = true

func finish_now() -> void:
	if not _typing_done:
		_skip_requested = true
		if label:
			label.visible_characters = -1
		_fire_all_remaining_triggers(_current_segment)

# Trigger parsing & splitting

func _process_triggers_and_split(orig_text: String) -> Array:
	var segments_raw := orig_text.split("[n]", false)
	var segments_clean := []
	var triggers := []

	for s_index in range(segments_raw.size()):
		var seg := segments_raw[s_index]
		var offset := 0
		# process emotion tags first
		var regex_em := RegEx.new()
		regex_em.compile("\\[emotion=(\\d+):([^\\]]+)\\]")

		var matches := regex_em.search_all(seg)
		var shift := 0
		var r := regex_em.search(seg)

		for m in matches:
			var start := m.get_start() - shift
			var end := m.get_end() - shift
			triggers.append({
				"segment": s_index,
				"pos": start,
				"type": "emotion",
				"index": int(m.get_string(1)),
				"value": m.get_string(2)
			})
			var removed_len := end - start
			seg = seg.erase(start, removed_len)
			shift += removed_len

			r = regex_em.search(seg)

		# process speech tags [INDEX:s] or [INDEX:sp]
		var regex_sp := RegEx.new()
		regex_sp.compile("\\[(\\d+):(s|sp)\\]")
		r = regex_sp.search(seg)
		while r:
			var start := r.get_start() - offset
			var end := r.get_end() - offset
			var idx := int(r.get_string(1))
			var val := r.get_string(2)
			triggers.append({
				"segment": s_index,
				"pos": start,
				"type": "speech",
				"index": idx,
				"value": val
			})
			var removed_len := end - start
			seg = seg.erase(start, removed_len)
			offset += removed_len
			r = regex_sp.search(seg)

		segments_clean.append(seg)

	# Sort triggers by segment then by pos (stability)
	triggers.sort_custom(Callable(self, "_sort_triggers"))
	return [segments_clean, triggers]

# helper for stable sorting
func _sort_triggers(a, b) -> int:
	if a.segment < b.segment:
		return -1
	if a.segment > b.segment:
		return 1
	if a.pos < b.pos:
		return -1
	if a.pos > b.pos:
		return 1
	return 0



#func _play_with_text(dialog_text: String) -> String:
	#var original := text
#
	#text = dialog_text
#
	#var res := await show_dialog()
#
	#text = original
#
	#return res


func force_stop() -> void:
	_skip_requested = true
	_paused = false
	_is_showing = false
	visible = false

	if label:
		label.visible_characters = -1

	_fire_all_remaining_triggers(_current_segment)

	_active_character = null
	_trigger_queue.clear()


func _show_segment(segment_index: int, seg_text: String) -> void:
	#label.clear()
	label.bbcode_enabled = true
	#label.text = ""

	if fade_in:
		await _fade_in()

	_skip_requested = false
	_typing_done = false

	# parse and reveal
	label.parse_bbcode(seg_text)
	label.visible_characters = _stored_char
	var total_chars := label.get_total_character_count()

	# Start speaking for all characters during segment by default
	if _active_character and _active_character.has_method("start_speaking"):
		_active_character.start_speaking()
	_active_character = null


	for i in range(total_chars + 1):
		for t in _trigger_queue:
			if t.segment == segment_index and t.pos == i:
				_process_trigger(t)

		if _skip_requested:
			label.visible_characters = -1
			_fire_all_remaining_triggers(_current_segment)
			break
		if _paused:
			_stored_char = i
			print("paused!", _stored_char)
			
			break
		label.visible_characters = i
		await get_tree().create_timer(typing_speed).timeout

	_active_character = null


	_typing_done = true

	if wait_time > 0.0:
		await get_tree().create_timer(wait_time).timeout

	if fade_out:
		await _fade_out()

func _process_trigger(t: Dictionary) -> void:
	if t.type == "emotion":
		_apply_emotion(t.index, str(t.value))
	elif t.type == "speech":
		var char := _get_character_node(int(t.index))
		if not char:
			return

		# stop previous speaker
		if _active_character and _active_character != char:
			if _active_character.has_method("stop_speaking"):
				_active_character.stop_speaking()

		_active_character = char


func _fire_all_remaining_triggers(segment_index: int) -> void:
	for t in _trigger_queue:
		if t.segment == segment_index:
			_process_trigger(t)

# Character helpers
func _get_character_node(index: int) -> Node:
	if index < 0 or index >= character_nodes.size():
		return null

	var path := character_nodes[index]
	if path == NodePath("") or str(path) == "":
		return null

	var n := get_node_or_null(path)
	if n:
		return n

	return get_tree().get_root().get_node_or_null(path)



# Emotion application 
func _apply_emotion(index: int, emotion: String) -> void:
	#if index < 0 or index >= character_nodes.size():
		#push_warning("Emotion index %d out of range on %s" % [index, self.name])
		#return
	var char := _get_character_node(index)
	if char == null:
		push_warning("Character at index %d not found on %s" % [index, self.name])
		return
	if not char.has_method("set_emotion"):
		push_warning("Character at index %d has no set_emotion() method on %s" % [index, self.name])
		return
	char.set_emotion(emotion)

# Style / effects helpers


func _install_inline_effects() -> void:
	_wave_effect = WaveEffect.new()
	_shake_effect = ShakeEffect.new()
	_rand_effect = RandScaleEffect.new()
	label.install_effect(_wave_effect)
	label.install_effect(_shake_effect)
	label.install_effect(_rand_effect)
	_update_effect_params()

func _update_effect_params() -> void:
	if _wave_effect:
		_wave_effect.amplitude = global_wave_amplitude
		_wave_effect.speed = global_wave_speed
		_wave_effect.randomness = global_wave_randomness_amount if global_wave_randomness else 0.0
		_wave_effect.enabled_amount = clamp(global_wave_amount, 0.0, 1.0)
	if _shake_effect:
		_shake_effect.intensity = global_shake_intensity
		_shake_effect.enabled_amount = clamp(global_shake_amount, 0.0, 1.0)
	if _rand_effect:
		_rand_effect.scale_amount = global_random_scale_amount

# Fade helpers 
func _fade_in() -> void:
	if anim and anim.has_animation("fade_in"):
		anim.play("fade_in")
		await anim.animation_finished
	else:
		await _simple_fade(0.0, 1.0)

func _fade_out() -> void:
	if anim and anim.has_animation("fade_out"):
		anim.play("fade_out")
		await anim.animation_finished
	else:
		await _simple_fade(1.0, 0.0)

func _simple_fade(from_alpha: float, to_alpha: float) -> void:
	var tw := create_tween()
	if panel:
		panel.modulate.a = from_alpha
		tw.tween_property(panel, "modulate:a", to_alpha, fade_duration)
	if label:
		label.modulate.a = from_alpha
		tw.parallel().tween_property(label, "modulate:a", to_alpha, fade_duration)
	if name_label:
		name_label.modulate.a = from_alpha
		tw.parallel().tween_property(name_label, "modulate:a", to_alpha, fade_duration)
	await tw.finished

func pause_dialog() -> void:
	if not _is_showing:
		return
	_paused = true

func resume_dialog() -> void:
	if not _is_showing:
		return
	_paused = false
	dialog_resumed.emit()

#func start_speaking():
	#$AnimationPlayer.play()
#
#func stop_speaking():
	#$AnimationPlayer.stop()

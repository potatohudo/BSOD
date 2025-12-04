extends Control
# DialogBubble.gd
# UI + per-dialog data node.
# - Put this on nodes that contain dialog text and exported next-paths.
# - Responsible for presentation, tag parsing, and triggering emotions / speech.
# - Emits when finished so DialogManager can pick the next dialog node.

signal dialog_finished(bubble_node: Node)

@onready var label: RichTextLabel = %RichTextLabel
@onready var name_label: Label = %NameLabel
@onready var panel: PanelContainer = %PanelContainer
@onready var anim: AnimationPlayer = %AnimationPlayer

# ----------------------------
# Exported dialog data (per-node)
# ----------------------------
@export_multiline var text: Array[String] = []
@export var speaker_name: String = ""
@export var style: Dictionary = {}

@export var character_nodes: Array[NodePath] = []# nodes to call start/stop speaking and set_emotion on

@export var next_yes: NodePath = NodePath("")# NodePath to the next dialog for "yes"
@export var next_no: NodePath = NodePath("")# NodePath to the next dialog for "no"
@export var next_none: Array[NodePath] = []	# list of NodePaths for "none" (queue or random)
@export var next_none_random: bool = false# true -> pick random from next_none; false -> queue (first available)
@export var walk_away: NodePath = NodePath("")# walk away dialog node (optional)
@export_multiline var return_text: String = ""


@export_range(0.005, 0.5, 0.001) var typing_speed := 0.03
@export_range(0.0, 10.0, 0.01) var wait_time := 0.0

# Effects / styling (kept for compatibility)
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

@export_group("Styling")
@export var label_settings: LabelSettings
@export var bubble_style: StyleBox

var _current_segment: int = 0
var _paused: bool = false
var _resume_segment: int = 0
var _resume_char: int = 0
var _resume_text: Array = []        # <<-- now an Array[String]
var _resume_triggers: Array = []




# --- internal state ---
var _is_showing := false
var _skip_requested := false
var _typing_done := false

# Triggers are per-segment. Each trigger dict:
# { "segment": int, "pos": int, "type": "emotion"|"speech", "index": int, "value": String }
var _trigger_queue := []

# kept inline effects
var _wave_effect
var _shake_effect
var _rand_effect

# --- inline text effects (kept from original) ---
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

# --- lifecycle / API ---
func _ready() -> void:
	_apply_style()
	_install_inline_effects()

# Start showing this dialog node. Awaitable — returns when done.
func show_dialog() -> void:
	if _is_showing:
		# already showing: don't re-enter
		return
	_is_showing = true
	_skip_requested = false
	_typing_done = false

	# Make visible immediately (manager hides siblings)
	self.visible = true
	_apply_style()
	_update_effect_params()


	# set name label
	if name_label:
		name_label.visible = speaker_name != ""
		name_label.text = speaker_name

	# parse triggers and split into segments
	var combined := "\n[n]\n".join(text)
	var result = _process_triggers_and_split(combined)
	var segments = result[0]
	var triggers = result[1]

	_trigger_queue = triggers

	# show segments in sequence
	for segment_index in range(segments.size()):
		# If paused, break immediately (we hide and let manager handle the rest)
		if _paused:
			break
		var seg_text = segments[segment_index]
		await _show_segment(segment_index, seg_text)
		# if paused after the segment started, stop processing further segments
		if _paused:
			break

		# if skip requested and user wanted to break early, we still continue to show remaining segments (consistency).
		# segment-level behavior is handled by skip flags.

	_is_showing = false
	emit_signal("dialog_finished", self)
	_paused = false
	_typing_done = true

	# Keep dialog visible for a short read-buffer; allow DialogManager's wait_time to add more
	var read_buffer := 0.6  # seconds; you can expose as export if you want
	if "wait_time" in self and float(wait_time) > 0.0:
		# if the bubble defines a wait_time, prefer it (keeps prior behavior)
		read_buffer = float(wait_time)

	# Wait a little so player can read (unless skip requested earlier)
	if read_buffer > 0.0:
		await get_tree().create_timer(read_buffer).timeout

	# hide bubble after display
	self.visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		# if typing -> skip to full text
		if not _typing_done:
			_skip_requested = true
		# else if finished -> hide early (simulate accept)
		elif _typing_done and _is_showing:
			# expedite hide: set tiny buffer to zero
			_skip_requested = true
			_typing_done = true


# Request the current reveal to finish immediately
func finish_now() -> void:
	if not _typing_done:
		_skip_requested = true
		# force visible characters to all so get_total_character_count won't block
		if label:
			label.visible_characters = -1
		# fire any remaining triggers for current segment and all others
		_fire_all_remaining_triggers()


# ----------------------------
# Trigger parsing & splitting
# ----------------------------
# Splits by [n] into segments, removes all tags from each segment, and returns:
# - segments_clean: Array[String]
# - triggers: Array[Dictionary]
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
		var r := regex_em.search(seg)
		while r:
			var start := r.get_start() - offset
			var end := r.get_end() - offset
			var idx := int(r.get_string(1))
			var val := r.get_string(2)
			triggers.append({
				"segment": s_index,
				"pos": start,
				"type": "emotion",
				"index": idx,
				"value": val
			})
			var removed_len := end - start
			seg = seg.erase(start, removed_len)
			offset += removed_len
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

# ----------------------------
# Segment presentation
# ----------------------------
func _show_segment(segment_index: int, seg_text: String) -> void:
	# seg_text may contain '\n' for new lines (keep those)
	# we'll parse BBCode as usual, but trigger tags at correct visible-character positions
	label.clear()
	label.bbcode_enabled = true
	label.text = ""

	if fade_in:
		await _fade_in()

	_skip_requested = false
	_typing_done = false

	# parse and reveal
	label.parse_bbcode(seg_text)
	label.visible_characters = 0
	var total_chars := label.get_total_character_count()

	# Start speaking for all characters during segment by default
	_start_all_characters_speaking()

	for i in range(total_chars + 1):
		# run triggers for this segment at position i
		for t in _trigger_queue:
			if t.segment == segment_index and t.pos == i:
				_process_trigger(t)

		if _skip_requested:
			label.visible_characters = -1
			_fire_remaining_triggers_for_segment(segment_index)
			break

		label.visible_characters = i
		await get_tree().create_timer(typing_speed).timeout

	_stop_all_characters_speaking()

	_typing_done = true

	if wait_time > 0.0:
		await get_tree().create_timer(wait_time).timeout

	if fade_out:
		await _fade_out()

func _process_trigger(t: Dictionary) -> void:
	if t.type == "emotion":
		_apply_emotion(t.index, str(t.value))
	elif t.type == "speech":
		# t.value is "s" or "sp"
		var idx := int(t.index)
		var char = _get_character_node(idx)
		if char:
			if str(t.value) == "s" and char.has_method("start_speaking"):
				char.start_speaking()
			elif str(t.value) == "sp" and char.has_method("stop_speaking"):
				char.stop_speaking()

func _fire_remaining_triggers_for_segment(segment_index: int) -> void:
	for t in _trigger_queue:
		if t.segment == segment_index:
			_process_trigger(t)

func _fire_all_remaining_triggers() -> void:
	for t in _trigger_queue:
		_process_trigger(t)

# Character helpers
func _get_character_node(index: int) -> Node:
	if index < 0 or index >= character_nodes.size():
		return null
	var path := character_nodes[index]
	if path == NodePath("") or str(path) == "":
		return null
	# Try relative resolution first
	var n := get_node_or_null(path)
	if n:
		return n
	return get_tree().get_root().get_node_or_null(path)

func _start_all_characters_speaking():
	for path in character_nodes:
		if path == NodePath("") or str(path) == "":
			continue
		var c := _get_character_node(character_nodes.find(path))
		if c and c.has_method("start_speaking"):
			c.start_speaking()

func _stop_all_characters_speaking():
	for path in character_nodes:
		if path == NodePath("") or str(path) == "":
			continue
		var c := _get_character_node(character_nodes.find(path))
		if c and c.has_method("stop_speaking"):
			c.stop_speaking()


# Emotion application (safe checks)

func _apply_emotion(index: int, emotion: String) -> void:
	if index < 0 or index >= character_nodes.size():
		push_warning("Emotion index %d out of range on %s" % [index, self.name])
		return
	var char := _get_character_node(index)
	if char == null:
		push_warning("Character at index %d not found on %s" % [index, self.name])
		return
	if not char.has_method("set_emotion"):
		push_warning("Character at index %d has no set_emotion() method on %s" % [index, self.name])
		return
	char.set_emotion(emotion)

# Style / effects helpers

func _apply_style() -> void:
	if panel and bubble_style:
		panel.add_theme_stylebox_override("panel", bubble_style)
	if label and label_settings:
		label.label_settings = label_settings

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

# Fade helpers (kept)
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
	finish_now()
	visible = false


func resume_dialog() -> void:
	if not _paused:
		return

	_paused = false
	visible = true
	await _resume_reveal()


func _resume_reveal() -> void:
	var combined := ""
	if _resume_text.size() > 0:
		combined = "\n[n]\n".join(_resume_text)
	else:
		combined = ""

	var parsed = _process_triggers_and_split(combined)
	var segments: Array = parsed[0]
	var triggers: Array = parsed[1]

	_trigger_queue = triggers

	for seg_i in range(_resume_segment, segments.size()):
		var seg_text: String = segments[seg_i]

		var start_char := (_resume_char if seg_i == _resume_segment else 0)

		await _resume_segment_reveal(seg_i, seg_text, start_char)

	_resume_char = 0

	emit_signal("dialog_finished", self)


func _resume_segment_reveal(seg_index: int, seg_text: String, start_char: int) -> void:
	_current_segment = seg_index

	label.clear()
	label.parse_bbcode(seg_text)
	label.visible_characters = start_char

	var total := label.get_total_character_count()
	_start_all_characters_speaking()

	for i in range(start_char, total + 1):

		for t in _trigger_queue:
			if t.segment == seg_index and t.pos == i:
				_process_trigger(t)

		if _skip_requested:
			label.visible_characters = -1
			break

		label.visible_characters = i
		await get_tree().create_timer(typing_speed).timeout

	_stop_all_characters_speaking()

func restart_dialog() -> void:
	_paused = false
	await show_dialog()

func play_return_text() -> void:
	if return_text.strip_edges() == "":
		return
	var original_segments := text.duplicate(true)
	text = [return_text]
	await show_dialog()
	text = original_segments

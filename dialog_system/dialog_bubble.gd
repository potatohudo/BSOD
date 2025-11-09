extends Control

signal dialog_finished

@onready var label: RichTextLabel = %RichTextLabel
@onready var name_label: Label = %NameLabel
@onready var panel: PanelContainer = %PanelContainer
@onready var anim: AnimationPlayer = %AnimationPlayer

@export_group("Dialog Content")
@export var dialogs: Array[String] = []
@export var dialog_names: Array[String] = []
@export var dialog_styles: Array[Dictionary] = []
@export var random_dialogs: Array[String] = []
@export var random_dialog_names: Array[String] = []
@export var typing_speed := 0.03

@export_group("Effects: Shake")
@export var global_shake := false
@export_range(0.0, 40.0, 0.1) var global_shake_intensity := 2.0
@export_range(0.0, 1.0, 0.01) var global_shake_amount := 1.0

@export_group("Effects: Random Scale (Paper Cut)")
@export var global_random_scale := false
@export_range(0.0, 1.0, 0.01) var global_random_scale_amount := 0.2

@export_group("Effects: Wave")
@export var global_wave := false
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

# internal state
var _paragraphs: PackedStringArray = []
var _current := 0
var _dialog_index := 0

var _typing_done := false        # true when the reveal finished or was skipped
var _skip_requested := false    # set when user presses accept during typing -> finish immediately
var _waiting_for_input := false # true when waiting for accept after finished
var _is_running := false        # guard to prevent reentrant driver

var _wave_effect
var _shake_effect
var _rand_effect

# --- inline text effects (kept from your original) ---
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

# --- lifecycle ---
func _ready() -> void:
	await get_tree().process_frame
	_apply_style()
	_install_inline_effects()
	# Start the single sequential dialog driver
	if not _is_running:
		_is_running = true
		await _run_dialog_sequence()
		_is_running = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		# If typing is in progress -> request skip to full text
		if not _typing_done:
			_skip_requested = true
		# If typing is done and we're waiting to advance -> advance immediately
		elif _waiting_for_input:
			_waiting_for_input = false

# --- style and effects setup ---
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

# --- top-level sequential driver (single source of truth) ---
func _run_dialog_sequence() -> void:
	# If no dialogs but random pool exists, start with random
	if dialogs.is_empty() and random_dialogs.size() > 0:
		_dialog_index = -1 # marker for random usage below

	while true:
		# pick next text
		var text: String
		var name: String = ""
		var style: Dictionary = {}
		if _dialog_index == -1:
			# random mode
			if random_dialogs.size() == 0:
				break
			var idx = randi() % random_dialogs.size()
			text = random_dialogs[idx]
			if idx < random_dialog_names.size():
				name = random_dialog_names[idx]
		else:
			if _dialog_index >= dialogs.size():
				break
			text = dialogs[_dialog_index]
			if _dialog_index < dialog_names.size():
				name = dialog_names[_dialog_index]
			if _dialog_index < dialog_styles.size():
				style = dialog_styles[_dialog_index]

		await _show_dialog(name, text, style)

		# advance index in sequential mode
		if _dialog_index >= 0:
			_dialog_index += 1

		# if we were in random mode only show one random and stop
		if _dialog_index == -1:
			break

	# finished all dialogs
	if fade_out:
		await _fade_out()
	hide()
	emit_signal("dialog_finished")

# --- show one dialog (awaits all paragraphs) ---
func _show_dialog(name: String, full_text: String, style: Dictionary) -> void:
	if name_label:
		name_label.visible = name != ""
		name_label.text = name

	if style and style.has("label_color"):
		label.add_theme_color_override("default_color", style["label_color"])
	if style and style.has("bubble_style") and panel:
		panel.add_theme_stylebox_override("panel", style["bubble_style"])
	if style and style.has("font_size") and label_settings:
		label_settings.font_size = style["font_size"]

	await _show_dialogs(full_text)

func _show_dialogs(full_text: String) -> void:
	# Split paragraphs by double newline (your original)
	_paragraphs = full_text.split("\n\n", false)
	_current = 0
	while _current < _paragraphs.size():
		await _display_one(_paragraphs[_current])
		_current += 1

# --- display a single paragraph, wait for player/timer to continue ---
func _display_one(text: String) -> void:
	_update_effect_params()

	if fade_in:
		await _fade_in()

	_typing_done = false
	_skip_requested = false
	_waiting_for_input = false

	label.clear()
	label.bbcode_enabled = true
	label.text = ""

	await _reveal_text(text)
	_typing_done = true

	# Wait up to 1.0s or until player presses accept (handled in _unhandled_input)
	_waiting_for_input = true
	var timer = get_tree().create_timer(1.0)
	while _waiting_for_input and timer.time_left > 0.0:
		await get_tree().process_frame
	# ensure waiting flag cleared
	_waiting_for_input = false

# --- reveal typing with skip handling ---
func _reveal_text(t: String) -> void:
	_update_effect_params()
	label.parse_bbcode(t)
	label.visible_characters = 0
	var total_chars = label.get_total_character_count()

	for i in range(total_chars + 1):
		if _skip_requested:
			# show full immediately
			label.visible_characters = -1
			_skip_requested = false
			break
		label.visible_characters = i
		# A small await per char — using timer allows consistent spacing
		await get_tree().create_timer(typing_speed).timeout

	# mark done
	label.visible_characters = -1
	_typing_done = true
	_skip_requested = false

# --- fades (unchanged behavior) ---
func _fade_in() -> void:
	if anim and anim.has_animation("fade_in"):
		anim.play("fade_in")
		await anim.animation_finished
	else:
		await _simple_fade(0.0, 1.0)

func _fade_out() -> void:
	if not _typing_done:
		# wait until current typing finishes/skip
		while not _typing_done:
			await get_tree().process_frame
	# brief flicker (optional)
	if label:
		for i in range(2):
			label.visible = false
			await get_tree().create_timer(0.04).timeout
			label.visible = true
			await get_tree().create_timer(0.04).timeout

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

# --- public helper to instantly finish typing of current paragraph ---
func finish_now() -> void:
	if not _typing_done:
		_skip_requested = true

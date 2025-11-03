extends Control


signal dialog_finished

@onready var label: RichTextLabel = %RichTextLabel
@onready var name_label: Label = %NameLabel
@onready var panel: PanelContainer = %PanelContainer
@onready var anim: AnimationPlayer = %AnimationPlayer

@export_group("Dialog Content")
@export var dialogs: Array[String] = []                # sequential dialogs
@export var dialog_names: Array[String] = []           # optional names
@export var dialog_styles: Array[Dictionary] = []      # per-dialog style overrides
@export var random_dialogs: Array[String] = []         # random pool
@export var random_dialog_names: Array[String] = []    # optional names/titles for randoms
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


var _paragraphs: PackedStringArray = []
var _current := 0
var _dialog_index := 0
var _wave_effect
var _shake_effect
var _rand_effect
var _typing_done := false

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
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		var random_phase := 0.0
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
		var s: float = clamp(1.0 + randf_range(-scale_amount, scale_amount), 0.8, 1.2)
		var tform := Transform2D()
		tform = tform.scaled(Vector2(s, s))
		char_fx.transform = tform
		return true

func _ready() -> void:
	await get_tree().process_frame
	_apply_style()

	if label:
		label.bbcode_enabled = true
		_install_inline_effects()

	connect("dialog_finished", Callable(self, "_on_dialog_finished"))
	start_dialog()

func _on_dialog_finished() -> void:
	await get_tree().create_timer(1.0).timeout

	_dialog_index += 1
	if _dialog_index < dialogs.size():
		start_dialog()
	else:
		await _fade_out()
		hide()

func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):
		if not _typing_done:
			_typing_done = true



func _rescale_to_viewport() -> void:
	# Keep scale proportional to viewport, relative to design width 1920px
	var viewport_size: Vector2 = get_viewport_rect().size
	var scale_factor: float = viewport_size.x / 1920.0
	scale = Vector2(scale_factor, scale_factor)



func _apply_style() -> void:
	if panel and bubble_style:
		panel.add_theme_stylebox_override("panel", bubble_style)
	if label and label_settings:
		label.label_settings = label_settings


func _install_inline_effects() -> void:
	_wave_effect = WaveEffect.new()
	_shake_effect = ShakeEffect.new()
	_rand_effect = RandScaleEffect.new()
	_update_effect_params()
	label.install_effect(_wave_effect)
	label.install_effect(_shake_effect)
	label.install_effect(_rand_effect)


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

func start_dialog(random: bool = false) -> void:
	if random and random_dialogs.size() > 0:
		var idx: int = randi() % random_dialogs.size()
		var text := random_dialogs[idx]
		var name := ""
		if idx < random_dialog_names.size():
			name = random_dialog_names[idx]
		_show_dialog(name, text, {})
		return

	if dialogs.is_empty():
		if random_dialogs.size() > 0:
			start_dialog(true)
		return

	if _dialog_index >= dialogs.size():
		emit_signal("dialog_finished")
		return

	var idx := _dialog_index
	var text := dialogs[idx]

	var name := ""
	if idx < dialog_names.size():
		name = dialog_names[idx]

	var style := {}
	if idx < dialog_styles.size():
		style = dialog_styles[idx]

	_show_dialog(name, text, style)

func _show_dialog(name: String, full_text: String, style: Dictionary) -> void:
	if name_label:
		name_label.visible = name != ""
		name_label.text = name

	if style.has("label_color") and label:
		label.add_theme_color_override("default_color", style["label_color"])
	if style.has("bubble_style") and panel:
		panel.add_theme_stylebox_override("panel", style["bubble_style"])
	if style.has("font_size") and label_settings:
		label_settings.font_size = style["font_size"]

	_show_dialogs(full_text)


func _show_dialogs(full_text: String) -> void:
	_paragraphs = full_text.split("\n\n", false)
	_current = 0
	await _display_next()


func _display_next() -> void:
	await get_tree().process_frame
	if _typing_done == false and _current > 0 and _current >= _paragraphs.size():
		return
	if _current >= _paragraphs.size():
		emit_signal("dialog_finished")
		return

	if fade_in:
		await _fade_in()

	_typing_done = false
	label.bbcode_enabled = true
	label.text = ""


	await _reveal_text(_paragraphs[_current])
	_typing_done = true

	await get_tree().create_timer(1.0).timeout

	_current += 1
	await _display_next()


func _reveal_text(t: String) -> void:
	_update_effect_params()
	label.bbcode_enabled = true
	label.clear()

	label.parse_bbcode(t)
	label.visible_characters = 0

	var total_chars := label.get_total_character_count()

	for i in range(total_chars + 1):
		if _typing_done:
			break

		label.visible_characters = i
		await get_tree().create_timer(typing_speed).timeout

	# When finished (naturally or skipped)
	label.visible_characters = -1
	_typing_done = true

# === Fades ===
func _fade_in() -> void:
	if anim and anim.has_animation("fade_in"):
		anim.play("fade_in")
		await anim.animation_finished
	else:
		await _simple_fade(0.0, 1.0)

func _fade_out() -> void:
	# Only start fading once text is done typing
	if not _typing_done:
		await wait_for_typing_done()
	# (rest of your flicker/fade code below)

	# Add a brief controlled flicker effect
	if label:
		for i in range(3):
			label.visible = false
			await get_tree().create_timer(0.05).timeout
			label.visible = true
			await get_tree().create_timer(0.05).timeout

	if anim and anim.has_animation("fade_out"):
		anim.play("fade_out")
		await anim.animation_finished
	else:
		await _simple_fade(1.0, 0.0)

func wait_for_typing_done() -> void:
	while not _typing_done:
		await get_tree().process_frame


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


# === Public helpers ===
func finish_now() -> void:
	if not _typing_done:
		label.visible_characters = -1
		_typing_done = true
		emit_signal("dialog_finished")

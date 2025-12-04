extends Node3D
class_name DialogBubble3D

signal dialog_finished

@export var dialog_text: String = "":
	set(value):
		dialog_text = value
		if dialog_ui:
			dialog_ui.set_text(value)

@export var viewport_base_size: Vector2i = Vector2i(512, 256)
@export var bubble_world_size: Vector2 = Vector2(1.0, 0.5)

# ─ Behaviour toggles ─
@export var auto_scale := true
@export_range(0.05, 3.0, 0.01) var scale_strength: float = 0.7

@export var floating := true
@export_range(0.0, 2.0, 0.01) var float_amplitude: float = 0.15
@export_range(0.1, 10.0, 0.1) var float_speed: float = 1.5

@export var follow := false
@export var follow_target: Node3D
@export_range(0.1, 20.0, 0.1) var follow_speed: float = 5.0
@export var follow_offset: Vector3 = Vector3(0, 2, 0)

@export_category("DialogBubble Settings")

@export var typing_speed: float = 0.03:
	set(value):
		typing_speed = value
		if dialog_ui:
			dialog_ui.typing_speed = value

@export var shake_intensity: float = 0.0:
	set(value):
		shake_intensity = value
		if dialog_ui:
			dialog_ui.global_shake_intensity = value

@export var label_settings: LabelSettings:
	set(value):
		label_settings = value
		if dialog_ui:
			dialog_ui.label_settings = value

@export var bubble_style: StyleBox:
	set(value):
		bubble_style = value
		if dialog_ui:
			dialog_ui.bubble_style = value

# Optional effect toggles for control from 3D
@export var enable_wave: bool = false:
	set(value):
		enable_wave = value
		if dialog_ui:
			dialog_ui.global_wave = value

@export var enable_random_scale: bool = false:
	set(value):
		enable_random_scale = value
		if dialog_ui:
			dialog_ui.global_random_scale = value

@export var enable_shake: bool = false:
	set(value):
		enable_shake = value
		if dialog_ui:
			dialog_ui.global_shake = value


# ─ Internals ─
var viewport: SubViewport
var sprite: Sprite3D
var dialog_ui: Control
var _base_y: float = 0.0
var _float_phase: float = 0.0

# ────────────────────────────────────────────────
func _ready() -> void:
	_create_viewport_and_sprite()
	_sync_size()
	_apply_forwarded_settings()
	_base_y = position.y

	if dialog_text != "":
		dialog_ui.set_text(dialog_text)

	# forward signal so DialogManager can use it
	if dialog_ui.has_signal("dialog_finished"):
		dialog_ui.dialog_finished.connect(func(): emit_signal("dialog_finished"))


func _create_viewport_and_sprite() -> void:
	if viewport:
		return # prevent duplicates

	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.size = viewport_base_size
	add_child(viewport)

	dialog_ui = preload("res://dialog_system/dialog_bubble.tscn").instantiate()
	viewport.add_child(dialog_ui)

	sprite = Sprite3D.new()
	sprite.texture = viewport.get_texture()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sprite)

	await get_tree().process_frame
	_sync_size()


func _process(delta: float) -> void:
	if not sprite:
		return

	if floating:
		_float_phase += delta * float_speed
		position.y = _base_y + sin(_float_phase) * float_amplitude

	if follow and follow_target:
		var target_pos: Vector3 = follow_target.global_position + follow_offset
		global_position = global_position.lerp(target_pos, delta * follow_speed)

	var cam: Camera3D = get_viewport().get_camera_3d()
	if not cam:
		return

	# Always face the camera
	look_at(cam.global_position, Vector3.UP)

	if auto_scale:
		var dist: float = global_position.distance_to(cam.global_position)
		var scale_factor: float = clamp((1.0 / dist) * scale_strength, 0.1, 2.0)
		scale = Vector3.ONE * scale_factor


func _sync_size() -> void:
	if not sprite:
		return
	var width: float = bubble_world_size.x
	var height: float = bubble_world_size.y
	sprite.scale = Vector3(width, height, 1.0)
	viewport.size = viewport_base_size


func _apply_forwarded_settings() -> void:
	if not dialog_ui:
		return

	dialog_ui.typing_speed = typing_speed
	dialog_ui.global_shake_intensity = shake_intensity
	dialog_ui.global_shake = enable_shake
	dialog_ui.global_wave = enable_wave
	dialog_ui.global_random_scale = enable_random_scale
	dialog_ui.label_settings = label_settings
	dialog_ui.bubble_style = bubble_style

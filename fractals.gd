@tool
extends Node2D   # works fine for Sprite2D or Sprite3D children

@export var shader_material: ShaderMaterial
@export_range(1, 2048, 1) var iterations: int = 256
@export_range(0.01, 10.0, 0.01) var zoom: float = 1.0
@export var mode: int = 0 # 0 = Mandelbrot, 1 = Burning Ship
@export var color_offset: Color = Color(0.4, 0.6, 0.8)

const FRACTAL_SHADER_PATH := "res://fractal_2d.gdshader"

func _ready():
	if Engine.is_editor_hint():
		set_process(true)
	_ensure_material()
	_push_params()

func _process(_delta: float) -> void:
	if shader_material:
		var res := Vector2(1024, 768)
		if get_viewport():
			res = get_viewport().get_visible_rect().size
		shader_material.set_shader_parameter("u_res", res)
	_push_params()

func _ensure_material():
	if shader_material:
		return
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload(FRACTAL_SHADER_PATH)

	# Auto-assign to common child nodes
	if has_node("Sprite2D"):
		$Sprite2D.material = shader_material
	elif has_node("Sprite3D"):
		$Sprite3D.material = shader_material

func _push_params():
	if not shader_material:
		return
	shader_material.set_shader_parameter("u_zoom", zoom)
	shader_material.set_shader_parameter("u_iter", iterations)
	shader_material.set_shader_parameter("u_mode", mode)
	shader_material.set_shader_parameter(
		"u_color_offset", Vector3(color_offset.r, color_offset.g, color_offset.b)
	)

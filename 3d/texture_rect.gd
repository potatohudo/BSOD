extends TextureRect

@export var max_glitches := 64
@export var min_width := 0.02
@export var max_width := 0.15
@export var min_count := 2
@export var max_count := 6
@export var keep_frames := 3

var shader_material: ShaderMaterial
var glitch_timer := 0
var current_glitch_y: Array[float] = []
var current_glitch_x: Array[float] = []
var current_glitch_w: Array[float] = []

func _ready():
	if material == null:
		push_error("Glitch generator: No material assigned to this TextureRect.")
		return

	shader_material = material as ShaderMaterial
	if shader_material == null:
		push_error("Glitch generator: Material is not a ShaderMaterial!")
		return

	print("Glitch generator active on:", self)

func _process(_delta):
	if shader_material == null:
		return

	glitch_timer -= 1
	if glitch_timer <= 0:
		_generate_glitches()
		glitch_timer = keep_frames

	shader_material.set_shader_parameter("glitch_count", current_glitch_y.size())
	shader_material.set_shader_parameter("glitch_y", current_glitch_y)
	shader_material.set_shader_parameter("glitch_x", current_glitch_x)
	shader_material.set_shader_parameter("glitch_w", current_glitch_w)

func _generate_glitches():
	current_glitch_y.clear()
	current_glitch_x.clear()
	current_glitch_w.clear()

	var tex: Texture2D = shader_material.get_shader_parameter("SCREEN_TEXTURE")
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	img.lock()

	var height: int = img.get_height()
	var width: int = img.get_width()
	var sample_step: int = 4

	var contrast_scores: Array[float] = []

	for y in range(0, height - sample_step, sample_step):
		var avg_contrast: float = 0.0
		for x in range(0, width, sample_step):
			var c1: Color = img.get_pixel(x, y)
			var c2: Color = img.get_pixel(x, y + sample_step)
			avg_contrast += sqrt(
				pow(c1.r - c2.r, 2) +
				pow(c1.g - c2.g, 2) +
				pow(c1.b - c2.b, 2)
			)
		avg_contrast /= float(width / sample_step)
		contrast_scores.append(avg_contrast)
	img.unlock()

	var max_c: float = contrast_scores.max()
	if max_c > 0.0:
		for i in range(contrast_scores.size()):
			contrast_scores[i] /= max_c

	var count: int = randi_range(min_count, max_count)
	count = clamp(count, 0, max_glitches)

	for i in range(count):
		var chosen_y_index: int = weighted_random_index(contrast_scores)
		var y_normalized: float = float(chosen_y_index * sample_step) / float(height)

		current_glitch_y.append(y_normalized)
		current_glitch_x.append(randf())
		current_glitch_w.append(randf_range(min_width, max_width))

func weighted_random_index(weights: Array[float]) -> int:
	var total: float = 0.0
	for w in weights:
		total += w
	var rnd: float = randf() * total
	var accum: float = 0.0
	for i in range(weights.size()):
		accum += weights[i]
		if rnd <= accum:
			return i
	return weights.size() - 1

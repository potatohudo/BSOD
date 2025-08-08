extends Node
#
### NodePath to the node that has your ShaderMaterial
#@export var shader_target: NodePath
### Max glitch strips allowed (shader arrays must be big enough)
#@export var max_glitches := 64
#
### Glitch settings
#@export var min_width := 0.02
#@export var max_width := 0.15
#@export var min_count := 2
#@export var max_count := 6
#@export var keep_frames := 3 # how many frames a set of glitches stays visible
#
#var shader_material: ShaderMaterial
#var glitch_timer := 0
#var current_glitch_y := []
#var current_glitch_x := []
#var current_glitch_w := []
#
#func _ready():
	#var target_node = get_node_or_null(shader_target)
	#if target_node == null:
		#push_error("Glitch generator: Target node not found! Check shader_target path.")
		#return
#
	## Try to get the material
	#shader_material = target_node.material as ShaderMaterial
	#if shader_material == null:
		#push_error("Glitch generator: No ShaderMaterial found on target node!")
		#return
#
	## Generate first glitch set
	#_generate_glitches()
#
#func _process(_delta):
	#if shader_material == null:
		#return
#
	#glitch_timer -= 1
	#if glitch_timer <= 0:
		#_generate_glitches()
		#glitch_timer = keep_frames
#
	#shader_material.set_shader_parameter("glitch_count", current_glitch_y.size())
	#shader_material.set_shader_parameter("glitch_y", current_glitch_y)
	#shader_material.set_shader_parameter("glitch_x", current_glitch_x)
	#shader_material.set_shader_parameter("glitch_w", current_glitch_w)
#
#func _generate_glitches():
	#current_glitch_y.clear()
	#current_glitch_x.clear()
	#current_glitch_w.clear()
#
	#if shader_material == null:
		#return
#
	## Get a small downsample of the screen from SCREEN_TEXTURE
	#var tex: Texture2D = shader_material.get_shader_parameter("SCREEN_TEXTURE")
	#if tex == null:
		#return
	#var img: Image = tex.get_image()
	#if img == null:
		#return
	#img.lock()
#
	#var height: int = img.get_height()
	#var width: int = img.get_width()
	#var sample_step: int = 4	# skip pixels for performance
#
	#var contrast_scores: Array[float] = []
#
	#for y in range(0, height - sample_step, sample_step):
		#var avg_contrast: float = 0.0
		#for x in range(0, width, sample_step):
			#var c1: Color = img.get_pixel(x, y)
			#var c2: Color = img.get_pixel(x, y + sample_step)
			#avg_contrast += c1.distance_to(c2)
		#avg_contrast /= float(width / sample_step)
		#contrast_scores.append(avg_contrast)
	#img.unlock()
#
	## Normalize contrast scores
	#var max_c: float = contrast_scores.max()
	#if max_c > 0.0:
		#for i in range(contrast_scores.size()):
			#contrast_scores[i] /= max_c
#
	#var count: int = randi_range(min_count, max_count)
	#count = clamp(count, 0, max_glitches)
#
	#for i in range(count):
		## Pick a line weighted toward high-contrast rows
		#var chosen_y_index: int = weighted_random_index(contrast_scores)
		#var y_normalized: float = float(chosen_y_index * sample_step) / float(height)
#
		#current_glitch_y.append(y_normalized)
		#current_glitch_x.append(randf()) # start X
		#current_glitch_w.append(randf_range(min_width, max_width))
#
#
#func weighted_random_index(weights: Array[float]) -> int:
	#var total: float = 0.0
	#for w in weights:
		#total += w
	#var rnd: float = randf() * total
	#var accum: float = 0.0
	#for i in range(weights.size()):
		#accum += weights[i]
		#if rnd <= accum:
			#return i
	#return weights.size() - 1

extends Control

@onready var fps_label: Label = $FPS
@onready var cpu_label: Label = $CPU
@onready var gpu_label: Label = $GPU
@onready var mem_label: Label = $Memory
@onready var hardware_label: Label = $Hardware


var min_fps: int = 9999
var max_fps: int = 0
var show_detailed := false

const HISTORY_NUM_FRAMES := 150
var frame_times_total: Array[float] = []
var frame_times_cpu: Array[float] = []
var frame_times_gpu: Array[float] = []
var last_tick := 0
var update_timer := 0.0

func _enter_tree() -> void:
	# Enable CPU/GPU timing as soon as the viewport exists
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)

func _ready() -> void:
	last_tick = Time.get_ticks_usec()
	cpu_label.visible = true
	gpu_label.visible = true
	mem_label.visible = false
	hardware_label.visible = false

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer < 1.0:
		return
	update_timer = 0.0

	$Speed.text = (str(round($"../SubViewportContainer/SubViewport/Node3D/CharacterBody3D".speed)))
	var fps := Engine.get_frames_per_second()
	if fps < min_fps:
		min_fps = fps
	if fps > max_fps:
		max_fps = fps

	var frametime_ms := (Time.get_ticks_usec() - last_tick) * 0.001
	last_tick = Time.get_ticks_usec()
	frame_times_total.push_back(frametime_ms)
	if frame_times_total.size() > HISTORY_NUM_FRAMES:
		frame_times_total.pop_front()

	var viewport_rid := get_viewport().get_viewport_rid()
	var frametime_cpu := (RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu()) * 1000.0
	frame_times_cpu.push_back(frametime_cpu)
	if frame_times_cpu.size() > HISTORY_NUM_FRAMES:
		frame_times_cpu.pop_front()

	var frametime_gpu := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid) * 1000.0
	frame_times_gpu.push_back(frametime_gpu)
	if frame_times_gpu.size() > HISTORY_NUM_FRAMES:
		frame_times_gpu.pop_front()

	if show_detailed:
		fps_label.text = "FPS: %d | Min: %d | Max: %d" % [fps, min_fps, max_fps]
	else:
		fps_label.text = "FPS: %d" % fps

	var avg_total := _avg(frame_times_total)
	var avg_cpu := _avg(frame_times_cpu)
	var avg_gpu := _avg(frame_times_gpu)

	var cpu_percent: float = (avg_cpu / avg_total) * 100.0 if avg_total > 0.0 else 0.0
	var gpu_percent: float = (avg_gpu / avg_total) * 100.0 if avg_total > 0.0 else 0.0

	if show_detailed:
		cpu_label.text = "CPU: %.1f%% | Avg=%.2f ms | Last=%.2f ms" % [cpu_percent, avg_cpu, frametime_cpu]
		gpu_label.text = "GPU: %.1f%% | Avg=%.2f ms | Last=%.2f ms" % [gpu_percent, avg_gpu, frametime_gpu]

		var static_mem: float = float(Performance.get_monitor(Performance.MEMORY_STATIC))
		var static_max: float = float(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
		mem_label.text = "Memory: %.1f MB / %.1f MB" % [static_mem / 1048576.0, static_max / 1048576.0]

		hardware_label.text = "OS: %s | CPU: %s (%d cores)" % [
			OS.get_name(),
			OS.get_processor_name(),
			OS.get_processor_count()
		]
	else:
		cpu_label.text = "CPU: %.1f%%" % cpu_percent
		gpu_label.text = "GPU: %.1f%%" % gpu_percent

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dbg"):
		show_detailed = !show_detailed
		mem_label.visible = show_detailed
		hardware_label.visible = show_detailed

func _avg(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	return arr.reduce(func(accum: float, val: float) -> float: return accum + val) / arr.size()

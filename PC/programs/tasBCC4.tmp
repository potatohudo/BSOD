extends Control

#every second-or-so it checks the task list in ../explorrer and visualizes it accordingly.


@onready var task_list = $"ScrollContainer/Tasklist"
@onready var kill_button = $"AspectRatioContainer/KillButton"

var tasks := {}
var usage = Vector2(100, 110)

func get_usage() -> Vector2:
	return usage

var update_interval := 1.5
var selected_task_name: String = ""

var update_timer: Timer = null
var explorer : Control = null  # reference to Explorer


func _ready():
	randomize()

	
	explorer = get_tree().get_root().get_node("/root/Main/SubViewportContainer/SubViewport/Explorer")  # e.g. "/root/Main/Explorer"
	if not explorer:
		push_error("Explorer node not found!")
	
	_start_update_timer()
	
	kill_button.pressed.connect(func():
		if selected_task_name != "":
			_on_end_task_pressed(selected_task_name)
	)

func _start_update_timer():
	update_timer = Timer.new()
	update_timer.wait_time = update_interval
	update_timer.timeout.connect(_sync_task_list)
	update_timer.autostart = true
	update_timer.one_shot = false
	add_child(update_timer)

func _sync_task_list():
	if not explorer:
		return

	var current_tasks: Dictionary = explorer.get_running_tasks()


	# Remove old tasks
	for name in tasks.keys():
		if not current_tasks.has(name):
			remove_task_entry(name)

	# Add new ones
	for task_info in current_tasks.values():
		if not tasks.has(task_info.name):
			add_task_entry(task_info)

	# Update CPU values
	_update_cpu_usage()

func add_task_entry(task_info: Dictionary):
	var hbox = HBoxContainer.new()
	hbox.name = task_info.name
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS

	var label = Label.new()
	label.text = task_info.name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var cpu_label = Label.new()
	cpu_label.name = "CPU"
	cpu_label.text = "%0.2f%%" % task_info.cpu
	cpu_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(cpu_label)

	# Make the whole row respond to clicks
	hbox.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select_task(task_info.name)
	)

	task_list.add_child(hbox)
	tasks[task_info.name] = hbox

func _select_task(name: String):
	# Clear old selection styles
	for task_name in tasks.keys():
		var row = tasks[task_name]
		row.remove_theme_color_override("panel")

	selected_task_name = name

	if tasks.has(name):
		tasks[name].add_theme_color_override("panel", Color(0.2, 0.4, 0.6, 0.4))  # subtle blue




func remove_task_entry(name: String):
	if tasks.has(name):
		tasks[name].queue_free()
		tasks.erase(name)


func _on_end_task_pressed(name: String):
	remove_task_entry(name)
	if explorer:
		if explorer.running_tasks.has(name):
			var info = explorer.running_tasks[name]
			if info.has("window") and info.window and is_instance_valid(info.window):
				info.window.queue_free()
		explorer.running_tasks.erase(name)

func _update_cpu_usage():
	if not explorer:
		return

	var current_tasks = explorer.get_running_tasks()

	for name in tasks.keys():
		if not current_tasks.has(name):
			continue

		var task_info = current_tasks[name]
		var range: Vector2 = task_info.get("usage", Vector2 (0.5, 3))

		if tasks[name].has_node("CPU"):
			var label = tasks[name].get_node("CPU")
			var new_val = randf_range(range.x, range.y)
			label.text = "%0.2f%%" % new_val

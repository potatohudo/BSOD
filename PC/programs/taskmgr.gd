extends Control

@onready var task_list = $"ScrollContainer/Tasklist"

var tasks := {}
var usage_range = Vector2(0.5, 10.0)
var update_interval := 1.5
var update_timer: Timer = null
var explorer : Control = null  # reference to Explorer

func _ready():
	randomize()

	# Look for the Explorer (assumes it's the parent or in scene tree)
	explorer = get_tree().get_root().get_node("/root/Main/SubViewportContainer/SubViewport/Explorer")  # e.g. "/root/Main/Explorer"
	if not explorer:
		push_error("Explorer node not found!")

	_start_update_timer()

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

	var label = Label.new()
	label.text = task_info.name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var cpu_label = Label.new()
	cpu_label.name = "CPU"
	cpu_label.text = "%0.2f%%" % task_info.cpu
	cpu_label.custom_minimum_size = Vector2(60, 0)
	hbox.add_child(cpu_label)

	var end_button = Button.new()
	end_button.text = "End"
	end_button.pressed.connect(func():
		_on_end_task_pressed(task_info.name)
	)
	hbox.add_child(end_button)

	task_list.add_child(hbox)
	tasks[task_info.name] = hbox

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
	for task in tasks.values():
		if task.has_node("CPU"):
			var label = task.get_node("CPU")
			var new_val = randf_range(usage_range.x, usage_range.y)
			label.text = "%0.2f%%" % new_val

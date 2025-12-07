extends Node

@export var meetings: Array[NodePath] = []
@export_multiline var walkaways: Array[String] = []# manager fallback walkaway texts (array of strings)
@export var walkaway_limit: int = 3

@export var character_nodes: Array[NodePath] = []# characters connected to this NPC

# Internal
var _current_bubble: Node = null
var _force_next: Node = null

var _pending_choice: String = "none"
var _meeting_counts := {}
var _pending_restart_bubble: Node = null
var _paused_bubble: Node = null

var _manager_walkaway_counts := {} 

var _local_walkaway_counts := {}


var _walkaway_queue := []
var _playing_walkaway := false

signal conversation_finished(npc_root: Node)
signal dialog_finished

var _running := false

var _paused_bubble_name: String = ""
var _pending_restart_name: String = ""


# Public API
func start_dialog(start_node: Node) -> void:
	if _running:
		push_warning("DialogManager already running a conversation.")
		return
	if start_node == null:
		push_warning("DialogManager.start_dialog(): start_node is null")
		return
	_running = true
	_pending_choice = "none"
	await _run_dialog_flow(start_node)
	_running = false
	emit_signal("conversation_finished", start_node.get_parent() if start_node.has_node("..") else start_node)

func provide_choice(choice: String) -> void:
	choice = choice.to_lower()
	if choice in ["yes", "no", "none", "walk_away"]:
		_pending_choice = choice
	else:
		push_warning("DialogManager.provide_choice(): invalid choice '%s'" % choice)

func start_conversation(npc_root: Node) -> void:
	if npc_root == null:
		push_warning("start_conversation: npc_root is null")
		return
	var key := str(npc_root.get_path())
	var count := 0
	if _meeting_counts.has(key):
		count = int(_meeting_counts[key])
	# try convention: child name "meeting_%d"
	var target_name := "meeting_%d" % count
	var candidate := npc_root.get_node_or_null(target_name)
	if candidate == null:
		# fallback: first child that has DialogBubble script
		for c in npc_root.get_children():
			if c is Node and "text" in c:
				candidate = c
				break
	if candidate == null:
		push_warning("start_conversation: no dialog node found under %s" % npc_root.name)
		return
	# increment meeting count
	_meeting_counts[key] = count + 1
	start_dialog(candidate)

# Internal flow

func _run_dialog_flow(start_node: Node) -> void:
	
	var current: Node = start_node
	if _force_next != null:
		current = _force_next
		_force_next = null

	while current != null:
		if not is_instance_valid(current):
			break
		if not current.has_method("show_dialog"):
			push_warning("DialogManager: Node %s has no show_dialog()" % current.name)
			break

		if current.has_method("set_character_nodes"):
			current.set_character_nodes(character_nodes)

		_current_bubble = current
		_hide_all_bubbles_except(current)
		print("FLOW: current =", current.name, " paused =", _paused_bubble, " pending_restart =", _pending_restart_bubble)

		if current.name == _paused_bubble_name:

			
			if current.has_method("play_return_text"):
				await current.play_return_text()
			_paused_bubble = null
			_pending_restart_bubble = null
	


		var res = await current.show_dialog()

		_current_bubble = null

		if res == "paused":
			_paused_bubble = current
			_pending_restart_bubble = current

			while _force_next == null and _running:
				# yield a frame to avoid busy loop
				await get_tree().process_frame
			# honor forced next if set
			if _force_next != null:
				current = _force_next
				_force_next = null
				continue
			# otherwise, break
			break

		# If an interrupt requested a forced next bubble, honor it immediately
		if _force_next != null:
			current = _force_next
			_force_next = null
			continue

		# normal flow: optional wait_time already handled per-bubble earlier
		var choice := _pending_choice
		_pending_choice = "none"

		var next = _decide_next_node(current, choice)

		# If a NodePath was returned, try several resolution bases:
		if typeof(next) == TYPE_NODE_PATH:
			# 1) resolve relative to current bubble (most likely)
			var resolved := _resolve_path_from(current, next)
			# 2) fallback: resolve relative to manager's parent (NPC root)
			if resolved == null:
				resolved = _resolve_path_from(get_parent(), next)
			# 3) finally: absolute root (handled inside helper)
			current = resolved
		elif typeof(next) == TYPE_OBJECT and next is Node:
			current = next
		else:
			current = null

	# finished chain
	_running = false
	

func _hide_all_bubbles_except(b: Node) -> void:
	for c in get_children():
		if c is Control:  # assuming dialogbubbles are Controls
			c.visible = (c == b)

# Decide next node given current dialog node and a choice string
func _decide_next_node(current: Node, choice: String):
	if choice == "walk_away":
		if "walk_away" in current and current.walk_away != NodePath(""):
			return current.walk_away
		return null

	if choice == "yes":
		if "next_yes" in current and current.next_yes != NodePath(""):
			return current.next_yes
		return null

	if choice == "no":
		if "next_no" in current and current.next_no != NodePath(""):
			return current.next_no
		return null

	# none (default) -> choose from next_none array
	if "next_none" in current:
		var arr = current.next_none
		if arr == null or arr.size() == 0:
			return null

		var valid := []
		for p in arr:
			if p != null and str(p) != "" and p != NodePath(""):
				valid.append(p)
		if valid.size() == 0:
			return null

		var random_mode := false
		if "next_none_random" in current:
			random_mode = bool(current.next_none_random)

		# Use GDScript conditional expression (a if cond else b)
		return valid[randi() % valid.size()] if random_mode else valid[0]

	return null

# Resolve NodePath relative to a source node, tries current node first then absolute
func _resolve_path_from(source: Node, path) -> Node:
	# Accept NodePath, String or Node
	if path == null:
		return null

	# If it's already a Node, return if valid
	if typeof(path) == TYPE_OBJECT and path is Node:
		return path if is_instance_valid(path) else null

	# If it's a NodePath variant
	if typeof(path) == TYPE_NODE_PATH:
		if path == NodePath("") or str(path) == "":
			return null
		# try relative to source (preferred)
		var n := source.get_node_or_null(path)
		if n:
			return n
		# try absolute via scene root
		n = get_tree().get_root().get_node_or_null(path)
		if n:
			return n
		return null

	# If it's a plain String that looks like a path, try converting
	if typeof(path) == TYPE_STRING:
		var s := str(path).strip_edges()
		if s == "":
			return null
		var np := NodePath(s)
		var n2 := source.get_node_or_null(np)
		if n2:
			return n2
		n2 = get_tree().get_root().get_node_or_null(np)
		return n2

	return null

# Meeting helpers (unchanged)
func _get_meeting_index() -> int:
	var key := str(get_parent().get_path())
	if not _meeting_counts.has(key):
		_meeting_counts[key] = 0
	return _meeting_counts[key]

func _get_meeting_dialog(index: int) -> Node:
	# index out of bounds -> null
	if index < 0 or index >= meetings.size():
		return null

	var entry = meetings[index]

	# Try to resolve via helper (handles Node, NodePath, String)
	var node := _resolve_path_from(self, entry)
	if node:
		return node

	# If resolution failed, emit a helpful warning with the raw entry type/value
	var typ := typeof(entry)
	push_warning("DialogManager: meeting[%d] could not be resolved (type=%s, value=%s)." % [index, str(typ), str(entry)])
	return null

# Walkaway queue & playback

func _enqueue_walkaway(texts: Array, template: Node, npc_key: String, use_manager_count: bool, bubble_key: String) -> void:
	if texts == null or texts.size() == 0:
		return
	_walkaway_queue.append({
		"texts": texts.duplicate(true),
		"template": template,
		"npc_key": npc_key,
		"use_manager_count": use_manager_count,
		"bubble_key": bubble_key
	})
	# start processing if not already
	if not _playing_walkaway:
		call_deferred("_process_walkaway_queue")

# Internal: process the queue (plays sequentially)
func _process_walkaway_queue() -> void:
	if _playing_walkaway:
		return
	_playing_walkaway = true
	while _walkaway_queue.size() > 0:
		var entry = _walkaway_queue.pop_front()
		var texts: Array = entry.texts
		var template: Node = entry.template
		var npc_key: String = entry.npc_key
		var use_manager_count: bool = entry.use_manager_count
		var bubble_key: String = entry.bubble_key

		# Decide which index to play (queue behavior)
		var idx := 0
		if use_manager_count:
			if not _manager_walkaway_counts.has(npc_key):
				_manager_walkaway_counts[npc_key] = 0
			idx = _manager_walkaway_counts[npc_key]
		else:
			if not _local_walkaway_counts.has(bubble_key):
				_local_walkaway_counts[bubble_key] = 0
			idx = _local_walkaway_counts[bubble_key]

		# clip to available texts
		var chosen_text := ""
		if idx >= 0 and idx < texts.size():
			chosen_text = texts[idx]
		else:
			# nothing left to play for this queue entry; skip
			continue

		if is_instance_valid(template):
			var temp := template.duplicate()
			add_child(temp)
			temp.name = "%s_walkaway_temp" % template.name

			# set its text to single-line
			if temp.has_method("play_quick_text"):
				var arr: Array[String] = []
				arr.append(str(chosen_text))   
				await temp.play_quick_text(arr)

			else:
				if "text" in temp:
					var original_text = temp.text.duplicate(true)
					temp.text = [chosen_text]
					await temp.show_dialog()
					temp.text = original_text
				else:
					pass
			if is_instance_valid(temp):
				temp.queue_free()
		else:
			pass

		# Increment the counters we used
		if use_manager_count:
			_manager_walkaway_counts[npc_key] = _manager_walkaway_counts[npc_key] + 1
			if walkaway_limit > 0 and _manager_walkaway_counts[npc_key] >= walkaway_limit:
				pass
		else:
			_local_walkaway_counts[bubble_key] = _local_walkaway_counts[bubble_key] + 1

	_playing_walkaway = false

func _npc_key_for_node(n: Node) -> String:
	if n == null:
		return ""
	var parent_npc := n.get_parent()
	return str(parent_npc.get_path()) if parent_npc else str(n.get_path())

# Interaction 

func _on_area_3d_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# If no conversation running → start normally
	if not _running:
		var index := _get_meeting_index()
		var start_bubble := _get_meeting_dialog(index)
		if start_bubble:
			_running = true
			var npc_key := _npc_key_for_node(start_bubble)
			_manager_walkaway_counts[npc_key] = 0
			_walkaway_queue.clear()
			_playing_walkaway = false
			await _run_dialog_flow(start_bubble)
		return

	if _pending_restart_name != "":
		var candidate = _find_bubble_by_name(_pending_restart_name)
		if candidate:
			_force_next = candidate
		_pending_restart_name = ""
		print("ENTER → pending restart:", _pending_restart_bubble, " force_next:", _force_next)
		return
		
func _find_bubble_by_name(name: String) -> Node:
	for c in get_children():
		if c is Control and c.name == name:
			return c
	return null


func _on_area_3d_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not _running:
		return

	if _current_bubble and _current_bubble.has_method("pause_dialog"):
		_current_bubble.pause_dialog()
		_paused_bubble = _current_bubble
		_paused_bubble_name = _current_bubble.name
		_pending_restart_name = _current_bubble.name


	var texts_to_use: Array = []
	var use_manager_count := true
	var bubble_key := ""
	var npc_key := _npc_key_for_node(_current_bubble)

	if _current_bubble:
		bubble_key = str(_current_bubble.get_path())
		# prefer bubble walkaway_texts if present
		if "walkaway_texts" in _current_bubble and _current_bubble.walkaway_texts and _current_bubble.walkaway_texts.size() > 0:
			texts_to_use = _current_bubble.walkaway_texts
			use_manager_count = false if not bool(_current_bubble.walkaway_replace) else true
			use_manager_count = bool(_current_bubble.walkaway_replace)
		else:
			# manager fallback
			if walkaways and walkaways.size() > 0:
				texts_to_use = walkaways
				use_manager_count = true
			else:
				texts_to_use = []

	if texts_to_use and texts_to_use.size() > 0:
		_enqueue_walkaway(texts_to_use, _current_bubble, npc_key, use_manager_count, bubble_key)
	else:
		pass

func get_manager_walkaway_count_for(npc_root: Node) -> int:
	var key := str(npc_root.get_path())
	return _manager_walkaway_counts.get(key, 0)


# Helpers for walkaway

func enqueue_walkaway_for_bubble(bubble_node: Node) -> void:
	if not bubble_node:
		return
	var npc_key := _npc_key_for_node(bubble_node)
	var bubble_key := str(bubble_node.get_path())
	var texts_to_use := []
	var use_manager_count := true
	if "walkaway_texts" in bubble_node and bubble_node.walkaway_texts and bubble_node.walkaway_texts.size() > 0:
		texts_to_use = bubble_node.walkaway_texts
		use_manager_count = bool(bubble_node.walkaway_replace)
	else:
		texts_to_use = walkaways
		use_manager_count = true
	_enqueue_walkaway(texts_to_use, bubble_node, npc_key, use_manager_count, bubble_key)

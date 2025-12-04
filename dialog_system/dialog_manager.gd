extends Node
# DialogManager.gd
# Single manager (make it an autoload or place it under a central scene).
# Responsibilities:
# - Start conversations given a starting DialogBubble node
# - Wait for DialogBubble to finish
# - Decide next DialogBubble node based on per-node exports:
#     next_yes, next_no, next_none (queue/random), walk_away, wait_time
# - Ignore empty NodePaths
# - Track meeting counts per NPC (keyed by parent path)
# - Provide API to receive player choices (yes/no/walk_away/none)
# - Minimal automatic meeting selection convention (see comments)

@export var meetings: Array[NodePath] = []# meeting[0], meeting[1], meeting[2]...
@export var walkaways: Array[NodePath] = []# walkaways[0], walkaways[1], ...
@export var walkaway_limit: int = 3

@export var character_nodes: Array[NodePath] = []# characters connected to this NPC
var _current_bubble: Node = null
var _force_next: Node = null

var _return_timer = null
var _paused_bubble: Node = null
var _pause_time := 0.0


signal conversation_finished(npc_root: Node)
signal dialog_finished

# pending choice provided by the player (or external system).
# Expected values: "yes", "no", "none", "walk_away"
var _pending_choice: String = "none"

# meeting counts: keyed by NPC parent path (String), value = int
var _meeting_counts := {}
var _pending_restart_bubble: Node = null

# internal guard
var _running := false

# Public API:
# Call this to start a dialog flow given a DialogBubble node (start_node).
# start_node should be the DialogBubble node to present first.
# This method returns after the whole chain (until no next node) finishes.
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
	

# External systems (player nod/shake) call this method to supply a choice.
# e.g. DialogManager.provide_choice("yes")
func provide_choice(choice: String) -> void:
	choice = choice.to_lower()
	if choice in ["yes", "no", "none", "walk_away"]:
		_pending_choice = choice
	else:
		push_warning("DialogManager.provide_choice(): invalid choice '%s'" % choice)

# Utility: Start conversation by NPC root node.
# Convention-based: tries to find meeting nodes under npc_root by names "meeting_0", "meeting_1", etc.
# If none found, it will try to find first child with DialogBubble script attached.
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

# ----------------------------
# Internal flow
# ----------------------------
func _start_dialog_flow(start_node: Node) -> void:
	await _run_dialog_flow(start_node)
	_running = false

	var parent_npc := get_parent()
	var key := str(parent_npc.get_path())
	_meeting_counts[key] += 1



func _run_dialog_flow(start_node: Node) -> void:
	var current: Node = start_node
		# If a forced next bubble was requested externally (e.g. player returned), honor it immediately
	if _force_next != null:
		current = _force_next
		_force_next = null

	while current != null:
		if not is_instance_valid(current):
			break
		if not current.has_method("show_dialog"):
			push_warning("DialogManager: Node %s has no show_dialog()" % current.name)
			break

		# give manager character_nodes to the bubble if it exposes setter
		if current.has_method("set_character_nodes"):
			current.set_character_nodes(character_nodes)

		# make this bubble the current one (used for interrupts)
		_current_bubble = current
		_hide_all_bubbles_except(current)

		# If this bubble was the paused one we intend to restart, play its return_text first.
		if current == _paused_bubble:
			if current.has_method("play_return_text"):
				await current.play_return_text()
			# clear pause marker (we will fully restart it now)
			_paused_bubble = null

		# Show dialog and wait. If interrupted, finish_now() will return early.
		# For a restarted bubble this will start it from the beginning.
		await current.show_dialog()


		# clear current
		_current_bubble = null

		# If an interrupt requested a forced next bubble, honor it immediately
		if _force_next != null:
			current = _force_next
			_force_next = null
			continue

		var wt := 0.0
		if "wait_time" in current:
			wt = float(current.wait_time)
		if wt > 0.0:
			await get_tree().create_timer(wt).timeout

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


var _walkaway_count := 0

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



func _get_walkaway_dialog() -> Node:
	for p in walkaways:
		if p != NodePath(""):
			var n := get_parent().get_node_or_null(p)
			if n: return n
	return null

func _interrupt_and_switch_to(bubble: Node) -> void:
	# Immediately finish current dialog so manager continues and uses _force_next
	_force_next = bubble
	if _current_bubble and _current_bubble.has_method("finish_now"):
		_current_bubble.finish_now()

func _interrupt_and_stop() -> void:
	_force_next = null
	if _current_bubble and _current_bubble.has_method("finish_now"):
		_current_bubble.finish_now()

func _on_area_3d_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	# If no conversation running → start normally
	if not _running:
		var index := _get_meeting_index()
		var start_bubble := _get_meeting_dialog(index)
		if start_bubble:
			_running = true
			_walkaway_count = 0
			await _start_dialog_flow(start_bubble)
		return

	# If we have a pending restart bubble (paused earlier), request the manager to go back to it
	if _pending_restart_bubble:
		_force_next = _pending_restart_bubble
		_pending_restart_bubble = null
		# manager will honor _force_next immediately after current bubble finishes




func _on_area_3d_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not _running:
		return

	# PAUSE current bubble (so it stops and hides)
	if _current_bubble and _current_bubble.has_method("pause_dialog"):
		_current_bubble.pause_dialog()
		_paused_bubble = _current_bubble
		# mark it as the one we should restart when player returns
		_pending_restart_bubble = _paused_bubble

	# Play WALKAWAY bubble immediately (bubble-specific first, then manager fallback)
	var bubble: Node = null
	if _current_bubble and "walk_away" in _current_bubble and _current_bubble.walk_away != NodePath(""):
		bubble = _resolve_path_from(self, _current_bubble.walk_away)
	if bubble == null:
		bubble = _get_walkaway_dialog()

	if bubble:
		# Immediately play the walkaway dialog NOW
		# Do NOT merge it into the main dialog chain
		_hide_all_bubbles_except(bubble)
		await bubble.show_dialog()
	else:
		_interrupt_and_stop()



	# START the 10-second return timer
	#_start_return_timer()
#
#func _start_return_timer() -> void:
	#if _return_timer:
		#_return_timer.time_left = 0.0
	#_return_timer = get_tree().create_timer(10.0)

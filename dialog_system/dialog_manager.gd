extends Node
signal player_nodded
signal player_shook_head

func connect_player(player):
	player.connect("nodded", Callable(self, "_on_player_nodded"))
	player.connect("shook_head", Callable(self, "_on_player_shook_head"))

func _on_player_nodded():
	emit_signal("player_nodded")

func _on_player_shook_head():
	emit_signal("player_shook_head")

extends Control

#@onready var animation_player = $AnimationPlayer




var subviewport_path: NodePath = "/root/Main/SubViewportContainer/SubViewport"

	

func play():
	visible = true
	var subviewport := get_node(subviewport_path) as SubViewport
	if subviewport:
		var tex := subviewport.get_texture()
		var material: ShaderMaterial = $Warp.material
		material.set_shader_parameter("warp_amount", 0)
		material.set_shader_parameter("SCREENSHOT", tex)
		var tween = get_tree().create_tween()
		tween.tween_property(material, "shader_parameter/warp_amount", 50, 4.0).set_trans(Tween.TRANS_CUBIC)
		#material.set_shader_parameter("warp_amount", 10)

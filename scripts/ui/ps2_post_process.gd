extends CanvasLayer
class_name PS2PostProcess
## Full-screen retro post-process (dithering, colour quantization, grain,
## scanlines, vignette). Sits below every other CanvasLayer (menus, HUD) so
## UI text stays crisp while the 3D view underneath gets the treatment.

func _ready() -> void:
	layer = -5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/materials/ps2_post.gdshader")
	rect.material = mat
	add_child(rect)

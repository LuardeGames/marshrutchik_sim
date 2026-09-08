extends RefCounted
class_name CityMaterials
## Shared world-space textures: no stretched UVs on batched buildings/roads.
static var _cache: Dictionary = {}

static func surface(kind: String) -> ShaderMaterial:
	if _cache.has(kind):
		return _cache[kind]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/materials/surface.gdshader")
	var colors := {"asphalt": Color("42464a"), "paving": Color("96958a"), "ground": Color("737b50"), "concrete": Color("b5b2a3")}
	mat.set_shader_parameter("tint", colors.get(kind, Color("b5b2a3")))
	mat.set_shader_parameter("paving", kind == "paving")
	mat.set_shader_parameter("variation", 0.24 if kind == "asphalt" else 0.12)
	_cache[kind] = mat
	return mat

static func facade(color: Color = Color("b8b3a3"), instanced: bool = false) -> ShaderMaterial:
	var key := "facade_%s_%s" % [color.to_html(), instanced]
	if _cache.has(key):
		return _cache[key]
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/materials/facade.gdshader")
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("instance_colors", instanced)
	_cache[key] = mat
	return mat

class_name CharMat
extends RefCounted
## Materiais realistas dos personagens: pele com rosto pintado, cabelo com brilho de
## fios, tecidos com trama e sheen, couro, metal e madeira. Cacheados quando possível.

const SKIN_SHADER := preload("res://src/resources/shaders/skin.gdshader")
const FACE_SHADER := preload("res://src/resources/shaders/face.gdshader")
const HAIR_SHADER := preload("res://src/resources/shaders/hair.gdshader")
const HAIR_SWAY_SHADER := preload("res://src/resources/shaders/hair_sway.gdshader")
const FABRIC_SHADER := preload("res://src/resources/shaders/fabric.gdshader")
const FABRIC_SWAY_SHADER := preload("res://src/resources/shaders/fabric_sway.gdshader")

static var _cache: Dictionary = {}


static func skin(color: Color) -> ShaderMaterial:
	var key := "skin|" + color.to_html()
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = SKIN_SHADER
		m.set_shader_parameter("skin", color)
		_cache[key] = m
	return _cache[key]


## Material único do rosto (cada personagem tem olhos, boca e sobrancelhas próprios).
static func face(color: Color, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FACE_SHADER
	m.set_shader_parameter("skin", color)
	m.set_shader_parameter("face_paint", 1.0)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func hair(color: Color, sway_amount: float = 1.0) -> ShaderMaterial:
	var key := "hair|%s|%f" % [color.to_html(), sway_amount]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = HAIR_SWAY_SHADER if sway_amount > 0.0 else HAIR_SHADER
		var l := color.get_luminance()
		m.set_shader_parameter("root_color", color.darkened(0.28 if l > 0.35 else 0.15))
		m.set_shader_parameter("tip_color", color.lightened(0.1 if l > 0.35 else 0.06))
		m.set_shader_parameter("spec_tint", Color(1.0, 0.96, 0.88).lerp(color.lightened(0.5), 0.4))
		m.set_shader_parameter("sway_amount", sway_amount)
		m.set_shader_parameter("shine", 1.0 if l > 0.2 else 0.7)
		_cache[key] = m
	return _cache[key]


## Tecido. opts: inner (cor do avesso), rough, sheen, weave, weave_strength, metal, grain,
## sway_top/sway_len (com eles o material balança: use só em peças da lista de pano).
static func fabric(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var key := "fab|%s|%s" % [color.to_html(), str(opts)]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = FABRIC_SWAY_SHADER if opts.has("sway_top") else FABRIC_SHADER
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("inner_color", Color(opts.get("inner", color.darkened(0.35))))
		m.set_shader_parameter("roughness", float(opts.get("rough", 0.86)))
		m.set_shader_parameter("metallic", float(opts.get("metal", 0.0)))
		m.set_shader_parameter("sheen", float(opts.get("sheen", 0.35)))
		m.set_shader_parameter("weave", float(opts.get("weave", 900.0)))
		m.set_shader_parameter("weave_strength", float(opts.get("weave_strength", 0.35)))
		m.set_shader_parameter("grain", float(opts.get("grain", 0.06)))
		m.set_shader_parameter("sway_top", float(opts.get("sway_top", 99.0)))
		m.set_shader_parameter("sway_len", float(opts.get("sway_len", 1.0)))
		m.set_shader_parameter("noise_tex", Toon.noise_texture())
		_cache[key] = m
	return _cache[key]


static func leather(color: Color, opts: Dictionary = {}) -> ShaderMaterial:
	var o := {"rough": 0.5, "sheen": 0.15, "weave": 2600.0, "weave_strength": 0.25, "grain": 0.16}
	o.merge(opts, true)
	return fabric(color, o)


static func metal(color: Color, rough: float = 0.28) -> StandardMaterial3D:
	var key := "metal|%s|%f" % [color.to_html(), rough]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.9
		m.roughness = rough
		m.metallic_specular = 0.6
		_cache[key] = m
	return _cache[key]


static func wood(color: Color) -> StandardMaterial3D:
	return Toon.mat(color, {"surface": "wood"})


static func glass(color: Color, alpha: float = 0.35) -> StandardMaterial3D:
	var key := "glass|%s|%f" % [color.to_html(), alpha]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 1.0
		m.rim_enabled = true
		m.rim = 0.4
		_cache[key] = m
	return _cache[key]

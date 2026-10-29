class_name Toon
extends RefCounted
## Fábrica de materiais em estilo cartoon (cel shading nativo + contorno invertido).
## Materiais são cacheados por cor/opções para reduzir trocas de estado na GPU.

const GRASS_SHADER := preload("res://src/resources/shaders/grass.gdshader")
const FOLIAGE_SHADER := preload("res://src/resources/shaders/foliage.gdshader")
const WATER_SHADER := preload("res://src/resources/shaders/water.gdshader")

static var _cache: Dictionary = {}


## Material cartoon básico. opts: rim (float), emission (float), outline (float), unshaded, alpha, metal
static func mat(color: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), str(opts)]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = float(opts.get("roughness", 0.85))
	m.metallic = float(opts.get("metal", 0.0))
	if opts.has("rim"):
		m.rim_enabled = true
		m.rim = float(opts.rim)
		m.rim_tint = 0.4
	if opts.has("emission"):
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = float(opts.emission)
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opts.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(opts.alpha)
	if opts.get("vertex_color", false):
		m.vertex_color_use_as_albedo = true
	if opts.get("double_sided", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if opts.has("outline"):
		m.next_pass = outline(Color(opts.get("outline_color", "#2a1d3a")), float(opts.outline))
	_cache[key] = m
	return m


## Contorno por casco invertido (desenhado como passe extra).
static func outline(color: Color, width: float) -> StandardMaterial3D:
	var key := "outline|%s|%f" % [color.to_html(), width]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.grow = true
	m.grow_amount = width
	_cache[key] = m
	return m


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	return mat(color, {"emission": energy, "unshaded": true})


static func translucent(color: Color, alpha: float, emission: float = 0.0) -> StandardMaterial3D:
	var opts := {"alpha": alpha, "unshaded": true}
	if emission > 0.0:
		opts["emission"] = emission
	return mat(color, opts)


static func vertex_colored(opts: Dictionary = {}) -> StandardMaterial3D:
	var o := opts.duplicate()
	o["vertex_color"] = true
	return mat(Color.WHITE, o)


static func grass() -> ShaderMaterial:
	if _cache.has("grass"):
		return _cache.grass
	var m := ShaderMaterial.new()
	m.shader = GRASS_SHADER
	_cache["grass"] = m
	return m


static func foliage() -> ShaderMaterial:
	if _cache.has("foliage"):
		return _cache.foliage
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	_cache["foliage"] = m
	return m


static func water() -> ShaderMaterial:
	# Cada superfície de água tem seu material (pode congelar independentemente).
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	return m

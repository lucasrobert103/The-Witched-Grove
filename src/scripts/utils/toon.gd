class_name Toon
extends RefCounted
## Fábrica de materiais do mundo. Visual realista estilizado: PBR (Burley + GGX),
## microdetalhe procedural em triplanar (relevo e variação de tom) conforme a
## superfície — madeira, pedra, reboco, telhado, folha, metal, terra, palha.
## (O nome "Toon" ficou por compatibilidade; o contorno cartoon foi aposentado.)
## Materiais são cacheados por cor/opções para reduzir trocas de estado na GPU.

const GRASS_SHADER := preload("res://src/resources/shaders/grass.gdshader")
const FOLIAGE_SHADER := preload("res://src/resources/shaders/foliage.gdshader")
const WATER_SHADER := preload("res://src/resources/shaders/water.gdshader")
const TERRAIN_SHADER := preload("res://src/resources/shaders/terrain.gdshader")

## surface → [escala triplanar, força do relevo, variação de tom, rugosidade]
const SURFACES := {
	"generic": [Vector3(3, 3, 3), 0.35, 0.12, 0.8],
	"wood": [Vector3(1.6, 9.0, 1.6), 0.6, 0.2, 0.78],
	"stone": [Vector3(1.4, 1.4, 1.4), 1.4, 0.32, 0.9],
	"plaster": [Vector3(2.2, 2.2, 2.2), 0.45, 0.16, 0.92],
	"roof": [Vector3(4.0, 7.0, 4.0), 1.2, 0.3, 0.85],
	"leaf": [Vector3(5.0, 5.0, 5.0), 1.1, 0.28, 0.7],
	"metal": [Vector3(6, 6, 6), 0.2, 0.06, 0.32],
	"soil": [Vector3(1.8, 1.8, 1.8), 1.0, 0.3, 0.95],
	"straw": [Vector3(2.0, 12.0, 2.0), 1.0, 0.35, 0.9],
	"cloth": [Vector3(14, 14, 14), 0.5, 0.1, 0.9],
	"ceramic": [Vector3(4, 4, 4), 0.15, 0.05, 0.25],
}

static var _cache: Dictionary = {}
static var _noise_tex: NoiseTexture2D
static var _noise_nrm: NoiseTexture2D
static var _noise_alb: Dictionary = {}


## Ruído contínuo (sem emendas) compartilhado por todos os materiais.
static func noise_texture() -> NoiseTexture2D:
	if _noise_tex == null:
		_noise_tex = _make_noise(false, false)
	return _noise_tex


static func _make_noise(as_normal: bool, as_albedo: bool, variation: float = 0.26) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.018
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 5
	n.seed = 31
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	t.generate_mipmaps = true
	if as_normal:
		t.as_normal_map = true
		t.bump_strength = 7.0
	if as_albedo:
		var g := Gradient.new()
		var lo := 1.0 - variation
		g.set_color(0, Color(lo, lo, lo))
		g.set_color(1, Color(1.0, 1.0, 1.0))
		t.color_ramp = g
	return t


static func _detail_normal() -> NoiseTexture2D:
	if _noise_nrm == null:
		_noise_nrm = _make_noise(true, false)
	return _noise_nrm


static func _detail_albedo(variation: float) -> NoiseTexture2D:
	var k := snappedf(variation, 0.02)
	if not _noise_alb.has(k):
		_noise_alb[k] = _make_noise(false, true, k)
	return _noise_alb[k]


## Material do mundo. opts: surface (ver SURFACES), rim, emission, unshaded, alpha, metal,
## roughness, vertex_color, double_sided. ("outline" é aceito e ignorado.)
static func mat(color: Color, opts: Dictionary = {}) -> StandardMaterial3D:
	var q := Settings.quality
	var key := "%s|%s|%d" % [color.to_html(), str(opts), q]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	var surf: String = opts.get("surface", "metal" if float(opts.get("metal", 0.0)) > 0.3 else "generic")
	var sd: Array = SURFACES.get(surf, SURFACES["generic"])
	m.roughness = float(opts.get("roughness", sd[3]))
	m.metallic = float(opts.get("metal", 0.0))
	if m.metallic > 0.0:
		m.metallic = maxf(m.metallic, 0.75)
		m.roughness = minf(m.roughness, 0.38)
	var unshaded: bool = opts.get("unshaded", false)
	if opts.has("rim") and not unshaded:
		m.rim_enabled = true
		m.rim = float(opts.rim) * 0.35
		m.rim_tint = 0.6
	if opts.has("emission"):
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = float(opts.emission)
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if opts.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = float(opts.alpha)
	if opts.get("vertex_color", false):
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
	if opts.get("double_sided", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# microdetalhe procedural (desligado na qualidade baixa e em materiais luminosos)
	var detail: bool = q > 0 and not unshaded and not opts.has("emission") and not opts.has("alpha") and surf != "none"
	if detail:
		m.uv1_triplanar = true
		m.uv1_scale = sd[0]
		m.uv1_triplanar_sharpness = 2.0
		m.normal_enabled = true
		m.normal_texture = _detail_normal()
		m.normal_scale = float(sd[1])
		if float(sd[2]) > 0.0 and not opts.get("vertex_color", false):
			var vari := float(sd[2])
			m.albedo_texture = _detail_albedo(vari)
			var gain := 1.0 / (1.0 - vari * 0.5)
			m.albedo_color = Color(minf(color.r * gain, 1.0), minf(color.g * gain, 1.0), minf(color.b * gain, 1.0), m.albedo_color.a)
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
	m.set_shader_parameter("noise_tex", noise_texture())
	_cache["grass"] = m
	return m


static func foliage() -> ShaderMaterial:
	if _cache.has("foliage"):
		return _cache.foliage
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	m.set_shader_parameter("noise_tex", noise_texture())
	_cache["foliage"] = m
	return m


static func terrain() -> ShaderMaterial:
	if _cache.has("terrain"):
		return _cache.terrain
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("noise_tex", noise_texture())
	m.set_shader_parameter("noise_nrm", _detail_normal())
	_cache["terrain"] = m
	return m


static func water() -> ShaderMaterial:
	# Cada superfície de água tem seu material (pode congelar independentemente).
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	return m

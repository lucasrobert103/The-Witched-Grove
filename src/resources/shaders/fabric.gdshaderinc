// Tecido e couro: trama fina em espaço de objeto, variação de tom, brilho de borda
// (sheen) e balanço da barra da saia/capa (sway por instância).

uniform vec3 color : source_color = vec3(0.45, 0.33, 0.25);
uniform vec3 inner_color : source_color = vec3(0.3, 0.12, 0.1);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float weave = 900.0;
uniform float weave_strength = 0.35;
uniform float sheen = 0.35;
uniform float grain = 0.06;
uniform float sway_top = 0.0;
uniform float sway_len = 1.0;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
#ifdef SWAY
instance uniform vec3 sway = vec3(0.0);
#else
const vec3 sway = vec3(0.0);
#endif

varying vec3 obj_p;

void vertex() {
	obj_p = VERTEX;
	float w = clamp((sway_top - VERTEX.y) / sway_len, 0.0, 1.0);
	VERTEX += sway * w * w;
}

void fragment() {
	vec3 p = obj_p;
	float n = texture(noise_tex, p.xz * 9.0 + p.y * 6.0).r * 0.6 + texture(noise_tex, p.xy * 1.3).r * 0.4;
	vec3 c = FRONT_FACING ? color : inner_color;
	c *= 1.0 - grain + grain * 2.0 * n;
	// trama: duas ondas cruzadas
	float wx = sin((p.x + p.z) * weave);
	float wy = sin(p.y * weave * 1.1);
	float wv = wx * wy;
	// some à distância (evita moiré)
	float ws = weave_strength * (1.0 - smoothstep(0.4, 1.6, fwidth(p.y * weave)));
	c *= 1.0 - ws * 0.08 * (wv * 0.5 + 0.5);
	ALBEDO = c;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL_MAP = vec3(0.5 + wx * 0.05 * ws, 0.5 + wy * 0.05 * ws, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	RIM = sheen;
	RIM_TINT = 0.6;
}

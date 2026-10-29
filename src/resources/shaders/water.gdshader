shader_type spatial;
// Água: ondulações em duas camadas (normal map procedural), reflexo do céu com
// fresnel, cor por profundidade (mais clara e transparente na margem), espuma onde
// encosta no fundo e modo "congelado" (gelo com rachaduras).
render_mode blend_mix, specular_schlick_ggx, cull_back, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.32, 0.62, 0.6, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.2, 0.3, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float frozen : hint_range(0.0, 1.0) = 0.0;
uniform float alpha = 0.82;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float waves(vec2 p, float t) {
	return noise(p * 0.9 + vec2(t * 0.12, t * 0.07)) * 0.6 + noise(p * 2.3 - vec2(t * 0.09, -t * 0.15)) * 0.3 + noise(p * 6.0 + vec2(t * 0.3, t * 0.2)) * 0.1;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(TIME * 1.3 + wpos.x * 0.7) * 0.018 + cos(TIME * 0.9 + wpos.z * 0.6) * 0.018;
	VERTEX.y += wave * (1.0 - frozen);
}

void fragment() {
	float t = TIME * (1.0 - frozen);
	// relevo das ondas por diferenças finitas
	vec2 p = wpos.xz;
	float e = 0.05;
	float h0 = waves(p, t);
	float hx = waves(p + vec2(e, 0.0), t);
	float hz = waves(p + vec2(0.0, e), t);
	vec2 slope = vec2(h0 - hx, h0 - hz) / e * 0.06 * (1.0 - frozen);
	// profundidade da água sob este pixel
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = clamp(-view.z - (-VERTEX.z), 0.0, 10.0);
	float shore = 1.0 - smoothstep(0.0, 1.4, water_depth);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(shore + h0 * 0.25, 0.0, 1.0));
	float foam = smoothstep(0.55, 0.0, water_depth) * smoothstep(0.35, 0.65, noise(p * 3.0 + vec2(t * 0.2, 0.0)));
	col = mix(col, foam_color.rgb, foam * 0.8 * (1.0 - frozen));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 ice = mix(vec3(0.72, 0.86, 0.95), vec3(0.93, 0.98, 1.0), noise(p * 2.5));
	float crack = smoothstep(0.02, 0.0, abs(noise(p * 1.7) - 0.5)) * 0.35;
	ice *= 1.0 - crack;
	col = mix(col, ice, frozen);
	ALBEDO = col;
	NORMAL_MAP = vec3(0.5 + slope.x, 0.5 + slope.y, 1.0);
	ROUGHNESS = mix(0.04, 0.35, frozen);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	ALPHA = mix(clamp(alpha * (0.55 + 0.45 * (1.0 - shore)) + fres * 0.3 + foam * 0.5, 0.0, 1.0), 0.97, frozen);
}

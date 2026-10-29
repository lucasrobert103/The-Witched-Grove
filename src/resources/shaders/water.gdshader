shader_type spatial;
// Água cartoon: manchas suaves, linhas de espuma animadas e modo "congelado".
render_mode blend_mix, specular_schlick_ggx, cull_back, depth_draw_opaque;

uniform vec4 shallow_color : source_color = vec4(0.42, 0.86, 0.9, 1.0);
uniform vec4 deep_color : source_color = vec4(0.14, 0.36, 0.62, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.98, 1.0, 1.0);
uniform float frozen : hint_range(0.0, 1.0) = 0.0;
uniform float alpha = 0.82;

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

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(TIME * 1.3 + wpos.x * 0.7) * 0.025 + cos(TIME * 0.9 + wpos.z * 0.6) * 0.025;
	VERTEX.y += wave * (1.0 - frozen);
}

void fragment() {
	float t = TIME * (1.0 - frozen);
	float n = noise(wpos.xz * 0.35 + vec2(t * 0.05, t * 0.03));
	float lines = smoothstep(0.64, 0.7, noise(wpos.xz * 1.1 + vec2(-t * 0.18, t * 0.11)));
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, n);
	col = mix(col, foam_color.rgb, lines * 0.55);
	vec3 ice = mix(vec3(0.78, 0.92, 1.0), vec3(0.95, 0.99, 1.0), noise(wpos.xz * 2.5));
	col = mix(col, ice, frozen);
	ALBEDO = col;
	ROUGHNESS = mix(0.15, 0.4, frozen);
	METALLIC = 0.0;
	ALPHA = mix(alpha, 0.97, frozen);
	EMISSION = col * 0.08;
}

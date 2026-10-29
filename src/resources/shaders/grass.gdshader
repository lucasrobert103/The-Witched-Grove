shader_type spatial;
// Grama com vento, translucidez (luz atravessando a lâmina), oclusão na base e
// manchas de cor em grande escala. Cor por instância (MultiMesh) em COLOR.
render_mode cull_disabled;

uniform float wind_strength = 0.14;
uniform float wind_speed = 1.5;
uniform vec3 tip_tint : source_color = vec3(1.1, 1.08, 0.78);
uniform vec3 base_tint : source_color = vec3(0.42, 0.52, 0.36);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying float h;
varying vec3 wp;

void vertex() {
	h = VERTEX.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = texture(noise_tex, wp.xz * 0.02 + vec2(TIME * 0.03, TIME * 0.02)).r;
	float w = sin(TIME * wind_speed + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(TIME * wind_speed * 2.3 + wp.x * 0.9 - wp.z * 0.4);
	w *= 0.6 + gust;
	VERTEX.x += w * wind_strength * h * h * 2.0;
	VERTEX.z += w * wind_strength * 0.6 * h * h * 2.0;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	float t = clamp(h * 2.0, 0.0, 1.0);
	float patch = texture(noise_tex, wp.xz * 0.035).r;
	vec3 c = to_linear(COLOR.rgb) * mix(base_tint, tip_tint, t);
	c *= mix(vec3(0.82, 0.86, 0.7), vec3(1.08, 1.04, 0.92), patch);
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.55 * t;
	AO = mix(0.45, 1.0, t);
	AO_LIGHT_AFFECT = 0.4;
}

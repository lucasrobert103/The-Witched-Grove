shader_type spatial;
// Grama estilizada com vento. Cor por instância (MultiMesh) em COLOR.
render_mode cull_disabled, diffuse_toon, specular_disabled;

uniform float wind_strength = 0.14;
uniform float wind_speed = 1.5;
uniform vec3 tip_tint : source_color = vec3(1.08, 1.08, 0.82);
uniform vec3 base_tint : source_color = vec3(0.62, 0.7, 0.55);

varying float h;

void vertex() {
	h = VERTEX.y;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(TIME * wind_speed + wp.x * 0.35 + wp.z * 0.27) + 0.5 * sin(TIME * wind_speed * 2.3 + wp.x * 0.9 - wp.z * 0.4);
	VERTEX.x += w * wind_strength * h;
	VERTEX.z += w * wind_strength * 0.6 * h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float t = clamp(h * 2.2, 0.0, 1.0);
	ALBEDO = COLOR.rgb * mix(base_tint, tip_tint, t);
	ROUGHNESS = 1.0;
}

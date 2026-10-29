shader_type spatial;
// Copas de árvore: tons por instância, leve balanço e brilho de borda (estilo cartoon).
render_mode diffuse_toon, specular_disabled;

uniform float sway = 0.05;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.7);
uniform float rim_amount = 0.35;
uniform float grey = 0.0;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 0.9 + wp.x * 0.21 + wp.z * 0.17);
	VERTEX.x += s * sway * max(VERTEX.y + 0.5, 0.0);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l * 0.9), grey);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color * pow(rim, 3.0) * rim_amount * (1.0 - grey);
}

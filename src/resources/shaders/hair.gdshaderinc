// Cabelo: fios finos ao longo da mecha (UV.y = raiz→ponta), gradiente da raiz à
// ponta e brilho anisotrópico duplo (Kajiya-Kay) que corre ao longo dos fios.
// "sway" (por instância, em espaço do modelo) balança as pontas.

uniform vec3 root_color : source_color = vec3(0.6, 0.45, 0.25);
uniform vec3 tip_color : source_color = vec3(0.9, 0.75, 0.48);
uniform vec3 spec_tint : source_color = vec3(1.0, 0.95, 0.85);
uniform float strand_freq = 70.0;
uniform float sway_amount = 1.0;
uniform float shine = 1.0;
#ifdef SWAY
instance uniform vec3 sway = vec3(0.0);
#else
const vec3 sway = vec3(0.0);
#endif

varying vec3 hair_t;

void vertex() {
	float v = UV.y;
	VERTEX += sway * v * v * sway_amount;
}

float hash(float x) {
	return fract(sin(x * 91.345) * 47453.5453);
}

void fragment() {
	float v = clamp(UV.y, 0.0, 1.0);
	float u = UV.x * strand_freq;
	float cell = floor(u);
	float f = fract(u);
	float strand = hash(cell) * 0.6 + 0.4 * sin(f * 3.14159);
	float fine = 0.5 + 0.5 * sin(UV.x * strand_freq * 3.7 + v * 6.0);
	vec3 c = mix(root_color, tip_color, smoothstep(0.0, 1.0, v));
	c *= 0.78 + 0.22 * strand * (0.8 + 0.2 * fine);
	// oclusão perto da raiz e nas laterais da mecha
	c *= mix(0.72, 1.0, smoothstep(0.0, 0.25, v));
	ALBEDO = c;
	ROUGHNESS = 0.45;
	hair_t = normalize(TANGENT) * (0.9 + 0.2 * strand);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.35) / 1.35, 0.0, 1.0);
	DIFFUSE_LIGHT += wrap * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	vec3 t1 = normalize(hair_t + NORMAL * 0.12);
	vec3 t2 = normalize(hair_t - NORMAL * 0.18);
	float th1 = dot(t1, h);
	float th2 = dot(t2, h);
	float s1 = pow(sqrt(max(1.0 - th1 * th1, 0.0)), 160.0) * 0.55;
	float s2 = pow(sqrt(max(1.0 - th2 * th2, 0.0)), 36.0) * 0.25;
	vec3 spec = spec_tint * s1 + ALBEDO * s2;
	SPECULAR_LIGHT += spec * shine * clamp(ndl + 0.2, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
}

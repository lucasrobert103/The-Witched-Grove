shader_type spatial;
// Terreno: cor por vértice (grama, terra das trilhas, areia, neve) enriquecida com
// manchas em grande escala, grão fino e relevo procedural em espaço do mundo.

uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_nrm : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// amostra triplanar (sem esticar em encostas)
float tri(vec3 p, float sc) {
	vec3 w = pow(abs(wn), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(noise_tex, p.zy * sc).r * w.x + texture(noise_tex, p.xz * sc).r * w.y + texture(noise_tex, p.xy * sc).r * w.z;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float big = texture(noise_tex, wp.xz * 0.018).r;
	float mid = tri(wp, 0.11);
	float fine = tri(wp, 0.9);
	float steep = 1.0 - smoothstep(0.55, 0.85, wn.y);
	float greenness = clamp((c.g - max(c.r, c.b)) * 6.0, 0.0, 1.0);
	// grama: manchas de tons quentes/frios; terra: grão
	vec3 warm = c * vec3(1.08, 1.02, 0.82);
	vec3 cool = c * vec3(0.84, 0.95, 0.9);
	c = mix(c, mix(cool, warm, big), 0.55 * greenness);
	c *= 0.86 + 0.22 * mid;
	c *= 0.9 + 0.2 * fine;
	ROUGHNESS = mix(0.95, 0.85, greenness);
	// rocha exposta nas encostas íngremes
	c = mix(c, c * (0.75 + 0.35 * fine), steep);
	ALBEDO = c;
	NORMAL_MAP = texture(noise_nrm, (abs(wn.y) > 0.6 ? wp.xz : (abs(wn.x) > abs(wn.z) ? wp.zy : wp.xy)) * 0.6).rgb;
	NORMAL_MAP_DEPTH = mix(mix(1.6, 0.8, greenness), 2.2, steep);
}

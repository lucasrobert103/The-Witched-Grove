shader_type spatial;
// Copas e arbustos: tufos de folhas (relevo e manchas por ruído em espaço do mundo),
// sombra interna, translucidez e balanço ao vento. "grey" = Silêncio Cinzento.

uniform float sway = 0.05;
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.7);
uniform float rim_amount = 0.06;
uniform float grey = 0.0;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying float up_ness;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = sin(TIME * 0.9 + origin.x * 0.21 + origin.z * 0.17);
	VERTEX.x += s * sway * max(VERTEX.y + 0.5, 0.0);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up_ness = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 1.6 + wpos.y * 0.9).r;
	float n2 = texture(noise_tex, wpos.xy * 2.7 + wpos.z * 0.5).r;
	float leaves = n1 * n2;
	vec3 c = to_linear(COLOR.rgb);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l * 0.9), grey);
	c *= 0.6 + leaves * 1.15;
	// interior e parte de baixo mais escuros
	float ao = mix(0.45, 1.0, smoothstep(-0.7, 0.8, up_ness));
	ALBEDO = c;
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
	AO = ao;
	AO_LIGHT_AFFECT = 0.5;
	NORMAL_MAP = vec3(0.5 + (n1 - 0.5) * 1.6, 0.5 + (n2 - 0.5) * 1.6, 1.0);
	NORMAL_MAP_DEPTH = 1.3;
	BACKLIGHT = c * 0.45;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = rim_color * pow(rim, 3.0) * rim_amount * (1.0 - grey);
}

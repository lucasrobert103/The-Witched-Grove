// Pele com dispersão subsuperficial falsa (luz que "atravessa" e avermelha o terminador)
// e rosto pintado em espaço de objeto: olhos de anime com íris em gradiente, pupila,
// brilhos, cílios, sobrancelhas, boca, blush e sardas. Piscar, olhar e falar por instância.

uniform vec3 skin : source_color = vec3(0.95, 0.8, 0.69);
uniform vec3 eye_color : source_color = vec3(0.79, 0.54, 0.23);
uniform vec3 brow_color : source_color = vec3(0.45, 0.33, 0.2);
uniform vec3 lash_color : source_color = vec3(0.16, 0.09, 0.06);
uniform vec3 lip_color : source_color = vec3(0.82, 0.45, 0.45);
uniform float face_paint = 0.0;        // 1 = malha da cabeça
uniform vec2 eye_center = vec2(0.03, 0.0);
uniform vec2 eye_half = vec2(0.017, 0.016);
uniform float eye_tilt = 0.12;
uniform float brow_y = 0.031;
uniform float brow_tilt = 0.0;
uniform float mouth_y = -0.06;
uniform float mouth_w = 0.0085;
uniform float blush = 0.35;
uniform float freckles = 0.0;
uniform float lash_weight = 1.0;
uniform float wrinkles = 0.0;
uniform float beard_shadow = 0.0;
uniform float sss = 0.55;
#ifdef FACE
instance uniform float blink = 0.0;
instance uniform float mouth_open = 0.0;
instance uniform vec2 look = vec2(0.0, 0.0);
#else
const float blink = 0.0;
const float mouth_open = 0.0;
const vec2 look = vec2(0.0, 0.0);
#endif

varying vec3 obj_p;
varying vec3 obj_n;

void vertex() {
	obj_p = VERTEX;
	obj_n = NORMAL;
}

float aa_step(float edge, float x) {
	float w = max(fwidth(x), 1e-5);
	return smoothstep(edge - w, edge + w, x);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Pinta um olho; devolve cor em rgb e cobertura em a.
vec4 eye(vec2 p, float side) {
	vec2 q = vec2((p.x - side * eye_center.x) * side, p.y - eye_center.y);
	float u = q.x / eye_half.x;
	float v = q.y / eye_half.y;
	float uu = clamp(u, -1.0, 1.0);
	float up_lid = 0.92 * pow(max(1.0 - uu * uu, 0.0), 0.55) + eye_tilt * uu;
	float lo_lid = -0.72 * pow(max(1.0 - uu * uu, 0.0), 0.75) + eye_tilt * 0.6 * uu;
	float b = clamp(blink, 0.0, 1.0);
	float lid = mix(up_lid, lo_lid + 0.05, b);
	vec4 o = vec4(0.0);
	float inside = aa_step(-1.0, -abs(u) * 1.0 + 0.0) * aa_step(lo_lid, v) * (1.0 - aa_step(lid, v));
	inside *= 1.0 - aa_step(1.0, abs(u));
	if (inside > 0.0) {
		vec3 white = mix(vec3(1.0, 0.99, 0.97), vec3(0.78, 0.8, 0.9), smoothstep(lid - 0.7, lid, v));
		// íris (elipse alta), deslocada pelo olhar
		vec2 ic = vec2(-0.05 + look.x * 0.35 * side, -0.08 + look.y * 0.3);
		vec2 d = vec2((u - ic.x) * eye_half.x, (v - ic.y) * eye_half.y) / eye_half.y;
		d.y /= 1.12;
		float r = length(d);
		float R = 0.8;
		vec3 c = white;
		float iris = 1.0 - aa_step(R, r);
		if (iris > 0.0) {
			float vy = d.y / R;
			vec3 top = eye_color * 0.32;
			vec3 bot = mix(eye_color * 1.45, vec3(1.0, 0.95, 0.75), 0.18);
			vec3 ic_col = mix(bot, top, smoothstep(-0.7, 0.75, vy));
			float ang = atan(d.y, d.x);
			ic_col *= 0.9 + 0.1 * sin(ang * 22.0 + r * 9.0);
			ic_col = mix(ic_col, eye_color * 0.25, smoothstep(0.78, 0.98, r / R));
			// pupila
			float pup = 1.0 - aa_step(0.3, length(d / vec2(0.85, 1.15)));
			ic_col = mix(ic_col, vec3(0.04, 0.025, 0.03), pup);
			// brilhos
			float h1 = 1.0 - aa_step(0.22, length(d - vec2(0.28 * side * -1.0 + 0.0, 0.36)));
			float h2 = 1.0 - aa_step(0.1, length(d - vec2(0.3, -0.42)));
			ic_col = mix(ic_col, vec3(1.0), max(h1, h2 * 0.85));
			c = mix(c, ic_col, iris);
		}
		// sombra da pálpebra superior
		c *= mix(1.0, 0.72, smoothstep(lid - 0.28, lid, v));
		o = vec4(c, inside);
	}
	// cílios superiores (linha grossa, engrossa no canto externo) e "asinha"
	float lw = (0.13 + 0.12 * smoothstep(-0.2, 1.0, u)) * lash_weight;
	float lash = (1.0 - aa_step(lw, abs(v - lid - lw * 0.55))) * (1.0 - aa_step(1.08, abs(u)));
	float wing_v = lid + 0.1 + (u - 0.85) * 0.9;
	float wing = (1.0 - aa_step(0.09 * lash_weight, abs(v - wing_v))) * aa_step(0.85, u) * (1.0 - aa_step(1.28, u));
	// cílio inferior discreto no canto externo
	float low = (1.0 - aa_step(0.05, abs(v - lo_lid + 0.04))) * aa_step(0.15, u) * (1.0 - aa_step(0.95, u)) * (1.0 - b);
	float l = max(max(lash, wing), low * 0.6);
	o.rgb = mix(o.rgb, lash_color, l);
	o.a = max(o.a, l);
	// dobra da pálpebra
	float crease = (1.0 - aa_step(0.035, abs(v - up_lid - 0.42 + 0.1 * uu * uu))) * (1.0 - aa_step(0.75, abs(u))) * (1.0 - b);
	o.rgb = mix(o.rgb, skin * 0.78, crease * (1.0 - o.a) * 0.6);
	o.a = max(o.a, crease * 0.35);
	return o;
}

vec4 brow(vec2 p, float side) {
	vec2 q = vec2((p.x - side * (eye_center.x + 0.002)) * side, p.y - brow_y);
	float u = q.x / (eye_half.x * 1.2);
	float y = 0.0025 * (1.0 - u * u) * 1.6 - brow_tilt * u * 0.004;
	float th = 0.0023 * (1.0 - smoothstep(-0.6, 1.1, u)) + 0.0009;
	float a = (1.0 - aa_step(th, abs(q.y - y))) * (1.0 - aa_step(1.0, abs(u)));
	return vec4(brow_color, a * 0.95);
}

void fragment() {
	vec3 col = skin;
	// variação sutil de tom (rosado nas extremidades)
	col = mix(col, col * vec3(1.02, 0.94, 0.92), 0.2 * smoothstep(0.02, 0.09, abs(obj_p.x)));
	float rough = 0.62;
	if (face_paint > 0.5 && obj_p.z < 0.0 && obj_n.z < -0.15) {
		vec2 p = obj_p.xy;
		float facing = smoothstep(-0.15, -0.45, obj_n.z);
		// blush
		for (int s = -1; s <= 1; s += 2) {
			vec2 bq = (p - vec2(float(s) * 0.044, -0.03)) / vec2(0.018, 0.008);
			col = mix(col, vec3(1.0, 0.5, 0.52), blush * 0.45 * exp(-dot(bq, bq)) * facing);
			if (freckles > 0.0) {
				vec2 g = floor((p - vec2(float(s) * 0.04, -0.03)) * 900.0);
				float f = step(0.86, hash(g)) * exp(-dot(bq * 0.8, bq * 0.8));
				col = mix(col, col * 0.62, f * freckles * facing);
			}
		}
		if (beard_shadow > 0.0) {
			col = mix(col, col * 0.78, beard_shadow * smoothstep(-0.055, -0.09, p.y) * facing);
		}
		if (wrinkles > 0.0) {
			float wr = sin(p.y * 900.0) * 0.5 + 0.5;
			col *= 1.0 - wrinkles * 0.08 * wr * smoothstep(0.02, 0.05, abs(p.x)) * smoothstep(0.03, 0.0, abs(p.y + 0.01)) * facing;
		}
		// boca
		float mx = p.x / mouth_w;
		float my = p.y - mouth_y;
		float smile = 0.0018 * mx * mx;
		float line = (1.0 - aa_step(0.0007 + 0.0004 * (1.0 - abs(mx)), abs(my - smile))) * (1.0 - aa_step(1.0, abs(mx)));
		float open = clamp(mouth_open, 0.0, 1.0);
		float oval = 1.0 - aa_step(1.0, length(vec2(mx * 0.8, (my + 0.002) / max(0.0001, 0.0045 * open))));
		col = mix(col, lip_color * 0.55, line * facing);
		col = mix(col, mix(vec3(0.35, 0.08, 0.1), vec3(0.85, 0.42, 0.45), smoothstep(0.0, -0.004, my + 0.002)), oval * open * facing);
		// sobrancelhas e olhos
		for (int s = -1; s <= 1; s += 2) {
			vec4 br = brow(p, float(s));
			col = mix(col, br.rgb, br.a * facing);
			vec4 e = eye(p, float(s));
			col = mix(col, e.rgb, e.a * facing);
			if (e.a > 0.5) {
				rough = 0.18;
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.5) / 1.5, 0.0, 1.0);
	float lam = clamp(ndl, 0.0, 1.0);
	vec3 scatter = vec3(1.0, 0.38, 0.28) * max(wrap - lam, 0.0) * sss;
	DIFFUSE_LIGHT += (vec3(lam) * 0.65 + vec3(wrap) * 0.35 + scatter) * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), mix(18.0, 120.0, 1.0 - ROUGHNESS)) * (1.0 - ROUGHNESS) * 0.6;
	SPECULAR_LIGHT += spec * lam * ATTENUATION * LIGHT_COLOR / PI;
}

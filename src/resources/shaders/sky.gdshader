shader_type sky;
// Céu estilizado: gradiente, sol, lua, estrelas cintilantes e faixas de nuvem.

uniform vec3 top_color : source_color = vec3(0.31, 0.62, 0.94);
uniform vec3 horizon_color : source_color = vec3(0.81, 0.91, 1.0);
uniform vec3 ground_color : source_color = vec3(0.25, 0.3, 0.32);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 moon_color : source_color = vec3(0.92, 0.94, 1.0);
uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);
uniform vec3 moon_dir = vec3(0.0, 0.7, 0.7);
uniform float sun_visible = 1.0;
uniform float moon_visible = 0.0;
uniform float moon_phase = 0.5;
uniform float star_intensity = 0.0;
uniform float cloud_amount = 0.5;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float t = clamp(d.y * 1.5, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(t, 0.55));
	if (d.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-d.y * 4.0, 0.0, 1.0));
	}
	// Estrelas
	if (star_intensity > 0.0 && d.y > 0.0) {
		vec3 p = d * 160.0;
		vec3 cell = floor(p);
		float h = hash3(cell);
		if (h > 0.985) {
			vec3 f = fract(p) - 0.5;
			float s = smoothstep(0.3, 0.0, length(f));
			float tw = 0.65 + 0.35 * sin(TIME * (2.0 + h * 4.0) + h * 80.0);
			col += vec3(1.0, 0.95, 0.85) * s * tw * star_intensity * clamp(d.y * 3.0, 0.0, 1.0);
		}
	}
	// Sol
	float sd = dot(d, normalize(sun_dir));
	col += sun_color * smoothstep(0.9985, 0.9993, sd) * sun_visible * 2.0;
	col += sun_color * pow(max(sd, 0.0), 24.0) * 0.35 * sun_visible;
	// Lua (com fase simples)
	vec3 md = normalize(moon_dir);
	float mdot = dot(d, md);
	float disc = smoothstep(0.9988, 0.9993, mdot);
	vec3 side = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
	float shade = smoothstep(-0.02, 0.02, dot(d - md, side) + (moon_phase - 0.5) * 0.07);
	col = mix(col, moon_color * mix(0.25, 1.0, shade), disc * moon_visible);
	col += moon_color * pow(max(mdot, 0.0), 80.0) * 0.25 * moon_visible;
	// Brilho do sol espalhado no horizonte (Mie)
	col += sun_color * pow(max(sd, 0.0), 6.0) * 0.12 * sun_visible * (1.0 - t * 0.6);
	// Nuvens volumosas (fbm) com base sombreada e borda iluminada pelo sol
	if (d.y > 0.0) {
		// projeção num "teto" de nuvens: perto do horizonte as nuvens somem na névoa
		vec2 uv = d.xz / max(d.y + 0.28, 0.3) * 1.1 + vec2(TIME * 0.004, TIME * 0.0015);
		float c = fbm(uv * 1.4);
		float lo = 0.7 - cloud_amount * 0.3;
		float cm = smoothstep(lo, lo + 0.22, c);
		float dens = fbm(uv * 1.4 + normalize(sun_dir).xz * 0.08);
		vec3 lit = cloud_color;
		vec3 shadow = cloud_color * vec3(0.7, 0.72, 0.8);
		vec3 cc = mix(lit, shadow, smoothstep(0.45, 0.85, dens) * 0.9);
		cc += sun_color * pow(max(sd, 0.0), 8.0) * 0.25 * sun_visible * (1.0 - cm);
		col = mix(col, cc, cm * 0.92 * smoothstep(0.06, 0.35, d.y));
	}
	COLOR = col;
}

shader_type spatial;

// Terreno del glaciar, todo en coordenadas de mundo (no necesita UV):
// - Caras de arriba: nieve con leve variación y brillitos que dependen de la vista.
// - Paredes: hielo con degradado por altura (azul profundo abajo, claro arriba),
//   vetas horizontales (estratos) y grietas finas.
// - Capa de nieve: el borde superior de cada pared se cubre de nieve.
//   `top_y` lo pone ice_formation.gd por instancia (altura de la cima).

uniform vec3 snow_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float snow_roughness = 0.82;
uniform vec3 ice_deep : source_color = vec3(0.06, 0.26, 0.48);
uniform vec3 ice_mid : source_color = vec3(0.30, 0.58, 0.82);
uniform vec3 ice_light : source_color = vec3(0.74, 0.88, 0.97);
uniform float ice_roughness = 0.18;
uniform float gradient_depth = 14.0;      // metros bajo la cima en que el hielo llega al azul profundo
uniform float band_frequency = 0.55;      // estratos por metro
uniform float band_strength = 0.22;
uniform float crack_strength = 0.22;
uniform float snow_cap = 0.7;             // grosor de la capa de nieve sobre el borde (m)
uniform float snow_slope = 0.6;           // normal.y desde la que una cara es "de arriba"
uniform float sparkle_density = 28.0;      // celdas de brillo por metro
uniform float sparkle_amount = 0.006;     // fracción de celdas que brillan
uniform float sparkle_strength = 1.6;
uniform float sparkle_distance = 14.0;
uniform float rim_strength = 0.35;

instance uniform float top_y = 10000.0;

varying vec3 wp;
varying vec3 wn;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p = p * 2.07 + vec3(3.1, 7.7, 1.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = fbm3(wp * 0.18);
	float fine = noise3(wp * 1.7);

	// Cuánto es nieve: caras de arriba + capa sobre el borde de las paredes.
	float top_amt = smoothstep(snow_slope - 0.1, snow_slope + 0.1, wn.y);
	float cap_edge = top_y - snow_cap * (0.6 + 0.8 * n);
	float cap_amt = smoothstep(cap_edge - 0.08, cap_edge + 0.08, wp.y);
	float snow = max(top_amt, cap_amt);

	// Hielo: degradado según lo lejos que está de la cima.
	float depth = clamp((top_y - wp.y) / gradient_depth + (n - 0.5) * 0.35, 0.0, 1.0);
	if (top_y > 9999.0) {
		depth = 0.5;
	}
	vec3 ice = mix(ice_light, ice_mid, smoothstep(0.0, 0.45, depth));
	ice = mix(ice, ice_deep, smoothstep(0.45, 1.0, depth));
	// Estratos: bandas horizontales onduladas.
	float bands = sin((wp.y + n * 2.5) * band_frequency * 6.2832) * 0.5 + 0.5;
	ice *= 1.0 - band_strength * pow(bands, 6.0);
	ice = mix(ice, ice_light, band_strength * 0.6 * pow(1.0 - bands, 10.0));
	// Grietas finas: líneas donde el ruido cruza 0.5.
	float crack = 1.0 - smoothstep(0.0, 0.025, abs(fbm3(wp * vec3(0.35, 0.9, 0.35)) - 0.5));
	ice = mix(ice, ice_deep * 0.7, crack * crack_strength);
	ice *= 0.92 + 0.16 * fine;

	vec3 snow_col = snow_color * (0.93 + 0.07 * n + 0.03 * fine);

	ALBEDO = mix(ice, snow_col, snow);
	ROUGHNESS = mix(ice_roughness + 0.15 * crack, snow_roughness, snow);
	SPECULAR = mix(0.65, 0.35, snow);
	RIM = rim_strength * (1.0 - snow);
	RIM_TINT = 0.8;

	// Brillitos de la nieve: celdas al azar que destellan según desde dónde se mira.
	vec3 wview = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	vec3 cell = floor(wp * sparkle_density);
	float r = hash3(cell + floor(wview * 6.0) * 13.0);
	float dist = length(wp - CAMERA_POSITION_WORLD);
	vec3 inner = fract(wp * sparkle_density) - 0.5;
	float dot_shape = 1.0 - smoothstep(0.12, 0.3, length(inner.xz));
	float glint = step(1.0 - sparkle_amount, r) * dot_shape * (1.0 - smoothstep(sparkle_distance * 0.5, sparkle_distance, dist));
	EMISSION = vec3(0.85, 0.93, 1.0) * glint * sparkle_strength * snow;
}

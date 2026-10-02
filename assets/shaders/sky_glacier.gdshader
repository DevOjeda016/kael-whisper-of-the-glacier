shader_type sky;

// Cielo del glaciar: degradado frío, sol cálido con halo, nubes procedurales
// que se mueven con el viento y, de noche, luna, estrellas y aurora boreal.
// Los colores y las direcciones del sol/luna los cambia day_night_cycle.gd
// según la hora; los valores de aquí son los del mediodía.

uniform vec3 top_color : source_color = vec3(0.24, 0.45, 0.72);
uniform vec3 horizon_color : source_color = vec3(0.78, 0.86, 0.93);
uniform vec3 ground_color : source_color = vec3(0.36, 0.44, 0.52);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.66);
uniform float sun_disk : hint_range(0.99, 1.0, 0.0001) = 0.9994;
uniform float sun_glow = 6.0;              // tamaño del halo (más alto = más pequeño)
uniform float sun_glow_strength = 0.55;
uniform vec3 cloud_light : source_color = vec3(0.98, 0.97, 0.95);
uniform vec3 cloud_shadow : source_color = vec3(0.62, 0.69, 0.78);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;
uniform float cloud_softness : hint_range(0.01, 0.5) = 0.22;
uniform float cloud_scale = 0.9;
uniform vec2 cloud_wind = vec2(0.006, 0.002);

uniform vec3 sun_dir = vec3(0.4, 0.6, 0.6);     // hacia el sol (lo pone el ciclo)
uniform vec3 moon_dir = vec3(-0.4, -0.6, 0.6);  // hacia la luna
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_color : source_color = vec3(0.85, 0.9, 1.0);
uniform float moon_disk : hint_range(0.99, 1.0, 0.0001) = 0.9992;
uniform float star_density = 0.0035;           // fracción de celdas con estrella
uniform float star_brightness = 2.2;
uniform vec3 aurora_color_a : source_color = vec3(0.2, 1.0, 0.6);
uniform vec3 aurora_color_b : source_color = vec3(0.45, 0.3, 1.0);
uniform float aurora_strength = 0.5;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	// Rotar cada octava rompe la rejilla del ruido (si no, salen nubes angulosas).
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = rot * p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

// Cortinas de aurora: bandas onduladas con rayas verticales que se mueven despacio.
vec3 aurora(vec3 d) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float layer_h = 0.18 + fi * 0.035;
		vec2 uv = d.xz / (d.y + layer_h) * 0.35;
		float wave = sin(uv.x * 1.3 + TIME * 0.04 + fi * 0.7) * 0.35 + fbm(vec2(uv.x * 0.6, TIME * 0.015)) * 0.8;
		float band = exp(-pow((uv.y + 0.9 - wave) * 7.0, 2.0));
		float rays = pow(noise(vec2(uv.x * 14.0 + fi * 3.0, TIME * 0.12)), 1.5);
		vec3 c = mix(aurora_color_a, aurora_color_b, fi / 4.0);
		acc += c * band * rays * (1.0 - fi * 0.15);
	}
	return acc * 0.3;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 3.0, 0.0, 1.0));
	}

	float above = smoothstep(-0.03, 0.02, h);

	// Estrellas: celdas al azar en la esfera del cielo que titilan; solo de noche.
	if (night > 0.0 && h > 0.0) {
		vec3 cell = floor(d * 260.0);
		float r = hash3(cell);
		if (r > 1.0 - star_density) {
			vec3 center = (cell + 0.5) / 260.0;
			float pt = 1.0 - smoothstep(0.0, 0.0026, length(d - normalize(center)));
			float tw = 0.65 + 0.35 * sin(TIME * (1.5 + r * 4.0) + r * 60.0);
			col += vec3(0.9, 0.95, 1.0) * pt * tw * star_brightness * night * night * smoothstep(0.0, 0.15, h);
		}
		// La aurora sale hacia el norte (-Z), donde está el glaciar.
		float north = smoothstep(0.2, -0.6, d.z);
		col += aurora(d) * aurora_strength * night * night * north * smoothstep(0.02, 0.25, h);
	}

	// Sol: disco + halo.
	float sd = dot(d, normalize(sun_dir));
	col += sun_color * pow(max(sd, 0.0), sun_glow) * sun_glow_strength * (1.0 - night * 0.8);
	col = mix(col, sun_color * 4.0, smoothstep(sun_disk, sun_disk + 0.0003, sd) * above);

	// Luna: disco con manchas suaves + halo azulado.
	float md = dot(d, normalize(moon_dir));
	float moon_mask = smoothstep(moon_disk, moon_disk + 0.0002, md) * above;
	float craters = 0.82 + 0.18 * noise(d.xy * 900.0 + d.z * 300.0);
	col += moon_color * pow(max(md, 0.0), 40.0) * 0.25 * night;
	col = mix(col, moon_color * 1.8 * craters, moon_mask * smoothstep(0.0, 0.3, night));

	// Nubes proyectadas sobre un plano alto; se desvanecen hacia el horizonte.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * cloud_scale + TIME * cloud_wind;
		uv += vec2(fbm(uv * 0.5), fbm(uv * 0.5 + 5.2)) * 0.8;   // deformar para formas más orgánicas
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
		vec3 light_dir = normalize(mix(sun_dir, moon_dir, night));
		float lit = clamp(fbm(uv + light_dir.xz * 0.08) - n + 0.6, 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow, cloud_light, lit);
		ccol += sun_color * pow(max(sd, 0.0), 12.0) * 0.4 * (1.0 - night);
		ccol += moon_color * pow(max(md, 0.0), 30.0) * 0.25 * night;
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, ccol, c * fade * mix(0.9, 0.75, night));
	}
	COLOR = col;
}

shader_type sky;

// Cielo del glaciar: degradado frío, sol cálido con halo y nubes procedurales
// que se mueven despacio con el viento. Todo ajustable desde world.tscn.

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

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, pow(h, 0.55));
	} else {
		col = mix(horizon_color, ground_color, clamp(-h * 3.0, 0.0, 1.0));
	}

	// Sol: disco + halo.
	float sd = dot(d, LIGHT0_DIRECTION);
	if (LIGHT0_ENABLED) {
		col += sun_color * pow(max(sd, 0.0), sun_glow) * sun_glow_strength * LIGHT0_ENERGY;
		col = mix(col, sun_color * 4.0, smoothstep(sun_disk, sun_disk + 0.0003, sd));
	}

	// Nubes proyectadas sobre un plano alto; se desvanecen hacia el horizonte.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * cloud_scale + TIME * cloud_wind;
		uv += vec2(fbm(uv * 0.5), fbm(uv * 0.5 + 5.2)) * 0.8;   // deformar para formas más orgánicas
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + cloud_softness, n);
		float lit = clamp(fbm(uv + LIGHT0_DIRECTION.xz * 0.08) - n + 0.6, 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow, cloud_light, lit);
		ccol += sun_color * pow(max(sd, 0.0), 12.0) * 0.4;
		float fade = smoothstep(0.0, 0.18, h);
		col = mix(col, ccol, c * fade * 0.9);
	}
	COLOR = col;
}

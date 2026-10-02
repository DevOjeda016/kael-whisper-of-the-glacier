shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// Agua del glaciar:
// - Color según la profundidad (turquesa en lo bajo, azul profundo en lo hondo),
//   leyendo la textura de profundidad de la escena.
// - Espuma donde el agua toca hielo u orilla (cerca en distancia de vista).
// - Fresnel: más opaca y reflejante al mirarla de lado.
// - Ondas: dos mapas de normales que se desplazan en direcciones distintas
//   (los pone water_surface.gd).

uniform vec3 shallow_color : source_color = vec3(0.18, 0.62, 0.72);
uniform vec3 deep_color : source_color = vec3(0.03, 0.16, 0.32);
uniform float depth_falloff = 0.45;        // qué tan rápido se oscurece con la profundidad
uniform float min_alpha = 0.55;
uniform float max_alpha = 0.95;
uniform vec3 foam_color : source_color = vec3(0.92, 0.97, 1.0);
uniform float foam_width = 0.9;             // metros de espuma junto a la orilla
uniform float foam_strength = 0.85;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tile_size = 9.0;
uniform vec2 wave_dir_a = vec2(0.035, 0.02);
uniform vec2 wave_dir_b = vec2(-0.02, 0.03);
uniform float normal_strength = 0.5;
uniform float roughness_value = 0.06;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float foam_noise(vec2 p) {
	return texture(normal_map, p).r;
}

void fragment() {
	// Profundidad de la escena detrás del agua, en coordenadas de mundo.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view_pos = INV_PROJECTION_MATRIX * ndc;
	view_pos.xyz /= view_pos.w;
	vec3 floor_world = (INV_VIEW_MATRIX * vec4(view_pos.xyz, 1.0)).xyz;
	float vertical = max(wp.y - floor_world.y, 0.0);
	float along_view = max(length(floor_world - wp), 0.0);

	// Color por profundidad.
	float t = 1.0 - exp(-vertical * depth_falloff);
	vec3 col = mix(shallow_color, deep_color, t);

	// Ondas.
	vec2 uv = wp.xz / tile_size;
	vec3 na = texture(normal_map, uv + TIME * wave_dir_a).xyz;
	vec3 nb = texture(normal_map, uv * 1.7 + TIME * wave_dir_b).xyz;
	NORMAL_MAP = normalize(mix(na, nb, 0.5));
	NORMAL_MAP_DEPTH = normal_strength;

	// Espuma junto a lo que toca el agua (cortada con ruido para que no sea una línea).
	float edge = 1.0 - smoothstep(0.0, foam_width, along_view);
	float breakup = foam_noise(wp.xz * 0.35 + TIME * 0.02);
	float foam = smoothstep(0.35, 0.75, edge + breakup * 0.6 - 0.3) * foam_strength;

	// Fresnel: de lado se ve más opaca.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	ALBEDO = mix(col, foam_color, foam);
	ROUGHNESS = mix(roughness_value, 0.7, foam);
	SPECULAR = 0.6;
	METALLIC = 0.1;
	ALPHA = clamp(mix(min_alpha, max_alpha, max(t, fres)) + foam, 0.0, 1.0);
}

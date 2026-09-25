shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Roche procedurale : grain fin, variations de couleur et litage horizontal.
// Tous les parametres viennent d'une ressource RockProfile (un profil par gisement).
// Aucune texture externe : tout est calcule a partir de la position dans le monde,
// ce qui garde le litage continu d'une face a l'autre du bloc.

uniform vec3 base_color : source_color = vec3(0.86, 0.82, 0.70);
uniform vec3 accent_color : source_color = vec3(0.72, 0.66, 0.53);
uniform vec3 deep_color : source_color = vec3(0.62, 0.57, 0.46);
uniform float grain_scale = 340.0;
uniform float grain_strength = 0.08;
uniform float mottle_scale = 12.0;
uniform float mottle_strength = 0.25;
uniform float lamination_scale = 900.0;
uniform float lamination_strength = 0.10;
uniform float rock_roughness = 0.82;

varying vec3 v_world;
varying vec3 v_normal_world;
varying float v_layer; // 1.0 = surface intacte, 0.0 = fond de la gangue

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	float x00 = mix(n000, n100, f.x);
	float x10 = mix(n010, n110, f.x);
	float x01 = mix(n001, n101, f.x);
	float x11 = mix(n011, n111, f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return total;
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_layer = COLOR.r;
}

void fragment() {
	float macro = fbm(v_world * mottle_scale);           // grandes taches
	float meso = fbm(v_world * mottle_scale * 5.0);      // variations moyennes
	float grain = value_noise(v_world * grain_scale);    // grain fin

	// Le litage se lit differemment selon l'orientation de la face :
	// - sur les tranches (parois creusees), on voit les lamines empilees ;
	// - sur un plan de stratification vu de dessus, on ne voit pas de lamines
	//   mais de fines trainees paralleles dans le plan du banc.
	float laminae = abs(sin(v_world.y * lamination_scale + macro * 3.0));
	float streaks = fbm(vec3(v_world.x * 2.5, 0.0, v_world.z * 55.0));
	float upness = clamp(abs(v_normal_world.y), 0.0, 1.0);
	float bedding = mix(laminae, streaks, upness);

	vec3 col = mix(base_color, accent_color, clamp(macro * mottle_strength * 3.0, 0.0, 1.0));
	col *= 1.0 + (meso - 0.5) * mottle_strength;
	// Plus on descend dans le bloc, plus la roche est "fraiche" (moins patinee).
	col = mix(col, deep_color, clamp((1.0 - v_layer) * 0.8, 0.0, 1.0));
	col *= 1.0 + (grain - 0.5) * grain_strength * 2.0;
	col *= 1.0 - (1.0 - bedding) * lamination_strength;

	ALBEDO = col;
	ROUGHNESS = clamp(rock_roughness - (grain - 0.5) * 0.12, 0.0, 1.0);
	SPECULAR = 0.25;
}

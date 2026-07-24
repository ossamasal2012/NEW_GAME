shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// خامة ماء بسيطة: تموّج رأسي خفيف + اضطراب عادي (Normal) متحرّك يمنح
// انعكاسات الفضاء الشاشي (SSR) سطحًا حيًّا لا مرآة مسطحة جامدة. كل شيء
// مبني من دوال جيبية بلا أي خامة خارجية — يكفي تمامًا لبركة صغيرة محصورة
// داخل الفانوس ولا يحتاج أداءً يُذكر.

uniform vec4 water_color : source_color = vec4(0.25, 0.55, 0.65, 0.75);
uniform vec4 water_deep_color : source_color = vec4(0.04, 0.13, 0.22, 0.92);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.06;
uniform float wave_speed : hint_range(0.0, 2.0) = 0.35;
uniform float wave_height : hint_range(0.0, 0.5) = 0.035;
uniform float wave_frequency : hint_range(0.1, 20.0) = 3.2;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	float t = TIME * wave_speed;
	float wave = sin(VERTEX.x * wave_frequency + t) * cos(VERTEX.z * wave_frequency * 0.8 + t * 1.3);
	VERTEX.y += wave * wave_height;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 uv = UV * wave_frequency;

	float n1 = sin(uv.x + t) * cos(uv.y * 1.3 + t * 0.7);
	float n2 = sin(uv.x * 2.1 - t * 1.4) * cos(uv.y * 1.7 + t);

	vec3 normal_perturb = normalize(vec3(n1 * normal_strength, 1.0, n2 * normal_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_perturb, 0.0)).xyz);

	float depth_mix = clamp(n1 * 0.5 + 0.5, 0.0, 1.0);
	ALBEDO = mix(water_deep_color.rgb, water_color.rgb, depth_mix);
	ALPHA = mix(water_deep_color.a, water_color.a, depth_mix);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}

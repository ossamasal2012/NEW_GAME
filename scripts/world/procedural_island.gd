extends MeshInstance3D
## ProceduralIsland
##
## يبني تضاريس الجزيرة إجرائيًا عند بدء التشغيل بدل استيراد نموذج جاهز.
## سببان لهذا القرار: أولًا، لا حاجة لأصول فنية خارجية لإنتاج شكل عضوي غير
## مكرَّر. وثانيًا — وهو الأهم على المدى الطويل — هذا بالضبط الأساس التقني
## الذي ستحتاجه ميكانيكا "النحت التفاعلي للتضاريس" الموصوفة في
## docs/GAME_DESIGN.md (المرحلة 4): تعديل قيم الارتفاع وإعادة بناء الشبكة
## حيًّا أثناء اللعب، بدل نموذج ثابت يجب استبداله بالكامل لاحقًا.
##
## الألوان تُخزَّن كألوان رؤوس (Vertex Colors) بدل خامات مستوردة — أسلوب
## فني مقصود (Stylized Low-Poly) لا حل بديل عن نقص الأصول: يمنح مظهرًا
## متماسكًا نظيفًا يعتمد على الإضاءة والتأثيرات اللاحقة (PBR، الظلال
## الناعمة، الانسداد المحيطي) لإبراز العمق، بدل الاعتماد على دقة الخامات.

@export var radius: float = 4.4
@export var grid_resolution: int = 46
@export var height_scale: float = 1.35
@export var noise_frequency: float = 0.5
@export var noise_seed: int = 1373
@export var edge_falloff_power: float = 2.3
@export var shoreline_depth: float = 0.55

# ألوان مناطق الارتفاع (من الأعمق إلى الأعلى) — تُمزَج بسلاسة بين بعضها.
@export var color_shore: Color = Color(0.71, 0.62, 0.45)
@export var color_lowland: Color = Color(0.35, 0.52, 0.28)
@export var color_highland: Color = Color(0.24, 0.38, 0.22)
@export var color_peak: Color = Color(0.55, 0.53, 0.52)

var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.5
	_noise.fractal_lacunarity = 2.1

	mesh = _build_terrain_mesh()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic = 0.0
	material_override = mat


func _height_at(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var normalized_dist: float = clampf(dist / radius, 0.0, 1.6)
	var falloff: float = clampf(1.0 - pow(normalized_dist, edge_falloff_power), 0.0, 1.0)
	var raw_noise := _noise.get_noise_2d(x, z)  # تقريبًا ضمن [-1, 1]
	var shaped_noise: float = (raw_noise * 0.5 + 0.5)  # [0, 1]
	return shaped_noise * height_scale * falloff - (1.0 - falloff) * shoreline_depth


func _color_for_height(h: float, normalized_h: float) -> Color:
	if h < 0.05:
		return color_shore
	elif normalized_h < 0.45:
		return color_shore.lerp(color_lowland, clampf(normalized_h / 0.45, 0.0, 1.0))
	elif normalized_h < 0.8:
		return color_lowland.lerp(color_highland, clampf((normalized_h - 0.45) / 0.35, 0.0, 1.0))
	else:
		return color_highland.lerp(color_peak, clampf((normalized_h - 0.8) / 0.2, 0.0, 1.0))


func _build_terrain_mesh() -> ArrayMesh:
	var half_extent: float = radius * 1.35
	var step: float = (half_extent * 2.0) / grid_resolution

	# نبني شبكة ارتفاعات أولًا كي نستطيع حساب أقصى ارتفاع فعلي (لتطبيع لون
	# القمم بدقة) قبل رسم أي مثلث.
	var heights := []
	var max_height := 0.001
	for j in range(grid_resolution + 1):
		var row := []
		var z: float = -half_extent + j * step
		for i in range(grid_resolution + 1):
			var x: float = -half_extent + i * step
			var h := _height_at(x, z)
			row.append(h)
			if h > max_height:
				max_height = h
		heights.append(row)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for j in range(grid_resolution):
		for i in range(grid_resolution):
			var x0: float = -half_extent + i * step
			var x1: float = x0 + step
			var z0: float = -half_extent + j * step
			var z1: float = z0 + step

			var h00: float = heights[j][i]
			var h10: float = heights[j][i + 1]
			var h01: float = heights[j + 1][i]
			var h11: float = heights[j + 1][i + 1]

			var p00 := Vector3(x0, h00, z0)
			var p10 := Vector3(x1, h10, z0)
			var p01 := Vector3(x0, h01, z1)
			var p11 := Vector3(x1, h11, z1)

			var c00 := _color_for_height(h00, clampf(h00 / max_height, 0.0, 1.0))
			var c10 := _color_for_height(h10, clampf(h10 / max_height, 0.0, 1.0))
			var c01 := _color_for_height(h01, clampf(h01 / max_height, 0.0, 1.0))
			var c11 := _color_for_height(h11, clampf(h11 / max_height, 0.0, 1.0))

			var uv00 := Vector2(float(i) / grid_resolution, float(j) / grid_resolution)
			var uv10 := Vector2(float(i + 1) / grid_resolution, float(j) / grid_resolution)
			var uv01 := Vector2(float(i) / grid_resolution, float(j + 1) / grid_resolution)
			var uv11 := Vector2(float(i + 1) / grid_resolution, float(j + 1) / grid_resolution)

			# مثلث أول: 00 → 10 → 01
			st.set_color(c00); st.set_uv(uv00); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)

			# مثلث ثانٍ: 10 → 11 → 01
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(uv11); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)

	st.generate_normals()
	st.generate_tangents()
	st.index()
	return st.commit()

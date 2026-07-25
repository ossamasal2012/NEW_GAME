class_name ProceduralIsland
extends MeshInstance3D
## ProceduralIsland
##
## يبني تضاريس الجزيرة إجرائيًا عند بدء التشغيل (كما في المرحلة 3)، لكن
## بيانات الارتفاع أصبحت الآن **حالة دائمة** (`_heights`) قابلة للتعديل
## حيًّا عبر apply_height_delta() — هذا بالضبط ما وُضع الأساس له في
## المرحلة 3. تُبنى شكل التصادم (Collision) من نفس بيانات الارتفاع
## بالضبط عبر HeightMapShape3D كي تُصيب أشعة اللمس (Raycasts) بقعة
## التضاريس الحقيقية بدقة الرأس الواحد.
##
## أداء التعديل الحي: apply_height_delta() لا تُعيد بناء الشبكة فورًا —
## فقط تُعلّم الحالة كـ"متّسخة" (_dirty)، وإعادة البناء الفعلية (المكلفة
## نسبيًا: SurfaceTool + تصادم) تحدث مرة واحدة كحد أقصى لكل إطار مُعروض
## عبر _process()، بصرف النظر عن عدد أحداث اللمس التي وصلت بينهما. هذا
## يمنع تكرار عملية إعادة بناء كاملة للشبكة عشرات المرات في الإطار نفسه.

@export var radius: float = 4.4
@export var grid_resolution: int = 46
@export var height_scale: float = 1.35
@export var noise_frequency: float = 0.5
@export var noise_seed: int = 1373
@export var edge_falloff_power: float = 2.3
@export var shoreline_depth: float = 0.55

@export var color_shore: Color = Color(0.71, 0.62, 0.45)
@export var color_lowland: Color = Color(0.35, 0.52, 0.28)
@export var color_highland: Color = Color(0.24, 0.38, 0.22)
@export var color_peak: Color = Color(0.55, 0.53, 0.52)

var _noise := FastNoiseLite.new()
var _heights := PackedFloat32Array()
var _grid_size: int
var _half_extent: float
var _step: float
var _dirty: bool = false
var _max_height_seen: float = 0.001

var _static_body: StaticBody3D
var _heightmap_shape: HeightMapShape3D


func _ready() -> void:
	_grid_size = grid_resolution + 1
	_half_extent = radius * 1.35
	_step = (_half_extent * 2.0) / grid_resolution

	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.5
	_noise.fractal_lacunarity = 2.1

	_generate_initial_heights()
	_setup_collision()
	_rebuild_visual_mesh()


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild_visual_mesh()
		_heightmap_shape.map_data = _heights
		_dirty = false


func _index(i: int, j: int) -> int:
	return j * _grid_size + i


func _generate_initial_heights() -> void:
	_heights.resize(_grid_size * _grid_size)
	_max_height_seen = 0.001
	for j in range(_grid_size):
		var z: float = -_half_extent + j * _step
		for i in range(_grid_size):
			var x: float = -_half_extent + i * _step
			var h := _compute_noise_height(x, z)
			_heights[_index(i, j)] = h
			if h > _max_height_seen:
				_max_height_seen = h


func _compute_noise_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var normalized_dist: float = clampf(dist / radius, 0.0, 1.6)
	var falloff: float = clampf(1.0 - pow(normalized_dist, edge_falloff_power), 0.0, 1.0)
	var raw_noise := _noise.get_noise_2d(x, z)
	var shaped_noise: float = raw_noise * 0.5 + 0.5
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


## يحوّل نقطة عالمية (من نتيجة Raycast مثلًا) إلى إحداثيات شبكة الارتفاع
## (قد تكون كسرية — القيمة الصحيحة تشير لأقرب رأس شبكة).
func world_to_grid(world_point: Vector3) -> Vector2:
	var local := to_local(world_point)
	return Vector2(
		(local.x + _half_extent) / _step,
		(local.z + _half_extent) / _step)


## نقطة الدخول الرئيسية لنحت التضاريس باللمس. delta موجب = رفع، سالب =
## خفض. التأثير يتلاشى بسلاسة (Smoothstep) من مركز اللمس حتى حافة نصف قطر
## الفرشاة، فتنتج كثبانًا وحُفرًا ناعمة الحواف بدل ارتفاعات حادة مفاجئة.
func apply_height_delta(world_point: Vector3, brush_radius: float, delta: float,
		min_h: float, max_h: float) -> void:
	var center := world_to_grid(world_point)
	var radius_in_cells: float = brush_radius / _step
	if radius_in_cells < 0.1:
		return

	var i_min: int = maxi(0, int(floor(center.x - radius_in_cells)))
	var i_max: int = mini(_grid_size - 1, int(ceil(center.x + radius_in_cells)))
	var j_min: int = maxi(0, int(floor(center.y - radius_in_cells)))
	var j_max: int = mini(_grid_size - 1, int(ceil(center.y + radius_in_cells)))

	for j in range(j_min, j_max + 1):
		for i in range(i_min, i_max + 1):
			var cell_dist: float = Vector2(i - center.x, j - center.y).length()
			if cell_dist > radius_in_cells:
				continue
			var falloff: float = smoothstep(0.0, 1.0, 1.0 - (cell_dist / radius_in_cells))
			var idx := _index(i, j)
			var new_h: float = clampf(_heights[idx] + delta * falloff, min_h, max_h)
			_heights[idx] = new_h
			if new_h > _max_height_seen:
				_max_height_seen = new_h

	_dirty = true


## بيانات الارتفاع الحالية الكاملة — تُستخدم في SaveManager لحفظ شكل
## الجزيرة الذي نحته اللاعب.
func get_height_data() -> PackedFloat32Array:
	return _heights


## يستبدل التضاريس المولَّدة افتراضيًا ببيانات محفوظة مسبقًا (استكمال جلسة
## سابقة). يُتجاهل بأمان إن كان حجم البيانات لا يطابق حجم الشبكة الحالية
## (مثلًا بعد تغيير grid_resolution في تحديث مستقبلي للعبة).
func set_height_data(data: PackedFloat32Array) -> void:
	if data.size() != _grid_size * _grid_size:
		push_warning(
			"ProceduralIsland: حجم بيانات الحفظ (%d) لا يطابق حجم الشبكة الحالية (%d) — تُتجاهَل." %
			[data.size(), _grid_size * _grid_size])
		return
	_heights = data
	_max_height_seen = 0.001
	for h in _heights:
		if h > _max_height_seen:
			_max_height_seen = h
	_dirty = true


func _rebuild_visual_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for j in range(grid_resolution):
		for i in range(grid_resolution):
			var x0: float = -_half_extent + i * _step
			var x1: float = x0 + _step
			var z0: float = -_half_extent + j * _step
			var z1: float = z0 + _step

			var h00: float = _heights[_index(i, j)]
			var h10: float = _heights[_index(i + 1, j)]
			var h01: float = _heights[_index(i, j + 1)]
			var h11: float = _heights[_index(i + 1, j + 1)]

			var p00 := Vector3(x0, h00, z0)
			var p10 := Vector3(x1, h10, z0)
			var p01 := Vector3(x0, h01, z1)
			var p11 := Vector3(x1, h11, z1)

			var c00 := _color_for_height(h00, clampf(h00 / _max_height_seen, 0.0, 1.0))
			var c10 := _color_for_height(h10, clampf(h10 / _max_height_seen, 0.0, 1.0))
			var c01 := _color_for_height(h01, clampf(h01 / _max_height_seen, 0.0, 1.0))
			var c11 := _color_for_height(h11, clampf(h11 / _max_height_seen, 0.0, 1.0))

			var uv00 := Vector2(float(i) / grid_resolution, float(j) / grid_resolution)
			var uv10 := Vector2(float(i + 1) / grid_resolution, float(j) / grid_resolution)
			var uv01 := Vector2(float(i) / grid_resolution, float(j + 1) / grid_resolution)
			var uv11 := Vector2(float(i + 1) / grid_resolution, float(j + 1) / grid_resolution)

			st.set_color(c00); st.set_uv(uv00); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)

			st.set_color(c10); st.set_uv(uv10); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(uv11); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(uv01); st.add_vertex(p01)

	st.generate_normals()
	st.generate_tangents()
	st.index()
	mesh = st.commit()

	if material_override == null:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.92
		mat.metallic = 0.0
		material_override = mat


func _setup_collision() -> void:
	_static_body = StaticBody3D.new()
	_static_body.name = "TerrainBody"
	add_child(_static_body)

	_heightmap_shape = HeightMapShape3D.new()
	_heightmap_shape.map_width = _grid_size
	_heightmap_shape.map_depth = _grid_size
	_heightmap_shape.map_data = _heights

	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = _heightmap_shape
	# HeightMapShape3D يفترض تباعدًا بوحدة واحدة بين نقاط الشبكة افتراضيًا؛
	# نطابق تباعدنا الفعلي (_step) بتحجيم محوري X/Z فقط دون التأثير على Y
	# (القيم الرأسية تأتي مباشرة من map_data نفسها بلا تحجيم إضافي).
	collision_shape.scale = Vector3(_step, 1.0, _step)
	_static_body.add_child(collision_shape)

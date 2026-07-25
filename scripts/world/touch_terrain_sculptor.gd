extends Node3D
## TouchTerrainSculptor
##
## يفسّر "ضغط مطوّل ثم سحب رأسي" كنحت تفاعلي للتضاريس، تمامًا كما يصف
## docs/GAME_DESIGN.md: سحب للأعلى بعد الضغط المطوّل = رفع الأرض عند نقطة
## الإرساء، سحب للأسفل = خفضها. نقطة الإرساء تُحدَّد لحظة تأكّد الضغط
## المطوّل عبر Raycast حقيقي على شكل تصادم الجزيرة، وتبقى ثابتة طوال بقاء
## الإصبع (لا "ترسم" أثناء التحرك الأفقي — فقط شدة السحب الرأسي تتحكم
## بالنحت، لتبقى النتيجة متوقَّعة ومفهومة من أول تجربة).
##
## التنسيق مع OrbitCameraController: كلاهما يستمع لنفس تدفّق اللمس، لذا
## نستخدم علمًا مشتركًا بسيطًا (`sculpting_active` على كائن الكاميرا) بدل
## أن يتنافسا على نفس حدث اللمس — بمجرد تأكّد النحت، يتوقف مدار الكاميرا
## عن معالجة أي لمسة فورًا وحتى رفع الإصبع.

@export var camera_path: NodePath
@export var island_path: NodePath
@export var orbit_controller_path: NodePath
@export var brush_cursor_path: NodePath

@export var long_press_duration: float = 0.32
@export var long_press_move_tolerance_px: float = 16.0
@export var brush_radius: float = 0.85
@export var height_sensitivity: float = 0.0065
@export var min_terrain_height: float = -1.0
@export var max_terrain_height: float = 2.4
@export var max_raycast_distance: float = 60.0

@onready var camera: Camera3D = get_node(camera_path)
@onready var island: ProceduralIsland = get_node(island_path)
@onready var orbit_controller: Node = get_node(orbit_controller_path)
@onready var brush_cursor: Node3D = get_node_or_null(brush_cursor_path)

var _touch_index: int = -1
var _press_start_screen_pos: Vector2
var _press_start_time: float
var _candidate_cancelled: bool = false
var _sculpting: bool = false
var _anchor_world_point: Vector3
var _last_drag_screen_y: float


func _ready() -> void:
	if brush_cursor:
		brush_cursor.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index == -1:
			_touch_index = event.index
			_press_start_screen_pos = event.position
			_press_start_time = Time.get_ticks_msec() / 1000.0
			_candidate_cancelled = false
	else:
		if event.index == _touch_index:
			_end_touch()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index or _candidate_cancelled:
		return
	if _sculpting:
		_continue_sculpting(event.position)
		return
	# قبل تأكّد الضغط المطوّل: أي تحرك واضح يعني أن هذه لفتة تدوير عادية،
	# لا نحت — نُلغي الترشّح ونترك OrbitCameraController يتولى الباقي.
	if event.position.distance_to(_press_start_screen_pos) > long_press_move_tolerance_px:
		_candidate_cancelled = true


func _process(_delta: float) -> void:
	if _touch_index == -1 or _sculpting or _candidate_cancelled:
		return
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _press_start_time
	if elapsed >= long_press_duration:
		_try_confirm_sculpting()


func _try_confirm_sculpting() -> void:
	var hit := _raycast_island(_press_start_screen_pos)
	if hit.is_empty():
		# ضغطة مطوّلة فوق فراغ (السماء، خارج الجزيرة) — ليست نحتًا؛ نُلغي
		# الترشّح ونترك التحكم الطبيعي بالكاميرا يعمل بلا عائق.
		_candidate_cancelled = true
		return

	_sculpting = true
	_anchor_world_point = hit["position"]
	_last_drag_screen_y = _press_start_screen_pos.y
	if orbit_controller:
		orbit_controller.sculpting_active = true
	if brush_cursor:
		brush_cursor.global_position = _anchor_world_point
		brush_cursor.visible = true


func _continue_sculpting(screen_pos: Vector2) -> void:
	var delta_y: float = _last_drag_screen_y - screen_pos.y  # موجب = سحب للأعلى
	_last_drag_screen_y = screen_pos.y
	var height_delta: float = delta_y * height_sensitivity
	island.apply_height_delta(
		_anchor_world_point, brush_radius, height_delta,
		min_terrain_height, max_terrain_height)


func _end_touch() -> void:
	var was_sculpting := _sculpting
	_touch_index = -1
	_sculpting = false
	_candidate_cancelled = false
	if orbit_controller:
		orbit_controller.sculpting_active = false
	if brush_cursor:
		brush_cursor.visible = false
	if was_sculpting:
		EventBus.world_state_changed.emit()


func _raycast_island(screen_pos: Vector2) -> Dictionary:
	var space_state := get_world_3d().direct_space_state
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * max_raycast_distance
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)

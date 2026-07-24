extends Node3D
## OrbitCameraController
##
## يدور حول نقطة محورية ثابتة (مركز الجزيرة) بلمسة واحدة، ويُقرِّب/يُبعِّد
## بإصبعين — بالضبط آليات التحكم الموصوفة في docs/GAME_DESIGN.md. لا يُنشئ
## أي عقدة Camera3D بنفسه؛ يتوقّع أن تكون كاميرا موجودة كابنة مباشرة له
## باسم "Camera3D"، فيدير موضعها فقط دون التدخّل في خصائصها الأخرى (FOV،
## Environment...).
##
## التخميد (Damping) على كل من الدوران والتكبير مقصود: يجعل حركة الكاميرا
## تتبع الإصبع بنعومة بدل القفز الفوري، وهذا هو الفرق المحسوس بين تحكم
## "احترافي" وتحكم خام يتبع بيانات اللمس حرفيًا كل إطار.

@export var pivot_target: Vector3 = Vector3.ZERO
@export var min_distance: float = 8.0
@export var max_distance: float = 16.0
@export var min_pitch_degrees: float = -55.0
@export var max_pitch_degrees: float = 20.0
@export var rotate_sensitivity: float = 0.32
@export var zoom_sensitivity: float = 0.024
@export var follow_damping: float = 9.0
@export var initial_distance: float = 11.5
@export var initial_pitch_degrees: float = -18.0
@export var initial_yaw_degrees: float = 35.0

@onready var camera: Camera3D = $Camera3D

var _yaw_degrees: float
var _pitch_degrees: float
var _distance: float

var _target_yaw_degrees: float
var _target_pitch_degrees: float
var _target_distance: float

var _active_touches: Dictionary = {}
var _last_pinch_distance: float = -1.0


func _ready() -> void:
	_yaw_degrees = initial_yaw_degrees
	_pitch_degrees = initial_pitch_degrees
	_distance = initial_distance
	_target_yaw_degrees = _yaw_degrees
	_target_pitch_degrees = _pitch_degrees
	_target_distance = _distance
	_apply_transform(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_active_touches[event.index] = event.position
		else:
			_active_touches.erase(event.index)
			_last_pinch_distance = -1.0
	elif event is InputEventScreenDrag:
		_active_touches[event.index] = event.position
		match _active_touches.size():
			1:
				_target_yaw_degrees -= event.relative.x * rotate_sensitivity
				_target_pitch_degrees = clampf(
					_target_pitch_degrees - event.relative.y * rotate_sensitivity,
					min_pitch_degrees, max_pitch_degrees)
			2:
				_handle_pinch()


func _handle_pinch() -> void:
	var positions := _active_touches.values()
	var current_distance: float = positions[0].distance_to(positions[1])
	if _last_pinch_distance > 0.0:
		var delta := current_distance - _last_pinch_distance
		_target_distance = clampf(
			_target_distance - delta * zoom_sensitivity, min_distance, max_distance)
	_last_pinch_distance = current_distance


func _process(delta: float) -> void:
	_apply_transform(delta)


func _apply_transform(delta: float) -> void:
	var t := clampf(follow_damping * delta, 0.0, 1.0)
	_yaw_degrees = lerp_angle(deg_to_rad(_yaw_degrees), deg_to_rad(_target_yaw_degrees), t)
	_yaw_degrees = rad_to_deg(_yaw_degrees)
	_pitch_degrees = lerpf(_pitch_degrees, _target_pitch_degrees, t)
	_distance = lerpf(_distance, _target_distance, t)

	var yaw_rad := deg_to_rad(_yaw_degrees)
	var pitch_rad := deg_to_rad(_pitch_degrees)
	var offset := Vector3(
		cos(pitch_rad) * sin(yaw_rad),
		sin(pitch_rad),
		cos(pitch_rad) * cos(yaw_rad)
	) * _distance

	camera.global_position = pivot_target + offset
	camera.look_at(pivot_target, Vector3.UP)

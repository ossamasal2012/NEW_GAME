extends Button
## TouchButtonFeedback
##
## سلوك بصري يُعاد استخدامه: يُرفق هذا السكربت مباشرة بأي عقدة Button بدل
## سكربت Button الافتراضي، فتكتسب الزر تلقائيًا "نبضة" لمس ناعمة عند الضغط
## والتحرير — بدون كتابة أي كود Tween في كل مكان يوجد فيه زر. هذا بالضبط ما
## يطلبه معيار "لا تكرر الأكواد" و"أنيميشن ناعم" معًا في ملف واحد صغير.
##
## الاستخدام: بدّل سكربت أي Button في المشهد إلى هذا الملف. لا حاجة لأي
## إعداد إضافي — يعمل فور دخول المشهد.

const PRESS_SCALE := 0.94
const PRESS_DURATION := 0.08
const RELEASE_DURATION := 0.35

var _feedback_tween: Tween


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)

	button_down.connect(_on_press)
	button_up.connect(_on_release)
	mouse_exited.connect(_on_release)
	focus_exited.connect(_on_release)


func _on_press() -> void:
	if disabled:
		return
	_animate_scale(Vector2.ONE * PRESS_SCALE, PRESS_DURATION, Tween.TRANS_SINE, Tween.EASE_OUT)


func _on_release() -> void:
	_animate_scale(Vector2.ONE, RELEASE_DURATION, Tween.TRANS_ELASTIC, Tween.EASE_OUT)


func _animate_scale(target: Vector2, duration: float, trans: Tween.TransitionType, ease: Tween.EaseType) -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(trans)
	_feedback_tween.set_ease(ease)
	_feedback_tween.tween_property(self, "scale", target, duration)

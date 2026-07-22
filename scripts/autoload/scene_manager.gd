extends CanvasLayer
## SceneManager
##
## المسؤول الوحيد عن الانتقال بين المشاهد. أي كود يريد الانتقال إلى مشهد
## آخر يستدعي change_scene() هنا بدل استدعاء get_tree().change_scene_to_file
## مباشرة، حتى يمر كل انتقال عبر نفس التلاشي الناعم — وهذا بالضبط ما طلبه
## معيار "احترافية وسلسة مع أنيميشن ناعم" في واجهة اللعبة.
##
## يُبنى غطاء التلاشي (fade overlay) برمجيًا في _ready() بدل الاعتماد على
## مشهد .tscn منفصل؛ فهو عنصر بسيط جدًا (مستطيل بلون واحد) لا يستفيد من
## محرر المشاهد، وإبقاؤه كودًا خالصًا يقلّل عدد الملفات دون أي تضحية
## بالوضوح.

const DEFAULT_FADE_DURATION := 0.35

var is_transitioning: bool = false

var _fade_rect: ColorRect


func _ready() -> void:
	layer = 4096  # فوق كل شيء آخر في اللعبة، بما فيها أي واجهة أخرى.
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)


## ينتقل إلى المشهد المحدد بمساره مع تلاشٍ إلى الأسود ثم منه. آمن ضد
## الاستدعاء المتكرر أثناء انتقال قائم بالفعل (يُتجاهل الاستدعاء الثاني).
func change_scene(scene_path: String, fade_duration: float = DEFAULT_FADE_DURATION) -> void:
	if is_transitioning:
		push_warning("SceneManager: تجاهل طلب انتقال أثناء انتقال آخر قائم بالفعل")
		return

	is_transitioning = true
	EventBus.scene_transition_started.emit(scene_path)

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # يمنع اللمس أثناء التلاشي.

	var fade_out := create_tween()
	fade_out.tween_property(_fade_rect, "color:a", 1.0, fade_duration)
	await fade_out.finished

	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneManager: فشل تحميل المشهد '%s' (code=%d)" % [scene_path, error])
		is_transitioning = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# ننتظر إطارًا واحدًا على الأقل بعد تبديل المشهد كي تُتاح فرصة لتشغيل
	# منطق _ready() الخاص بالمشهد الجديد قبل أن نكشف عنه بالتلاشي.
	await get_tree().process_frame

	var fade_in := create_tween()
	fade_in.tween_property(_fade_rect, "color:a", 0.0, fade_duration)
	await fade_in.finished

	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	EventBus.scene_transition_finished.emit(scene_path)

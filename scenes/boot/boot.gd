extends Control
## Boot
##
## أول مشهد يُحمَّل عند تشغيل التطبيق. مهمته الآن: تقديم شاشة إقلاع أنيقة
## بينما تُهيّئ الأنظمة الأساسية (كلها Autoloads جاهزة فعلًا في هذه المرحلة
## لأنها تُحمَّل قبل أي مشهد). حين يُبنى القائمة الرئيسية في المرحلة
## القادمة، سيُضاف هنا سطر واحد فقط يستدعي
## SceneManager.change_scene("res://scenes/main_menu/main_menu.tscn")
## بعد اكتمال دورة الإقلاع — دون أي حاجة لتعديل ما هو موجود حاليًا.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel

var _pulse_tween: Tween


func _ready() -> void:
	GameManager.current_state = GameManager.State.BOOTING

	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0

	var intro := create_tween()
	intro.set_trans(Tween.TRANS_SINE)
	intro.tween_property(title_label, "modulate:a", 1.0, 1.1)
	intro.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 1.1).set_delay(0.35)
	intro.tween_callback(_start_idle_pulse)

	GameManager.has_completed_first_boot = true


## نبضة توهّج ناعمة ومستمرة على العنوان أثناء بقاء الشاشة معروضة، تمنح
## شاشة الإقلاع إحساسًا حيًّا بدل أن تكون صورة ثابتة جامدة.
func _start_idle_pulse() -> void:
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(title_label, "modulate", Color(1.15, 1.08, 0.85), 1.6)
	_pulse_tween.tween_property(title_label, "modulate", Color(1.0, 1.0, 1.0), 1.6)

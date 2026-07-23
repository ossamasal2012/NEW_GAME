extends Control
## Boot
##
## أول مشهد يُحمَّل عند تشغيل التطبيق. يعرض شاشة إقلاع أنيقة (تتزامن مع كل
## الأنظمة الأساسية Autoloads التي تُحمَّل قبل أي مشهد أصلًا)، ثم ينتقل
## تلقائيًا إلى القائمة الرئيسية بعد نبضة توهّج واحدة على الشعار.

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel


func _ready() -> void:
	GameManager.current_state = GameManager.State.BOOTING

	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0

	var intro := create_tween()
	intro.set_trans(Tween.TRANS_SINE)
	intro.tween_property(title_label, "modulate:a", 1.0, 1.1)
	intro.parallel().tween_property(subtitle_label, "modulate:a", 1.0, 1.1).set_delay(0.35)
	intro.tween_callback(_play_pulse_then_continue)

	GameManager.has_completed_first_boot = true


## نبضة توهّج ناعمة واحدة على الشعار، ثم انتقال إلى القائمة الرئيسية.
## دورة كاملة (تكبير ناعم للتوهّج ثم عودة) تمنح شاشة الإقلاع إحساسًا حيًّا
## بدل أن تكون صورة ثابتة جامدة تختفي فجأة.
func _play_pulse_then_continue() -> void:
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_SINE)
	pulse.set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(title_label, "modulate", Color(1.15, 1.08, 0.85), 0.9)
	pulse.tween_property(title_label, "modulate", Color(1.0, 1.0, 1.0), 0.9)
	await pulse.finished
	SceneManager.change_scene(MAIN_MENU_SCENE)

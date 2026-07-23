extends Control
## MainMenu
##
## القائمة الرئيسية: شاشة واحدة تحتوي ثلاث "شاشات فرعية" داخلية (رئيسية/
## إعدادات/عن اللعبة) يُبدَّل بينها بتلاشٍ وانزلاق ناعمين، بدل معاملتها
## كمشاهد Godot منفصلة تتطلب انتقال SceneManager الكامل — هذه الشاشات
## خفيفة ومترابطة بما يكفي ليكون التبديل المحلي داخل نفس المشهد أنسب
## وأسرع إحساسًا. SceneManager يبقى محجوزًا للانتقالات الكبرى بين مشاهد
## مستقلة فعلًا (كما بين Boot والقائمة الرئيسية، ولاحقًا بين القائمة
## وعالم اللعب نفسه).

const SCREEN_TRANSITION_DURATION := 0.3

@onready var home_screen: Control = %HomeScreen
@onready var settings_screen: Control = %SettingsScreen
@onready var about_screen: Control = %AboutScreen

@onready var play_button: Button = %PlayButton
@onready var settings_button: Button = %SettingsButton
@onready var about_button: Button = %AboutButton
@onready var settings_back_button: Button = %SettingsBackButton
@onready var about_back_button: Button = %AboutBackButton

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ui_slider: HSlider = %UISlider
@onready var master_value_label: Label = %MasterValueLabel
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var ui_value_label: Label = %UIValueLabel

@onready var quality_high_button: Button = %QualityHighButton
@onready var quality_balanced_button: Button = %QualityBalancedButton

@onready var version_label: Label = %VersionLabel

var _current_screen: Control


func _ready() -> void:
	GameManager.current_state = GameManager.State.MAIN_MENU

	# لا يوجد بعد عالم لعب فعلي (يُبنى في المرحلة 3 وما بعدها) — الزر
	# موجود وواضح بدل أن يُخفى، لكنه معطَّل صراحة بدل أن يقود لمكان فارغ.
	# راجع خارطة الطريق في docs/GAME_DESIGN.md.
	play_button.disabled = true

	settings_button.pressed.connect(_switch_to.bind(settings_screen))
	about_button.pressed.connect(_switch_to.bind(about_screen))
	settings_back_button.pressed.connect(_switch_to.bind(home_screen))
	about_back_button.pressed.connect(_switch_to.bind(home_screen))

	_setup_volume_slider(master_slider, master_value_label, SettingsManager.master_volume, SettingsManager.set_master_volume)
	_setup_volume_slider(music_slider, music_value_label, SettingsManager.music_volume, SettingsManager.set_music_volume)
	_setup_volume_slider(sfx_slider, sfx_value_label, SettingsManager.sfx_volume, SettingsManager.set_sfx_volume)
	_setup_volume_slider(ui_slider, ui_value_label, SettingsManager.ui_volume, SettingsManager.set_ui_volume)

	quality_high_button.pressed.connect(func() -> void:
		SettingsManager.set_graphics_quality(SettingsManager.GraphicsQuality.HIGH))
	quality_balanced_button.pressed.connect(func() -> void:
		SettingsManager.set_graphics_quality(SettingsManager.GraphicsQuality.BALANCED))
	_refresh_quality_buttons()

	version_label.text = "الإصدار %s" % SaveManager.APP_VERSION

	home_screen.show()
	home_screen.modulate.a = 1.0
	settings_screen.hide()
	about_screen.hide()
	_current_screen = home_screen


## يربط شريحة صوت واحدة بقيمتها الحالية وبدالّة الضبط المناسبة في
## SettingsManager، ويحدّث تسمية النسبة المئوية معها لحظيًا. دالة واحدة
## تُستخدم أربع مرات بدل تكرار نفس منطق الربط لكل شريحة على حدة.
func _setup_volume_slider(slider: HSlider, value_label: Label, initial: float, setter: Callable) -> void:
	slider.value = initial
	value_label.text = _format_percent(initial)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		value_label.text = _format_percent(v))


func _format_percent(v: float) -> String:
	return "%d%%" % int(round(v * 100.0))


func _refresh_quality_buttons() -> void:
	var is_high := SettingsManager.graphics_quality == SettingsManager.GraphicsQuality.HIGH
	quality_high_button.button_pressed = is_high
	quality_balanced_button.button_pressed = not is_high


## يبدّل الشاشة الفرعية الظاهرة بتلاشٍ وانزلاق رأسي خفيف متزامنين، ويخفي
## الشاشة السابقة فقط بعد اكتمال التلاشي كي لا تتراكب لمسات غير مقصودة.
func _switch_to(target: Control) -> void:
	if target == _current_screen:
		return

	var outgoing := _current_screen
	_current_screen = target

	target.modulate.a = 0.0
	target.position.y = 28.0
	target.show()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, SCREEN_TRANSITION_DURATION)
	tween.tween_property(target, "position:y", 0.0, SCREEN_TRANSITION_DURATION)

	if outgoing:
		tween.tween_property(outgoing, "modulate:a", 0.0, SCREEN_TRANSITION_DURATION * 0.7)
		tween.chain().tween_callback(outgoing.hide)

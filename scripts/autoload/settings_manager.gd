extends Node
## SettingsManager
##
## يحفظ تفضيلات المستخدم (مستويات الصوت، جودة الرسوميات، اللغة) في ملف
## إعدادات منفصل تمامًا عن ملف حفظ اللعبة (SaveManager). الفصل مقصود:
## إعدادات الجهاز/المستخدم شيء، وتقدّم اللاعب داخل عالم اللعبة شيء آخر؛
## دمجهما في ملف واحد يعقّد كل عملية نقل حفظ أو استكشاف أخطاء لاحقًا.
##
## نستخدم هنا ConfigFile المدمجة في Godot (صيغة .ini) بدل JSON لأنها الأداة
## المخصصة أصلًا لإعدادات من هذا النوع (مفتاح/قيمة بسيطة)، وتقرأ وتكتب
## نفسها دون الحاجة لأي تحويل يدوي.

const SETTINGS_FILE_PATH := "user://settings.cfg"

enum GraphicsQuality {
	BALANCED,  ## دقة عرض مخفّضة قليلًا وظلال أبسط — لأجهزة متوسطة الفئة.
	HIGH,      ## الدقة الكاملة وكل التأثيرات — للأجهزة العالية الفئة.
}

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
var graphics_quality: GraphicsQuality = GraphicsQuality.HIGH
var language: String = "ar"

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()
	apply_all_settings()


func load_settings() -> void:
	var err := _config.load(SETTINGS_FILE_PATH)
	if err != OK:
		# لا يوجد ملف إعدادات بعد (أول تشغيل) — نُبقي القيم الافتراضية
		# ونكتب ملفًا جديدًا بها كي يكون موجودًا للمرة القادمة.
		save_settings()
		return

	master_volume = float(_config.get_value("audio", "master_volume", master_volume))
	music_volume = float(_config.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(_config.get_value("audio", "sfx_volume", sfx_volume))
	ui_volume = float(_config.get_value("audio", "ui_volume", ui_volume))
	graphics_quality = int(_config.get_value("graphics", "quality", graphics_quality)) as GraphicsQuality
	language = String(_config.get_value("locale", "language", language))


func save_settings() -> void:
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("audio", "ui_volume", ui_volume)
	_config.set_value("graphics", "quality", graphics_quality)
	_config.set_value("locale", "language", language)
	_config.save(SETTINGS_FILE_PATH)


## يطبّق كل الإعدادات الحالية على الأنظمة الحيّة (الصوت، الرسوميات...).
## يُستدعى عند الإقلاع وبعد أي تحميل لإعدادات جديدة.
func apply_all_settings() -> void:
	AudioManager.set_bus_volume_linear("Master", master_volume)
	AudioManager.set_bus_volume_linear("Music", music_volume)
	AudioManager.set_bus_volume_linear("SFX", sfx_volume)
	AudioManager.set_bus_volume_linear("UI", ui_volume)
	_apply_graphics_quality()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume_linear("Master", master_volume)
	save_settings()
	EventBus.settings_changed.emit("master_volume", master_volume)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume_linear("Music", music_volume)
	save_settings()
	EventBus.settings_changed.emit("music_volume", music_volume)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume_linear("SFX", sfx_volume)
	save_settings()
	EventBus.settings_changed.emit("sfx_volume", sfx_volume)


func set_ui_volume(value: float) -> void:
	ui_volume = clampf(value, 0.0, 1.0)
	AudioManager.set_bus_volume_linear("UI", ui_volume)
	save_settings()
	EventBus.settings_changed.emit("ui_volume", ui_volume)


func set_graphics_quality(value: GraphicsQuality) -> void:
	graphics_quality = value
	_apply_graphics_quality()
	save_settings()
	EventBus.settings_changed.emit("graphics_quality", graphics_quality)


## يترجم اختيار الجودة إلى إعدادات محرك فعلية. نبقي الاختلاف بين
## المستويين داخل خط العرض Forward+ نفسه (دقة العرض الداخلية وحجم أطلس
## الظل) بدل تبديل خط العرض بالكامل، لأن Godot لا يسمح بتبديل رندرر
## المشروع أثناء التشغيل — راجع docs/ARCHITECTURE.md لتفاصيل هذا القرار.
func _apply_graphics_quality() -> void:
	var viewport := get_viewport()
	match graphics_quality:
		GraphicsQuality.HIGH:
			viewport.scaling_3d_scale = 1.0
			viewport.positional_shadow_atlas_size = 4096
		GraphicsQuality.BALANCED:
			viewport.scaling_3d_scale = 0.85
			viewport.positional_shadow_atlas_size = 2048

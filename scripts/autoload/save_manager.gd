extends Node
## SaveManager
##
## خدمة حفظ/تحميل عامة تتعامل مع ملف JSON واحد داخل `user://` (المسار الآمن
## والمخصص لكل تطبيق على أندرويد، لا علاقة له بمجلد المشروع). هذا السكربت
## "غبي" عن قصد: لا يعرف شيئًا عن عالم اللعبة أو التقدّم أو المخلوقات — فقط
## يعرف كيف يكتب Dictionary إلى القرص ويقرأه بأمان. الأنظمة التي ستُبنى لاحقًا
## (عالم الفانوس، التطور، الإنجازات...) تُغذّي بياناتها عبر build_current_save_data()
## دون أن يتغيّر أي سطر هنا.
##
## لماذا رقم إصدار (SAVE_VERSION) منذ اليوم الأول؟
## لأن شكل بيانات الحفظ سيتطوّر حتمًا مع كل نظام جديد يُضاف على مدى سنوات
## من الدعم الحي. بلا رقم إصدار، أي تغيير مستقبلي في البنية قد يكسر حفظ
## اللاعبين القدامى. الدالة _migrate_save_data تبقى نقطة وحيدة يُضاف إليها
## معالج تحويل لكل إصدار جديد، فيما يبقى استدعاء load_game() من الخارج
## دون تغيير.

const SAVE_DIRECTORY := "user://saves/"
const SAVE_FILE_PATH := SAVE_DIRECTORY + "fanous_save.json"
const CURRENT_SAVE_VERSION := 1

## رقم إصدار اللعبة نفسها (وليس إصدار بنية الحفظ). يُحدَّث يدويًا مع كل
## إصدار جديد يُنشر؛ يُخزَّن داخل الحفظ لأغراض التشخيص وتقارير الأعطال.
const APP_VERSION := "0.1.0"


func save_game(data: Dictionary) -> bool:
	EventBus.save_started.emit()

	var dir_result := DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)
	if dir_result != OK and dir_result != ERR_ALREADY_EXISTS:
		EventBus.save_failed.emit("تعذّر إنشاء مجلد الحفظ (code=%d)" % dir_result)
		return false

	data["save_version"] = CURRENT_SAVE_VERSION
	data["saved_at_unix"] = Time.get_unix_time_from_system()

	var json_text := JSON.stringify(data, "\t")

	# نكتب أولًا إلى ملف مؤقت ثم نستبدل الملف الأصلي دفعة واحدة، بحيث لا
	# يمكن أبدًا أن ينقطع التطبيق أثناء الكتابة ويترك ملف حفظ تالفًا نصفيًا.
	var tmp_path := SAVE_FILE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		EventBus.save_failed.emit("تعذّر فتح ملف الحفظ المؤقت (error=%d)" % FileAccess.get_open_error())
		return false

	file.store_string(json_text)
	file.close()

	var dir := DirAccess.open(SAVE_DIRECTORY)
	if dir == null:
		EventBus.save_failed.emit("تعذّر الوصول إلى مجلد الحفظ")
		return false

	var rename_result := dir.rename(tmp_path.get_file(), SAVE_FILE_PATH.get_file())
	if rename_result != OK:
		EventBus.save_failed.emit("تعذّر إتمام كتابة ملف الحفظ (code=%d)" % rename_result)
		return false

	EventBus.save_completed.emit()
	return true


func load_game() -> Dictionary:
	if not has_save_file():
		return {}

	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		EventBus.load_failed.emit("تعذّر فتح ملف الحفظ (error=%d)" % FileAccess.get_open_error())
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		EventBus.load_failed.emit("ملف الحفظ تالف أو بصيغة غير صالحة")
		return {}

	var data: Dictionary = parsed
	var found_version: int = int(data.get("save_version", 0))
	if found_version < CURRENT_SAVE_VERSION:
		data = _migrate_save_data(data, found_version)

	EventBus.load_completed.emit()
	return data


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)


func delete_save() -> bool:
	if not has_save_file():
		return true
	var dir := DirAccess.open(SAVE_DIRECTORY)
	if dir == null:
		return false
	return dir.remove(SAVE_FILE_PATH.get_file()) == OK


## يجمع البيانات الحالية القابلة للحفظ من كل الأنظمة. في هذه المرحلة
## التأسيسية لا يوجد بعد عالم لعب فعلي، لذلك تُعاد بيانات وصفية أساسية
## فقط. كل نظام جديد (عالم الفانوس، التقدّم، المخلوقات...) سيضيف قسمه
## الخاص هنا حين يُبنى، دون أن يغيّر توقيع الدالة أو مستدعيها.
func build_current_save_data() -> Dictionary:
	return {
		"save_version": CURRENT_SAVE_VERSION,
		"app_version": APP_VERSION,
	}


## نقطة تحويل الحفظات القديمة إلى الشكل الحالي. لا تزال بلا أي تحويل فعلي
## لأنه لا يوجد إلا إصدار واحد حتى الآن؛ ستُملأ هذه الدالة بمعالج `match`
## لكل إصدار سابق فور إضافة إصدار ثانٍ من بنية الحفظ.
func _migrate_save_data(data: Dictionary, from_version: int) -> Dictionary:
	return data

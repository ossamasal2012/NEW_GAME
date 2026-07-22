extends Node
## AudioManager
##
## الواجهة الوحيدة التي يجب أن يستخدمها أي كود آخر لتشغيل صوت. لا أحد خارج
## هذا الملف يجب أن يُنشئ AudioStreamPlayer بنفسه أو يلمس AudioServer
## مباشرة — هذا يضمن أن كل قواعد الصوت (القنوات الصحيحة، التلاشي الناعم،
## عدم تسرّب العقد) مطبَّقة في مكان واحد فقط.
##
## القنوات (Buses) المستخدمة معرّفة في audio/bus_layout.tres:
## Master → Music / SFX / UI / Ambience

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_BUS := "UI"

var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer
var _music_fade_tween: Tween


func _ready() -> void:
	_music_player_a = _make_music_player()
	_music_player_b = _make_music_player()
	_active_music_player = _music_player_a


func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = MUSIC_BUS
	player.volume_db = 0.0
	add_child(player)
	return player


## يشغّل موسيقى خلفية مع تلاشٍ متقاطع (Crossfade) ناعم بين المقطوعة
## الحالية والجديدة، بدل قطع الصوت فجأة — تفصيل صغير لكنه يميّز تجربة
## احترافية عن تجربة هاوية.
## ملاحظة: التكرار (Loop) لا يُضبط هنا، بل هو خاصية على مصدر الصوت نفسه
## (AudioStreamOggVorbis.loop مثلًا) تُضبط عند استيراد الملف — لأن كل نوع
## تدفق صوتي في Godot يعرّف خاصية التكرار بطريقته الخاصة، فلا توجد واجهة
## موحّدة آمنة لفرضها هنا على أي نوع بشكل عام.
func play_music(stream: AudioStream, fade_seconds: float = 1.5) -> void:
	if stream == null:
		return

	var incoming := _music_player_b if _active_music_player == _music_player_a else _music_player_a
	var outgoing := _active_music_player

	if incoming.stream == stream and incoming.playing:
		return

	incoming.stream = stream
	incoming.volume_db = linear_to_db(0.0001)
	incoming.play()

	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()

	_music_fade_tween = create_tween()
	_music_fade_tween.set_parallel(true)
	_music_fade_tween.tween_property(incoming, "volume_db", 0.0, fade_seconds)
	if outgoing.playing:
		_music_fade_tween.tween_property(outgoing, "volume_db", linear_to_db(0.0001), fade_seconds)
		_music_fade_tween.chain().tween_callback(outgoing.stop)

	_active_music_player = incoming


func stop_music(fade_seconds: float = 1.0) -> void:
	if not _active_music_player.playing:
		return
	if _music_fade_tween and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	var player := _active_music_player
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(player, "volume_db", linear_to_db(0.0001), fade_seconds)
	_music_fade_tween.tween_callback(player.stop)


## يشغّل مؤثرًا صوتيًا لمرة واحدة عبر مشغّل مؤقت يُحرَّر تلقائيًا فور
## الانتهاء. مناسب لمعظم مؤثرات اللعب؛ إن أظهر التوصيف لاحقًا حاجة لتجميع
## (Pooling) صريح بسبب عدد كبير من الأصوات المتزامنة، يُضاف هنا فقط دون
## تغيير طريقة الاستدعاء من بقية الكود.
func play_sfx(stream: AudioStream, bus: String = SFX_BUS, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_ui_sound(stream: AudioStream) -> void:
	play_sfx(stream, UI_BUS)


## يحوّل قيمة خطية (0.0 – 1.0) قادمة من شرائح الإعدادات إلى ديسيبل
## ويطبّقها على القناة المطلوبة. يتجاهل بأمان أي اسم قناة غير موجود بدل أن
## يُسبّب خطأ، لأن هذا السكربت قد يُستدعى قبل أن يضمن أحد وجود القناة.
func set_bus_volume_linear(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("AudioManager: bus '%s' غير موجود في bus_layout.tres" % bus_name)
		return
	var clamped := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamped))
	EventBus.audio_bus_volume_changed.emit(bus_name, clamped)

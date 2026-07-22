extends Node
## GameManager
##
## المايسترو المسؤول عن حالة اللعبة العامة (Global State) ودورة حياتها على
## منصة أندرويد تحديدًا: الإيقاف المؤقت، الانتقال بين الخلفية والمقدمة
## (مهم جدًا لاستهلاك البطارية)، وزر الرجوع.
##
## هذا السكربت لا يحتوي منطق أي نظام فرعي (لا يعرف كيف تُحفظ اللعبة ولا كيف
## تُعرض القوائم) — فقط ينسّق بينها عبر EventBus. أي نظام فرعي جديد يُضاف
## لاحقًا (التقدّم، الإيكولوجي...) يسجّل حالته هنا إن احتاج التزامن مع
## الإيقاف المؤقت، دون أن يعرف GameManager تفاصيله الداخلية.

## الحالات العامة الممكنة للعبة. تُستخدم لتحديد السلوك المناسب في كل سياق
## (مثال: تجاهل ضغطات اللمس أثناء BOOTING، أو منع الإيقاف المؤقت أثناءه).
enum State {
	BOOTING,      ## شاشة الإقلاع/العرض الافتتاحي.
	MAIN_MENU,    ## في القائمة الرئيسية.
	PLAYING,      ## داخل اللعب الفعلي.
	PAUSED,       ## متوقف مؤقتًا (قائمة إيقاف، أو التطبيق في الخلفية).
}

var current_state: State = State.BOOTING:
	set(value):
		current_state = value

## هل اللعبة متوقفة مؤقتًا حاليًا (إما يدويًا أو لأن النظام أرسل التطبيق
## للخلفية). منفصل عن SceneTree.paused لنتحكم بدقة فيما يتوقف وما يستمر
## (مثال: قد نريد ترك الموسيقى تكمل أثناء إيقاف مؤقت للّعب فقط).
var is_paused: bool = false

## يصير true بعد أول تشغيل كامل ناجح لدورة الإقلاع؛ يفيد لاحقًا في تحديد
## ما إذا كانت هذه أول تجربة للمستخدم مع اللعبة.
var has_completed_first_boot: bool = false


func _ready() -> void:
	# اسم فريد لعقدة الجذر يسهّل تتبعها أثناء التطوير والتصحيح.
	name = "GameManager"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# يرسلها نظام أندرويد عندما ينتقل التطبيق فعليًا للخلفية (Home،
			# تبديل تطبيق، تعتيم الشاشة). هذه هي اللحظة الحاسمة لتقليل
			# استهلاك البطارية: نوقف اللعب فورًا ونحفظ تلقائيًا كإجراء أمان.
			_on_application_paused()
		NOTIFICATION_APPLICATION_RESUMED:
			_on_application_resumed()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# زر/إيماءة الرجوع في أندرويد. السلوك الافتراضي الآمن هنا هو
			# إشعار الواجهة الحالية عبر EventBus لتقرر بنفسها (إغلاق قائمة
			# فرعية، أو طلب تأكيد الخروج)، بدل إغلاق التطبيق فجأة دون تحذير.
			_on_back_requested()


func pause_game() -> void:
	if is_paused:
		return
	is_paused = true
	if current_state == State.PLAYING:
		current_state = State.PAUSED
	EventBus.game_pause_state_changed.emit(true)


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	if current_state == State.PAUSED:
		current_state = State.PLAYING
	EventBus.game_pause_state_changed.emit(false)


func _on_application_paused() -> void:
	pause_game()
	# حفظ احترازي فوري: لو أنهى المستخدم التطبيق فعليًا من قائمة المهام
	# الأخيرة بعد هذه اللحظة، لن يفقد تقدّمه.
	SaveManager.save_game(SaveManager.build_current_save_data())


func _on_application_resumed() -> void:
	# نترك قرار الاستئناف الفعلي (متابعة اللعب مباشرة أو إبقاء قائمة
	# الإيقاف ظاهرة) للواجهة الحالية؛ هنا فقط نُعلم بقية الأنظمة بالحدث.
	EventBus.game_pause_state_changed.emit(is_paused)


func _on_back_requested() -> void:
	get_viewport().set_input_as_handled()
	EventBus.settings_changed.emit("__back_requested__", null)

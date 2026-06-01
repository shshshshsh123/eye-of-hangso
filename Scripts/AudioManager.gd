extends Node

## ─────────────────────────────────────────────────────
##  AudioManager  (AutoLoad: "AudioManager")
##  배경음(BGM)·효과음(SFX) 볼륨을 전역으로 관리한다.
##
##  파일 위치: res://Resource/Audio/
## ─────────────────────────────────────────────────────

const SAVE_PATH := "user://hangso_audio.cfg"
const AUDIO_DIR := "res://Resource/Audio/"

# ── 사운드 파일 경로 ──────────────────────────────────
const BGM_PATH          := AUDIO_DIR + "hangso_bgm.mp3"
const SFX_BOOK_PAGE     := AUDIO_DIR + "hangso_book_page.mp3"       # 룰북 페이지이동 + 의뢰서 펼치기
const SFX_BTN_PRESSED   := AUDIO_DIR + "hangso_button_pressed.mp3"  # 승인 / 반려 버튼
const SFX_CORRECT       := AUDIO_DIR + "hangso_correct.mp3"         # 정답 결과
const SFX_FAILED        := AUDIO_DIR + "hangso_failed.mp3"          # 오답 결과
const SFX_UI            := AUDIO_DIR + "hangso_ui.mp3"              # 일반 UI 버튼 클릭

var bgm_volume: float = 1.0   ## 0.0 ~ 1.0
var sfx_volume: float = 1.0

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

# ── 미리 로드한 스트림 캐시 ──────────────────────────
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)

	load_settings()
	_apply_volumes()

	# BGM 자동 시작 (파일이 있을 때만)
	_start_bgm()

func _start_bgm() -> void:
	if ResourceLoader.exists(BGM_PATH):
		var stream := load(BGM_PATH) as AudioStream
		if stream:
			bgm_player.stream = stream
			bgm_player.play()

# ── SFX 단축 메서드 ──────────────────────────────────
func play_button_pressed()   -> void: _play_sfx_path(SFX_BTN_PRESSED)  # 승인 / 반려 버튼
func play_book_page()        -> void: _play_sfx_path(SFX_BOOK_PAGE)    # 룰북 페이지이동 + 의뢰서 펼치기
func play_correct()          -> void: _play_sfx_path(SFX_CORRECT)      # 정답
func play_failed()           -> void: _play_sfx_path(SFX_FAILED)       # 오답
func play_ui()               -> void: _play_sfx_path(SFX_UI)           # 일반 UI 버튼

func _play_sfx_path(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	if not _sfx_cache.has(path):
		_sfx_cache[path] = load(path) as AudioStream
	var stream: AudioStream = _sfx_cache[path]
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

# ── 볼륨 설정 ──────────────────────────────────────────
func set_bgm_volume(val: float) -> void:
	bgm_volume = clampf(val, 0.0, 1.0)
	bgm_player.volume_db = _to_db(bgm_volume)
	save_settings()

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	sfx_player.volume_db = _to_db(sfx_volume)
	save_settings()

func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return linear_to_db(linear)

func _apply_volumes() -> void:
	bgm_player.volume_db = _to_db(bgm_volume)
	sfx_player.volume_db = _to_db(sfx_volume)

# ── BGM 재생 ──────────────────────────────────────────
func play_bgm(stream: AudioStream) -> void:
	if stream == null:
		return
	if bgm_player.stream != stream:
		bgm_player.stream = stream
	if not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	bgm_player.stop()

# ── SFX 재생 ──────────────────────────────────────────
func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	sfx_player.stream = stream
	sfx_player.play()

# ── 저장 / 불러오기 ──────────────────────────────────
func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		bgm_volume = cfg.get_value("audio", "bgm_volume", 1.0)
		sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	else:
		bgm_volume = 1.0
		sfx_volume = 1.0

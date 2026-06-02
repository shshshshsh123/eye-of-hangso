extends Control

## ─────────────────────────────────────────────────────
##  MainMenu  (res://Scenes/MainMenu.tscn)
##  타이틀 화면: 게임시작 / 옵션 / 게임종료
##  옵션 패널: 배경음·효과음 슬라이더
## ─────────────────────────────────────────────────────

const MAIN_GAME_SCENE := "res://main_game.tscn"
const HANGSO_FONT := preload("res://Font/BMJUA_ttf.ttf")

# 세이브 초기화 확인 대화상자 (코드로 생성)
var _reset_dialog: Control = null

# ── UI 노드 참조 ──────────────────────────────────────
@onready var _high_score_label: Label   = $TitleBox/HighScoreLabel
@onready var _options_panel: Panel      = $OptionsPanel
@onready var _bgm_slider: HSlider       = $OptionsPanel/BGMRow/BGMSlider
@onready var _sfx_slider: HSlider       = $OptionsPanel/SFXRow/SFXSlider
@onready var _bgm_value_label: Label    = $OptionsPanel/BGMRow/ValueLabel
@onready var _sfx_value_label: Label    = $OptionsPanel/SFXRow/ValueLabel

func _ready() -> void:
	_options_panel.visible = false
	_refresh_high_score()

	# 슬라이더를 저장된 볼륨값으로 초기화
	_bgm_slider.value = AudioManager.bgm_volume * 100.0
	_sfx_slider.value = AudioManager.sfx_volume * 100.0
	_update_bgm_label(AudioManager.bgm_volume * 100.0)
	_update_sfx_label(AudioManager.sfx_volume * 100.0)

	_build_reset_dialog()

func _refresh_high_score() -> void:
	var hs := GameManager.high_score
	if hs > 0:
		_high_score_label.text = "최고 기록: %d점" % hs
	else:
		_high_score_label.text = "최고 기록: —"

# ── 버튼 콜백 ─────────────────────────────────────────
func _on_start_btn_pressed() -> void:
	AudioManager.play_ui()
	GameManager.reset_game()
	SceneTransition.fade_to(MAIN_GAME_SCENE)

func _on_options_btn_pressed() -> void:
	AudioManager.play_ui()
	_options_panel.visible = true

func _on_quit_btn_pressed() -> void:
	AudioManager.play_ui()
	get_tree().quit()

func _on_options_close_btn_pressed() -> void:
	AudioManager.play_ui()
	_options_panel.visible = false

## 디버그 모드 시작 — 감정 3회만에 주간 결산이 뜬다
func _on_debug_btn_pressed() -> void:
	AudioManager.play_ui()
	GameManager.reset_game(true)
	SceneTransition.fade_to(MAIN_GAME_SCENE)

# ── 세이브 초기화 ─────────────────────────────────────
## 세이브 초기화 버튼 → 확인 대화상자 표시
func _on_reset_save_btn_pressed() -> void:
	AudioManager.play_ui()
	_reset_dialog.visible = true
	_reset_dialog.move_to_front()

## 확인 대화상자에서 "초기화" 선택 시 실제 초기화 수행
func _on_reset_confirmed() -> void:
	AudioManager.play_ui()
	GameManager.reset_high_score()
	_refresh_high_score()
	_reset_dialog.visible = false

## 세이브 초기화 확인 대화상자 빌드 (BMJUA 폰트 적용을 위해 코드로 생성)
func _build_reset_dialog() -> void:
	_reset_dialog = Control.new()
	_reset_dialog.name = "ResetConfirmDialog"
	_reset_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reset_dialog.visible = false
	add_child(_reset_dialog)

	# 배경 어둡게 + 뒤쪽 클릭 차단
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_dialog.add_child(dim)

	# 중앙 패널
	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -290.0; panel.offset_top = -150.0
	panel.offset_right = 290.0; panel.offset_bottom = 150.0
	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.08, 0.06, 0.12, 0.98)
	bg.border_color = Color(0.70, 0.35, 0.35, 1.0)
	bg.set_border_width_all(3)
	for corner in [&"corner_radius_top_left", &"corner_radius_top_right",
				   &"corner_radius_bottom_left", &"corner_radius_bottom_right"]:
		bg.set(corner, 8)
	panel.add_theme_stylebox_override("panel", bg)
	_reset_dialog.add_child(panel)

	# 메시지
	var msg := Label.new()
	msg.text = "정말로 세이브를 초기화 하시겠습니까?\n최고 기록이 삭제됩니다."
	msg.add_theme_font_override("font", HANGSO_FONT)
	msg.add_theme_font_size_override("font_size", 30)
	msg.add_theme_color_override("font_color", Color(0.95, 0.90, 0.85, 1))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	msg.position = Vector2(30, 40)
	msg.size     = Vector2(520, 130)
	panel.add_child(msg)

	# 취소 버튼
	var cancel_btn := Button.new()
	cancel_btn.text = "취소"
	cancel_btn.add_theme_font_override("font", HANGSO_FONT)
	cancel_btn.add_theme_font_size_override("font_size", 28)
	cancel_btn.position = Vector2(70, 205)
	cancel_btn.size     = Vector2(180, 64)
	cancel_btn.pressed.connect(func():
		AudioManager.play_ui()
		_reset_dialog.visible = false)
	panel.add_child(cancel_btn)

	# 초기화 버튼
	var confirm_btn := Button.new()
	confirm_btn.text = "초기화"
	confirm_btn.add_theme_font_override("font", HANGSO_FONT)
	confirm_btn.add_theme_font_size_override("font_size", 28)
	confirm_btn.add_theme_color_override("font_color", Color(1, 0.55, 0.55, 1))
	confirm_btn.position = Vector2(330, 205)
	confirm_btn.size     = Vector2(180, 64)
	confirm_btn.pressed.connect(_on_reset_confirmed)
	panel.add_child(confirm_btn)

# ── 슬라이더 콜백 ─────────────────────────────────────
func _on_bgm_slider_value_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value / 100.0)
	_update_bgm_label(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value / 100.0)
	_update_sfx_label(value)

func _update_bgm_label(val: float) -> void:
	_bgm_value_label.text = "%d" % int(val)

func _update_sfx_label(val: float) -> void:
	_sfx_value_label.text = "%d" % int(val)

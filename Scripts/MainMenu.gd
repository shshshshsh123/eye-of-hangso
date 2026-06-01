extends Control

## ─────────────────────────────────────────────────────
##  MainMenu  (res://Scenes/MainMenu.tscn)
##  타이틀 화면: 게임시작 / 옵션 / 게임종료
##  옵션 패널: 배경음·효과음 슬라이더
## ─────────────────────────────────────────────────────

const MAIN_GAME_SCENE := "res://main_game.tscn"

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

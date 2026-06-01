extends Control

## ─────────────────────────────────────────────────────
##  WeeklySummary  (res://Scenes/WeeklySummary.tscn)
##  Papers Please 스타일 주간 결산 화면.
##  GameManager.pending_summary 를 읽어 표시한다.
## ─────────────────────────────────────────────────────

const MAIN_GAME_SCENE := "res://main_game.tscn"
const MAIN_MENU_SCENE := "res://Scenes/MainMenu.tscn"

# 항목이 하나씩 나타나는 연출 설정
const REVEAL_DELAY  := 0.22   # 항목 간 간격(초)
const REVEAL_TOTAL  := 0.18   # 각 항목 페이드인 시간

@onready var _week_label:      Label  = $Header/WeekLabel
@onready var _msg_label:       Label  = $MsgLabel
@onready var _items_container: VBoxContainer = $ItemsContainer
@onready var _total_label:     Label  = $TotalRow/TotalLabel
@onready var _new_high_label:  Label  = $NewHighLabel
@onready var _continue_btn:    Button = $ContinueBtn
@onready var _menu_btn:        Button = $MenuBtn

var _summary: Dictionary = {}

func _ready() -> void:
	_summary = GameManager.pending_summary
	if _summary.is_empty():
		# 데이터 없이 직접 실행한 경우 — 더미 데이터
		_summary = {
			"week": 1, "savings_before": 0,
			"correct": 5, "salary": 25,
			"incorrect": 2, "penalty": -6,
			"bonus_net": 19, "score_after": 19,
			"is_new_high": false, "high_score": 0,
		}

	_continue_btn.visible = false
	_menu_btn.visible     = false
	_new_high_label.visible = false
	_total_label.visible    = false

	# 헤더
	_week_label.text = "결말  %d주" % _summary["week"]

	# 메시지 (순이익 부호에 따라)
	if _summary["bonus_net"] > 0:
		_msg_label.text = "이번 주 성과가 좋습니다."
	elif _summary["bonus_net"] == 0:
		_msg_label.text = "이번 주는 본전이었습니다."
	else:
		_msg_label.text = "이번 주 감점이 봉급을 앞섰습니다."

	# 항목 행 생성 후 순차 표시
	_build_rows()
	_animate_rows()

# ── 항목 행 빌드 ──────────────────────────────────────
func _build_rows() -> void:
	# 기존 자식 제거
	for child in _items_container.get_children():
		child.queue_free()

	var rows: Array[Dictionary] = [
		{"label": "저  축  금",
		 "value": _summary["savings_before"],
		 "extra": ""},
		{"label": "봉  급",
		 "value": _summary["salary"],
		 "extra": "(%d건)" % _summary["correct"]},
		{"label": "감  점",
		 "value": _summary["penalty"],
		 "extra": "(%d건)" % _summary["incorrect"]},
	]

	for row_data in rows:
		var hbox := HBoxContainer.new()
		hbox.modulate = Color(1, 1, 1, 0)   # 처음엔 투명
		_items_container.add_child(hbox)

		# 왼쪽: 항목명 + 괄호
		var name_lbl := Label.new()
		var name_str: String = row_data["label"]
		if row_data["extra"] != "":
			name_str += "  " + row_data["extra"]
		name_lbl.text = name_str
		name_lbl.add_theme_font_override("font", _get_font())
		name_lbl.add_theme_font_size_override("font_size", 32)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15, 1.0))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_lbl)

		# 오른쪽: 금액
		var val_lbl := Label.new()
		val_lbl.text = _fmt_value(row_data["value"])
		val_lbl.add_theme_font_override("font", _get_font())
		val_lbl.add_theme_font_size_override("font_size", 32)
		var col: Color
		if row_data["value"] > 0:
			col = Color(0.85, 0.15, 0.15, 1.0)
		elif row_data["value"] == 0:
			col = Color(0.60, 0.55, 0.50, 1.0)
		else:
			col = Color(0.85, 0.15, 0.15, 1.0)
		val_lbl.add_theme_color_override("font_color", col)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(val_lbl)

func _fmt_value(v: int) -> String:
	if v > 0:
		return "+%d" % v
	return str(v)

func _get_font() -> FontFile:
	# BMJUA 폰트가 테마에 등록돼 있으면 사용, 없으면 null 반환 (기본 폰트)
	var theme_font = ThemeDB.get_project_theme()
	if theme_font != null:
		var f = theme_font.get_font("font", "Label")
		if f is FontFile:
			return f as FontFile
	return null

# ── 순차 표시 애니메이션 ──────────────────────────────
func _animate_rows() -> void:
	var rows := _items_container.get_children()
	var delay := 0.3
	for i in rows.size():
		var row = rows[i]
		var t := get_tree().create_tween()
		t.tween_interval(delay)
		t.tween_property(row, "modulate", Color(1, 1, 1, 1), REVEAL_TOTAL)
		delay += REVEAL_DELAY

	# 합계선 + 버튼 표시
	var finish_time := delay + 0.3
	var total_tween := get_tree().create_tween()
	total_tween.tween_interval(finish_time)
	total_tween.tween_callback(_show_total)

func _show_total() -> void:
	_total_label.visible = true
	_total_label.text = "$%d" % _summary["score_after"]

	if _summary["is_new_high"]:
		_new_high_label.visible = true

	var t := get_tree().create_tween()
	t.tween_interval(0.3)
	t.tween_callback(_show_buttons)

func _show_buttons() -> void:
	_continue_btn.visible = true
	_menu_btn.visible     = true

# ── 버튼 콜백 ─────────────────────────────────────────
func _on_continue_btn_pressed() -> void:
	AudioManager.play_ui()
	SceneTransition.fade_to(MAIN_GAME_SCENE)

func _on_menu_btn_pressed() -> void:
	AudioManager.play_ui()
	SceneTransition.fade_to(MAIN_MENU_SCENE)

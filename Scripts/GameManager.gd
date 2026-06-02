extends Node

## ─────────────────────────────────────────────────────
##  GameManager  (AutoLoad: "GameManager")
##  게임 전반의 상태·점수·저장을 담당한다.
## ─────────────────────────────────────────────────────

const SAVE_PATH := "user://hangso_save.cfg"

# ── 현재 게임 상태 (씬 전환 시에도 유지) ──────────────
var score: int = 0
var day: int = 1
var artifacts_today: int = 0
var artifacts_per_day: int = 5
var week_number: int = 1

# ── 디버그 모드 ───────────────────────────────────────
## true 이면 감정 DEBUG_ARTIFACTS_PER_WEEK회 만에 주간 결산이 나온다.
var debug_mode: bool = false
const DEBUG_ARTIFACTS_PER_WEEK := 3

# ── 주간 통계 ─────────────────────────────────────────
var weekly_correct: int = 0
var weekly_incorrect: int = 0

# ── 최고 점수 ─────────────────────────────────────────
var high_score: int = 0

# ── 주간 결산용 스냅샷 (WeeklySummary 씬에서 읽음) ────
var pending_summary: Dictionary = {}

signal high_score_updated(new_high: int)

func _ready() -> void:
	load_data()

# ── 게임 초기화 ──────────────────────────────────────
func reset_game(debug: bool = false) -> void:
	score         = 0
	day           = 1
	artifacts_today = 0
	week_number   = 1
	weekly_correct   = 0
	weekly_incorrect = 0
	pending_summary  = {}
	debug_mode       = debug

# ── 판정 결과 반영 ───────────────────────────────────
## correct=true → +10, false → -5
func apply_judgment(correct: bool) -> void:
	if correct:
		score += 10
		weekly_correct += 1
	else:
		score -= 5
		weekly_incorrect += 1
	score = max(score, 0)

# ── 유물 처리 후 일수 진행 ────────────────────────────
## Returns true 이면 이번 주 7일이 막 완료됨 → WeeklySummary 표시
func advance_artifact() -> bool:
	# ── 디버그 모드: 감정 N회만에 주간 결산 ───────────────
	# weekly_correct + weekly_incorrect == 이번 주 누적 감정 횟수
	if debug_mode:
		if (weekly_correct + weekly_incorrect) >= DEBUG_ARTIFACTS_PER_WEEK:
			artifacts_today = 0
			day = week_number * 7 + 1   # 점수바가 다음 주로 표시되도록 보정
			_build_weekly_summary()
			return true
		return false

	artifacts_today += 1
	if artifacts_today >= artifacts_per_day:
		artifacts_today = 0
		day += 1
		# 방금 끝난 날이 7의 배수(7일, 14일, …)면 주간 결산
		if (day - 1) % 7 == 0:
			_build_weekly_summary()
			return true
	return false

# ── 주간 결산 데이터 생성 ─────────────────────────────
func _build_weekly_summary() -> void:
	# 봉급: 정답 1건당 +5
	var salary    := weekly_correct * 5
	# 벌금: 오답 1건당 -3
	var penalty   := weekly_incorrect * 3
	# 주간 순이익
	var bonus_net := salary - penalty

	var savings_before := score
	score = max(score + bonus_net, 0)

	# 최고 점수 갱신
	var is_new_high := false
	if score > high_score:
		high_score = score
		save_data()
		is_new_high = true
		emit_signal("high_score_updated", high_score)

	pending_summary = {
		"week":           week_number,
		"savings_before": savings_before,
		"correct":        weekly_correct,
		"salary":         salary,
		"incorrect":      weekly_incorrect,
		"penalty":        -penalty,
		"bonus_net":      bonus_net,
		"score_after":    score,
		"is_new_high":    is_new_high,
		"high_score":     high_score,
	}

	# 다음 주 준비
	week_number     += 1
	weekly_correct   = 0
	weekly_incorrect = 0

# ── 저장 / 불러오기 ──────────────────────────────────
func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "high_score", high_score)
	cfg.save(SAVE_PATH)

func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = cfg.get_value("scores", "high_score", 0)
	else:
		high_score = 0

func reset_high_score() -> void:
	high_score = 0
	save_data()

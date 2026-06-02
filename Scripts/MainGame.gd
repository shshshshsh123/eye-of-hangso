extends Control

# ──────────────────────────────────────────────
# 데이터
# ──────────────────────────────────────────────
const TxtPath = "res://Data/ArtifactData.txt"
var ArtifactList: Array[ArtifactData] = []
var currentArtifact: Dictionary = {}

const WEEKLY_SUMMARY_SCENE := "res://Scenes/WeeklySummary.tscn"
const MAIN_MENU_SCENE      := "res://Scenes/MainMenu.tscn"
const HANGSO_FONT          := preload("res://Font/BMJUA_ttf.ttf")

# ──────────────────────────────────────────────
# 게임 상태 (GameManager에 위임, 로컬 미러만 유지)
# ──────────────────────────────────────────────
var waiting_for_next: bool = false

# 편의 프로퍼티 — GameManager 값을 바로 읽음
var score: int:
	get: return GameManager.score
var day: int:
	get: return GameManager.day

# ──────────────────────────────────────────────
# UI 노드 참조
# ──────────────────────────────────────────────
# 의뢰서 패널
@onready var CommissionPanel: Panel           = $CommissionPanel
@onready var CommissionContent: RichTextLabel = $CommissionPanel/CommissionContent
@onready var InspectButton: Button            = $CommissionPanel/InspectButton
@onready var CommissionCloseButton: Button    = $CommissionPanel/CloseButton

# 실물 검사 팝업
@onready var InspectPopup: Panel              = $InspectPopup
@onready var InspectImage: TextureRect        = $InspectPopup/InspectImage
@onready var InspectCloseBtn: Button          = $InspectPopup/InspectCloseBtn

# 점수 바
@onready var DayLabel: Label                  = $ScoreBar/DayLabel
@onready var ScoreLabel: Label                = $ScoreBar/ScoreLabel

# 결과 팝업
@onready var ResultPopup: Panel               = $ResultPopup
@onready var ResultContent: RichTextLabel     = $ResultPopup/ResultContent
@onready var NextArtifactBtn: Button          = $ResultPopup/NextArtifactBtn

# 튜토리얼에서 강조할 버튼·이미지
@onready var CommissionButton: Button         = $CommissionButton
@onready var RuleBookButton: Button           = $RuleBookButton
@onready var ApproveImg: TextureRect          = $ApproveImg
@onready var RejectImg: TextureRect           = $RejectImg

# 룰북 UI
@onready var RuleBookUI: Control              = $RuleBookUI
@onready var BookBackground: TextureRect      = $RuleBookUI/BookBackground
@onready var ContentLabel1: RichTextLabel     = $RuleBookUI/ContentLabel1
@onready var ContentLabel2: RichTextLabel     = $RuleBookUI/ContentLabel2
@onready var PrevButton: TextureButton        = $RuleBookUI/PrevButton
@onready var NextButton: TextureButton        = $RuleBookUI/NextButton
@onready var CloseButton: Button              = $RuleBookUI/CloseButton

var manual_pages: Array[String] = []
var manual_page_artifacts: Array = []
var current_page_index: int = 0

# ──────────────────────────────────────────────
# 드래그 상태
# ──────────────────────────────────────────────
var _dragging_commission: bool = false
var _commission_drag_offset: Vector2 = Vector2.ZERO
var _dragging_rulebook: bool = false
var _rulebook_drag_offset: Vector2 = Vector2.ZERO
var _dragging_inspect: bool = false
var _inspect_drag_offset: Vector2 = Vector2.ZERO

# ──────────────────────────────────────────────
# 인게임 옵션 패널 (ESC로 열고 닫기)
# ──────────────────────────────────────────────
var _ingame_options:   Panel  = null
var _igopt_bgm_slider: HSlider = null
var _igopt_sfx_slider: HSlider = null
var _igopt_bgm_val:   Label  = null
var _igopt_sfx_val:   Label  = null

# ──────────────────────────────────────────────
# 튜토리얼 (디버그 모드에서는 실행 안 함)
# ──────────────────────────────────────────────
enum TutStep { COMMISSION, RULEBOOK, PAGEFLIP, ARRANGE, INSPECT, INSPECT_CLOSE, JUDGE }
var _tut_active: bool = false
var _tut_step: int = 0
var _tut_block_input: bool = false          # true면 게임 측 드래그/입력 차단
var _tut_target_rect: Rect2 = Rect2()       # 현재 클릭 허용 영역(빨간 박스)
var _tut_layer: CanvasLayer = null
var _tut_root: Control = null               # 전체 클릭 차단막
var _tut_dim: Array = []                     # 스포트라이트용 4분할 어둠막
var _tut_box: ReferenceRect = null          # 강조 빨간 박스(주 대상)
var _tut_box2: ReferenceRect = null         # 보조 빨간 박스(반려 버튼)
var _tut_msg: Label = null
var _tut_next_btn: Button = null
var _tut_skip_btn: Button = null

# ──────────────────────────────────────────────
# 인트로 스토리 (튜토리얼 직전 1회)
# ──────────────────────────────────────────────
var _story_layer: CanvasLayer = null
var _story_root: Control = null
var _story_img: TextureRect = null
var _story_label: Label = null
var _story_next_btn: Button = null
var _story_index: int = 0
var _story_slides: Array = []

# ──────────────────────────────────────────────
# 초기화
# ──────────────────────────────────────────────
func _ready() -> void:
	CommissionContent.scroll_active = false
	ResultContent.scroll_active = false

	InspectImage.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	InspectImage.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE

	# 의뢰서 패널: 이미지 배경 사용 → Panel 기본 배경 제거
	$CommissionPanel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# 결과 팝업
	var result_bg = StyleBoxFlat.new()
	result_bg.bg_color     = Color(0.10, 0.08, 0.14, 0.97)
	result_bg.border_color = Color(0.55, 0.45, 0.70, 1.0)
	result_bg.set_border_width_all(3)
	result_bg.corner_radius_top_left     = 6
	result_bg.corner_radius_top_right    = 6
	result_bg.corner_radius_bottom_left  = 6
	result_bg.corner_radius_bottom_right = 6
	$ResultPopup.add_theme_stylebox_override("panel", result_bg)

	# 실물 검사 팝업
	var inspect_bg = StyleBoxFlat.new()
	inspect_bg.bg_color     = Color(0.05, 0.05, 0.08, 0.97)
	inspect_bg.border_color = Color(0.60, 0.50, 0.30, 1.0)
	inspect_bg.set_border_width_all(3)
	inspect_bg.corner_radius_top_left     = 8
	inspect_bg.corner_radius_top_right    = 8
	inspect_bg.corner_radius_bottom_left  = 8
	inspect_bg.corner_radius_bottom_right = 8
	$InspectPopup.add_theme_stylebox_override("panel", inspect_bg)

	# 점수바
	var score_bg = StyleBoxFlat.new()
	score_bg.bg_color     = Color(0.08, 0.08, 0.12, 0.88)
	score_bg.border_color = Color(0.40, 0.40, 0.50, 1.0)
	score_bg.set_border_width_all(1)
	score_bg.corner_radius_top_left     = 4
	score_bg.corner_radius_top_right    = 4
	score_bg.corner_radius_bottom_left  = 4
	score_bg.corner_radius_bottom_right = 4
	$ScoreBar.add_theme_stylebox_override("panel", score_bg)

	DayLabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	ScoreLabel.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	LoadArtifactDataFromTXT()
	InitializeRuleBook()
	UpdateScoreBar()
	ShowNextArtifact()
	_build_ingame_options()
	_maybe_start_intro()

# ──────────────────────────────────────────────
# 데이터 로드 (CSV 파싱)
# ──────────────────────────────────────────────
func LoadArtifactDataFromTXT() -> void:
	if not FileAccess.file_exists(TxtPath):
		printerr("TXT 파일을 찾을 수 없습니다: ", TxtPath)
		return

	var file = FileAccess.open(TxtPath, FileAccess.READ)
	var _headers = file.get_csv_line()

	while not file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 9:
			continue

		var newArtifact = ArtifactData.new()
		newArtifact.Id               = row[0]
		newArtifact.ArtifactName     = row[1]
		newArtifact.CorrectMaterial  = ArtifactData.EMaterial.get(row[2], 0)
		newArtifact.CorrectSignature = ArtifactData.ESignature.get(row[3], 0)
		newArtifact.CorrectType      = ArtifactData.EType.get(row[4], 0)
		newArtifact.CorrectColor     = ArtifactData.EColor.get(row[5], 0)
		newArtifact.CorrectRarity    = ArtifactData.ERarity.get(row[6], 0)
		newArtifact.CorrectOrigin    = ArtifactData.EOrigin.get(row[7], 0)
		newArtifact.CorrectCondition = ArtifactData.ECondition.get(row[8], 0)
		if row.size() >= 10:
			newArtifact.SpecialRule  = ArtifactData.ESpecialRule.get(row[9], 0)

		var artifact_idx = ArtifactList.size()
		var tres_path = "res://Resource/Artifact/AtlasTextures/artifact_%02d.tres" % artifact_idx
		var atlas = load(tres_path) as AtlasTexture
		if atlas != null:
			newArtifact.ArtifactImage = atlas
		else:
			printerr("AtlasTexture 로드 실패: ", tres_path)

		ArtifactList.append(newArtifact)

	print("데이터 로드 완료. 총 유물: ", ArtifactList.size())

	# 데이터 무결성 검사 — 의도된 함정 외에 규칙 위반이 있으면 경고 출력
	for art in ArtifactList:
		var probe := {
			"material": art.CorrectMaterial, "signature": art.CorrectSignature,
			"type": art.CorrectType, "color": art.CorrectColor,
			"rarity": art.CorrectRarity, "origin": art.CorrectOrigin,
			"condition": art.CorrectCondition, "specialRule": art.SpecialRule,
		}
		var chk := _evaluate_validity(probe)
		if not chk["valid"]:
			print("[데이터 검증] 규칙 위반/함정: %s (%s) — %s" % [art.Id, art.ArtifactName, chk["reason"]])

# ──────────────────────────────────────────────
# 통합 규칙 검증 (모든 합법성 판단의 단일 기준)
# ──────────────────────────────────────────────
# 의뢰서에 표시되는 속성만으로 규칙 위반 여부를 판정한다.
# (이미지-품명 불일치 위조는 여기서 다루지 않고 별도 처리)
# 반환: { "valid": bool, "reason": String }
func _evaluate_validity(a: Dictionary) -> Dictionary:
	var mat  = a["material"]
	var sig  = a["signature"]
	var typ  = a["type"]
	var col  = a["color"]
	var rar  = a["rarity"]
	var ori  = a["origin"]
	var cond = a["condition"]
	var sr   = a["specialRule"]

	# R2: 위조 마크 — 무조건 거부
	if sig == ArtifactData.ESignature.FAKE_MARK:
		return _invalid("위조 마크(FAKE_MARK) 발견 — 즉시 거부")

	# R1: 출처별 공식 각인 규정 (NONE/CURSE 각인은 어느 출처든 허용)
	if ori == ArtifactData.EOrigin.ROYAL_CAPITAL:
		if sig == ArtifactData.ESignature.ARTISAN:
			return _invalid("왕도(ROYAL_CAPITAL) 출처에 장인(ARTISAN) 각인 — 왕실 전용")
	elif ori == ArtifactData.EOrigin.DWARF_MINE:
		if sig == ArtifactData.ESignature.ROYAL:
			return _invalid("드워프 광산(DWARF_MINE) 출처에 왕실(ROYAL) 각인 — 장인 전용")
	elif ori == ArtifactData.EOrigin.ELF_FOREST:
		if sig == ArtifactData.ESignature.ROYAL:
			return _invalid("엘프 숲(ELF_FOREST) 출처에 왕실(ROYAL) 각인 — 장인 전용")
	elif ori == ArtifactData.EOrigin.UNKNOWN:
		if sig == ArtifactData.ESignature.ROYAL or sig == ArtifactData.ESignature.ARTISAN:
			return _invalid("출처 미상(UNKNOWN)에 공식 각인 — 인증 기관 위조")

	# R3: 출처별 재질 규정
	if ori == ArtifactData.EOrigin.ROYAL_CAPITAL:
		if mat == ArtifactData.EMaterial.WOOD or mat == ArtifactData.EMaterial.BONE:
			return _invalid("왕도(ROYAL_CAPITAL) 반출 금지 재질(나무/뼈)")
	elif ori == ArtifactData.EOrigin.DWARF_MINE:
		if not (mat == ArtifactData.EMaterial.IRON or mat == ArtifactData.EMaterial.GOLD \
			or mat == ArtifactData.EMaterial.SILVER or mat == ArtifactData.EMaterial.STONE):
			return _invalid("드워프 광산(DWARF_MINE) 비허용 재질 — 금속·돌만 허용")
	elif ori == ArtifactData.EOrigin.ELF_FOREST:
		if mat == ArtifactData.EMaterial.IRON or mat == ArtifactData.EMaterial.GOLD \
			or mat == ArtifactData.EMaterial.SILVER:
			return _invalid("엘프 숲(ELF_FOREST) 금속 재질 불가")

	# R5: 물약은 유리 용기 필수
	if typ == ArtifactData.EType.POTION and mat != ArtifactData.EMaterial.GLASS:
		return _invalid("물약(POTION)인데 유리(GLASS) 용기가 아님")

	# R6: 전설 등급은 왕실 각인 전용
	if rar == ArtifactData.ERarity.LEGENDARY and sig != ArtifactData.ESignature.ROYAL:
		return _invalid("전설(LEGENDARY) 등급인데 왕실(ROYAL) 각인이 아님")

	# R8(신규): 전설 등급은 왕도 출처 전용
	if rar == ArtifactData.ERarity.LEGENDARY and ori != ArtifactData.EOrigin.ROYAL_CAPITAL:
		return _invalid("전설(LEGENDARY) 등급인데 왕도(ROYAL_CAPITAL) 출처가 아님")

	# R9(신규): 저주 각인은 보라색이어야 함
	if sig == ArtifactData.ESignature.CURSE and col != ArtifactData.EColor.PURPLE:
		return _invalid("저주(CURSE) 각인인데 색상이 보라(PURPLE)가 아님")

	# R4: 마력 상태 규정
	if cond == ArtifactData.ECondition.DEPLETED:
		if typ == ArtifactData.EType.WEAPON or typ == ArtifactData.EType.POTION:
			return _invalid("소진(DEPLETED) 상태의 무기/물약 — 매입 불가")
	elif cond == ArtifactData.ECondition.CORRUPTED:
		if sig != ArtifactData.ESignature.CURSE:
			return _invalid("오염(CORRUPTED) 상태인데 저주(CURSE) 각인이 없음")

	# R7: 유물 전용 특이 규칙
	if sr == ArtifactData.ESpecialRule.MUST_BE_ACTIVE:
		if cond != ArtifactData.ECondition.ACTIVE:
			return _invalid("[규칙 위반] 마력 상태 ACTIVE 필수 유물")
	elif sr == ArtifactData.ESpecialRule.MUST_BE_ARTISAN:
		if sig != ArtifactData.ESignature.ARTISAN:
			return _invalid("[규칙 위반] 장인(ARTISAN) 각인 필수 유물")
	elif sr == ArtifactData.ESpecialRule.MUST_BE_ROYAL:
		if sig != ArtifactData.ESignature.ROYAL:
			return _invalid("[규칙 위반] 왕실(ROYAL) 각인 필수 유물")
	elif sr == ArtifactData.ESpecialRule.MUST_HAVE_CURSE:
		if sig != ArtifactData.ESignature.CURSE:
			return _invalid("[규칙 위반] 저주(CURSE) 각인 필수 유물")

	return { "valid": true, "reason": "" }

func _invalid(reason: String) -> Dictionary:
	return { "valid": false, "reason": reason }

# ──────────────────────────────────────────────
# 위조품 생성 로직 (기믹 0~14, 일수 기반 가중치)
# ──────────────────────────────────────────────

# 일수에 따른 기믹 가중치 테이블 반환
# 높은 가중치 = 더 자주 등장. 일수가 오를수록 어려운 기믹 비중 증가.
func _build_gimmick_weights(base: ArtifactData) -> Dictionary:
	var w: Dictionary = {}

	# ── 기본 기믹 (1일차부터) ─────────────────────────────
	w[0]  = 10                          # 출처-서명 불일치
	w[1]  = 10                          # 상태-분류 모순
	w[2]  = 10                          # 재질 속이기
	w[3]  = 8                           # 저주 은폐
	w[4]  = max(1, 16 - day * 2)        # 조잡한 FAKE_MARK — 초반엔 쉬워서 높음, 점감
	w[6]  = max(2, 14 - day * 2)        # 이미지 교체 쉬운 버전(다른 type) — 점감
	w[7]  = 8                           # 전설 등급 + ARTISAN 각인
	w[8]  = 8                           # 엘프 숲 + 금속 재질
	w[10] = 8                           # 왕도 + 금지 재질
	w[11] = 8                           # 드워프 + 비허용 재질

	# ── 조건부 기믹 ───────────────────────────────────────
	if base.SpecialRule != ArtifactData.ESpecialRule.NONE:
		w[5] = 10                       # 유물 전용 규칙 위반

	if base.CorrectType == ArtifactData.EType.POTION:
		w[9] = 8                        # 물약 + 유리 아님

	# ── 2일차 이후 해금 ───────────────────────────────────
	if day >= 2:
		w[12] = min(15, (day - 1) * 4)  # 미상 출처 + 공식 각인

	# ── 3일차 이후 해금 (고난이도) ────────────────────────
	if day >= 3:
		w[13] = min(15, (day - 2) * 4)  # 복합 위조
		w[14] = min(15, (day - 2) * 3)  # 동일 분류 이미지 교체

	# ── 신규 규칙 기믹 ────────────────────────────────────
	w[16] = 7                           # 저주 각인 색상 위조 (R9)
	if day >= 2:
		w[15] = min(12, day * 3)        # 전설 등급 출처 위조 (R8)

	return w

# 가중치 Dictionary에서 랜덤 기믹 ID 추출
func _pick_weighted_gimmick(weights: Dictionary) -> int:
	var total := 0
	for v in weights.values():
		total += v
	var roll := randi() % total
	var cumul := 0
	for id in weights:
		cumul += weights[id]
		if roll < cumul:
			return id
	return weights.keys()[0]

const IMAGE_GIMMICKS := [6, 14]   # 이미지-품명 불일치 위조 (속성 검증 제외)

func GenerateRandomArtifact() -> Dictionary:
	if ArtifactList.is_empty():
		return {}

	var base = ArtifactList.pick_random()
	var genuine := {
		"name":        base.ArtifactName,
		"image":       base.ArtifactImage,
		"isGenuine":   true,
		"fakeReason":  "",
		"material":    base.CorrectMaterial,
		"signature":   base.CorrectSignature,
		"type":        base.CorrectType,
		"color":       base.CorrectColor,
		"rarity":      base.CorrectRarity,
		"origin":      base.CorrectOrigin,
		"condition":   base.CorrectCondition,
		"specialRule": base.SpecialRule,
	}

	# ── 진품 경로 ────────────────────────────────────────
	# 데이터 자체가 규칙을 위반하는 의도된 함정은 위조로 처리
	if randf() <= 0.5:
		var gv := _evaluate_validity(genuine)
		if not gv["valid"]:
			genuine["isGenuine"]  = false
			genuine["fakeReason"] = gv["reason"]
		return genuine

	# ── 위조 경로 ────────────────────────────────────────
	# 기믹 적용 후 실제 규칙 위반이 생겼을 때만 채택(감지 불가 위조 방지)
	var weights := _build_gimmick_weights(base)
	for _attempt in range(8):
		var result := genuine.duplicate()
		result["isGenuine"] = false
		var gimmick := _pick_weighted_gimmick(weights)

		match gimmick:
			# ────────────────────────────────────────────────
			# 기본 기믹 (0~9)
			# ────────────────────────────────────────────────
			0: # 출처-서명 불일치
				if result["origin"] == ArtifactData.EOrigin.ROYAL_CAPITAL:
					result["signature"] = ArtifactData.ESignature.ARTISAN
					result["fakeReason"] = "출처(왕도)와 각인(장인) 불일치"
				elif result["origin"] == ArtifactData.EOrigin.DWARF_MINE:
					result["signature"] = ArtifactData.ESignature.ROYAL
					result["fakeReason"] = "출처(드워프 광산)와 각인(왕실) 불일치"
				else:
					result["signature"] = ArtifactData.ESignature.FAKE_MARK
					result["fakeReason"] = "허가되지 않은 위조 각인 발견"

			1: # 상태-분류 모순
				if result["type"] == ArtifactData.EType.WEAPON or result["type"] == ArtifactData.EType.POTION:
					result["condition"] = ArtifactData.ECondition.DEPLETED
					result["fakeReason"] = "무기/물약의 마력이 소진됨(DEPLETED) — 매입 불가"
				else:
					result["condition"] = ArtifactData.ECondition.CORRUPTED
					result["fakeReason"] = "마력 오염(CORRUPTED) — 즉시 파기 대상"

			2: # 재질 속이기
				if result["material"] == ArtifactData.EMaterial.IRON or result["material"] == ArtifactData.EMaterial.SILVER:
					result["material"] = ArtifactData.EMaterial.WOOD
					result["fakeReason"] = "외형과 서류의 재질 불일치 (나무로 위장됨)"
				else:
					result["material"] = ArtifactData.EMaterial.GLASS
					result["fakeReason"] = "외형과 서류의 재질 불일치 (유리로 위장됨)"

			3: # 저주 은폐 — CORRUPTED인데 ROYAL 각인으로 위장
				result["condition"] = ArtifactData.ECondition.CORRUPTED
				result["signature"] = ArtifactData.ESignature.ROYAL
				result["fakeReason"] = "오염(CORRUPTED) 상태임에도 저주 각인 누락"

			4: # 조잡한 위조 마크
				result["signature"] = ArtifactData.ESignature.FAKE_MARK
				result["fakeReason"] = "조잡한 위조 마크(FAKE_MARK) 발견"

			5: # 유물별 전용 규칙 위반
				match base.SpecialRule:
					ArtifactData.ESpecialRule.MUST_BE_ACTIVE:
						result["condition"] = ArtifactData.ECondition.DEPLETED
						result["fakeReason"] = "[규칙 위반] 마력 상태 ACTIVE 필수인 유물이 DEPLETED 상태"
					ArtifactData.ESpecialRule.MUST_BE_ARTISAN:
						result["signature"] = ArtifactData.ESignature.FAKE_MARK
						result["fakeReason"] = "[규칙 위반] ARTISAN 각인 필수인 유물에 위조 마크 발견"
					ArtifactData.ESpecialRule.MUST_BE_ROYAL:
						result["signature"] = ArtifactData.ESignature.ARTISAN
						result["fakeReason"] = "[규칙 위반] ROYAL 각인 필수인 유물에 ARTISAN 각인"
					ArtifactData.ESpecialRule.MUST_HAVE_CURSE:
						result["signature"] = ArtifactData.ESignature.NONE
						result["fakeReason"] = "[규칙 위반] CURSE 각인 필수인 유물에 각인 누락"
					_:
						result["signature"] = ArtifactData.ESignature.FAKE_MARK
						result["fakeReason"] = "조잡한 위조 마크(FAKE_MARK) 발견"

			6: # 이미지 교체 — 다른 분류(type) 이미지로 교체 (쉬운 버전)
				var other6 = ArtifactList.pick_random()
				var att6 := 0
				while other6.CorrectType == base.CorrectType and att6 < 15:
					other6 = ArtifactList.pick_random()
					att6 += 1
				result["image"] = other6.ArtifactImage
				result["fakeReason"] = "실물 검사 결과 의뢰서 품명과 외형 불일치"

			7: # 전설 등급인데 왕실 각인 없음
				result["rarity"] = ArtifactData.ERarity.LEGENDARY
				result["signature"] = ArtifactData.ESignature.ARTISAN
				result["fakeReason"] = "전설(LEGENDARY) 등급임에도 왕실(ROYAL) 각인 없음"

			8: # 엘프 숲 출처인데 금속 재질
				result["origin"] = ArtifactData.EOrigin.ELF_FOREST
				result["material"] = ArtifactData.EMaterial.IRON
				result["signature"] = ArtifactData.ESignature.ARTISAN
				result["fakeReason"] = "엘프 숲(ELF_FOREST) 출처인데 금속(IRON) 재질 — 출처 위조"

			9: # 물약인데 유리 재질 아님 (POTION 전용)
				result["material"] = ArtifactData.EMaterial.IRON
				result["fakeReason"] = "물약(POTION)임에도 유리(GLASS) 재질이 아님 — 용기 위조"

			# ────────────────────────────────────────────────
			# 심화 기믹 (10~14)
			# ────────────────────────────────────────────────
			10: # 왕도 출처 + 금지 재질 (WOOD / BONE)
				result["origin"]    = ArtifactData.EOrigin.ROYAL_CAPITAL
				result["signature"] = ArtifactData.ESignature.ROYAL  # 각인만 맞춰 단일 위반
				var forbidden10: Array = [ArtifactData.EMaterial.WOOD, ArtifactData.EMaterial.BONE]
				result["material"] = forbidden10[randi() % forbidden10.size()]
				var mat10 := "나무(WOOD)" if result["material"] == ArtifactData.EMaterial.WOOD else "뼈(BONE)"
				result["fakeReason"] = "왕도(ROYAL_CAPITAL) 출처인데 반출 금지 재질(" + mat10 + ")"

			11: # 드워프 광산 출처 + 비허용 재질 (LEATHER / GLASS / WOOD)
				result["origin"]    = ArtifactData.EOrigin.DWARF_MINE
				result["signature"] = ArtifactData.ESignature.ARTISAN  # 각인만 맞춰 단일 위반
				var forbidden11: Array = [
					ArtifactData.EMaterial.LEATHER,
					ArtifactData.EMaterial.GLASS,
					ArtifactData.EMaterial.WOOD,
				]
				result["material"] = forbidden11[randi() % forbidden11.size()]
				var mat11_map := {
					ArtifactData.EMaterial.LEATHER: "가죽(LEATHER)",
					ArtifactData.EMaterial.GLASS:   "유리(GLASS)",
					ArtifactData.EMaterial.WOOD:    "나무(WOOD)",
				}
				result["fakeReason"] = "드워프 광산(DWARF_MINE) 출처인데 비허용 재질(" \
					+ mat11_map[result["material"]] + ")"

			12: # 미상(UNKNOWN) 출처 + 공식 각인 (2일차~)
				result["origin"] = ArtifactData.EOrigin.UNKNOWN
				var official12: Array = [
					ArtifactData.ESignature.ROYAL,
					ArtifactData.ESignature.ARTISAN,
				]
				result["signature"] = official12[randi() % official12.size()]
				var sig12 := "왕실(ROYAL)" if result["signature"] == ArtifactData.ESignature.ROYAL \
					else "장인(ARTISAN)"
				result["fakeReason"] = "출처 미상(UNKNOWN)인데 공식 각인(" + sig12 + ") — 인증 기관 위조"

			13: # 복합 위조 — 두 가지 규칙 동시 위반 (3일차~)
				var sub13 := randi() % 3
				match sub13:
					0: # 엘프 숲 + 금속 재질 AND 마력 오염
						result["origin"]    = ArtifactData.EOrigin.ELF_FOREST
						result["material"]  = ArtifactData.EMaterial.IRON
						result["signature"] = ArtifactData.ESignature.ARTISAN
						result["condition"] = ArtifactData.ECondition.CORRUPTED
						result["fakeReason"] = "[복합 위조] 엘프 숲+금속 재질 AND 마력 오염(CORRUPTED)"
					1: # 전설 등급 + ARTISAN 각인 AND 미상 출처 + 공식 각인
						result["rarity"]    = ArtifactData.ERarity.LEGENDARY
						result["signature"] = ArtifactData.ESignature.ARTISAN
						result["origin"]    = ArtifactData.EOrigin.UNKNOWN
						result["fakeReason"] = "[복합 위조] 전설+ARTISAN 각인 AND 출처 미상+공식 각인"
					2: # 재질 불일치 AND 마력 오염
						result["material"] = ArtifactData.EMaterial.WOOD \
							if result["material"] != ArtifactData.EMaterial.WOOD \
							else ArtifactData.EMaterial.GLASS
						result["condition"] = ArtifactData.ECondition.CORRUPTED
						result["fakeReason"] = "[복합 위조] 재질 불일치 AND 마력 오염(CORRUPTED)"

			14: # 이미지 교체 강화판 — 같은 분류(type)이지만 다른 유물 외형 (3일차~)
				var same_type: Array = ArtifactList.filter(
					func(a: ArtifactData) -> bool:
						return a.CorrectType == base.CorrectType and a != base
				)
				if same_type.is_empty():
					# 같은 type 후보 없으면 다른 type으로 fallback
					var other14 = ArtifactList.pick_random()
					var att14 := 0
					while other14.CorrectType == base.CorrectType and att14 < 15:
						other14 = ArtifactList.pick_random()
						att14 += 1
					result["image"] = other14.ArtifactImage
				else:
					same_type.shuffle()
					result["image"] = same_type[0].ArtifactImage
				result["fakeReason"] = "실물 검사 결과 의뢰서 품명과 외형 불일치 (동일 분류 내 교체)"

			15: # 전설 등급 위장 — 왕도 출처가 아님 (R8)
				result["rarity"]    = ArtifactData.ERarity.LEGENDARY
				result["signature"] = ArtifactData.ESignature.ROYAL
				var leg_origins: Array = [
					ArtifactData.EOrigin.DWARF_MINE,
					ArtifactData.EOrigin.ELF_FOREST,
					ArtifactData.EOrigin.UNKNOWN,
				]
				result["origin"] = leg_origins[randi() % leg_origins.size()]
				result["fakeReason"] = "전설(LEGENDARY) 등급인데 왕도(ROYAL_CAPITAL) 출처가 아님"

			16: # 저주 각인 색상 위조 — 보라색이 아님 (R9)
				result["signature"] = ArtifactData.ESignature.CURSE
				var non_purple16: Array = [
					ArtifactData.EColor.RED,
					ArtifactData.EColor.BLUE,
					ArtifactData.EColor.GREEN,
					ArtifactData.EColor.BLACK,
				]
				result["color"] = non_purple16[randi() % non_purple16.size()]
				result["fakeReason"] = "저주(CURSE) 각인인데 색상이 보라(PURPLE)가 아님"

		# ── 위조 결과 검증 ───────────────────────────────
		# 이미지 위조는 실물 검사로만 감지 → 그대로 채택
		if gimmick in IMAGE_GIMMICKS:
			return result
		# 속성 위조는 실제 규칙 위반이 생겼을 때만 채택, 아니면 재시도
		if not _evaluate_validity(result)["valid"]:
			return result

	# ── 폴백: 어떤 기믹도 규칙 위반을 만들지 못함 → 확실한 위조 ──
	var fb := genuine.duplicate()
	fb["isGenuine"]  = false
	fb["signature"]  = ArtifactData.ESignature.FAKE_MARK
	fb["fakeReason"] = "조잡한 위조 마크(FAKE_MARK) 발견"
	return fb

# ──────────────────────────────────────────────
# 다음 유물 표시
# ──────────────────────────────────────────────
func ShowNextArtifact() -> void:
	currentArtifact = GenerateRandomArtifact()
	if currentArtifact.is_empty():
		return

	InspectPopup.visible = false
	UpdateCommissionPanel()
	ResultPopup.visible = false
	waiting_for_next = false

	print("유물: %s | 진품: %s" % [currentArtifact["name"], currentArtifact["isGenuine"]])

# ──────────────────────────────────────────────
# 의뢰서 패널 업데이트
# ──────────────────────────────────────────────
func UpdateCommissionPanel() -> void:
	if currentArtifact.is_empty():
		return

	var mat_names    = ["금(GOLD)", "은(SILVER)", "철(IRON)", "나무(WOOD)", "돌(STONE)", "가죽(LEATHER)", "유리(GLASS)", "뼈(BONE)"]
	var sig_names    = ["왕실 인장(ROYAL)", "장인 인장(ARTISAN)", "위조 마크(FAKE_MARK)", "각인 없음(NONE)", "저주 각인(CURSE)"]
	var type_names   = ["무기(WEAPON)", "방어구(ARMOR)", "물약(POTION)", "도구(TOOL)", "장신구(ACCESSORY)", "기타(MISC)"]
	var color_names  = ["빨강(RED)", "파랑(BLUE)", "초록(GREEN)", "보라(PURPLE)", "금색(GOLD)", "은색(SILVER)", "검정(BLACK)"]
	var rarity_names = ["일반(COMMON)", "고급(UNCOMMON)", "희귀(RARE)", "서사(EPIC)", "[color=#cc00cc]전설(LEGENDARY)[/color]"]
	var origin_names = ["왕도(ROYAL_CAPITAL)", "드워프 광산(DWARF_MINE)", "엘프 숲(ELF_FOREST)", "미상(UNKNOWN)"]
	var cond_names   = ["활성(ACTIVE)", "소진(DEPLETED)", "오염(CORRUPTED)"]
	var cond_colors  = ["#005500", "#cc6600", "#cc0000"]

	var t = "[color=#111111]"
	t += "[center][font_size=26][b][ 유물 의뢰서 ][/b][/font_size][/center]\n"
	t += "[center][color=#999999]━━━━━━━━━━━━━━━━━━[/color][/center]\n\n"
	t += "[center][font_size=24][b]" + currentArtifact["name"] + "[/b][/font_size][/center]\n\n"
	t += "[center][color=#999999]──────────────────[/color][/center]\n\n"
	t += "[font_size=22]"
	t += "[center][b]재  질[/b]  " + mat_names[currentArtifact["material"]] + "[/center]\n\n"
	t += "[center][b]각  인[/b]  " + sig_names[currentArtifact["signature"]] + "[/center]\n\n"
	t += "[center][b]분  류[/b]  " + type_names[currentArtifact["type"]] + "[/center]\n\n"
	t += "[center][b]색  상[/b]  " + color_names[currentArtifact["color"]] + "[/center]\n\n"
	t += "[center][b]희귀도[/b]  " + rarity_names[currentArtifact["rarity"]] + "[/center]\n\n"
	t += "[center][b]출  처[/b]  " + origin_names[currentArtifact["origin"]] + "[/center]\n\n"
	var ci = currentArtifact["condition"]
	t += "[center][b]마력 상태[/b]  "
	t += "[color=" + cond_colors[ci] + "][b]" + cond_names[ci] + "[/b][/color][/center]\n\n"
	# 특이 규칙 표시
	var rule_descs = ["", "마력 상태 ACTIVE 필수", "장인(ARTISAN) 각인 필수", "왕실(ROYAL) 각인 필수", "저주(CURSE) 각인 필수"]
	var sr = currentArtifact["specialRule"]
	if sr != ArtifactData.ESpecialRule.NONE:
		t += "[center][color=#999999]──────────────────[/color][/center]\n\n"
		t += "[center][color=#cc6600][b]⚠ 특이사항[/b]  " + rule_descs[sr] + "[/color][/center]"
	t += "[/font_size]\n"
	t += "[/color]"
	CommissionContent.text = t

# ──────────────────────────────────────────────
# 실물 검사 팝업
# ──────────────────────────────────────────────
func _on_inspect_btn_pressed() -> void:
	AudioManager.play_ui()
	InspectImage.texture = currentArtifact["image"]
	_anim_open(InspectPopup)

func _on_inspect_close_btn_pressed() -> void:
	AudioManager.play_ui()
	_anim_close(InspectPopup)

# ──────────────────────────────────────────────
# 승인 / 반려 버튼
# ──────────────────────────────────────────────
func _on_approve_btn_pressed() -> void:
	if waiting_for_next:
		return
	if _tut_active:
		_tutorial_finish()
	waiting_for_next = true
	InspectPopup.visible = false
	AudioManager.play_button_pressed()
	EvaluateJudgment(true)

func _on_reject_btn_pressed() -> void:
	if waiting_for_next:
		return
	if _tut_active:
		_tutorial_finish()
	waiting_for_next = true
	InspectPopup.visible = false
	AudioManager.play_button_pressed()
	EvaluateJudgment(false)

# ──────────────────────────────────────────────
# 판정 처리
# ──────────────────────────────────────────────
func EvaluateJudgment(playerApproved: bool) -> void:
	var correct: bool = (playerApproved == currentArtifact["isGenuine"])
	GameManager.apply_judgment(correct)
	# 사운드는 reveal 시점에 재생 (ShowResultPopupAnimated 내부)
	ShowResultPopupAnimated(correct, playerApproved)
	UpdateScoreBar()

func ShowResultPopupAnimated(correct: bool, playerApproved: bool) -> void:
	# 이전 잔여 애니메이션 노드 정리
	for child in ResultPopup.get_children():
		if child.name.begins_with("_anim_"):
			child.queue_free()

	ResultContent.text = ""
	NextArtifactBtn.visible = false
	ResultPopup.visible = true
	ResultPopup.call_deferred("move_to_front")

	# ── Phase 1 : 서스펜스 "판정 중..." ──────────────
	var suspense := Label.new()
	suspense.name = "_anim_suspense"
	suspense.text = "판  정  중  . . ."
	suspense.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suspense.position = Vector2(0, 315)
	suspense.size = Vector2(1000, 80)
	suspense.add_theme_font_size_override("font_size", 44)
	suspense.add_theme_color_override("font_color", Color(0.85, 0.78, 0.50))
	ResultPopup.add_child(suspense)

	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(suspense, "modulate:a", 0.15, 0.55)
	pulse.tween_property(suspense, "modulate:a", 1.0,  0.55)

	await get_tree().create_timer(1.3).timeout
	if not is_instance_valid(suspense): return
	pulse.kill()
	suspense.queue_free()

	# ── Phase 2 : 판정 결과 bounce 등장 ──────────────
	if correct: AudioManager.play_correct()
	else:       AudioManager.play_failed()

	var verdict := RichTextLabel.new()
	verdict.name = "_anim_verdict"
	verdict.bbcode_enabled = true
	verdict.fit_content = true
	verdict.scroll_active = false
	verdict.size = Vector2(940, 120)
	verdict.position = Vector2(30, 50)
	verdict.pivot_offset = Vector2(470, 60)
	verdict.scale = Vector2(0.2, 0.2)
	verdict.modulate = Color(1, 1, 1, 0)
	var verdict_text := "✓  정확한 판단" if correct else "✗  오    판"
	verdict.text = "[center][color=%s][font_size=76]%s[/font_size][/color][/center]" % \
		["#44dd44" if correct else "#ff5555", verdict_text]
	ResultPopup.add_child(verdict)

	var t_bounce := create_tween()
	t_bounce.set_parallel(true)
	t_bounce.tween_property(verdict, "scale", Vector2(1.0, 1.0), 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_bounce.tween_property(verdict, "modulate:a", 1.0, 0.25)

	await get_tree().create_timer(0.55).timeout
	if not is_instance_valid(verdict): return

	# ── Phase 3 : 행동 메시지 ─────────────────────────
	var msg := ""
	if correct:
		msg = "[center][color=#dddddd]진품을 올바르게 승인했습니다.[/color][/center]" \
			if playerApproved else \
			"[center][color=#dddddd]위조품을 올바르게 반려했습니다.[/color][/center]"
	else:
		msg = "[center][color=#ffaaaa]위조품을 승인하고 말았습니다.[/color][/center]" \
			if playerApproved else \
			"[center][color=#ffaaaa]진품을 반려했습니다.[/color][/center]"

	var msg_lbl := _make_result_label(msg, Vector2(30, 210), 42)
	ResultPopup.add_child(msg_lbl)
	_fade_in_node(msg_lbl, 0.28)

	await get_tree().create_timer(0.38).timeout
	if not is_instance_valid(msg_lbl): return

	# ── Phase 4 : 위조 사유 (위조품 관련 판정 시) ────
	var next_y := 300.0
	var show_reason := (correct and not playerApproved) or (not correct and playerApproved)
	if show_reason:
		var rc := "#aaaaaa" if correct else "#ff9999"
		var reason_lbl := _make_result_label(
			"[center][color=%s]위조 사유: %s[/color][/center]" \
				% [rc, currentArtifact["fakeReason"]],
			Vector2(30, next_y), 34)
		ResultPopup.add_child(reason_lbl)
		_fade_in_node(reason_lbl, 0.28)
		await get_tree().create_timer(0.38).timeout
		if not is_instance_valid(reason_lbl): return
		next_y += 92.0

	# ── Phase 5 : 점수 변동 ───────────────────────────
	var dc := "#88dd88" if correct else "#dd8888"
	var ds := "+10" if correct else "-5"

	var delta_lbl := _make_result_label(
		"[center][color=%s][font_size=58]%s점[/font_size][/color][/center]" % [dc, ds],
		Vector2(30, next_y), 36)
	ResultPopup.add_child(delta_lbl)
	_fade_in_node(delta_lbl, 0.28)

	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(delta_lbl): return

	# ── Phase 6 : 이번 주 봉급·감점 현황 ─────────────
	var wc := GameManager.weekly_correct
	var wi := GameManager.weekly_incorrect
	var weekly_lbl := _make_result_label(
		"[center][color=#888888]이번 주  봉급 대상 [color=#88dd88]%d건[/color]   감점 대상 [color=#dd8888]%d건[/color][/color][/center]" \
			% [wc, wi],
		Vector2(30, next_y + 88), 34)
	ResultPopup.add_child(weekly_lbl)
	_fade_in_node(weekly_lbl, 0.28)

	await get_tree().create_timer(0.30).timeout
	if not is_instance_valid(weekly_lbl): return

	# ── Phase 7 : 현재 총점 ───────────────────────────
	var total_lbl := _make_result_label(
		"[center][color=#ccbb88]현재 점수  %d점[/color][/center]" % score,
		Vector2(30, next_y + 170), 44)
	ResultPopup.add_child(total_lbl)
	_fade_in_node(total_lbl, 0.28)

	await get_tree().create_timer(0.38).timeout

	# ── Phase 8 : 다음 버튼 페이드인 ─────────────────
	NextArtifactBtn.modulate = Color(1, 1, 1, 0)
	NextArtifactBtn.visible = true
	_fade_in_node(NextArtifactBtn, 0.35)


## 애니메이션용 RichTextLabel 생성 헬퍼
func _make_result_label(bbtext: String, pos: Vector2, font_size: int) -> RichTextLabel:
	var lbl := RichTextLabel.new()
	lbl.name = "_anim_%d" % randi()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.size = Vector2(940, 90)
	lbl.position = pos
	lbl.text = bbtext
	# RichTextLabel은 "font_size"가 아니라 normal/bold 별도 항목을 사용한다
	lbl.add_theme_font_size_override("normal_font_size", font_size)
	lbl.add_theme_font_size_override("bold_font_size", font_size)
	lbl.modulate = Color(1, 1, 1, 0)
	return lbl


## 노드 페이드인 헬퍼
func _fade_in_node(node: CanvasItem, duration: float) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, duration)

# ──────────────────────────────────────────────
# 다음 의뢰 버튼
# ──────────────────────────────────────────────
func _on_next_artifact_btn_pressed() -> void:
	AudioManager.play_ui()
	# GameManager.advance_artifact()가 내부에서 day/artifacts_today를 갱신하고
	# 7일 완료 시 True를 반환하여 주간 결산 씬으로 전환한다.
	var week_ended := GameManager.advance_artifact()
	if week_ended:
		SceneTransition.fade_to(WEEKLY_SUMMARY_SCENE)
		return
	UpdateScoreBar()
	ShowNextArtifact()

# ──────────────────────────────────────────────
# 점수 바 업데이트
# ──────────────────────────────────────────────
var _score_tween: Tween = null
var _shown_score: int = 0

func UpdateScoreBar() -> void:
	var week_day := ((GameManager.day - 1) % 7) + 1
	var week_num := (GameManager.day - 1) / 7 + 1
	DayLabel.text = "%d주 %d일" % [week_num, week_day]
	_animate_score(GameManager.score)

## 점수 숫자를 현재값 → 목표값까지 부드럽게 카운트업/다운
func _animate_score(target: int) -> void:
	if _score_tween != null and _score_tween.is_valid():
		_score_tween.kill()
	if _shown_score == target:
		_set_score_text(float(target))
		return
	_score_tween = create_tween()
	_score_tween.tween_method(_set_score_text, float(_shown_score), float(target), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 점수 라벨 살짝 팝
	ScoreLabel.pivot_offset = ScoreLabel.size / 2.0
	var pop := create_tween()
	pop.tween_property(ScoreLabel, "scale", Vector2(1.12, 1.12), 0.12).set_ease(Tween.EASE_OUT)
	pop.tween_property(ScoreLabel, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_score_text(v: float) -> void:
	_shown_score = int(round(v))
	ScoreLabel.text = "점수: %d  (최고: %d)" % [_shown_score, GameManager.high_score]

# ──────────────────────────────────────────────
# 부드러운 팝업 열기/닫기 (TWEEN: 페이드 + 선택적 스케일)
# ──────────────────────────────────────────────
func _anim_open(ctrl: Control, use_scale: bool = false) -> void:
	_kill_anim_tween(ctrl)
	ctrl.visible = true
	ctrl.call_deferred("move_to_front")
	ctrl.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ctrl, "modulate:a", 1.0, 0.18)
	if use_scale:
		ctrl.pivot_offset = ctrl.size / 2.0
		ctrl.scale = Vector2(0.9, 0.9)
		tw.tween_property(ctrl, "scale", Vector2.ONE, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ctrl.set_meta("_anim_tw", tw)

func _anim_close(ctrl: Control, use_scale: bool = false) -> void:
	if not ctrl.visible:
		return
	_kill_anim_tween(ctrl)
	if use_scale:
		ctrl.pivot_offset = ctrl.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ctrl, "modulate:a", 0.0, 0.15)
	if use_scale:
		tw.tween_property(ctrl, "scale", Vector2(0.9, 0.9), 0.15).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		ctrl.visible = false
		ctrl.modulate.a = 1.0
		ctrl.scale = Vector2.ONE)
	ctrl.set_meta("_anim_tw", tw)

func _kill_anim_tween(ctrl: Control) -> void:
	if ctrl.has_meta("_anim_tw"):
		var prev = ctrl.get_meta("_anim_tw")
		if prev is Tween and prev.is_valid():
			prev.kill()

# ──────────────────────────────────────────────
# 룰북 초기화
# ──────────────────────────────────────────────
func InitializeRuleBook() -> void:
	manual_pages.clear()
	manual_page_artifacts.clear()
	var bs = "[font_size=22][color=#111111]"
	var es = "[/color][/font_size]"

	# ── 페이지 0: 기본 수칙 ─────────────────────────────
	var p0 = bs
	p0 += "[center][font_size=30][b]- 감정 기본 수칙 -[/b][/font_size][/center]\n\n"
	p0 += "모든 제출품은 [b]의뢰서의 내용[/b]과\n[b]실물 검사[/b]가 모두 규정에 맞아야 한다.\n\n"
	p0 += "1. 각인과 출처의 교차 검증을 실시할 것.\n"
	p0 += "2. 마력 보존 상태를 반드시 확인할 것.\n"
	p0 += "3. [b]실물 검사[/b] 버튼으로 외형을 확인할 것.\n\n"
	p0 += "[color=#cc0000][b]단 하나의 모순이라도 발견 시\n승인을 거부한다.[/b][/color]"
	p0 += es
	manual_pages.append(p0)
	manual_page_artifacts.append([])

	# ── 페이지 1: 출처 및 각인 규정 ─────────────────────
	var p1 = bs
	p1 += "[center][font_size=30][b]- 출처 및 각인 규정 -[/b][/font_size][/center]\n\n"
	p1 += "[color=#555555]※ 공식 각인 = 왕실(ROYAL)·장인(ARTISAN)\n각인 없음(NONE)은 어느 출처든 허용[/color]\n\n"
	p1 += "[color=#8800aa][b]왕도 (ROYAL_CAPITAL)[/b][/color]\n"
	p1 += "공식 각인: ROYAL만\n"
	p1 += "금지 재질: WOOD, BONE\n\n"
	p1 += "[color=#555500][b]드워프 광산 (DWARF_MINE)[/b][/color]\n"
	p1 += "공식 각인: ARTISAN만\n"
	p1 += "허용 재질: IRON, GOLD, SILVER, STONE만\n\n"
	p1 += "[color=#006600][b]엘프 숲 (ELF_FOREST)[/b][/color]\n"
	p1 += "공식 각인: ARTISAN만\n"
	p1 += "금지 재질: 금속류 (IRON, GOLD, SILVER)\n\n"
	p1 += "[color=#777777][b]미상 (UNKNOWN)[/b][/color]\n"
	p1 += "[color=#cc0000]공식 각인(ROYAL/ARTISAN) 불가[/color]\n"
	p1 += "허용: NONE, CURSE\n\n"
	p1 += "[color=#cc0000]FAKE_MARK 발견 시 즉시 거부[/color]"
	p1 += es
	manual_pages.append(p1)
	manual_page_artifacts.append([])

	# ── 페이지 2: 마력 상태 및 분류 규정 ────────────────
	var p2 = bs
	p2 += "[center][font_size=30][b]- 마력 상태 · 등급 규정 -[/b][/font_size][/center]\n\n"
	p2 += "[b]마력 보존 상태 (Condition)[/b]\n\n"
	p2 += "[color=#005500]ACTIVE:[/color] 정상 매입 가능.\n\n"
	p2 += "[color=#cc6600]DEPLETED:[/color] 무기/물약 매입 불가.\n(도구(TOOL)는 예외 허용)\n\n"
	p2 += "[color=#cc0000]CORRUPTED:[/color] 저주(CURSE) 각인이 있을\n때만 정상. 그 외에는 즉시 거절.\n\n"
	p2 += "[color=#999999]────────────────[/color]\n\n"
	p2 += "[b]분류·등급별 규정[/b]\n\n"
	p2 += "[color=#0055cc]물약(POTION):[/color] 반드시 유리(GLASS).\n\n"
	p2 += "[color=#880055]전설(LEGENDARY):[/color]\n왕실(ROYAL) 각인 + 왕도 출처 전용.\n\n"
	p2 += "[color=#8800aa]저주(CURSE) 각인:[/color]\n반드시 보라색(PURPLE)."
	p2 += es
	manual_pages.append(p2)
	manual_page_artifacts.append([])

	# ── 페이지 3: 실물 검사 안내 ─────────────────────────
	var p3 = bs
	p3 += "[center][font_size=30][b]- 실물 검사 안내 -[/b][/font_size][/center]\n\n"
	p3 += "[b]실물 검사[/b] 버튼을 눌러\n유물의 외형을 직접 확인할 것.\n\n"
	p3 += "의뢰서의 [b]품명(이름)[/b]과\n실제 외형이 [b]일치해야[/b] 한다.\n\n"
	p3 += "[color=#0000cc]의뢰서: 기본 철검[/color]\n"
	p3 += "[color=#005500]→ 실물: 검 형태  ✓ 일치[/color]\n"
	p3 += "[color=#cc0000]→ 실물: 목걸이   ✗ 불일치 → 위조품[/color]\n\n"
	p3 += "[color=#888888]도감 페이지에서 각 유물의\n외형을 미리 확인할 수 있다.[/color]"
	p3 += es
	manual_pages.append(p3)
	manual_page_artifacts.append([])

	# ── 페이지 4: 주요 유물 도감 (텍스트) ───────────────
	var p4 = bs
	p4 += "[center][font_size=30][b]- 주요 유물 도감 -[/b][/font_size][/center]\n\n"
	p4 += "[b]기사단 흉갑[/b]  [color=#cc00cc](전설)[/color]\n"
	p4 += "재질: IRON / 각인: ROYAL\n"
	p4 += "출처: 왕도\n\n"
	p4 += "[b]관찰자의 마법서[/b]  [color=#cc00cc](전설)[/color]\n"
	p4 += "재질: LEATHER / 각인: ROYAL\n"
	p4 += "출처: 왕도\n\n"
	p4 += "[b]흑요석 단검[/b]\n"
	p4 += "재질: STONE / 각인: CURSE\n"
	p4 += "상태: CORRUPTED (정상)\n\n"
	p4 += "[color=#888888](도감 정보와 다르면 위조품)[/color]"
	p4 += es
	manual_pages.append(p4)
	manual_page_artifacts.append([])

	# ── 유물 이미지 도감 페이지 (4개씩) ─────────────────
	var per_page := 4
	var total := ArtifactList.size()
	var num_catalog := (total + per_page - 1) / per_page

	for page_idx in range(num_catalog):
		var p = bs
		p += "[center][font_size=22][b]- 유물 도감 %d / %d -[/b][/font_size][/center]\n\n" \
			 % [page_idx + 1, num_catalog]
		p += es
		manual_pages.append(p)
		var page_artifacts: Array = []
		for i in range(per_page):
			var artifact_idx := page_idx * per_page + i
			if artifact_idx < total:
				page_artifacts.append(ArtifactList[artifact_idx])
		manual_page_artifacts.append(page_artifacts)

	current_page_index = 0
	update_page_display()

func render_to_label(label: RichTextLabel, page_idx: int) -> void:
	label.clear()
	if page_idx >= manual_pages.size():
		return
	label.append_text(manual_pages[page_idx])
	var artifacts: Array = manual_page_artifacts[page_idx] if page_idx < manual_page_artifacts.size() else []
	for i in range(artifacts.size()):
		var art: ArtifactData = artifacts[i]
		var img: Texture2D = art.ArtifactImage
		var name_tag = "[font_size=18][b]" + art.ArtifactName + "[/b][/font_size]"
		if i % 2 == 0:
			if img:
				label.add_image(img, 80, 80)
			label.append_text("  " + name_tag + "\n")
		else:
			label.push_paragraph(HORIZONTAL_ALIGNMENT_RIGHT)
			label.append_text(name_tag + "  ")
			if img:
				label.add_image(img, 80, 80)
			label.pop()
			label.append_text("\n")

func update_page_display() -> void:
	render_to_label(ContentLabel1, current_page_index)
	render_to_label(ContentLabel2, current_page_index + 1)
	PrevButton.visible = (current_page_index > 0)
	NextButton.visible = (current_page_index + 2 < manual_pages.size())

# ──────────────────────────────────────────────
# 전역 입력: 드래그 모션 / 마우스 릴리즈 / ESC 처리
# ──────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# 인트로/튜토리얼 차단 중에는 게임 측 드래그/입력을 막는다
	if _tut_block_input or _story_layer != null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		if event.pressed:
			# ── 드래그 가능한 UI 목록 (ResultPopup은 드래그 불가) ──
			# RuleBookUI는 자체 rect가 작으므로 BookBackground rect로 판별
			var draggable: Array = [
				{ "ui": CommissionPanel, "rect": CommissionPanel.get_global_rect() },
				{ "ui": InspectPopup,    "rect": InspectPopup.get_global_rect() },
				{ "ui": RuleBookUI,      "rect": BookBackground.get_global_rect() },
			]
			# ResultPopup은 bring-to-front만 (드래그 없음)
			var all_ui: Array = [CommissionPanel, InspectPopup, RuleBookUI, ResultPopup]
			var all_rects: Dictionary = {
				CommissionPanel: CommissionPanel.get_global_rect(),
				InspectPopup:    InspectPopup.get_global_rect(),
				RuleBookUI:      BookBackground.get_global_rect(),
				ResultPopup:     ResultPopup.get_global_rect(),
			}

			# 클릭 위치에 겹쳐 있는 UI 중 가장 위에 있는 것 찾기
			var clicked: Array = []
			for ui in all_ui:
				if ui.visible and all_rects[ui].has_point(mouse_pos):
					clicked.append(ui)
			if clicked.is_empty():
				return
			clicked.sort_custom(func(a, b): return a.get_index() < b.get_index())
			var top_ui = clicked.back()

			# 맨 앞으로
			top_ui.move_to_front()

			# 드래그 시작 (gui_input 경유 없이 여기서 직접 처리)
			match top_ui:
				CommissionPanel:
					_dragging_commission = true
					_commission_drag_offset = CommissionPanel.position - mouse_pos
				InspectPopup:
					_dragging_inspect = true
					_inspect_drag_offset = InspectPopup.position - mouse_pos
				RuleBookUI:
					_dragging_rulebook = true
					_rulebook_drag_offset = RuleBookUI.position - mouse_pos
		else:
			# 마우스 릴리즈 → 모든 드래그 해제
			_dragging_commission = false
			_dragging_rulebook   = false
			_dragging_inspect    = false

	# 드래그 중 마우스 이동 처리 (Panel 밖으로 나가도 유지)
	elif event is InputEventMouseMotion:
		if _dragging_commission:
			CommissionPanel.position = get_global_mouse_position() + _commission_drag_offset
		elif _dragging_rulebook:
			RuleBookUI.position = get_global_mouse_position() + _rulebook_drag_offset
		elif _dragging_inspect:
			InspectPopup.position = get_global_mouse_position() + _inspect_drag_offset

func _unhandled_input(event: InputEvent) -> void:
	# 인트로/튜토리얼 진행 중에는 ESC(옵션/팝업 토글)를 막는다
	if _tut_active or _story_layer != null:
		return
	if not (event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_ESCAPE):
		return

	# ① 인게임 옵션이 열려 있으면 먼저 닫기
	if _ingame_options != null and _ingame_options.visible:
		_anim_close(_ingame_options, true)
		get_viewport().set_input_as_handled()
		return

	# ② 다른 팝업 닫기 (가장 위에 있는 것 하나씩)
	var open_uis: Array = []
	for ui in [CommissionPanel, InspectPopup, RuleBookUI, ResultPopup]:
		if ui.visible:
			open_uis.append(ui)
	if not open_uis.is_empty():
		open_uis.sort_custom(func(a, b): return a.get_index() < b.get_index())
		_anim_close(open_uis.back())
		get_viewport().set_input_as_handled()
		return

	# ③ 모든 팝업이 닫혀 있으면 인게임 옵션 열기
	if _ingame_options != null:
		# 슬라이더를 현재 볼륨값으로 동기화
		_igopt_bgm_slider.value = AudioManager.bgm_volume * 100.0
		_igopt_sfx_slider.value = AudioManager.sfx_volume * 100.0
		_anim_open(_ingame_options, true)
		get_viewport().set_input_as_handled()

# ──────────────────────────────────────────────
# 인게임 옵션 패널 빌드 (코드로 생성)
# ──────────────────────────────────────────────
func _build_ingame_options() -> void:
	# ── 패널 본체 ──────────────────────────────
	_ingame_options = Panel.new()
	_ingame_options.name    = "IngameOptions"
	_ingame_options.visible = false
	_ingame_options.size    = Vector2(540, 470)
	# 화면 중앙에 배치 (1920×1080 기준)
	_ingame_options.position = Vector2(690, 305)
	var bg := StyleBoxFlat.new()
	bg.bg_color     = Color(0.06, 0.05, 0.10, 0.96)
	bg.border_color = Color(0.50, 0.42, 0.68, 1.0)
	bg.set_border_width_all(3)
	for corner in [&"corner_radius_top_left", &"corner_radius_top_right",
				   &"corner_radius_bottom_left", &"corner_radius_bottom_right"]:
		bg.set(corner, 8)
	_ingame_options.add_theme_stylebox_override("panel", bg)
	add_child(_ingame_options)

	# ── 타이틀 ─────────────────────────────────
	var title := Label.new()
	title.text = "[ 옵션 ]"
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22; title.offset_bottom = 72
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.60))
	_ingame_options.add_child(title)

	# ── BGM 슬라이더 ───────────────────────────
	var bgm_row := _make_slider_row("배경음", 118, AudioManager.bgm_volume * 100.0)
	_ingame_options.add_child(bgm_row)
	_igopt_bgm_slider = bgm_row.get_child(1) as HSlider
	_igopt_bgm_val    = bgm_row.get_child(2) as Label
	_igopt_bgm_slider.value_changed.connect(func(v):
		AudioManager.set_bgm_volume(v / 100.0)
		_igopt_bgm_val.text = "%d" % int(v))

	# ── SFX 슬라이더 ───────────────────────────
	var sfx_row := _make_slider_row("효과음", 200, AudioManager.sfx_volume * 100.0)
	_ingame_options.add_child(sfx_row)
	_igopt_sfx_slider = sfx_row.get_child(1) as HSlider
	_igopt_sfx_val    = sfx_row.get_child(2) as Label
	_igopt_sfx_slider.value_changed.connect(func(v):
		AudioManager.set_sfx_volume(v / 100.0)
		_igopt_sfx_val.text = "%d" % int(v))

	# ── 메인 메뉴로 돌아가기 버튼 ───────────────
	var menu_btn := Button.new()
	menu_btn.text     = "메인 메뉴로 돌아가기"
	menu_btn.position = Vector2(110, 288)
	menu_btn.size     = Vector2(320, 56)
	menu_btn.add_theme_font_override("font", HANGSO_FONT)
	menu_btn.add_theme_font_size_override("font_size", 26)
	menu_btn.pressed.connect(func():
		AudioManager.play_ui()
		_ingame_options.visible = false
		SceneTransition.fade_to(MAIN_MENU_SCENE))
	_ingame_options.add_child(menu_btn)

	# ── 닫기 버튼 ──────────────────────────────
	var close_btn := Button.new()
	close_btn.text     = "닫기  ( ESC )"
	close_btn.position = Vector2(155, 368)
	close_btn.size     = Vector2(230, 56)
	close_btn.add_theme_font_override("font", HANGSO_FONT)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(func():
		AudioManager.play_ui()
		_anim_close(_ingame_options, true))
	_ingame_options.add_child(close_btn)

## 슬라이더 한 행(HBoxContainer) 생성 헬퍼
func _make_slider_row(label_text: String, y: float, init_val: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position = Vector2(44, y)
	row.size     = Vector2(452, 56)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100, 0)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.85))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0; slider.max_value = 100.0; slider.step = 1.0
	slider.value = init_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(260, 0)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d" % int(init_val)
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.add_theme_font_size_override("font_size", 26)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val_lbl)

	return row

# ──────────────────────────────────────────────
# 드래그 — 의뢰서 패널
# ──────────────────────────────────────────────
func _on_commission_button_pressed() -> void:
	if CommissionPanel.visible:
		AudioManager.play_ui()
		_anim_close(CommissionPanel)
	else:
		AudioManager.play_book_page()
		_anim_open(CommissionPanel)

func _on_commission_panel_close_pressed() -> void:
	AudioManager.play_ui()
	_anim_close(CommissionPanel)

func _on_commission_panel_gui_input(_event: InputEvent) -> void:
	pass  # 드래그 처리는 _input() 에서 일괄 처리

# ──────────────────────────────────────────────
# 드래그 — 룰북
# ──────────────────────────────────────────────
func _on_rulebook_bg_gui_input(_event: InputEvent) -> void:
	pass  # 드래그 처리는 _input() 에서 일괄 처리


func _on_rule_book_button_pressed() -> void:
	AudioManager.play_ui()
	_anim_open(RuleBookUI)

func _on_close_button_pressed() -> void:
	AudioManager.play_ui()
	_anim_close(RuleBookUI)

func _on_next_page_button_pressed() -> void:
	if current_page_index + 2 < manual_pages.size():
		current_page_index += 2
		update_page_display()
		AudioManager.play_book_page()

func _on_prev_page_button_pressed() -> void:
	if current_page_index - 2 >= 0:
		current_page_index -= 2
		update_page_display()
		AudioManager.play_book_page()

# ──────────────────────────────────────────────
# 튜토리얼 (디버그 모드 / 1일차가 아니면 실행 안 함)
# ──────────────────────────────────────────────
func _maybe_start_intro() -> void:
	# 디버그 모드이거나, 첫 주(1일차) 시작이 아니면 인트로/튜토리얼 생략
	if GameManager.debug_mode:
		return
	if GameManager.day != 1:
		return
	_build_story_ui()
	_story_show(0)

func _start_tutorial() -> void:
	_build_tutorial_ui()
	_tut_active = true
	_tut_step = TutStep.COMMISSION
	_tut_apply_step()

# ── 인트로 스토리 ─────────────────────────────────────
func _build_story_ui() -> void:
	# 각 슬라이드: {text, image}. image 파일이 있으면 자동 표시, 없으면 텍스트만.
	_story_slides = [
		{"text": "계명대학교 행소박물관.\n여느 때와 다름없는 조용한 아침이었다.",
		 "image": "res://Resource/Story/story_1.jpg"},
		{"text": "그런데 전시실 한가운데, 허공이 일렁이더니\n정체불명의 [게이트]가 열렸다.",
		 "image": "res://Resource/Story/story_2.png"},
		{"text": "게이트 너머에서 낯선 이방인들이\n갖가지 유물을 손에 들고 걸어 나왔다.",
		 "image": "res://Resource/Story/story_3.png"},
		{"text": "\"이 유물을 박물관에 등록하고 싶소.\"\n그들은 저마다 의뢰서를 내밀었다.",
		 "image": "res://Resource/Story/story_4.png"},
		{"text": "하지만 그 속에는 진품으로 둔갑한\n교묘한 위조품도 섞여 있다는데…",
		 "image": "res://Resource/Story/story_5.png"},
		{"text": "당신은 행소박물관의 유물 감정관.\n진품과 위조품을 가려내라!",
		 "image": "res://Resource/Story/story_6.png"},
	]

	_story_layer = CanvasLayer.new()
	_story_layer.layer = 110
	add_child(_story_layer)

	_story_root = Control.new()
	_story_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_story_root.gui_input.connect(_on_story_root_gui_input)
	_story_layer.add_child(_story_root)

	# 어두운 배경
	var bgc := ColorRect.new()
	bgc.color = Color(0.02, 0.02, 0.04, 0.97)
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_root.add_child(bgc)

	# 일러스트 영역 (이미지가 있을 때만 표시)
	_story_img = TextureRect.new()
	_story_img.position = Vector2(560, 110)
	_story_img.size = Vector2(800, 470)
	_story_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_story_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_story_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_img.visible = false
	_story_root.add_child(_story_img)

	# 내레이션 패널
	var tpanel := Panel.new()
	tpanel.position = Vector2(360, 630)
	tpanel.size = Vector2(1200, 230)
	tpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tbg := StyleBoxFlat.new()
	tbg.bg_color     = Color(0.06, 0.05, 0.10, 0.9)
	tbg.border_color = Color(0.55, 0.45, 0.70, 1.0)
	tbg.set_border_width_all(2)
	for c in [&"corner_radius_top_left", &"corner_radius_top_right",
			  &"corner_radius_bottom_left", &"corner_radius_bottom_right"]:
		tbg.set(c, 10)
	tpanel.add_theme_stylebox_override("panel", tbg)
	_story_root.add_child(tpanel)

	_story_label = Label.new()
	_story_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_label.offset_left = 40
	_story_label.offset_right = -40
	_story_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_label.add_theme_font_override("font", HANGSO_FONT)
	_story_label.add_theme_font_size_override("font_size", 40)
	_story_label.add_theme_color_override("font_color", Color(1, 0.97, 0.92))
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tpanel.add_child(_story_label)

	# 다음 버튼
	_story_next_btn = Button.new()
	_story_next_btn.add_theme_font_override("font", HANGSO_FONT)
	_story_next_btn.add_theme_font_size_override("font_size", 28)
	_story_next_btn.position = Vector2(1558, 900)
	_story_next_btn.size = Vector2(300, 70)
	_story_next_btn.text = "다음 ▶"
	_story_next_btn.pressed.connect(_story_advance)
	_story_root.add_child(_story_next_btn)

	# 건너뛰기 버튼
	var skip := Button.new()
	skip.add_theme_font_override("font", HANGSO_FONT)
	skip.add_theme_font_size_override("font_size", 22)
	skip.position = Vector2(1620, 28)
	skip.size = Vector2(270, 54)
	skip.text = "건너뛰기 ▶▶"
	skip.pressed.connect(_story_finish)
	_story_root.add_child(skip)

	# 하단 힌트
	var hint := Label.new()
	hint.add_theme_font_override("font", HANGSO_FONT)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(0.7, 0.68, 0.78))
	hint.position = Vector2(70, 905)
	hint.size = Vector2(700, 30)
	hint.text = "(화면을 클릭해도 다음으로 넘어갑니다)"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_root.add_child(hint)

func _story_show(i: int) -> void:
	_story_index = i
	var slide: Dictionary = _story_slides[i]
	_story_label.text = slide["text"]
	var path: String = slide.get("image", "")
	if path != "" and ResourceLoader.exists(path):
		_story_img.texture = load(path)
		_story_img.visible = true
	else:
		_story_img.visible = false
	_story_next_btn.text = "시작하기 ▶" if i >= _story_slides.size() - 1 else "다음 ▶"

func _on_story_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_story_advance()

func _story_advance() -> void:
	AudioManager.play_book_page()
	if _story_index + 1 >= _story_slides.size():
		_story_finish()
	else:
		_story_show(_story_index + 1)

func _story_finish() -> void:
	if is_instance_valid(_story_layer):
		_story_layer.queue_free()
	_story_layer = null
	_story_root = null
	_start_tutorial()

func _build_tutorial_ui() -> void:
	_tut_layer = CanvasLayer.new()
	_tut_layer.layer = 100               # 게임 UI(0)보다 위, 씬 전환(128)보다 아래
	add_child(_tut_layer)

	# 전체 클릭 차단막
	_tut_root = Control.new()
	_tut_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tut_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_tut_root.gui_input.connect(_on_tut_root_gui_input)
	_tut_layer.add_child(_tut_root)

	# 스포트라이트용 4분할 어둠막
	for i in range(4):
		var d := ColorRect.new()
		d.color = Color(0, 0, 0, 0.62)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tut_root.add_child(d)
		_tut_dim.append(d)

	# 강조 빨간 박스 2개
	_tut_box  = _make_tut_box()
	_tut_box2 = _make_tut_box()
	_tut_root.add_child(_tut_box)
	_tut_root.add_child(_tut_box2)

	# 안내 말풍선 (상단 중앙)
	var bubble := Panel.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.position = Vector2(460, 95)
	bubble.size = Vector2(1000, 112)
	var bbg := StyleBoxFlat.new()
	bbg.bg_color     = Color(0.06, 0.05, 0.10, 0.92)
	bbg.border_color = Color(1, 0.35, 0.35, 1.0)
	bbg.set_border_width_all(3)
	for c in [&"corner_radius_top_left", &"corner_radius_top_right",
			  &"corner_radius_bottom_left", &"corner_radius_bottom_right"]:
		bbg.set(c, 10)
	bubble.add_theme_stylebox_override("panel", bbg)
	_tut_root.add_child(bubble)

	_tut_msg = Label.new()
	_tut_msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tut_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tut_msg.add_theme_font_override("font", HANGSO_FONT)
	_tut_msg.add_theme_font_size_override("font_size", 28)
	_tut_msg.add_theme_color_override("font_color", Color(1, 0.96, 0.9, 1))
	_tut_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut_msg.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_tut_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.add_child(_tut_msg)

	# "다음 ▶" 버튼 (이동 안내 단계 전용)
	_tut_next_btn = Button.new()
	_tut_next_btn.text = "다음 ▶"
	_tut_next_btn.add_theme_font_override("font", HANGSO_FONT)
	_tut_next_btn.add_theme_font_size_override("font_size", 28)
	_tut_next_btn.position = Vector2(860, 224)
	_tut_next_btn.size = Vector2(200, 60)
	_tut_next_btn.visible = false
	_tut_next_btn.pressed.connect(_on_tut_next_pressed)
	_tut_root.add_child(_tut_next_btn)

	# Skip 버튼 (우상단)
	_tut_skip_btn = Button.new()
	_tut_skip_btn.text = "튜토리얼 건너뛰기 ▶▶"
	_tut_skip_btn.add_theme_font_override("font", HANGSO_FONT)
	_tut_skip_btn.add_theme_font_size_override("font_size", 22)
	_tut_skip_btn.position = Vector2(1556, 20)
	_tut_skip_btn.size = Vector2(340, 56)
	_tut_skip_btn.pressed.connect(_on_tut_skip_pressed)
	_tut_root.add_child(_tut_skip_btn)

func _make_tut_box() -> ReferenceRect:
	var b := ReferenceRect.new()
	b.border_color = Color(1, 0.2, 0.2, 1)
	b.border_width = 5.0
	b.editor_only  = false               # 실행 중에도 테두리 표시
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = false
	return b

# 단계별 화면 구성
func _tut_apply_step() -> void:
	_tut_box.visible = false
	_tut_box2.visible = false
	_tut_next_btn.visible = false
	match _tut_step:
		TutStep.COMMISSION:
			_tut_block_input = true
			_tut_set_block(true)
			_tut_msg.text = "① 먼저 [의뢰서]를 열어봅시다.\n빨간 박스를 클릭하세요."
			_tut_focus_node(CommissionButton)
		TutStep.RULEBOOK:
			_tut_block_input = true
			_tut_set_block(true)
			_tut_msg.text = "② 유물 규정이 담긴 [규정집]을 펼쳐봅시다.\n빨간 박스를 클릭하세요."
			_tut_focus_node(RuleBookButton)
		TutStep.PAGEFLIP:
			RuleBookUI.visible = true
			RuleBookUI.move_to_front()
			_tut_block_input = true
			_tut_set_block(true)
			_tut_msg.text = "③ 규정집은 화살표로 좌우 페이지를 넘길 수 있어요.\n[다음 페이지] 화살표를 클릭해보세요."
			_tut_focus_node(NextButton)
		TutStep.ARRANGE:
			_tut_block_input = false
			_tut_set_block(false)
			_tut_msg.text = "④ 창이 겹치면 보고 싶은 창을 [클릭]해 맨 앞으로 올리거나,\n[드래그]로 옮길 수 있어요. 직접 정리한 뒤 [다음]."
			_tut_next_btn.visible = true
		TutStep.INSPECT:
			CommissionPanel.visible = true
			CommissionPanel.move_to_front()
			_tut_block_input = true
			_tut_set_block(true)
			_tut_msg.text = "⑤ 의뢰서의 [실물 검사]로 유물의 외형을 확인하세요.\n빨간 박스를 클릭하세요."
			_tut_focus_node(InspectButton)
		TutStep.INSPECT_CLOSE:
			_tut_block_input = true
			_tut_set_block(true)
			_tut_msg.text = "⑥ 외형을 확인했으면 팝업의 [닫기] 버튼으로 닫으세요.\n빨간 박스를 클릭하세요."
			_tut_focus_node(InspectCloseBtn)
		TutStep.JUDGE:
			# 아래 승인/반려 버튼이 가려지지 않도록 켜져있는 창을 모두 닫는다
			CommissionPanel.visible = false
			RuleBookUI.visible = false
			InspectPopup.visible = false
			# 버튼은 강조만 하고 클릭은 막는다 → [다음]으로만 진행
			_tut_block_input = true
			_tut_set_block(true)
			_tut_target_rect = Rect2()      # 클릭 허용 영역 없음(버튼 클릭 차단)
			_tut_msg.text = "⑦ 판정은 아래 [진품 승인] · [가품 반려] 버튼으로 합니다.\n비교해보고 눌러보세요!  ([다음]을 누르면 자유 조작)"
			_tut_next_btn.visible = true
			var ra := _node_screen_rect(ApproveImg)
			var rb := _node_screen_rect(RejectImg)
			_tut_spotlight(ra.merge(rb))
			_tut_box.visible = true
			_tut_box2.visible = true
			_tut_place_rect(_tut_box,  ra)
			_tut_place_rect(_tut_box2, rb)

func _tut_set_block(b: bool) -> void:
	if _tut_root == null:
		return
	_tut_root.mouse_filter = Control.MOUSE_FILTER_STOP if b else Control.MOUSE_FILTER_IGNORE
	for d in _tut_dim:
		d.visible = b

func _tut_focus_node(c: Control) -> void:
	var r := _node_screen_rect(c)
	_tut_target_rect = r
	_tut_spotlight(r)
	_tut_box.visible = true
	_tut_place_rect(_tut_box, r)

# 노드의 실제 화면 사각형 (자체 scale·좌우 반전 반영)
func _node_screen_rect(c: Control) -> Rect2:
	var pos := c.global_position
	var sz := c.size * c.scale
	if sz.x < 0.0:
		pos.x += sz.x
		sz.x = -sz.x
	if sz.y < 0.0:
		pos.y += sz.y
		sz.y = -sz.y
	return Rect2(pos, sz)

func _tut_place_rect(ctrl: Control, r: Rect2) -> void:
	var pad := 8.0
	ctrl.position = r.position - Vector2(pad, pad)
	ctrl.size = r.size + Vector2(pad * 2.0, pad * 2.0)

# 대상 영역만 남기고 화면을 어둡게 (4분할)
func _tut_spotlight(r: Rect2) -> void:
	var vp := get_viewport_rect().size
	var rx := r.position.x + r.size.x
	var by := r.position.y + r.size.y
	_tut_dim[0].position = Vector2.ZERO
	_tut_dim[0].size = Vector2(vp.x, max(0.0, r.position.y))
	_tut_dim[1].position = Vector2(0, by)
	_tut_dim[1].size = Vector2(vp.x, max(0.0, vp.y - by))
	_tut_dim[2].position = Vector2(0, r.position.y)
	_tut_dim[2].size = Vector2(max(0.0, r.position.x), r.size.y)
	_tut_dim[3].position = Vector2(rx, r.position.y)
	_tut_dim[3].size = Vector2(max(0.0, vp.x - rx), r.size.y)

func _on_tut_root_gui_input(event: InputEvent) -> void:
	if not _tut_block_input:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _tut_target_rect.has_point(event.position):
			_tut_do_target_action()

func _tut_do_target_action() -> void:
	match _tut_step:
		TutStep.COMMISSION:
			_on_commission_button_pressed()
		TutStep.RULEBOOK:
			_on_rule_book_button_pressed()
		TutStep.PAGEFLIP:
			_on_next_page_button_pressed()
		TutStep.INSPECT:
			_on_inspect_btn_pressed()
		TutStep.INSPECT_CLOSE:
			_on_inspect_close_btn_pressed()
	_tut_advance()

func _tut_advance() -> void:
	_tut_step += 1
	_tut_apply_step()

func _on_tut_next_pressed() -> void:
	AudioManager.play_ui()
	# 마지막(판정) 단계에서 [다음]은 튜토리얼을 끝내고 자유 조작으로
	if _tut_step == TutStep.JUDGE:
		_tutorial_finish()
	else:
		_tut_advance()

func _on_tut_skip_pressed() -> void:
	AudioManager.play_ui()
	_tutorial_finish()

func _tutorial_finish() -> void:
	if not _tut_active:
		return
	_tut_active = false
	_tut_block_input = false
	if is_instance_valid(_tut_layer):
		_tut_layer.queue_free()
	_tut_layer = null
	_tut_root  = null
	_tut_box   = null
	_tut_box2  = null
	_tut_dim.clear()

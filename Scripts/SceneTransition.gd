extends CanvasLayer

## ─────────────────────────────────────────────────────
##  SceneTransition  (AutoLoad: "SceneTransition")
##  씬 전환 시 검은 화면 페이드를 담당한다.
##  CanvasLayer(layer=128)이므로 어떤 씬 위에도 표시된다.
##  씬이 교체되는 순간에도 이 노드는 살아있어 깜빡임이 없다.
## ─────────────────────────────────────────────────────

const FADE_DURATION := 0.45   # 초

var _overlay: ColorRect

func _ready() -> void:
	layer = 128   # 최상단 레이어

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 1)   # 처음엔 완전 검정
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# 게임 첫 실행 시 페이드인
	_fade_in()

## 검정 → 투명 (씬 진입)
func _fade_in() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)

## 투명 → 검정 후 씬 전환 (씬 나갈 때)
func fade_to(scene_path: String) -> void:
	# 전환 중 클릭 차단
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	t.tween_callback(func():
		get_tree().change_scene_to_file(scene_path)
		# 씬이 바뀐 다음 프레임에 페이드인
		_fade_in()
	)

class_name ChipStack
extends Node3D
## A neat stack of chips (largest denomination at the bottom). Tall stacks spill
## into a second column so the pile stays readable.

const ChipFactory = preload("res://scripts/table/chip_factory.gd")
const TableLayout = preload("res://scripts/table/table_layout.gd")
const BJMoney = preload("res://scripts/engine/bj_money.gd")

const COLUMN_MAX := 14

var chips: Array[int] = []
var _nodes: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7


func amount() -> int:
	var t := 0
	for c in chips:
		t += c
	return t


func set_amount(cents: int) -> void:
	var list: Array[int] = BJMoney.breakdown(cents)
	set_chips(list)


## Rebuilds the stack (sorted largest-first unless `sort` is false). When
## `drop_last` is set the top chip falls into place.
func set_chips(list: Array, drop_last: bool = false, sort: bool = true) -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	chips.clear()
	var sorted: Array[int] = []
	for v in list:
		sorted.append(int(v))
	if sort:
		sorted.sort()
		sorted.reverse()
	_rng.seed = 7
	for i in sorted.size():
		chips.append(sorted[i])
		var chip := ChipFactory.make(sorted[i])
		chip.position = _slot(i)
		chip.rotation.y = _rng.randf() * TAU
		add_child(chip)
		_nodes.append(chip)
	if drop_last and not _nodes.is_empty():
		var top: Node3D = _nodes.back()
		var target: Vector3 = top.position
		top.position = target + Vector3(0, 0.05, 0.02)
		var tw := top.create_tween()
		tw.tween_property(top, "position", target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func height() -> float:
	return float(mini(chips.size(), COLUMN_MAX)) * TableLayout.CHIP_HEIGHT


func top_position() -> Vector3:
	return global_position + Vector3(0, height() + 0.01, 0)


## Slides the whole stack, optionally freeing it on arrival.
func slide_to(world_pos: Vector3, duration: float, free_after: bool = false) -> void:
	var start := global_position
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var e := t * t * (3.0 - 2.0 * t)
		global_position = start.lerp(world_pos, e) + Vector3.UP * sin(t * PI) * 0.02
	, 0.0, 1.0, maxf(duration, 0.01))
	if free_after:
		tw.tween_callback(queue_free)


func _slot(i: int) -> Vector3:
	var col := i / COLUMN_MAX
	var row := i % COLUMN_MAX
	var jitter := Vector3(_rng.randf_range(-0.0007, 0.0007), 0, _rng.randf_range(-0.0007, 0.0007))
	var base := Vector3(float(col) * TableLayout.CHIP_RADIUS * 2.15, 0, float(col % 2) * 0.004)
	return base + jitter + Vector3(0, TableLayout.CHIP_HEIGHT * (float(row) + 0.5), 0)

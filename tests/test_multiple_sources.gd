extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Multiple Sources Tests (US4) ===")
	_test_two_sources_compound()
	_test_unregister_makes_rule_dormant()
	print("=== Results: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_passed += 1
		print("  PASS: %s" % test_name)
	else:
		_failed += 1
		print("  FAIL: %s" % test_name)


func _create_manager() -> Node:
	var script: GDScript = load("res://addons/unlock_system/unlock_manager.gd") as GDScript
	var m: Node = script.new()
	root.add_child(m)
	return m


func _test_two_sources_compound() -> void:
	var m: Node = _create_manager()
	var progress: _MockSource = _MockSource.new()
	progress._data = {"level_10": false}
	var stats: _MockSource = _MockSource.new()
	stats._data = {"kills": 0}

	m.register_source("progress", progress)
	m.register_source("stats", stats)

	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "progress"
	c1.key = "level_10"
	c1.operator = UnlockCondition.Operator.EQ
	c1.target_value = true

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "stats"
	c2.key = "kills"
	c2.operator = UnlockCondition.Operator.GEQ
	c2.target_value = 100

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "multi_source"
	rule.conditions = root
	rule.targets = ["reward_1"]

	m.add_rule(rule)

	progress.set_value("level_10", true)
	_assert(not m.is_unlocked("reward_1"), "partial: only progress met")

	stats.set_value("kills", 100)
	_assert(m.is_unlocked("reward_1"), "fully met: both sources satisfied")
	m.queue_free()


func _test_unregister_makes_rule_dormant() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"done": false}
	m.register_source("s", src)

	var leaf: UnlockCondition = UnlockCondition.new()
	leaf.source_name = "s"
	leaf.key = "done"
	leaf.operator = UnlockCondition.Operator.EQ
	leaf.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [leaf]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = root
	rule.targets = ["t1"]

	m.add_rule(rule)
	m.unregister_source("s")

	var errors: Array[String] = []
	m.evaluation_error.connect(func(_rid: String, msg: String) -> void: errors.append(msg))

	# Re-add rule to trigger evaluation with missing source
	m.remove_rule("r1")
	m.add_rule(rule)

	_assert(errors.size() > 0, "evaluation_error emitted for unregistered source")
	_assert(not m.is_unlocked("t1"), "target stays locked when source unregistered")
	m.queue_free()


class _MockSource:
	extends RefCounted

	signal value_changed(key: String, new_value: Variant)

	var _data: Dictionary = {}

	func get_value(key: String) -> Variant:
		return _data.get(key)

	func set_value(key: String, val: Variant) -> void:
		_data[key] = val
		value_changed.emit(key, val)

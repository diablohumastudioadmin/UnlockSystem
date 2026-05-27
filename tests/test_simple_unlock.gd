extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Simple Unlock Tests (US1) ===")
	_test_simple_rule_unlocks_on_condition_met()
	_test_simple_rule_stays_locked_when_unmet()
	_test_signal_fires_on_unlock()
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


func _test_simple_rule_unlocks_on_condition_met() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"level_4_passed": false}
	m.register_source("progress", source)

	var leaf: UnlockCondition = UnlockCondition.new()
	leaf.source_name = "progress"
	leaf.key = "level_4_passed"
	leaf.operator = UnlockCondition.Operator.EQ
	leaf.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [leaf]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_level_5"
	rule.conditions = root
	rule.targets = ["level_5"]

	m.add_rule(rule)
	_assert(not m.is_unlocked("level_5"), "locked before condition met")

	source.set_value("level_4_passed", true)
	_assert(m.is_unlocked("level_5"), "unlocked after condition met")

	m.queue_free()


func _test_simple_rule_stays_locked_when_unmet() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"level_4_passed": false}
	m.register_source("progress", source)

	var leaf: UnlockCondition = UnlockCondition.new()
	leaf.source_name = "progress"
	leaf.key = "level_4_passed"
	leaf.operator = UnlockCondition.Operator.EQ
	leaf.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [leaf]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_level_5"
	rule.conditions = root
	rule.targets = ["level_5"]

	m.add_rule(rule)

	# Change value but not to the target
	source.set_value("level_4_passed", false)
	_assert(not m.is_unlocked("level_5"), "stays locked when condition not met")

	m.queue_free()


func _test_signal_fires_on_unlock() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"done": false}
	m.register_source("s", source)

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

	var received: Array[String] = []
	m.unlock_granted.connect(func(key: String) -> void: received.append(key))

	m.add_rule(rule)
	source.set_value("done", true)

	_assert(received.size() == 1, "signal fired once")
	_assert(received[0] == "t1" if not received.is_empty() else false, "signal carried correct target key")

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

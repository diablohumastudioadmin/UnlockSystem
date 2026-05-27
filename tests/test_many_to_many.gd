extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Many-to-Many Tests (US3) ===")
	_test_one_rule_multiple_targets()
	_test_multiple_rules_same_target()
	_test_mixed_sources_in_single_rule()
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


func _test_one_rule_multiple_targets() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"level_40": false}
	m.register_source("progress", src)

	var leaf: UnlockCondition = UnlockCondition.new()
	leaf.source_name = "progress"
	leaf.key = "level_40"
	leaf.operator = UnlockCondition.Operator.EQ
	leaf.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [leaf]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "pass_level_40"
	rule.conditions = root
	rule.targets = ["char_b_level_2", "ach_veteran"]

	var unlocked: Array[String] = []
	m.unlock_granted.connect(func(key: String) -> void: unlocked.append(key))

	m.add_rule(rule)
	src.set_value("level_40", true)

	_assert(m.is_unlocked("char_b_level_2"), "target 1 unlocked")
	_assert(m.is_unlocked("ach_veteran"), "target 2 unlocked")
	_assert(unlocked.size() == 2, "two unlock_granted signals emitted")
	m.queue_free()


func _test_multiple_rules_same_target() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"a": false, "b": false}
	m.register_source("s", src)

	# Rule 1: a == true → unlock t1
	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "s"
	c1.key = "a"
	c1.operator = UnlockCondition.Operator.EQ
	c1.target_value = true

	var root1: CompoundCondition = CompoundCondition.new()
	root1.operator = CompoundCondition.Logic.AND
	root1.children = [c1]

	var rule1: UnlockRule = UnlockRule.new()
	rule1.rule_id = "r1"
	rule1.conditions = root1
	rule1.targets = ["t1"]

	# Rule 2: b == true → also unlock t1
	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "s"
	c2.key = "b"
	c2.operator = UnlockCondition.Operator.EQ
	c2.target_value = true

	var root2: CompoundCondition = CompoundCondition.new()
	root2.operator = CompoundCondition.Logic.AND
	root2.children = [c2]

	var rule2: UnlockRule = UnlockRule.new()
	rule2.rule_id = "r2"
	rule2.conditions = root2
	rule2.targets = ["t1"]

	m.add_rule(rule1)
	m.add_rule(rule2)

	# Either rule can unlock t1
	src.set_value("a", true)
	_assert(m.is_unlocked("t1"), "t1 unlocked by first of two rules")

	var signal_count: Array[int] = [0]
	m.unlock_granted.connect(func(_key: String) -> void: signal_count[0] += 1)

	# Second rule fires but t1 already unlocked → idempotent
	src.set_value("b", true)
	_assert(signal_count[0] == 0, "no duplicate signal for already-unlocked target")
	m.queue_free()


func _test_mixed_sources_in_single_rule() -> void:
	var m: Node = _create_manager()
	var progress_src: _MockSource = _MockSource.new()
	progress_src._data = {"level_10": false}
	var currency_src: _MockSource = _MockSource.new()
	currency_src._data = {"coins": 0}

	m.register_source("progress", progress_src)
	m.register_source("currency", currency_src)

	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "progress"
	c1.key = "level_10"
	c1.operator = UnlockCondition.Operator.EQ
	c1.target_value = true

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "currency"
	c2.key = "coins"
	c2.operator = UnlockCondition.Operator.GEQ
	c2.target_value = 500

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "mixed_sources"
	rule.conditions = root
	rule.targets = ["special_item"]

	m.add_rule(rule)

	progress_src.set_value("level_10", true)
	_assert(not m.is_unlocked("special_item"), "locked: only progress source met")

	currency_src.set_value("coins", 500)
	_assert(m.is_unlocked("special_item"), "unlocked: both sources met")
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

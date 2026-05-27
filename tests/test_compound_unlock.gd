extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Compound Unlock Tests (US2) ===")
	_test_and_both_met()
	_test_and_partial()
	_test_or_one_met()
	_test_nested_or_c_alone()
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


func _test_and_both_met() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"kills": 0, "coins": 0}
	m.register_source("stats", src)

	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "stats"
	c1.key = "kills"
	c1.operator = UnlockCondition.Operator.GEQ
	c1.target_value = 100

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "stats"
	c2.key = "coins"
	c2.operator = UnlockCondition.Operator.GEQ
	c2.target_value = 1000

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "achievement_x"
	rule.conditions = root
	rule.targets = ["ach_x"]

	m.add_rule(rule)
	src.set_value("kills", 100)
	_assert(not m.is_unlocked("ach_x"), "AND: one met, one not → locked")
	src.set_value("coins", 1000)
	_assert(m.is_unlocked("ach_x"), "AND: both met → unlocked")
	m.queue_free()


func _test_and_partial() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"a": false, "b": false}
	m.register_source("s", src)

	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "s"
	c1.key = "a"
	c1.operator = UnlockCondition.Operator.EQ
	c1.target_value = true

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "s"
	c2.key = "b"
	c2.operator = UnlockCondition.Operator.EQ
	c2.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = root
	rule.targets = ["t1"]

	m.add_rule(rule)
	src.set_value("a", true)
	_assert(not m.is_unlocked("t1"), "AND partial: only a met → locked")
	m.queue_free()


func _test_or_one_met() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"level_3": false, "level_5": false}
	m.register_source("progress", src)

	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "progress"
	c1.key = "level_3"
	c1.operator = UnlockCondition.Operator.EQ
	c1.target_value = true

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "progress"
	c2.key = "level_5"
	c2.operator = UnlockCondition.Operator.EQ
	c2.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.OR
	root.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_level_7"
	rule.conditions = root
	rule.targets = ["level_7"]

	m.add_rule(rule)
	src.set_value("level_3", true)
	_assert(m.is_unlocked("level_7"), "OR: one met → unlocked")
	m.queue_free()


func _test_nested_or_c_alone() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"a": false, "b": false, "c": false}
	m.register_source("s", src)

	var a: UnlockCondition = UnlockCondition.new()
	a.source_name = "s"
	a.key = "a"
	a.operator = UnlockCondition.Operator.EQ
	a.target_value = true

	var b: UnlockCondition = UnlockCondition.new()
	b.source_name = "s"
	b.key = "b"
	b.operator = UnlockCondition.Operator.EQ
	b.target_value = true

	var c: UnlockCondition = UnlockCondition.new()
	c.source_name = "s"
	c.key = "c"
	c.operator = UnlockCondition.Operator.EQ
	c.target_value = true

	var and_group: CompoundCondition = CompoundCondition.new()
	and_group.operator = CompoundCondition.Logic.AND
	and_group.children = [a, b]

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.OR
	root.children = [and_group, c]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "nested_rule"
	rule.conditions = root
	rule.targets = ["nested_target"]

	m.add_rule(rule)
	src.set_value("c", true)
	_assert(m.is_unlocked("nested_target"), "nested (A AND B) OR C: C alone → unlocked")
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

extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Code Configuration Tests (US6) ===")
	_test_create_rule_via_code()
	_test_remove_rule_stops_evaluation()
	_test_modify_rule_at_runtime()
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


func _test_create_rule_via_code() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"done": false}
	m.register_source("s", src)

	# Create everything via .new() — no .tres files
	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = "s"
	condition.key = "done"
	condition.operator = UnlockCondition.Operator.EQ
	condition.target_value = true

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "code_rule"
	rule.conditions = compound
	rule.targets = ["code_target"]

	m.add_rule(rule)
	src.set_value("done", true)

	_assert(m.is_unlocked("code_target"), "code-created rule unlocks correctly")
	m.queue_free()


func _test_remove_rule_stops_evaluation() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"val": 0}
	m.register_source("s", src)

	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = "s"
	condition.key = "val"
	condition.operator = UnlockCondition.Operator.GEQ
	condition.target_value = 100

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "removable"
	rule.conditions = compound
	rule.targets = ["t1"]

	m.add_rule(rule)
	m.remove_rule("removable")

	# Now trigger the condition — should NOT unlock since rule was removed
	src.set_value("val", 200)
	_assert(not m.is_unlocked("t1"), "removed rule does not trigger unlock")
	m.queue_free()


func _test_modify_rule_at_runtime() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"val": 50}
	m.register_source("s", src)

	# Original rule: val >= 100
	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = "s"
	c1.key = "val"
	c1.operator = UnlockCondition.Operator.GEQ
	c1.target_value = 100

	var compound1: CompoundCondition = CompoundCondition.new()
	compound1.operator = CompoundCondition.Logic.AND
	compound1.children = [c1]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "modifiable"
	rule.conditions = compound1
	rule.targets = ["t1"]

	m.add_rule(rule)
	_assert(not m.is_unlocked("t1"), "not unlocked with threshold 100 and val 50")

	# Modify: lower threshold to 25 (remove + re-add)
	m.remove_rule("modifiable")

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = "s"
	c2.key = "val"
	c2.operator = UnlockCondition.Operator.GEQ
	c2.target_value = 25

	var compound2: CompoundCondition = CompoundCondition.new()
	compound2.operator = CompoundCondition.Logic.AND
	compound2.children = [c2]

	var rule2: UnlockRule = UnlockRule.new()
	rule2.rule_id = "modifiable"
	rule2.conditions = compound2
	rule2.targets = ["t1"]

	m.add_rule(rule2)
	_assert(m.is_unlocked("t1"), "unlocked after modifying threshold to 25 (val is 50)")
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

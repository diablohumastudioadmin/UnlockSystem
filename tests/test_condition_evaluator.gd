extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== ConditionEvaluator Tests ===")
	_test_boolean_eq_true()
	_test_boolean_eq_false()
	_test_threshold_geq_met()
	_test_threshold_geq_not_met()
	_test_compound_and_both_met()
	_test_compound_and_one_unmet()
	_test_compound_or_one_met()
	_test_compound_or_none_met()
	_test_nested_compound()
	_test_null_source_returns_false()
	_test_get_condition_status()
	_test_get_condition_status_nested()
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


# --- Helpers ---


func _make_source(data: Dictionary) -> Object:
	var source: _MockSource = _MockSource.new()
	source._data = data
	return source


func _make_leaf(source_name: String, key: String, op: UnlockCondition.Operator, value: Variant) -> UnlockCondition:
	var c: UnlockCondition = UnlockCondition.new()
	c.source_name = source_name
	c.key = key
	c.operator = op
	c.target_value = value
	return c


func _make_compound(op: CompoundCondition.Logic, children: Array) -> CompoundCondition:
	var cc: CompoundCondition = CompoundCondition.new()
	cc.operator = op
	cc.children = children
	return cc


# --- Tests ---


func _test_boolean_eq_true() -> void:
	var sources: Dictionary = {"progress": _make_source({"level_4_passed": true})}
	var leaf: UnlockCondition = _make_leaf("progress", "level_4_passed", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	_assert(ConditionEvaluator.evaluate(root, sources), "boolean EQ true")


func _test_boolean_eq_false() -> void:
	var sources: Dictionary = {"progress": _make_source({"level_4_passed": false})}
	var leaf: UnlockCondition = _make_leaf("progress", "level_4_passed", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	_assert(not ConditionEvaluator.evaluate(root, sources), "boolean EQ false when not met")


func _test_threshold_geq_met() -> void:
	var sources: Dictionary = {"stats": _make_source({"coins": 1500})}
	var leaf: UnlockCondition = _make_leaf("stats", "coins", UnlockCondition.Operator.GEQ, 1000)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	_assert(ConditionEvaluator.evaluate(root, sources), "threshold GEQ met (1500 >= 1000)")


func _test_threshold_geq_not_met() -> void:
	var sources: Dictionary = {"stats": _make_source({"coins": 500})}
	var leaf: UnlockCondition = _make_leaf("stats", "coins", UnlockCondition.Operator.GEQ, 1000)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	_assert(not ConditionEvaluator.evaluate(root, sources), "threshold GEQ not met (500 < 1000)")


func _test_compound_and_both_met() -> void:
	var sources: Dictionary = {
		"stats": _make_source({"kills": 100, "coins": 1000}),
	}
	var c1: UnlockCondition = _make_leaf("stats", "kills", UnlockCondition.Operator.GEQ, 100)
	var c2: UnlockCondition = _make_leaf("stats", "coins", UnlockCondition.Operator.GEQ, 1000)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [c1, c2])
	_assert(ConditionEvaluator.evaluate(root, sources), "compound AND both met")


func _test_compound_and_one_unmet() -> void:
	var sources: Dictionary = {
		"stats": _make_source({"kills": 50, "coins": 1000}),
	}
	var c1: UnlockCondition = _make_leaf("stats", "kills", UnlockCondition.Operator.GEQ, 100)
	var c2: UnlockCondition = _make_leaf("stats", "coins", UnlockCondition.Operator.GEQ, 1000)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [c1, c2])
	_assert(not ConditionEvaluator.evaluate(root, sources), "compound AND one unmet")


func _test_compound_or_one_met() -> void:
	var sources: Dictionary = {
		"progress": _make_source({"level_3_passed": true, "level_5_passed": false}),
	}
	var c1: UnlockCondition = _make_leaf("progress", "level_3_passed", UnlockCondition.Operator.EQ, true)
	var c2: UnlockCondition = _make_leaf("progress", "level_5_passed", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.OR, [c1, c2])
	_assert(ConditionEvaluator.evaluate(root, sources), "compound OR one met")


func _test_compound_or_none_met() -> void:
	var sources: Dictionary = {
		"progress": _make_source({"level_3_passed": false, "level_5_passed": false}),
	}
	var c1: UnlockCondition = _make_leaf("progress", "level_3_passed", UnlockCondition.Operator.EQ, true)
	var c2: UnlockCondition = _make_leaf("progress", "level_5_passed", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.OR, [c1, c2])
	_assert(not ConditionEvaluator.evaluate(root, sources), "compound OR none met")


func _test_nested_compound() -> void:
	# (A AND B) OR C — C alone should pass
	var sources: Dictionary = {
		"s": _make_source({"a": false, "b": false, "c": true}),
	}
	var a: UnlockCondition = _make_leaf("s", "a", UnlockCondition.Operator.EQ, true)
	var b: UnlockCondition = _make_leaf("s", "b", UnlockCondition.Operator.EQ, true)
	var c: UnlockCondition = _make_leaf("s", "c", UnlockCondition.Operator.EQ, true)
	var and_group: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [a, b])
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.OR, [and_group, c])
	_assert(ConditionEvaluator.evaluate(root, sources), "nested (A AND B) OR C — C alone met")


func _test_null_source_returns_false() -> void:
	var sources: Dictionary = {} # no sources registered
	var leaf: UnlockCondition = _make_leaf("missing", "key", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	_assert(not ConditionEvaluator.evaluate(root, sources), "missing source returns false")


func _test_get_condition_status() -> void:
	var sources: Dictionary = {
		"stats": _make_source({"kills": 50, "coins": 1000}),
	}
	var c1: UnlockCondition = _make_leaf("stats", "kills", UnlockCondition.Operator.GEQ, 100)
	var c2: UnlockCondition = _make_leaf("stats", "coins", UnlockCondition.Operator.GEQ, 1000)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [c1, c2])

	var status: Array[Dictionary] = ConditionEvaluator.get_condition_status(root, sources)
	_assert(status.size() == 2, "get_condition_status returns 2 entries")
	_assert(status[0].is_met == false, "kills not met (50 < 100)")
	_assert(status[0].current_value == 50, "kills current value is 50")
	_assert(status[1].is_met == true, "coins met (1000 >= 1000)")
	_assert(status[1].current_value == 1000, "coins current value is 1000")


func _test_get_condition_status_nested() -> void:
	var sources: Dictionary = {"s": _make_source({"a": true, "b": false})}
	var a: UnlockCondition = _make_leaf("s", "a", UnlockCondition.Operator.EQ, true)
	var b: UnlockCondition = _make_leaf("s", "b", UnlockCondition.Operator.EQ, true)
	var inner: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [a, b])
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.OR, [inner])

	var status: Array[Dictionary] = ConditionEvaluator.get_condition_status(root, sources)
	_assert(status.size() == 1, "nested status has 1 compound entry")
	_assert(status[0].has("children"), "compound entry has children key")
	_assert(status[0].is_met == false, "inner AND is not met (b is false)")


# --- Mock ---


class _MockSource:
	extends RefCounted

	signal value_changed(key: String, new_value: Variant)

	var _data: Dictionary = {}

	func get_value(key: String) -> Variant:
		return _data.get(key)

	func set_value(key: String, val: Variant) -> void:
		_data[key] = val
		value_changed.emit(key, val)

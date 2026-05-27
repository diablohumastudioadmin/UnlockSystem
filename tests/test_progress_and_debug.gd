extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Progress & Debug Tests ===")
	_test_get_progress_counts()
	_test_why_locked_returns_status()
	_test_progress_updated_signal()
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


func _test_get_progress_counts() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"a": true, "b": false, "c": true}
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

	var c3: UnlockCondition = UnlockCondition.new()
	c3.source_name = "s"
	c3.key = "c"
	c3.operator = UnlockCondition.Operator.EQ
	c3.target_value = true

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [c1, c2, c3]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = compound
	rule.targets = ["achievement"]

	m.add_rule(rule)

	var progress: Dictionary = m.get_progress("achievement")
	_assert(progress.met == 2, "get_progress: 2 of 3 conditions met")
	_assert(progress.total == 3, "get_progress: total is 3")
	_assert(progress.conditions.size() == 3, "get_progress: 3 condition entries")
	m.queue_free()


func _test_why_locked_returns_status() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"kills": 50, "coins": 1500}
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

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = compound
	rule.targets = ["ach"]

	m.add_rule(rule)

	var reasons: Array[Dictionary] = m.why_locked("ach")
	_assert(reasons.size() == 2, "why_locked: 2 conditions")

	# First condition: kills 50 < 100 → not met
	_assert(reasons[0].source_name == "stats", "why_locked: source_name correct")
	_assert(reasons[0].key == "kills", "why_locked: key correct")
	_assert(reasons[0].current_value == 50, "why_locked: current_value correct")
	_assert(reasons[0].is_met == false, "why_locked: kills not met")

	# Second condition: coins 1500 >= 1000 → met
	_assert(reasons[1].is_met == true, "why_locked: coins met")

	# Unknown target returns empty
	var unknown: Array[Dictionary] = m.why_locked("nonexistent")
	_assert(unknown.is_empty(), "why_locked: unknown target → empty array")
	m.queue_free()


func _test_progress_updated_signal() -> void:
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

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = compound
	rule.targets = ["t1"]

	m.add_rule(rule)

	var updates: Array[Dictionary] = []
	m.progress_updated.connect(func(key: String, met: int, total: int) -> void:
		updates.append({"key": key, "met": met, "total": total})
	)

	src.set_value("a", true)
	_assert(not updates.is_empty(), "progress_updated emitted on source change")
	if not updates.is_empty():
		var last: Dictionary = updates[updates.size() - 1]
		_assert(last.met == 1, "progress_updated: 1 met")
		_assert(last.total == 2, "progress_updated: 2 total")

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

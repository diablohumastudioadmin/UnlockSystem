extends SceneTree


var _passed: int = 0
var _failed: int = 0
var _manager: Node = null


func _init() -> void:
	print("=== UnlockManager Tests ===")

	_test_register_and_has_source()
	_test_unregister_source()
	_test_add_and_get_rule()
	_test_remove_rule()
	_test_simple_unlock_via_source_change()
	_test_unlock_granted_signal()
	_test_is_unlocked()
	_test_idempotent_unlock()
	_test_get_state_load_state()
	_test_clear_state()
	_test_evaluation_error_missing_source()

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
	var manager_script: GDScript = load("res://addons/unlock_system/unlock_manager.gd") as GDScript
	var m: Node = manager_script.new()
	root.add_child(m)
	return m


func _cleanup_manager(m: Node) -> void:
	m.queue_free()


# --- Helpers ---


func _make_source(data: Dictionary) -> RefCounted:
	var source: _MockSource = _MockSource.new()
	source._data = data
	return source


func _make_leaf(source_name: String, key: String, op: int, value: Variant) -> UnlockCondition:
	var c: UnlockCondition = UnlockCondition.new()
	c.source_name = source_name
	c.key = key
	c.operator = op
	c.target_value = value
	return c


func _make_compound(op: int, children: Array) -> CompoundCondition:
	var cc: CompoundCondition = CompoundCondition.new()
	cc.operator = op
	cc.children = children
	return cc


func _make_rule(id: String, conditions: CompoundCondition, targets: Array[String], effects: Array[UnlockEffect] = []) -> UnlockRule:
	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = id
	rule.conditions = conditions
	rule.targets = targets
	rule.effects = effects
	return rule


# --- Tests ---


func _test_register_and_has_source() -> void:
	var m: Node = _create_manager()
	var source: RefCounted = _make_source({})
	m.register_source("test", source)
	_assert(m.has_source("test"), "has_source returns true after register")
	_assert(not m.has_source("other"), "has_source returns false for unregistered")
	_cleanup_manager(m)


func _test_unregister_source() -> void:
	var m: Node = _create_manager()
	var source: RefCounted = _make_source({})
	m.register_source("test", source)
	m.unregister_source("test")
	_assert(not m.has_source("test"), "has_source returns false after unregister")
	_cleanup_manager(m)


func _test_add_and_get_rule() -> void:
	var m: Node = _create_manager()
	var leaf: UnlockCondition = _make_leaf("s", "k", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["target_a"])
	m.add_rule(rule)
	_assert(m.get_rule("r1") == rule, "get_rule returns added rule")
	_assert(m.get_rule("nonexistent") == null, "get_rule returns null for unknown")
	_assert(m.get_all_rules().size() == 1, "get_all_rules returns 1 rule")
	_cleanup_manager(m)


func _test_remove_rule() -> void:
	var m: Node = _create_manager()
	var leaf: UnlockCondition = _make_leaf("s", "k", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["target_a"])
	m.add_rule(rule)
	m.remove_rule("r1")
	_assert(m.get_rule("r1") == null, "rule removed")
	_assert(m.get_all_rules().size() == 0, "no rules after remove")
	_cleanup_manager(m)


func _test_simple_unlock_via_source_change() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"level_4_passed": false}
	m.register_source("progress", source)

	var leaf: UnlockCondition = _make_leaf("progress", "level_4_passed", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("unlock_level_5", root, ["level_5"])
	m.add_rule(rule)

	_assert(not m.is_unlocked("level_5"), "level_5 locked before trigger")

	# Trigger the condition
	source.set_value("level_4_passed", true)

	_assert(m.is_unlocked("level_5"), "level_5 unlocked after source change")
	_cleanup_manager(m)


func _test_unlock_granted_signal() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"done": false}
	m.register_source("s", source)

	var leaf: UnlockCondition = _make_leaf("s", "done", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["t1"])
	m.add_rule(rule)

	var received: Array[String] = []
	m.unlock_granted.connect(func(key: String) -> void: received.append(key))

	source.set_value("done", true)

	_assert(received.size() == 1, "unlock_granted emitted once")
	_assert(received[0] == "t1" if received.size() > 0 else false, "unlock_granted received correct target")
	_cleanup_manager(m)


func _test_is_unlocked() -> void:
	var m: Node = _create_manager()
	_assert(not m.is_unlocked("anything"), "is_unlocked returns false for unknown target")
	_cleanup_manager(m)


func _test_idempotent_unlock() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"done": true}
	m.register_source("s", source)

	var leaf: UnlockCondition = _make_leaf("s", "done", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["t1"])

	var signal_count: Array[int] = [0]
	m.unlock_granted.connect(func(_key: String) -> void: signal_count[0] += 1)

	m.add_rule(rule)
	# Rule fires immediately since condition is already met → signal_count = 1

	# Trigger again
	source.set_value("done", true)

	_assert(signal_count[0] == 1, "idempotent: unlock_granted emitted only once despite re-trigger")
	_cleanup_manager(m)


func _test_get_state_load_state() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"done": true}
	m.register_source("s", source)

	var leaf: UnlockCondition = _make_leaf("s", "done", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["t1"])
	m.add_rule(rule)

	var state: Dictionary = m.get_state()
	_assert(state.has("unlocked_targets"), "state has unlocked_targets")
	_assert(state.unlocked_targets.get("t1", false), "state includes t1 as unlocked")
	_assert(state.has("version"), "state has version")

	# Create a fresh manager and load state
	var m2: Node = _create_manager()
	m2.register_source("s", source)
	m2.add_rule(rule)
	m2.clear_state()
	_assert(not m2.is_unlocked("t1"), "cleared state: t1 locked")

	m2.load_state(state)
	_assert(m2.is_unlocked("t1"), "loaded state: t1 unlocked")

	_cleanup_manager(m)
	_cleanup_manager(m2)


func _test_clear_state() -> void:
	var m: Node = _create_manager()
	var source: _MockSource = _MockSource.new()
	source._data = {"done": true}
	m.register_source("s", source)

	var leaf: UnlockCondition = _make_leaf("s", "done", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["t1"])
	m.add_rule(rule)

	_assert(m.is_unlocked("t1"), "t1 unlocked before clear")
	m.clear_state()
	_assert(not m.is_unlocked("t1"), "t1 locked after clear")
	_cleanup_manager(m)


func _test_evaluation_error_missing_source() -> void:
	var m: Node = _create_manager()
	var leaf: UnlockCondition = _make_leaf("nonexistent", "key", UnlockCondition.Operator.EQ, true)
	var root: CompoundCondition = _make_compound(CompoundCondition.Logic.AND, [leaf])
	var rule: UnlockRule = _make_rule("r1", root, ["t1"])

	var errors: Array[String] = []
	m.evaluation_error.connect(func(rid: String, msg: String) -> void: errors.append(msg))

	m.add_rule(rule)

	_assert(errors.size() > 0, "evaluation_error emitted for missing source")
	_assert(not m.is_unlocked("t1"), "target stays locked when source missing")
	_cleanup_manager(m)


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

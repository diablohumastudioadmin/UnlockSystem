extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Quickstart Validation Tests ===")
	_test_data_source_contract()
	_test_code_configuration()
	_test_listen_for_unlocks()
	_test_progress_and_debug()
	_test_save_load_state()
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


func _test_data_source_contract() -> void:
	# Validates Section 2: data source contract (signal + get_value)
	var m: Node = _create_manager()
	var tracker: _CoinTracker = _CoinTracker.new()
	m.register_source("coins", tracker)
	_assert(m.has_source("coins"), "quickstart: source registered")
	_assert(tracker.get_value("balance") == 0, "quickstart: initial balance is 0")
	tracker.add_coins(100)
	_assert(tracker.get_value("balance") == 100, "quickstart: balance after add_coins")
	m.queue_free()


func _test_code_configuration() -> void:
	# Validates Section 4: configure unlock rule via code
	var m: Node = _create_manager()
	var progress_src: _MockSource = _MockSource.new()
	progress_src._data = {"level_4_passed": false}
	m.register_source("progress", progress_src)

	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = "progress"
	condition.key = "level_4_passed"
	condition.operator = UnlockCondition.Operator.EQ
	condition.target_value = true

	var root_cond: CompoundCondition = CompoundCondition.new()
	root_cond.operator = CompoundCondition.Logic.AND
	root_cond.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_level_5"
	rule.conditions = root_cond
	rule.targets = ["level_5"]

	m.add_rule(rule)
	_assert(not m.is_unlocked("level_5"), "quickstart: level_5 locked initially")

	progress_src.set_value("level_4_passed", true)
	_assert(m.is_unlocked("level_5"), "quickstart: level_5 unlocked after condition met")
	m.queue_free()


func _test_listen_for_unlocks() -> void:
	# Validates Section 5: listen for unlock_granted signal
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"done": false}
	m.register_source("s", src)

	var unlocked_keys: Array[String] = []
	m.unlock_granted.connect(func(key: String) -> void: unlocked_keys.append(key))

	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = "s"
	condition.key = "done"
	condition.operator = UnlockCondition.Operator.EQ
	condition.target_value = true

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = compound
	rule.targets = ["reward"]
	m.add_rule(rule)

	src.set_value("done", true)
	_assert("reward" in unlocked_keys, "quickstart: unlock_granted signal received")
	m.queue_free()


func _test_progress_and_debug() -> void:
	# Validates Section 6: get_progress and why_locked
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
	rule.rule_id = "ach_vet"
	rule.conditions = compound
	rule.targets = ["achievement_veteran"]
	m.add_rule(rule)

	var progress: Dictionary = m.get_progress("achievement_veteran")
	_assert(progress.met == 1, "quickstart: 1/2 conditions met (coins >= 1000)")
	_assert(progress.total == 2, "quickstart: 2 total conditions")

	var reasons: Array[Dictionary] = m.why_locked("achievement_veteran")
	_assert(reasons.size() == 2, "quickstart: why_locked returns 2 entries")
	m.queue_free()


func _test_save_load_state() -> void:
	# Validates Section 7: get_state / load_state round-trip
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"done": true}
	m.register_source("s", src)

	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = "s"
	condition.key = "done"
	condition.operator = UnlockCondition.Operator.EQ
	condition.target_value = true

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "r1"
	rule.conditions = compound
	rule.targets = ["t1"]
	m.add_rule(rule)

	_assert(m.is_unlocked("t1"), "quickstart save/load: initially unlocked")

	var state: Dictionary = m.get_state()
	_assert(state.has("unlocked_targets"), "quickstart save/load: state has unlocked_targets")

	m.clear_state()
	_assert(not m.is_unlocked("t1"), "quickstart save/load: cleared")

	m.load_state(state)
	_assert(m.is_unlocked("t1"), "quickstart save/load: restored")
	m.queue_free()


class _CoinTracker:
	extends RefCounted

	signal value_changed(key: String, new_value: Variant)

	var _coins: int = 0

	func get_value(key: String) -> Variant:
		if key == "balance":
			return _coins
		return null

	func add_coins(amount: int) -> void:
		_coins += amount
		value_changed.emit("balance", _coins)


class _MockSource:
	extends RefCounted

	signal value_changed(key: String, new_value: Variant)

	var _data: Dictionary = {}

	func get_value(key: String) -> Variant:
		return _data.get(key)

	func set_value(key: String, val: Variant) -> void:
		_data[key] = val
		value_changed.emit(key, val)

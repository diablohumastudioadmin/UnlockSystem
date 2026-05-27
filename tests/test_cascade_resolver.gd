extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Cascade Resolver Tests (US5) ===")
	_test_linear_cascade()
	_test_cascade_completed_signal()
	_test_circular_dependency_detection()
	_test_cascade_with_effects()
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


func _make_leaf(source_name: String, key: String, op: int, value: Variant) -> UnlockCondition:
	var c: UnlockCondition = UnlockCondition.new()
	c.source_name = source_name
	c.key = key
	c.operator = op
	c.target_value = value
	return c


func _make_compound(children: Array) -> CompoundCondition:
	var cc: CompoundCondition = CompoundCondition.new()
	cc.operator = CompoundCondition.Logic.AND
	cc.children = children
	return cc


func _make_rule(id: String, conditions: CompoundCondition, targets: Array[String], effects: Array[UnlockEffect] = []) -> UnlockRule:
	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = id
	rule.conditions = conditions
	rule.targets = targets
	rule.effects = effects
	return rule


func _test_linear_cascade() -> void:
	# A → B → C: unlocking A should cascade to B then C
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"trigger_a": false}

	# Use the unlock system's own state as a "source" for cascade conditions
	# by making unlock targets write back to a source
	var unlock_src: _MockSource = _MockSource.new()
	unlock_src._data = {}

	m.register_source("triggers", src)
	m.register_source("unlocks", unlock_src)

	# Rule 1: trigger_a → unlock A (and write A to unlocks source)
	var effect_a: UnlockEffect = UnlockEffect.new()
	effect_a.target_source = "unlocks"
	effect_a.target_key = "a_unlocked"
	effect_a.operation = UnlockEffect.Operation.SET
	effect_a.value = true

	var rule1: UnlockRule = _make_rule(
		"r1",
		_make_compound([_make_leaf("triggers", "trigger_a", UnlockCondition.Operator.EQ, true)]),
		["target_a"],
		[effect_a]
	)

	# Rule 2: a_unlocked → unlock B (and write B to unlocks source)
	var effect_b: UnlockEffect = UnlockEffect.new()
	effect_b.target_source = "unlocks"
	effect_b.target_key = "b_unlocked"
	effect_b.operation = UnlockEffect.Operation.SET
	effect_b.value = true

	var rule2: UnlockRule = _make_rule(
		"r2",
		_make_compound([_make_leaf("unlocks", "a_unlocked", UnlockCondition.Operator.EQ, true)]),
		["target_b"],
		[effect_b]
	)

	# Rule 3: b_unlocked → unlock C
	var rule3: UnlockRule = _make_rule(
		"r3",
		_make_compound([_make_leaf("unlocks", "b_unlocked", UnlockCondition.Operator.EQ, true)]),
		["target_c"]
	)

	m.add_rule(rule1)
	m.add_rule(rule2)
	m.add_rule(rule3)

	src.set_value("trigger_a", true)

	_assert(m.is_unlocked("target_a"), "cascade: A unlocked")
	_assert(m.is_unlocked("target_b"), "cascade: B unlocked (via A)")
	_assert(m.is_unlocked("target_c"), "cascade: C unlocked (via B)")
	m.queue_free()


func _test_cascade_completed_signal() -> void:
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"go": false}
	var cascade_src: _MockSource = _MockSource.new()
	cascade_src._data = {}

	m.register_source("s", src)
	m.register_source("cascade", cascade_src)

	var effect: UnlockEffect = UnlockEffect.new()
	effect.target_source = "cascade"
	effect.target_key = "a_done"
	effect.operation = UnlockEffect.Operation.SET
	effect.value = true

	var rule1: UnlockRule = _make_rule(
		"r1",
		_make_compound([_make_leaf("s", "go", UnlockCondition.Operator.EQ, true)]),
		["t1"],
		[effect]
	)
	var rule2: UnlockRule = _make_rule(
		"r2",
		_make_compound([_make_leaf("cascade", "a_done", UnlockCondition.Operator.EQ, true)]),
		["t2"]
	)

	m.add_rule(rule1)
	m.add_rule(rule2)

	var chains: Array = []
	m.cascade_completed.connect(func(chain: Array[String]) -> void: chains.append(chain))

	src.set_value("go", true)

	_assert(chains.size() == 1, "cascade_completed emitted once")
	if not chains.is_empty():
		_assert(chains[0].size() >= 2, "chain includes at least 2 targets")

	m.queue_free()


func _test_circular_dependency_detection() -> void:
	# A requires B unlocked, B requires A unlocked → cycle
	var m: Node = _create_manager()
	var src: _MockSource = _MockSource.new()
	src._data = {"a_unlocked": false, "b_unlocked": false}
	m.register_source("s", src)

	# Rule 1: a_unlocked → unlock B (and set b_unlocked)
	var effect_b: UnlockEffect = UnlockEffect.new()
	effect_b.target_source = "s"
	effect_b.target_key = "b_unlocked"
	effect_b.operation = UnlockEffect.Operation.SET
	effect_b.value = true

	var rule1: UnlockRule = _make_rule(
		"r1",
		_make_compound([_make_leaf("s", "a_unlocked", UnlockCondition.Operator.EQ, true)]),
		["target_b"],
		[effect_b]
	)

	# Rule 2: b_unlocked → unlock A (and set a_unlocked)
	var effect_a: UnlockEffect = UnlockEffect.new()
	effect_a.target_source = "s"
	effect_a.target_key = "a_unlocked"
	effect_a.operation = UnlockEffect.Operation.SET
	effect_a.value = true

	var rule2: UnlockRule = _make_rule(
		"r2",
		_make_compound([_make_leaf("s", "b_unlocked", UnlockCondition.Operator.EQ, true)]),
		["target_a"],
		[effect_a]
	)

	m.add_rule(rule1)
	m.add_rule(rule2)

	# Trigger the cycle
	src.set_value("a_unlocked", true)

	# The system should not hang. Both may unlock (since each satisfies the other)
	# but the cascade must terminate (not infinite loop)
	_assert(true, "circular dependency did not cause infinite loop")
	m.queue_free()


func _test_cascade_with_effects() -> void:
	# Rule fires → effect grants 500 coins → coins condition met → second rule fires
	var m: Node = _create_manager()
	var trigger_src: _MockSource = _MockSource.new()
	trigger_src._data = {"quest_done": false}
	var currency_src: _MockSource = _MockSource.new()
	currency_src._data = {"coins": 0}

	m.register_source("triggers", trigger_src)
	m.register_source("currency", currency_src)

	# Rule 1: quest_done → unlock achievement + grant 500 coins
	var coin_effect: UnlockEffect = UnlockEffect.new()
	coin_effect.target_source = "currency"
	coin_effect.target_key = "coins"
	coin_effect.operation = UnlockEffect.Operation.ADD
	coin_effect.value = 500

	var rule1: UnlockRule = _make_rule(
		"r1",
		_make_compound([_make_leaf("triggers", "quest_done", UnlockCondition.Operator.EQ, true)]),
		["ach_quest"],
		[coin_effect]
	)

	# Rule 2: coins >= 500 → unlock skin
	var rule2: UnlockRule = _make_rule(
		"r2",
		_make_compound([_make_leaf("currency", "coins", UnlockCondition.Operator.GEQ, 500)]),
		["skin_gold"]
	)

	m.add_rule(rule1)
	m.add_rule(rule2)

	trigger_src.set_value("quest_done", true)

	_assert(m.is_unlocked("ach_quest"), "achievement unlocked")
	_assert(currency_src._data.get("coins") == 500, "coins granted via effect")
	_assert(m.is_unlocked("skin_gold"), "skin unlocked via cascaded coin grant")
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

extends SceneTree


var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== Character Progression Tests (US7) ===")
	_test_purchase_unlocks_specific_branch_level()
	_test_gameplay_unlocks_character_level()
	_test_mixed_conditions_character_upgrade()
	_test_unlock_isolation_across_branches()
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


func _make_rule(id: String, conditions: CompoundCondition, targets: Array[String]) -> UnlockRule:
	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = id
	rule.conditions = conditions
	rule.targets = targets
	return rule


func _test_purchase_unlocks_specific_branch_level() -> void:
	var m: Node = _create_manager()
	var shop: _MockSource = _MockSource.new()
	shop._data = {"char_a_b2_l3_purchased": false}
	m.register_source("shop", shop)

	var rule: UnlockRule = _make_rule(
		"char_a_b2_l3",
		_make_compound([_make_leaf("shop", "char_a_b2_l3_purchased", UnlockCondition.Operator.EQ, true)]),
		["char_a_branch_2_level_3"]
	)
	m.add_rule(rule)

	shop.set_value("char_a_b2_l3_purchased", true)
	_assert(m.is_unlocked("char_a_branch_2_level_3"), "purchase unlocks specific branch level")
	m.queue_free()


func _test_gameplay_unlocks_character_level() -> void:
	var m: Node = _create_manager()
	var progress: _MockSource = _MockSource.new()
	progress._data = {"level_40_passed": false}
	m.register_source("progress", progress)

	var rule: UnlockRule = _make_rule(
		"char_b_l1",
		_make_compound([_make_leaf("progress", "level_40_passed", UnlockCondition.Operator.EQ, true)]),
		["char_b_level_1"]
	)
	m.add_rule(rule)

	progress.set_value("level_40_passed", true)
	_assert(m.is_unlocked("char_b_level_1"), "gameplay unlocks character level")
	m.queue_free()


func _test_mixed_conditions_character_upgrade() -> void:
	var m: Node = _create_manager()
	var progress: _MockSource = _MockSource.new()
	progress._data = {"level_20_passed": false}
	var shop: _MockSource = _MockSource.new()
	shop._data = {"char_c_upgrade_bought": false}

	m.register_source("progress", progress)
	m.register_source("shop", shop)

	var c1: UnlockCondition = _make_leaf("progress", "level_20_passed", UnlockCondition.Operator.EQ, true)
	var c2: UnlockCondition = _make_leaf("shop", "char_c_upgrade_bought", UnlockCondition.Operator.EQ, true)

	var rule: UnlockRule = _make_rule(
		"char_c_b1_l2",
		_make_compound([c1, c2]),
		["char_c_branch_1_level_2"]
	)
	m.add_rule(rule)

	progress.set_value("level_20_passed", true)
	_assert(not m.is_unlocked("char_c_branch_1_level_2"), "mixed: only gameplay met → locked")

	shop.set_value("char_c_upgrade_bought", true)
	_assert(m.is_unlocked("char_c_branch_1_level_2"), "mixed: both met → unlocked")
	m.queue_free()


func _test_unlock_isolation_across_branches() -> void:
	var m: Node = _create_manager()
	var shop: _MockSource = _MockSource.new()
	shop._data = {"buy_a_b1_l1": false, "buy_a_b2_l1": false}
	m.register_source("shop", shop)

	var rule1: UnlockRule = _make_rule(
		"a_b1_l1",
		_make_compound([_make_leaf("shop", "buy_a_b1_l1", UnlockCondition.Operator.EQ, true)]),
		["char_a_branch_1_level_1"]
	)
	var rule2: UnlockRule = _make_rule(
		"a_b2_l1",
		_make_compound([_make_leaf("shop", "buy_a_b2_l1", UnlockCondition.Operator.EQ, true)]),
		["char_a_branch_2_level_1"]
	)

	m.add_rule(rule1)
	m.add_rule(rule2)

	shop.set_value("buy_a_b1_l1", true)
	_assert(m.is_unlocked("char_a_branch_1_level_1"), "branch 1 unlocked")
	_assert(not m.is_unlocked("char_a_branch_2_level_1"), "branch 2 still locked (isolation)")
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

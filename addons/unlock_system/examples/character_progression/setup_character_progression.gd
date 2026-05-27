## Example: Character progression with 2 branches, 3 levels each.
## Demonstrates varied condition types (purchase, gameplay, compound).
extends Node


func _ready() -> void:
	# Branch 1: gameplay-based progression
	_add_gameplay_rule("char_a_b1_l1", "progress", "level_10_passed")
	_add_gameplay_rule("char_a_b1_l2", "progress", "level_20_passed")
	_add_gameplay_rule("char_a_b1_l3", "progress", "level_30_passed")

	# Branch 2: purchase-based for level 1 and 2, compound for level 3
	_add_purchase_rule("char_a_b2_l1", "shop", "char_a_b2_l1_purchased")
	_add_purchase_rule("char_a_b2_l2", "shop", "char_a_b2_l2_purchased")
	_add_compound_rule(
		"char_a_b2_l3",
		"shop", "char_a_b2_l3_purchased",
		"progress", "level_40_passed"
	)


func _add_gameplay_rule(target: String, source: String, key: String) -> void:
	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = source
	condition.key = key
	condition.operator = UnlockCondition.Operator.EQ
	condition.target_value = true

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_%s" % target
	rule.conditions = compound
	rule.targets = [target]

	UnlockManager.add_rule(rule)


func _add_purchase_rule(target: String, source: String, key: String) -> void:
	_add_gameplay_rule(target, source, key)


func _add_compound_rule(
	target: String,
	source1: String, key1: String,
	source2: String, key2: String,
) -> void:
	var c1: UnlockCondition = UnlockCondition.new()
	c1.source_name = source1
	c1.key = key1
	c1.operator = UnlockCondition.Operator.EQ
	c1.target_value = true

	var c2: UnlockCondition = UnlockCondition.new()
	c2.source_name = source2
	c2.key = key2
	c2.operator = UnlockCondition.Operator.EQ
	c2.target_value = true

	var compound: CompoundCondition = CompoundCondition.new()
	compound.operator = CompoundCondition.Logic.AND
	compound.children = [c1, c2]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_%s" % target
	rule.conditions = compound
	rule.targets = [target]

	UnlockManager.add_rule(rule)

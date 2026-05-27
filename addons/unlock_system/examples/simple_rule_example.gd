## Example: How to create a simple unlock rule via code.
## "Level 5 unlocks when Level 4 is passed"
##
## This script can be attached to any Node in your scene to demonstrate
## simple rule creation. In production, you'd do this in your game's
## initialization logic.
extends Node


func _ready() -> void:
	var condition: UnlockCondition = UnlockCondition.new()
	condition.source_name = "progress"
	condition.key = "level_4_passed"
	condition.operator = UnlockCondition.Operator.EQ
	condition.target_value = true

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "unlock_level_5"
	rule.conditions = root
	rule.targets = ["level_5"]

	UnlockManager.add_rule(rule)

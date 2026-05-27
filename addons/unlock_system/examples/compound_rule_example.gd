## Example: Compound unlock rule with AND conditions from different sources.
## "Achievement X requires killing 100 enemies AND having 1000 coins"
extends Node


func _ready() -> void:
	var kills_condition: UnlockCondition = UnlockCondition.new()
	kills_condition.source_name = "stats"
	kills_condition.key = "enemies_killed"
	kills_condition.operator = UnlockCondition.Operator.GEQ
	kills_condition.target_value = 100

	var coins_condition: UnlockCondition = UnlockCondition.new()
	coins_condition.source_name = "currency"
	coins_condition.key = "balance"
	coins_condition.operator = UnlockCondition.Operator.GEQ
	coins_condition.target_value = 1000

	var root: CompoundCondition = CompoundCondition.new()
	root.operator = CompoundCondition.Logic.AND
	root.children = [kills_condition, coins_condition]

	var rule: UnlockRule = UnlockRule.new()
	rule.rule_id = "achievement_warrior"
	rule.conditions = root
	rule.targets = ["ach_warrior"]

	UnlockManager.add_rule(rule)

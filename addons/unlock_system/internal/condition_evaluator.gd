class_name ConditionEvaluator
extends RefCounted


## Evaluate a compound condition tree against registered data sources.
## [param sources] is a Dictionary[String, Object] mapping source names to source objects.
## Each source object must have a method get_value(key: String) -> Variant.
static func evaluate(condition: CompoundCondition, sources: Dictionary) -> bool:
	if condition == null or condition.children.is_empty():
		return false

	if condition.operator == CompoundCondition.Logic.AND:
		for child: Resource in condition.children:
			if not _evaluate_child(child, sources):
				return false
		return true
	else: # OR
		for child: Resource in condition.children:
			if _evaluate_child(child, sources):
				return true
		return false


## Return per-condition status for a compound condition tree.
## Returns an Array of Dictionaries, each with:
##   source_name, key, operator, target_value, current_value, is_met
## For compound children, includes a "children" key with nested results.
static func get_condition_status(condition: CompoundCondition, sources: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if condition == null:
		return result

	for child: Resource in condition.children:
		if child is UnlockCondition:
			var leaf: UnlockCondition = child as UnlockCondition
			var current_value: Variant = _get_source_value(leaf.source_name, leaf.key, sources)
			var is_met: bool = _evaluate_leaf(leaf, current_value)
			result.append({
				"source_name": leaf.source_name,
				"key": leaf.key,
				"operator": leaf.operator,
				"target_value": leaf.target_value,
				"current_value": current_value,
				"is_met": is_met,
			})
		elif child is CompoundCondition:
			var compound: CompoundCondition = child as CompoundCondition
			var children_status: Array[Dictionary] = get_condition_status(compound, sources)
			var compound_met: bool = evaluate(compound, sources)
			result.append({
				"operator": compound.operator,
				"is_met": compound_met,
				"children": children_status,
			})

	return result


static func _evaluate_child(child: Resource, sources: Dictionary) -> bool:
	if child is UnlockCondition:
		var leaf: UnlockCondition = child as UnlockCondition
		var current_value: Variant = _get_source_value(leaf.source_name, leaf.key, sources)
		return _evaluate_leaf(leaf, current_value)
	elif child is CompoundCondition:
		return evaluate(child as CompoundCondition, sources)
	return false


static func _evaluate_leaf(leaf: UnlockCondition, current_value: Variant) -> bool:
	if current_value == null:
		return false

	match leaf.operator:
		UnlockCondition.Operator.EQ:
			return current_value == leaf.target_value
		UnlockCondition.Operator.NEQ:
			return current_value != leaf.target_value
		UnlockCondition.Operator.GEQ:
			return current_value >= leaf.target_value
		UnlockCondition.Operator.LEQ:
			return current_value <= leaf.target_value
		UnlockCondition.Operator.GT:
			return current_value > leaf.target_value
		UnlockCondition.Operator.LT:
			return current_value < leaf.target_value

	return false


static func _get_source_value(source_name: String, key: String, sources: Dictionary) -> Variant:
	if not sources.has(source_name):
		return null
	var source: Object = sources[source_name]
	if source == null or not source.has_method("get_value"):
		return null
	return source.get_value(key)

extends Node


signal unlock_granted(target_key: String)
signal progress_updated(target_key: String, met: int, total: int)
signal cascade_completed(chain: Array[String])
signal evaluation_error(rule_id: String, message: String)


var _sources: Dictionary = {} # String → Object
var _rules: Dictionary = {} # String → UnlockRule
var _source_to_rules: Dictionary = {} # String → Array[String] (rule_ids)
var _unlocked_targets: Dictionary = {} # String → bool
var _cascade_max_depth: int = 10
var _evaluating: bool = false
var _cascade_chain: Array[String] = []


# --- Data Source Management ---


func register_source(source_name: String, source: Object) -> void:
	if _sources.has(source_name):
		push_warning("UnlockManager: overwriting existing source '%s'" % source_name)
		_disconnect_source(source_name)

	_sources[source_name] = source

	if source.has_signal("value_changed"):
		source.value_changed.connect(_on_source_value_changed.bind(source_name))

	_rebuild_source_index_for(source_name)


func unregister_source(source_name: String) -> void:
	if not _sources.has(source_name):
		return

	_disconnect_source(source_name)
	_sources.erase(source_name)
	_source_to_rules.erase(source_name)


func has_source(source_name: String) -> bool:
	return _sources.has(source_name)


# --- Rule Management ---


func add_rule(rule: UnlockRule) -> void:
	if rule == null or rule.rule_id.is_empty():
		push_warning("UnlockManager: cannot add rule with empty rule_id")
		return

	if _rules.has(rule.rule_id):
		push_warning("UnlockManager: overwriting existing rule '%s'" % rule.rule_id)
		_remove_rule_from_index(rule.rule_id)

	_rules[rule.rule_id] = rule
	_index_rule(rule)
	_evaluate_rule(rule)


func remove_rule(rule_id: String) -> void:
	if not _rules.has(rule_id):
		return

	_remove_rule_from_index(rule_id)
	_rules.erase(rule_id)


func get_rule(rule_id: String) -> UnlockRule:
	return _rules.get(rule_id) as UnlockRule


func get_all_rules() -> Array[UnlockRule]:
	var result: Array[UnlockRule] = []
	for rule: UnlockRule in _rules.values():
		result.append(rule)
	return result


# --- State Queries ---


func is_unlocked(target_key: String) -> bool:
	return _unlocked_targets.get(target_key, false)


func get_progress(target_key: String) -> Dictionary:
	var rules_for_target: Array[UnlockRule] = _find_rules_for_target(target_key)
	if rules_for_target.is_empty():
		return {"met": 0, "total": 0, "conditions": []}

	# Use the first rule that targets this key
	var rule: UnlockRule = rules_for_target[0]
	var status: Array[Dictionary] = ConditionEvaluator.get_condition_status(
		rule.conditions, _sources
	)

	var met: int = 0
	var total: int = status.size()
	for entry: Dictionary in status:
		if entry.get("is_met", false):
			met += 1

	return {"met": met, "total": total, "conditions": status}


func why_locked(target_key: String) -> Array[Dictionary]:
	var rules_for_target: Array[UnlockRule] = _find_rules_for_target(target_key)
	if rules_for_target.is_empty():
		return []

	var rule: UnlockRule = rules_for_target[0]
	return ConditionEvaluator.get_condition_status(rule.conditions, _sources)


# --- State Persistence ---


func get_state() -> Dictionary:
	return {
		"unlocked_targets": _unlocked_targets.duplicate(),
		"version": 1,
	}


func load_state(state: Dictionary) -> void:
	_unlocked_targets = state.get("unlocked_targets", {}).duplicate()
	evaluate_all()


func clear_state() -> void:
	_unlocked_targets.clear()


# --- Manual Triggers ---


func evaluate_all() -> void:
	for rule: UnlockRule in _rules.values():
		_evaluate_rule(rule)


# --- Internal ---


func _on_source_value_changed(_key: String, _new_value: Variant, source_name: String) -> void:
	if not _source_to_rules.has(source_name):
		return

	var rule_ids: Array = _source_to_rules[source_name]
	for rule_id: String in rule_ids:
		if _rules.has(rule_id):
			_evaluate_rule(_rules[rule_id])


func _evaluate_rule(rule: UnlockRule) -> void:
	if rule == null or not rule.enabled:
		return

	# Check all referenced sources are registered
	var missing_sources: Array[String] = _get_missing_sources(rule.conditions)
	if not missing_sources.is_empty():
		evaluation_error.emit(
			rule.rule_id,
			"Missing data sources: %s" % ", ".join(missing_sources)
		)
		return

	var met: bool = ConditionEvaluator.evaluate(rule.conditions, _sources)

	# Emit progress for each target
	if rule.conditions != null:
		var status: Array[Dictionary] = ConditionEvaluator.get_condition_status(
			rule.conditions, _sources
		)
		var met_count: int = 0
		for entry: Dictionary in status:
			if entry.get("is_met", false):
				met_count += 1

		for target_key: String in rule.targets:
			if not is_unlocked(target_key):
				progress_updated.emit(target_key, met_count, status.size())

	if not met:
		return

	# Grant unlocks for targets not yet unlocked
	var newly_unlocked: Array[String] = []
	for target_key: String in rule.targets:
		if not is_unlocked(target_key):
			_unlocked_targets[target_key] = true
			newly_unlocked.append(target_key)
			_cascade_chain.append(target_key)
			unlock_granted.emit(target_key)

	if newly_unlocked.is_empty():
		return

	var is_root_evaluation: bool = not _evaluating
	if is_root_evaluation:
		_evaluating = true

	# Execute effects
	for effect: UnlockEffect in rule.effects:
		_execute_effect(effect)

	# Cascade: only at root level
	if is_root_evaluation:
		_resolve_cascade(newly_unlocked, 0)
		_evaluating = false
		if _cascade_chain.size() > newly_unlocked.size():
			cascade_completed.emit(_cascade_chain.duplicate())
		_cascade_chain.clear()


func _resolve_cascade(
	newly_unlocked: Array[String], depth: int
) -> void:
	if depth >= _cascade_max_depth:
		evaluation_error.emit("", "Cascade exceeded max depth of %d" % _cascade_max_depth)
		return

	var next_unlocked: Array[String] = []

	for rule: UnlockRule in _rules.values():
		if not rule.enabled:
			continue

		var has_locked_target: bool = false
		for target_key: String in rule.targets:
			if not is_unlocked(target_key):
				has_locked_target = true
				break

		if not has_locked_target:
			continue

		var missing: Array[String] = _get_missing_sources(rule.conditions)
		if not missing.is_empty():
			continue

		if ConditionEvaluator.evaluate(rule.conditions, _sources):
			for target_key: String in rule.targets:
				if not is_unlocked(target_key):
					_unlocked_targets[target_key] = true
					next_unlocked.append(target_key)
					_cascade_chain.append(target_key)
					unlock_granted.emit(target_key)

			for effect: UnlockEffect in rule.effects:
				_execute_effect(effect)

	if not next_unlocked.is_empty():
		_resolve_cascade(next_unlocked, depth + 1)


func _execute_effect(effect: UnlockEffect) -> void:
	if not _sources.has(effect.target_source):
		evaluation_error.emit("", "Effect target source '%s' not registered" % effect.target_source)
		return

	var source: Object = _sources[effect.target_source]

	match effect.operation:
		UnlockEffect.Operation.SET:
			if source.has_method("set_value"):
				source.set_value(effect.target_key, effect.value)
		UnlockEffect.Operation.ADD:
			if source.has_method("get_value") and source.has_method("set_value"):
				var current: Variant = source.get_value(effect.target_key)
				if current != null:
					source.set_value(effect.target_key, current + effect.value)
		UnlockEffect.Operation.SUBTRACT:
			if source.has_method("get_value") and source.has_method("set_value"):
				var current: Variant = source.get_value(effect.target_key)
				if current != null:
					source.set_value(effect.target_key, current - effect.value)


func _get_missing_sources(condition: CompoundCondition) -> Array[String]:
	var missing: Array[String] = []
	if condition == null:
		return missing

	for child: Resource in condition.children:
		if child is UnlockCondition:
			var leaf: UnlockCondition = child as UnlockCondition
			if not _sources.has(leaf.source_name) and leaf.source_name not in missing:
				missing.append(leaf.source_name)
		elif child is CompoundCondition:
			var sub_missing: Array[String] = _get_missing_sources(child as CompoundCondition)
			for s: String in sub_missing:
				if s not in missing:
					missing.append(s)

	return missing


func _index_rule(rule: UnlockRule) -> void:
	var source_names: Array[String] = _collect_source_names(rule.conditions)
	for source_name: String in source_names:
		if not _source_to_rules.has(source_name):
			_source_to_rules[source_name] = []
		if rule.rule_id not in _source_to_rules[source_name]:
			_source_to_rules[source_name].append(rule.rule_id)


func _remove_rule_from_index(rule_id: String) -> void:
	for source_name: String in _source_to_rules:
		var rule_ids: Array = _source_to_rules[source_name]
		rule_ids.erase(rule_id)


func _collect_source_names(condition: CompoundCondition) -> Array[String]:
	var names: Array[String] = []
	if condition == null:
		return names

	for child: Resource in condition.children:
		if child is UnlockCondition:
			var leaf: UnlockCondition = child as UnlockCondition
			if leaf.source_name not in names:
				names.append(leaf.source_name)
		elif child is CompoundCondition:
			var sub_names: Array[String] = _collect_source_names(child as CompoundCondition)
			for s: String in sub_names:
				if s not in names:
					names.append(s)

	return names


func _rebuild_source_index_for(source_name: String) -> void:
	for rule: UnlockRule in _rules.values():
		var names: Array[String] = _collect_source_names(rule.conditions)
		if source_name in names:
			if not _source_to_rules.has(source_name):
				_source_to_rules[source_name] = []
			if rule.rule_id not in _source_to_rules[source_name]:
				_source_to_rules[source_name].append(rule.rule_id)


func _disconnect_source(source_name: String) -> void:
	if not _sources.has(source_name):
		return
	var source: Object = _sources[source_name]
	if source.has_signal("value_changed") and source.value_changed.is_connected(_on_source_value_changed):
		source.value_changed.disconnect(_on_source_value_changed)


func _find_rules_for_target(target_key: String) -> Array[UnlockRule]:
	var result: Array[UnlockRule] = []
	for rule: UnlockRule in _rules.values():
		if target_key in rule.targets:
			result.append(rule)
	return result

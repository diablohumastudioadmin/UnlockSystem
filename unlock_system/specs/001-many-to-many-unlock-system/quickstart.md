# Quickstart: Many-to-Many Unlock System

## 1. Enable the Plugin

1. Copy `addons/unlock_system/` into your project's `addons/` directory.
2. Open Project → Project Settings → Plugins.
3. Enable "Unlock System". This registers the `UnlockManager` autoload.

## 2. Register a Data Source

Your game systems must conform to the data source contract (one signal + one method):

```gdscript
# Example: A simple coin tracker
class_name CoinTracker
extends Node

signal value_changed(key: String, new_value: Variant)

var _coins: int = 0

func get_value(key: String) -> Variant:
    if key == "balance":
        return _coins
    return null

func add_coins(amount: int) -> void:
    _coins += amount
    value_changed.emit("balance", _coins)
```

Register it with the unlock system:

```gdscript
func _ready() -> void:
    UnlockManager.register_source("coins", %CoinTracker)
```

## 3. Configure an Unlock Rule in the Editor

1. Create a new `UnlockRule` resource (`.tres` file).
2. Set `rule_id` to a unique string (e.g., `"unlock_level_5"`).
3. Create a `CompoundCondition` for the `conditions` property.
4. Add an `UnlockCondition` child: `source_name = "progress"`, `key = "level_4_passed"`, `operator = EQUALS`, `target_value = true`.
5. Set `targets` to `["level_5"]`.
6. Save the resource and add the rule in your game's initialization.

## 4. Configure an Unlock Rule via Code

```gdscript
func _ready() -> void:
    var condition: UnlockCondition = UnlockCondition.new()
    condition.source_name = "progress"
    condition.key = "level_4_passed"
    condition.operator = UnlockCondition.Operator.EQUALS
    condition.target_value = true

    var root: CompoundCondition = CompoundCondition.new()
    root.operator = CompoundCondition.Logic.AND
    root.children = [condition]

    var rule: UnlockRule = UnlockRule.new()
    rule.rule_id = "unlock_level_5"
    rule.conditions = root
    rule.targets = ["level_5"]

    UnlockManager.add_rule(rule)
```

## 5. Listen for Unlocks

```gdscript
func _ready() -> void:
    UnlockManager.unlock_granted.connect(_on_unlock_granted)

func _on_unlock_granted(target_key: String) -> void:
    print("Unlocked: ", target_key)
```

## 6. Check Progress

```gdscript
# Compound progress: how many conditions are met
var progress: Dictionary = UnlockManager.get_progress("achievement_veteran")
print("%d/%d conditions met" % [progress.met, progress.total])

# Debug: why is it still locked?
var reasons: Array = UnlockManager.why_locked("achievement_veteran")
for condition_info: Dictionary in reasons:
    print("%s.%s: %s (need %s %s)" % [
        condition_info.source_name,
        condition_info.key,
        condition_info.current_value,
        condition_info.operator,
        condition_info.target_value
    ])
```

## 7. Save / Load State

```gdscript
# Save
var unlock_state: Dictionary = UnlockManager.get_state()
# ... persist unlock_state in your save file ...

# Load
UnlockManager.load_state(saved_unlock_state)
```

## Validation Checklist

- [ ] Plugin enabled in Project Settings → Plugins
- [ ] Data sources registered before rules reference them
- [ ] Each data source emits `value_changed(key, new_value)` on every relevant change
- [ ] Each data source implements `get_value(key) -> Variant`
- [ ] Rule IDs are unique across all rules
- [ ] Target keys are consistent strings used across rules and game code

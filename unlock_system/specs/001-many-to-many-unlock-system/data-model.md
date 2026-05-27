# Data Model: Many-to-Many Unlock System

**Date**: 2026-05-26

## Entity Diagram

```text
UnlockRule
├── conditions: CompoundCondition (root of condition tree)
├── targets: Array[String] (target keys to unlock)
└── effects: Array[UnlockEffect] (side effects on unlock)

CompoundCondition (recursive tree)
├── operator: AND | OR
└── children: Array (mix of UnlockCondition and CompoundCondition)

UnlockCondition (leaf node)
├── source_name: String (registered data source name)
├── key: String (value key within the source)
├── operator: EQUALS | NOT_EQUALS | GREATER_EQUAL | LESS_EQUAL | GREATER | LESS
└── target_value: Variant (the threshold or expected value)

UnlockEffect
├── target_source: String (data source to write to)
├── target_key: String (key within the source)
├── operation: SET | ADD | SUBTRACT
└── value: Variant (the value to set/add/subtract)
```

## Entity Details

### UnlockCondition (extends Resource)

A single evaluable check against a data source value.

| Property      | Type    | Description                                          |
| ------------- | ------- | ---------------------------------------------------- |
| source_name   | String  | Name of the registered data source                   |
| key           | String  | Key to query from the data source                    |
| operator      | int     | Comparison operator (enum: EQ, NEQ, GEQ, LEQ, GT, LT) |
| target_value  | Variant | Value to compare against                             |

**Validation rules**:
- `source_name` must not be empty
- `key` must not be empty
- `target_value` type must be compatible with the operator (numeric for GEQ/LEQ/GT/LT, any for EQ/NEQ)

### CompoundCondition (extends Resource)

Groups conditions with AND/OR logic. Can nest other CompoundConditions.

| Property | Type                                          | Description                          |
| -------- | --------------------------------------------- | ------------------------------------ |
| operator | int                                           | Logic operator (enum: AND, OR)       |
| children | Array (UnlockCondition or CompoundCondition)  | Child conditions to evaluate         |

**Validation rules**:
- `children` must have at least 1 entry
- A single-child CompoundCondition is valid (acts as passthrough)

**Evaluation**:
- AND: all children must evaluate to `true`
- OR: at least one child must evaluate to `true`
- Evaluation is short-circuit: AND stops on first `false`, OR stops on first `true`

### UnlockEffect (extends Resource)

An action performed when an unlock rule fires.

| Property      | Type    | Description                                    |
| ------------- | ------- | ---------------------------------------------- |
| target_source | String  | Data source to write to                        |
| target_key    | String  | Key within the target source                   |
| operation     | int     | Operation type (enum: SET, ADD, SUBTRACT)      |
| value         | Variant | Value to apply                                 |

**Validation rules**:
- `target_source` must reference a registered data source
- `operation` must be valid for the value type (ADD/SUBTRACT only for numeric)

### UnlockRule (extends Resource)

The core wire connecting conditions to targets and effects.

| Property   | Type                    | Description                                       |
| ---------- | ----------------------- | ------------------------------------------------- |
| rule_id    | String                  | Unique identifier for this rule                   |
| conditions | CompoundCondition       | Root of the condition tree                        |
| targets    | Array[String]           | Keys of targets to unlock when conditions are met |
| effects    | Array[UnlockEffect]     | Effects to execute when the rule fires            |
| enabled    | bool                    | Whether this rule is active (default: true)       |

**Validation rules**:
- `rule_id` must be unique across all registered rules
- `targets` must have at least 1 entry
- `conditions` must not be null

**State transitions**:
- Rule is **dormant** until all referenced data sources are registered
- Rule is **active** when all data sources are available and `enabled` is true
- Rule **fires** when conditions evaluate to true and at least one target is not yet unlocked
- After firing, the rule does not fire again for already-unlocked targets (idempotent)

## Runtime State (managed by UnlockManager, not persisted as Resources)

| State             | Type                        | Description                                      |
| ----------------- | --------------------------- | ------------------------------------------------ |
| unlocked_targets  | Dictionary[String, bool]    | Map of target key → unlocked status              |
| registered_sources | Dictionary[String, Object] | Map of source name → source object               |
| source_to_rules   | Dictionary[String, Array]   | Index: which rules reference each source          |

## Relationships

```text
DataSource (game-provided)
  ↑ reads from (via get_value)
  ↑ listens to (via value_changed signal)
UnlockCondition ──references──→ DataSource[source_name][key]

CompoundCondition ──contains──→ UnlockCondition (leaf)
                  ──contains──→ CompoundCondition (nested)

UnlockRule ──has──→ CompoundCondition (root)
           ──targets──→ target keys (strings)
           ──has──→ UnlockEffect[]

UnlockEffect ──writes to──→ DataSource[target_source][target_key]
```

## Serialization (save/load)

`UnlockManager.get_state()` returns:
```text
{
  "unlocked_targets": { "level_5": true, "achievement_veteran": true, ... },
  "version": 1
}
```

`UnlockManager.load_state(state: Dictionary)` restores the unlocked_targets map and re-evaluates all active rules to resolve any cascades that may result from the loaded state.

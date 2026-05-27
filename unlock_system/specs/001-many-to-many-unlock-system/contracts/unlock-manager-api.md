# Contract: UnlockManager Public API

**Date**: 2026-05-26

The `UnlockManager` is a singleton autoload node. It is the only public entry point for the plugin.

## Signals (outward notifications)

| Signal                                                    | Description                                              |
| --------------------------------------------------------- | -------------------------------------------------------- |
| `unlock_granted(target_key: String)`                      | Emitted when a target transitions from locked to unlocked |
| `progress_updated(target_key: String, met: int, total: int)` | Emitted when a condition's evaluation changes for a target |
| `cascade_completed(chain: Array[String])`                 | Emitted after a full cascade chain resolves               |
| `evaluation_error(rule_id: String, message: String)`      | Emitted when evaluation fails (missing source, cycle, etc.) |

## Methods (inward commands)

### Data Source Management

| Method | Signature | Description |
|--------|-----------|-------------|
| `register_source` | `(name: String, source: Object) -> void` | Register a named data source. Source must have signal `value_changed(key: String, new_value: Variant)` and method `get_value(key: String) -> Variant`. |
| `unregister_source` | `(name: String) -> void` | Remove a data source. Rules referencing it become dormant. |
| `has_source` | `(name: String) -> bool` | Check if a source is registered. |

### Rule Management

| Method | Signature | Description |
|--------|-----------|-------------|
| `add_rule` | `(rule: UnlockRule) -> void` | Register an unlock rule. Indexes it by referenced sources. |
| `remove_rule` | `(rule_id: String) -> void` | Remove a rule by ID. |
| `get_rule` | `(rule_id: String) -> UnlockRule` | Retrieve a rule by ID. Returns null if not found. |
| `get_all_rules` | `() -> Array[UnlockRule]` | Return all registered rules. |

### State Queries

| Method | Signature | Description |
|--------|-----------|-------------|
| `is_unlocked` | `(target_key: String) -> bool` | Check if a target is currently unlocked. |
| `get_progress` | `(target_key: String) -> Dictionary` | Returns `{ "met": int, "total": int, "conditions": Array[Dictionary] }` with per-condition status. |
| `why_locked` | `(target_key: String) -> Array[Dictionary]` | Debug query. Returns condition tree with met/unmet status and current values. |

### State Persistence

| Method | Signature | Description |
|--------|-----------|-------------|
| `get_state` | `() -> Dictionary` | Returns serializable dictionary of all unlock state. |
| `load_state` | `(state: Dictionary) -> void` | Restores unlock state and re-evaluates cascades. |
| `clear_state` | `() -> void` | Resets all unlocks (for new game). |

### Manual Triggers

| Method | Signature | Description |
|--------|-----------|-------------|
| `evaluate_all` | `() -> void` | Force re-evaluation of all active rules. Useful after `load_state`. |

## Data Source Contract

Any object registered as a data source must conform to:

```text
Required signal:
  value_changed(key: String, new_value: Variant)

Required method:
  get_value(key: String) -> Variant
```

The `UnlockManager` connects to `value_changed` on registration and disconnects on unregistration.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `register_source` with duplicate name | Overwrites previous source (warning emitted) |
| `add_rule` with duplicate rule_id | Overwrites previous rule (warning emitted) |
| Condition references unregistered source | Rule stays dormant; `evaluation_error` emitted on first evaluation attempt |
| Circular dependency detected during cascade | Chain halted; `evaluation_error` emitted with cycle path |
| Cascade exceeds max depth | Chain halted; `evaluation_error` emitted |
| `why_locked` for unknown target | Returns empty array |
| `is_unlocked` for unknown target | Returns `false` |

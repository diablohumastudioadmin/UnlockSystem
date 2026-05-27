# Research: Many-to-Many Unlock System

**Date**: 2026-05-26

## R1: Condition Evaluation Strategy (Reactive Push)

**Decision**: Data sources emit a signal on value change. The `UnlockManager` maintains a mapping of `source_name → Array[UnlockRule]` that reference that source. On signal, it re-evaluates only the affected rules.

**Rationale**: Avoids polling every frame. Evaluation cost is proportional to the number of rules referencing the changed source, not the total rule count. Aligns with Constitution Principle II (signal-driven).

**Alternatives considered**:
- Per-frame polling of all conditions: O(n) every frame regardless of changes. Wasteful for 200+ rules.
- Deferred batch evaluation (collect changes, evaluate next frame): Adds latency and complexity. Not needed unless profiling shows signal-based evaluation causes frame spikes.

## R2: Compound Condition Representation

**Decision**: Use a recursive Resource structure. `CompoundCondition` extends `Resource` with an `operator` enum (AND/OR) and a typed array of children that can be either `UnlockCondition` (leaf) or `CompoundCondition` (branch). This forms a tree.

**Rationale**: Godot's inspector natively supports nested Resource arrays with `@export`. Designers can build trees in the inspector without custom UI. Code can construct the same tree programmatically.

**Alternatives considered**:
- Flat list with operator tokens (postfix/prefix notation): Harder to author in inspector, error-prone.
- Expression string parser ("level_passed AND (coins >= 1000 OR items >= 5)"): Requires building a parser; fragile, not inspector-friendly.

## R3: Cascade Resolution & Cycle Detection

**Decision**: When an unlock is granted, check if the newly unlocked target satisfies conditions in other rules. Use a depth-first traversal with a visited set to detect cycles. Configurable max depth (default 10).

**Rationale**: DFS with visited set is O(V+E) and naturally detects cycles. Max depth prevents runaway chains even without cycles (e.g., extremely long legitimate chains).

**Alternatives considered**:
- Breadth-first: Same complexity, but DFS is simpler to implement with a stack/recursion.
- Pre-computed topological sort at configuration time: Would catch cycles earlier but requires rebuilding the graph every time a rule is added/removed. Not worth the complexity for v1 given rules change infrequently at runtime.

## R4: Data Source Contract

**Decision**: Data sources are registered by string name via `UnlockManager.register_source(name: String, source: Object)`. The source object must:
1. Have a signal named `value_changed(key: String, new_value: Variant)`.
2. Have a method `get_value(key: String) -> Variant` for on-demand reads (used during initial evaluation and debug queries).

**Rationale**: Minimal contract — any game system (coins, stats, progress tracker) can conform by adding one signal and one method. No base class or interface inheritance required, keeping integration friction low.

**Alternatives considered**:
- Base class (`extends UnlockDataSource`): Forces inheritance on the game's existing systems. Invasive.
- Dictionary-based registration (pass a dict of values + update it): Loses reactivity. Game would need to call an update method manually, which is effectively poll-with-extra-steps.

## R5: Unlock State Persistence Contract

**Decision**: `UnlockManager` exposes `get_state() -> Dictionary` and `load_state(state: Dictionary)`. The dictionary maps target keys to their unlock status (and optionally cached progress). The consuming game calls these during save/load.

**Rationale**: Keeps the plugin agnostic to save file format (JSON, binary, cloud saves). The game owns persistence; the plugin owns state.

**Alternatives considered**:
- Built-in file save/load: Assumes file access patterns; conflicts with games using cloud saves or custom formats.
- Signal-only (emit state on every change, game records it): Puts burden on game to reconstruct full state from events. Error-prone.

## R6: Debug Query Implementation

**Decision**: `UnlockManager.why_locked(target_key: String) -> Array[Dictionary]` returns an array where each entry represents a condition with keys: `source_name`, `key`, `operator`, `target_value`, `current_value`, `is_met`. For compound conditions, entries are nested with a `children` key.

**Rationale**: Returns structured data (not just a string), allowing games to format debug output however they want (console, UI overlay, editor print).

**Alternatives considered**:
- Print-only debug (push_warning): Not queryable; can't be used for in-game debug UI.
- Separate debug resource/node: Over-engineering per Principle IV.

## R7: Godot Plugin Structure

**Decision**: Standard `addons/unlock_system/` layout with `plugin.cfg`. The `EditorPlugin` script registers `UnlockManager` as an autoload on activation. Resources are available in the inspector once the plugin is enabled.

**Rationale**: Standard Godot addon conventions. Users enable the plugin in Project Settings → Plugins, and the autoload is automatically available.

**Alternatives considered**:
- No autoload (users manually add the manager node): Adds friction; every project must remember to add the node.
- Multiple autoloads (separate manager for rules, sources, state): Violates Principle IV (YAGNI). One manager is sufficient.

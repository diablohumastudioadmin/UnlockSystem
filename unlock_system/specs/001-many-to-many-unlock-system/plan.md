# Implementation Plan: Many-to-Many Unlock System

**Branch**: `001-many-to-many-unlock-system` | **Date**: 2026-05-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-many-to-many-unlock-system/spec.md`

## Summary

A Godot 4.6 editor plugin that provides a many-to-many unlock/progression system. Unlock rules connect conditions (reading from named data sources) to targets via compound AND/OR logic. The system uses a reactive (push) evaluation model — data sources emit signals on change, triggering automatic re-evaluation. Unlocks are permanent, can cascade, and can write effects back to data sources. All unlock definitions are Resource-based (`.tres`), configurable in the inspector or via code. An `UnlockManager` autoload exposes the public signal API and data source registry.

## Technical Context

**Language/Version**: GDScript (Godot 4.6)

**Primary Dependencies**: Godot Engine 4.6 built-in APIs only (no third-party addons)

**Storage**: Resource files (`.tres`) for unlock definitions; runtime state in memory (persistence delegated to consuming game's save system)

**Testing**: Headless GDScript test scripts via `<godot-binary> --headless --path . --script tests/test_<name>.gd`

**Target Platform**: Cross-platform (wherever Godot 4.6 exports)

**Project Type**: Godot editor plugin / addon

**Performance Goals**: 200+ active unlock rules evaluated within a single frame; cascade chains of 5+ levels resolved within a single frame

**Constraints**: No third-party dependencies; plugin must be self-contained under `addons/unlock_system/`; no custom editor docks in v1

**Scale/Scope**: Plugin-sized codebase (~15-25 scripts); targets indie-to-mid game projects with up to hundreds of unlock rules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Resource-Based Data Model | ✅ PASS | All unlock definitions (rules, conditions, effects, targets) are modeled as `extends Resource` scripts with `.tres` files. Runtime state is separate from definitions. |
| II. Signal-Driven Communication | ✅ PASS | `UnlockManager` autoload exposes signals (`unlock_granted`, `progress_updated`). Data sources push changes via signals. No polling. |
| III. Test Coverage | ✅ PASS | Headless test scripts planned for every condition type, compound logic, cascading, cycle detection, and idempotency. |
| IV. Simplicity (YAGNI) | ✅ PASS | Flat composition: Resources + one manager node. No base class hierarchies, no factory patterns, no registries beyond the data source map. |

**Gate result**: PASS — no violations. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/001-many-to-many-unlock-system/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── unlock-manager-api.md
└── tasks.md
```

### Source Code (repository root)

```text
addons/unlock_system/
├── plugin.cfg                    # Plugin metadata
├── plugin.gd                     # EditorPlugin script (registers autoload)
├── unlock_manager.gd             # Autoload: public API, data source registry, evaluation engine
├── resources/
│   ├── unlock_condition.gd       # Base condition Resource (source_name, key, operator, target_value)
│   ├── compound_condition.gd     # AND/OR grouping of conditions (recursive nesting)
│   ├── unlock_effect.gd          # Effect Resource (target source, key, operation, value)
│   ├── unlock_rule.gd            # Rule Resource: conditions + targets + effects
│   └── unlock_target.gd          # Target Resource: identifier key + unlock state
└── internal/
    ├── condition_evaluator.gd    # Pure logic: evaluate condition trees against data source values
    └── cascade_resolver.gd       # Cascade chain processing with cycle detection

tests/
├── test_condition_evaluator.gd   # Boolean, threshold, compound AND/OR/nested
├── test_unlock_manager.gd        # Registration, rule evaluation, signal emission
├── test_cascade_resolver.gd      # Chain resolution, cycle detection, depth limit
└── test_unlock_rule.gd           # Rule-level integration (conditions → targets → effects)
```

**Structure Decision**: Standard Godot plugin layout under `addons/unlock_system/`. Resources in `resources/` subdirectory per Constitution Principle I. Internal logic helpers in `internal/` to keep the manager script focused. Tests at project root under `tests/`.

## Complexity Tracking

> No violations to justify. All four constitution principles are satisfied with flat composition.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none)    | —          | —                                   |

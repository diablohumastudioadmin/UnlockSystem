<!--
  Sync Impact Report
  ==================
  Version change: 0.0.0 → 1.0.0 (initial ratification)
  Modified principles: N/A (first version)
  Added sections:
    - Core Principles (4 principles)
    - Technology Stack
    - Development Workflow
    - Governance
  Removed sections: N/A
  Templates requiring updates:
    - plan-template.md: ✅ no changes needed (Constitution Check section
      is generic and will be filled per-feature)
    - spec-template.md: ✅ no changes needed (structure is compatible)
    - tasks-template.md: ✅ no changes needed (phase structure is compatible)
  Follow-up TODOs: none
-->

# Unlock System Constitution

## Core Principles

### I. Resource-Based Data Model

All unlock definitions, requirements, rewards, and progression data MUST be
modeled as Godot custom Resources (`.tres` files with backing `extends Resource`
scripts). This applies to unlockable items, condition descriptors, reward
payloads, and progression tiers.

Rationale: Resources are serializable, inspector-editable, reusable, and
decouple data authoring from runtime logic. Designers can create and tweak
unlock configurations without touching GDScript.

Rules:
- Every data entity (unlock definition, condition, reward) MUST have a
  dedicated `extends Resource` script with exported properties.
- Runtime state (e.g., current progress counters) MAY live in nodes or
  dictionaries, but the *definition* of what can be unlocked MUST be a
  Resource.
- Resource files MUST be stored under `addons/unlock_system/resources/` or
  a clearly scoped subdirectory.
- Avoid hardcoding unlock IDs or thresholds in scripts; reference Resource
  properties instead.

### II. Signal-Driven Communication

The unlock system MUST communicate state changes (unlocked, progress updated,
requirement met) exclusively via signals. Consuming systems (UI, save system,
analytics) MUST connect to signals rather than polling or directly reading
internal state.

Rationale: Signals enforce loose coupling, making the plugin drop-in for any
Godot project without requiring consumers to subclass or modify plugin code.

Rules:
- The plugin MUST expose a public signal API from a single autoload or
  manager node (e.g., `UnlockManager`).
- Internal implementation details MUST NOT leak through the signal API;
  signals carry only the data consumers need (unlock ID, new state, delta).
- Direct method calls into the plugin are allowed for *commands* (e.g.,
  `grant_progress()`), but *notifications outward* MUST use signals.
- Signal names MUST be descriptive and past-tense for state changes
  (e.g., `unlock_granted`, `progress_updated`).

### III. Test Coverage

Core unlock logic (condition evaluation, progress tracking, unlock granting)
MUST have headless GDScript test scripts that run without the editor GUI.

Rationale: Unlock logic involves combinatorial conditions (AND/OR requirements,
thresholds, dependencies). Manual testing is insufficient to catch regressions
across all combinations.

Rules:
- Test scripts MUST live under `tests/` and run via
  `<godot-binary> --headless --path . --script tests/test_<name>.gd`.
- Every condition type and unlock flow MUST have at least one passing test
  before the feature is considered complete.
- Tests MUST NOT depend on scene tree structure or visual elements; test
  the Resource and logic layers directly.
- When a bug is fixed, a regression test MUST be added.

### IV. Simplicity (YAGNI)

Every abstraction, class, and indirection MUST justify its existence with a
concrete current requirement. Speculative features, premature generalization,
and framework-style patterns MUST NOT be introduced.

Rationale: Plugin code is consumed by other projects. Unnecessary complexity
increases integration friction and maintenance burden.

Rules:
- Do NOT create base classes, registries, or factories unless three or more
  concrete implementations already exist.
- Prefer flat composition (Resources + signals) over deep inheritance
  hierarchies.
- A new file MUST solve a current problem, not a hypothetical future one.
- If a feature can be implemented in fewer than 20 lines within an existing
  file, it MUST NOT get its own file.

## Technology Stack

- **Engine**: Godot 4.6 (Forward Plus renderer, Jolt Physics 3D)
- **Language**: GDScript (all plugin code)
- **Project type**: Editor plugin / addon (`addons/unlock_system/`)
- **Target**: Cross-platform (wherever Godot 4.6 exports)
- **Testing**: Headless GDScript test scripts (`--headless --script`)

## Development Workflow

- **Proposal before implementation**: Every change starts with a written
  proposal (problem / fix / files). Implementation begins only after
  user approval.
- **One commit per change**: Each logical change gets its own commit with
  a clear message. Commits happen only when explicitly requested.
- **SpecKit pipeline**: Features flow through `/speckit-specify` →
  `/speckit-clarify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-implement`. The constitution gates plan approval.
- **Constitution compliance**: The plan-template Constitution Check MUST
  verify against these four principles before Phase 0 research begins.

## Governance

This constitution is the authoritative source for architectural decisions in
the Unlock System project. All implementation work, code reviews, and plan
approvals MUST verify compliance with the principles defined here.

Amendment procedure:
1. Propose the amendment with rationale and impact assessment.
2. Document the change in this file with updated version, date, and Sync
   Impact Report.
3. Propagate changes to affected templates (plan, spec, tasks) and update
   the CLAUDE.md if the amendment changes workflow or commands.
4. Version using semantic versioning: MAJOR for principle
   removals/redefinitions, MINOR for new principles or material expansions,
   PATCH for clarifications and wording fixes.

Complexity MUST be justified. Any violation of a principle MUST be documented
in the plan's Complexity Tracking table with the reason and the simpler
alternative that was rejected.

**Version**: 1.0.0 | **Ratified**: 2026-05-26 | **Last Amended**: 2026-05-26

# Tasks: Many-to-Many Unlock System

**Input**: Design documents from `specs/001-many-to-many-unlock-system/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/unlock-manager-api.md

**Tests**: Included — Constitution Principle III requires test coverage for all condition types and unlock flows.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup

**Purpose**: Plugin skeleton and project structure

- [ ] T001 Create plugin directory structure: `addons/unlock_system/`, `addons/unlock_system/resources/`, `addons/unlock_system/internal/`, `tests/`
- [ ] T002 Create `addons/unlock_system/plugin.cfg` with plugin metadata (name: "Unlock System", version: "0.1.0")
- [ ] T003 Create `addons/unlock_system/plugin.gd` extending EditorPlugin — registers/unregisters `UnlockManager` autoload on enable/disable

**Checkpoint**: Plugin appears in Project Settings → Plugins and can be enabled/disabled.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Resource scripts and core evaluation logic that ALL user stories depend on

**CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 [P] Create `addons/unlock_system/resources/unlock_condition.gd` — extends Resource with exported properties: `source_name: String`, `key: String`, `operator: int` (enum: EQ, NEQ, GEQ, LEQ, GT, LT), `target_value: Variant`
- [ ] T005 [P] Create `addons/unlock_system/resources/compound_condition.gd` — extends Resource with exported properties: `operator: int` (enum: AND, OR), `children: Array` (of UnlockCondition or CompoundCondition)
- [ ] T006 [P] Create `addons/unlock_system/resources/unlock_effect.gd` — extends Resource with exported properties: `target_source: String`, `target_key: String`, `operation: int` (enum: SET, ADD, SUBTRACT), `value: Variant`
- [ ] T007 [P] Create `addons/unlock_system/resources/unlock_rule.gd` — extends Resource with exported properties: `rule_id: String`, `conditions: CompoundCondition`, `targets: Array[String]`, `effects: Array[UnlockEffect]`, `enabled: bool` (default true)
- [ ] T008 Create `addons/unlock_system/internal/condition_evaluator.gd` — pure logic script: `evaluate(condition: CompoundCondition, sources: Dictionary) -> bool` with short-circuit AND/OR, recursive nesting support; `get_condition_status(condition: CompoundCondition, sources: Dictionary) -> Array[Dictionary]` returning per-condition met/unmet status with current values
- [ ] T009 Create `addons/unlock_system/unlock_manager.gd` — autoload script with: signals (`unlock_granted`, `progress_updated`, `cascade_completed`, `evaluation_error`), data source registry (`register_source`, `unregister_source`, `has_source`), rule registry (`add_rule`, `remove_rule`, `get_rule`, `get_all_rules`), state queries (`is_unlocked`, `get_progress`, `why_locked`), persistence (`get_state`, `load_state`, `clear_state`), reactive evaluation (connect to source `value_changed` signals, re-evaluate affected rules on change)

### Tests for Foundational Phase

- [ ] T010 [P] Create `tests/test_condition_evaluator.gd` — test boolean condition (EQ true), threshold condition (GEQ 1000), compound AND (both met → true, one unmet → false), compound OR (one met → true, none met → false), nested compound ((A AND B) OR C), short-circuit behavior, `get_condition_status` returns correct met/unmet per leaf
- [ ] T011 [P] Create `tests/test_unlock_manager.gd` — test `register_source`/`unregister_source`/`has_source`, `add_rule`/`remove_rule`/`get_rule`, reactive evaluation (source value_changed triggers rule evaluation), `unlock_granted` signal emission, `is_unlocked` returns correct state, idempotency (unlock already-unlocked target produces no duplicate signal), `get_state`/`load_state`/`clear_state` round-trip

**Checkpoint**: All foundational Resources compile, condition evaluator passes all logic tests, UnlockManager registers sources/rules and evaluates reactively. User story implementation can now begin.

---

## Phase 3: User Story 1 — Define Simple Unlock Rules (Priority: P1) MVP

**Goal**: A single-condition unlock rule can be configured in the editor and evaluated at runtime.

**Independent Test**: Create one unlock rule with a single condition (level passed). Trigger the condition via a mock data source. Verify the target unlocks and `unlock_granted` signal fires.

### Tests for User Story 1

- [ ] T012 [US1] Create `tests/test_simple_unlock.gd` — end-to-end test: create a mock data source, register it, create an UnlockRule resource with one condition referencing the source, add the rule, emit `value_changed` from the source to satisfy the condition, assert `is_unlocked` returns true and `unlock_granted` signal was emitted

### Implementation for User Story 1

- [ ] T013 [US1] Verify that an `UnlockRule` resource with a single `UnlockCondition` inside a `CompoundCondition` (AND with one child) can be created and saved as `.tres` via the inspector — create an example resource at `addons/unlock_system/examples/simple_rule_example.tres`

**Checkpoint**: A designer can create a `.tres` rule in the inspector, and a developer can verify it works via the headless test. MVP complete.

---

## Phase 4: User Story 2 — Define Compound Unlock Rules (Priority: P1)

**Goal**: Compound AND/OR/nested conditions evaluate correctly and can be configured in the inspector.

**Independent Test**: Create rules with AND, OR, and nested compound conditions. Verify each evaluates correctly when conditions are met/unmet in various combinations.

### Tests for User Story 2

- [ ] T014 [US2] Create `tests/test_compound_unlock.gd` — test compound AND rule (2 conditions, both sources must satisfy), compound OR rule (either source satisfies), nested rule ((A AND B) OR C), partial satisfaction (1 of 2 AND conditions met → stays locked)

### Implementation for User Story 2

- [ ] T015 [US2] Create example compound rule resource at `addons/unlock_system/examples/compound_rule_example.tres` — demonstrates AND with two conditions from different sources and verifies inspector editability of nested CompoundCondition children

**Checkpoint**: Compound AND/OR/nested conditions work end-to-end. Designers can build multi-condition rules in the inspector.

---

## Phase 5: User Story 3 — Many-to-Many Relationships (Priority: P1)

**Goal**: One trigger unlocks multiple targets; one target is gated by multiple rules from different source types.

**Independent Test**: Configure one source event that unlocks two targets. Configure a separate target requiring two different trigger types. Verify all relationships resolve correctly.

### Tests for User Story 3

- [ ] T016 [US3] Create `tests/test_many_to_many.gd` — test one rule with multiple targets (source change unlocks both), two rules targeting the same target with different conditions (both must be met or either, depending on rule design), mixed source types (progress source + currency source) in a single rule

### Implementation for User Story 3

- [ ] T017 [US3] Implement multiple-target support in `addons/unlock_system/unlock_manager.gd` — when a rule fires, iterate `targets` array and unlock each independently; emit `unlock_granted` per target; skip already-unlocked targets (idempotent)

**Checkpoint**: Many-to-many relationships resolve correctly. One event can unlock many things; one thing can be gated by many conditions across different sources.

---

## Phase 6: User Story 4 — Multiple Data Sources (Priority: P2)

**Goal**: The system reads from multiple independently-registered data sources and conditions can reference any registered source.

**Independent Test**: Register two data sources (progress + stats). Create a rule spanning both. Update each source independently. Verify evaluation re-triggers on each change and unlocks only when the compound condition across sources is fully met.

### Tests for User Story 4

- [ ] T018 [US4] Create `tests/test_multiple_sources.gd` — register two mock sources ("progress" and "stats"), create a rule with conditions referencing both, update "progress" source (partial satisfaction → stays locked), update "stats" source (now fully satisfied → unlocks), test unregistering a source makes referencing rules dormant (evaluation_error emitted)

### Implementation for User Story 4

- [ ] T019 [US4] Implement source-to-rule index in `addons/unlock_system/unlock_manager.gd` — maintain `_source_to_rules: Dictionary[String, Array]` mapping; on `register_source`, connect `value_changed` and index all rules referencing that source; on `unregister_source`, disconnect and mark affected rules dormant; on `value_changed`, re-evaluate only rules in the index for that source

**Checkpoint**: Multiple data sources work independently. Rules spanning sources evaluate correctly. Source lifecycle (register/unregister) is handled gracefully.

---

## Phase 7: User Story 5 — Bidirectional Data Flow (Priority: P2)

**Goal**: Unlock effects write data back to sources, triggering cascading evaluations.

**Independent Test**: Create a chain: condition met → rule fires → effect writes to source → second rule's condition now met → second rule fires. Verify cascade resolves. Verify circular dependency is detected.

### Tests for User Story 5

- [ ] T020 [US5] Create `tests/test_cascade_resolver.gd` — test linear cascade (A → B → C, 3 levels deep), verify `cascade_completed` signal with full chain, test circular dependency detection (A → B → A, emit `evaluation_error` with cycle path), test max depth limit (configurable, default 10, emit error if exceeded), test cascade with effects (rule fires → effect grants coins → coins satisfy next rule)

### Implementation for User Story 5

- [ ] T021 [US5] Create `addons/unlock_system/internal/cascade_resolver.gd` — `resolve(initial_targets: Array[String], manager: UnlockManager) -> Array[String]` using DFS with visited set; processes unlock effects via manager; detects cycles; enforces max depth; returns full chain of unlocked targets
- [ ] T022 [US5] Implement effect execution in `addons/unlock_system/unlock_manager.gd` — when a rule fires, execute each `UnlockEffect` (call data source's setter or emit through the source); after effects, call cascade resolver to process downstream unlocks; emit `cascade_completed` with full chain

**Checkpoint**: Cascading unlocks work end-to-end. Circular dependencies are caught and reported. Effects write back to sources correctly.

---

## Phase 8: User Story 6 — Configure via Code (Priority: P2)

**Goal**: Unlock rules can be created, modified, and removed entirely via code at runtime with identical behavior to editor-configured rules.

**Independent Test**: Create a rule via code (no `.tres`). Trigger its condition. Verify it unlocks identically to an editor-configured rule.

### Tests for User Story 6

- [ ] T023 [US6] Create `tests/test_code_configuration.gd` — test creating UnlockCondition, CompoundCondition, UnlockEffect, and UnlockRule via `*.new()` and setting properties; add rule via `add_rule`; trigger condition; verify unlock; test `remove_rule` stops evaluation; test modifying a rule at runtime (remove + re-add with changed conditions)

### Implementation for User Story 6

- [ ] T024 [US6] Verify and fix any issues in `addons/unlock_system/unlock_manager.gd` — ensure `add_rule` properly indexes a code-created rule into `_source_to_rules`, connects to relevant source signals, and evaluates immediately if conditions are already met; ensure `remove_rule` cleans up the index and disconnects

**Checkpoint**: Code-created rules behave identically to editor-configured rules. Rules can be added/removed at runtime.

---

## Phase 9: User Story 7 — Character Upgrade Progression (Priority: P3)

**Goal**: Validate that the many-to-many model handles hierarchical/branched progression (character branches and levels) without requiring special-purpose code.

**Independent Test**: Configure a character with 2 branches, 3 levels each. Set different conditions per level (purchase + gameplay). Verify each level unlocks independently.

### Tests for User Story 7

- [ ] T025 [US7] Create `tests/test_character_progression.gd` — model a character with targets like "char_a_branch_1_level_1", "char_a_branch_2_level_3"; set purchase condition on one, gameplay condition on another, mixed conditions on a third; verify each unlocks independently; verify unlocking one level does not affect other branches

### Implementation for User Story 7

- [ ] T026 [US7] Create example character progression resources at `addons/unlock_system/examples/character_progression/` — a set of `.tres` files demonstrating a character with 2 branches, 3 levels each, with varied condition types (purchase, gameplay, compound) to serve as a reference for users

**Checkpoint**: Character upgrade trees work using the existing many-to-many system with no special-purpose code. Validates the architecture.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Progress tracking, debug queries, and final validation across all stories

- [ ] T027 [P] Implement `get_progress` in `addons/unlock_system/unlock_manager.gd` — returns `{ "met": int, "total": int, "conditions": Array[Dictionary] }` for a target key; counts met conditions in the root CompoundCondition; includes per-condition current values read from sources
- [ ] T028 [P] Implement `why_locked` in `addons/unlock_system/unlock_manager.gd` — returns full condition tree as Array[Dictionary] with keys: `source_name`, `key`, `operator`, `target_value`, `current_value`, `is_met`; for compound conditions, includes nested `children` key
- [ ] T029 [P] Implement `progress_updated` signal emission in `addons/unlock_system/unlock_manager.gd` — emit after each re-evaluation with `(target_key, met_count, total_count)` so UI consumers can update progress bars
- [ ] T030 Create `tests/test_progress_and_debug.gd` — test `get_progress` returns correct met/total counts, test `why_locked` returns correct condition tree with current values, test `progress_updated` signal emits on each re-evaluation with correct counts
- [ ] T031 Run all test scripts and verify 100% pass rate; fix any regressions
- [ ] T032 Run quickstart.md validation — verify each code example from quickstart.md works against the implemented plugin

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Stories (Phase 3–9)**: All depend on Foundational phase completion
  - US1 (Phase 3): No dependencies on other stories
  - US2 (Phase 4): No dependencies on other stories
  - US3 (Phase 5): No dependencies on other stories
  - US4 (Phase 6): No dependencies on other stories
  - US5 (Phase 7): Depends on US3 (multi-target) and US4 (multi-source) for full cascade testing
  - US6 (Phase 8): No dependencies on other stories
  - US7 (Phase 9): No dependencies on other stories (uses existing system)
- **Polish (Phase 10)**: Depends on US1–US5 completion (progress/debug queries need evaluation engine complete)

### User Story Dependencies

- **US1, US2, US3, US4, US6, US7**: Can start after Foundational (Phase 2) — independently testable
- **US5**: Should follow US3 + US4 (cascading depends on multi-target + multi-source)
- **US1, US2, US3** (all P1): Recommended sequential for MVP validation, but can be parallelized

### Parallel Opportunities

- Phase 2: T004, T005, T006, T007 can all run in parallel (independent resource scripts)
- Phase 2: T010, T011 can run in parallel (independent test files)
- Phase 3–9: US1, US2, US3, US4, US6, US7 can run in parallel after Phase 2 (different files, independent stories)
- Phase 10: T027, T028, T029 can run in parallel (different methods in same file, but no dependencies between them)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Run test_simple_unlock.gd and test_condition_evaluator.gd
5. Plugin is functional for simple single-condition unlock rules

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Test → Simple unlocks work (MVP!)
3. Add US2 → Test → Compound conditions work
4. Add US3 → Test → Many-to-many relationships work
5. Add US4 → Test → Multiple data sources work
6. Add US5 → Test → Cascading + effects work
7. Add US6 → Test → Code configuration works
8. Add US7 → Test → Character progression validated
9. Polish → Progress tracking + debug queries + final validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Constitution Principle III mandates tests for all condition types and unlock flows
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently

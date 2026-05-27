# Feature Specification: Many-to-Many Unlock System

**Feature Branch**: `001-many-to-many-unlock-system`

**Created**: 2026-05-26

**Status**: Draft

**Input**: User description: "A many-to-many unlock/progression system plugin for Godot 4.6 with compound conditions, multiple data sources, and bidirectional data flow."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Define Simple Unlock Rules (Priority: P1)

As a game designer, I want to define a simple unlock rule (e.g., "Level 5 unlocks when Level 4 is passed") using the editor, so that I can set up basic progression without writing code.

**Why this priority**: The most fundamental capability — without single-condition unlock rules, no other feature works.

**Independent Test**: Create one unlock rule with a single condition (level passed). Trigger the condition. Verify the target unlocks.

**Acceptance Scenarios**:

1. **Given** an unlock rule "Level 5 requires Level 4 passed" is configured, **When** Level 4 is marked as passed, **Then** Level 5 becomes unlocked.
2. **Given** an unlock rule exists but its condition is not met, **When** the system checks unlock status, **Then** the target remains locked.
3. **Given** an unlock rule is configured in the editor, **When** a developer queries the rule at runtime, **Then** the rule is accessible and evaluable without additional code.

---

### User Story 2 - Define Compound Unlock Rules (Priority: P1)

As a game designer, I want to define compound conditions using AND/OR logic (e.g., "pass Level 10 AND have 1000 coins"), so that I can create rich, multi-requirement unlock gates.

**Why this priority**: Most real-world unlock scenarios require multiple conditions. This is core to the many-to-many promise.

**Independent Test**: Create an unlock rule with two AND conditions (level passed + coin threshold). Verify unlock only triggers when both are satisfied simultaneously.

**Acceptance Scenarios**:

1. **Given** a rule "Achievement X requires 100 enemies killed AND 1000 coins", **When** both conditions are met, **Then** the achievement unlocks.
2. **Given** a compound AND rule where only one condition is met, **When** the system evaluates, **Then** the target remains locked.
3. **Given** a compound OR rule "Level 7 requires Level 3 passed OR Level 5 passed", **When** either condition is met, **Then** Level 7 unlocks.
4. **Given** a nested compound rule (e.g., "(A AND B) OR C"), **When** condition C alone is met, **Then** the target unlocks.

---

### User Story 3 - Many-to-Many Relationships (Priority: P1)

As a game designer, I want one trigger to unlock multiple targets and one target to require multiple triggers (even of different types), so that I can model complex progression graphs.

**Why this priority**: This is the defining characteristic of the system — without it, the plugin is just a basic if/then unlocker.

**Independent Test**: Configure one event (e.g., "pass Level 40") that unlocks both a character level and an achievement. Configure a separate target that requires two different trigger types (a level pass + a purchase). Verify all relationships resolve correctly.

**Acceptance Scenarios**:

1. **Given** "pass Level 40" triggers both "Character B Level 2 unlock" and "Achievement: Veteran", **When** Level 40 is passed, **Then** both targets unlock.
2. **Given** "Character A branch 2 level 3" requires a purchase event, **When** the purchase is completed, **Then** that specific character level unlocks.
3. **Given** a target requires triggers from two different data sources (game progress + in-game currency), **When** both triggers fire, **Then** the target unlocks.

---

### User Story 4 - Multiple Data Sources (Priority: P2)

As a game developer, I want the system to read from and write to different data sources (user progress, in-game stats like enemies killed, ally levels, currency), so that unlock conditions can span any game data.

**Why this priority**: Enables the system to integrate with the full breadth of game state rather than being limited to a single progress tracker.

**Independent Test**: Register two data sources (a "player progress" source and an "in-game stats" source). Create a rule that reads from both. Verify the system evaluates conditions across sources correctly.

**Acceptance Scenarios**:

1. **Given** a data source "player progress" tracks levels passed, **When** a condition references "level 10 passed", **Then** the system reads from that source to evaluate.
2. **Given** a data source "in-game stats" tracks enemies killed, **When** a condition references "enemies killed >= 100", **Then** the system reads the correct value.
3. **Given** an unlock rule spans two data sources, **When** each source updates independently, **Then** the system re-evaluates and unlocks when the compound condition is fully satisfied.

---

### User Story 5 - Bidirectional Data Flow (Priority: P2)

As a game developer, I want the unlock system to not only read data (to check conditions) but also write data back (to grant rewards, update progress, mark achievements), so that unlocking a thing can itself become a trigger for further unlocks.

**Why this priority**: Enables chained progression — unlocking one thing cascades into unlocking others, which is essential for deep progression trees.

**Independent Test**: Create a chain: "Pass Level 10" → unlocks "Achievement A" → achievement grants 500 coins → coins satisfy condition for "Skin B unlock". Verify the full chain resolves.

**Acceptance Scenarios**:

1. **Given** unlocking Achievement A is configured to grant 500 coins, **When** Achievement A unlocks, **Then** the coin balance increases by 500.
2. **Given** a cascading chain of unlocks (A → B → C), **When** the initial trigger fires, **Then** the system resolves all downstream unlocks in the correct order.
3. **Given** a circular dependency is accidentally configured (A requires B, B requires A), **When** the system evaluates, **Then** it detects the cycle and reports an error rather than looping infinitely.

---

### User Story 6 - Configure via Code (Priority: P2)

As a game developer, I want to define and modify unlock rules programmatically at runtime (not only through the editor), so that I can generate dynamic content, modding support, or server-driven unlock configurations.

**Why this priority**: Editor-only configuration covers design-time needs; code-based configuration covers runtime and dynamic scenarios.

**Independent Test**: Create an unlock rule entirely via code (no editor setup). Trigger its condition. Verify the target unlocks identically to an editor-configured rule.

**Acceptance Scenarios**:

1. **Given** a developer creates an unlock rule via code, **When** the rule's condition is met at runtime, **Then** the target unlocks.
2. **Given** an editor-configured rule and a code-configured rule for the same target, **When** either rule's condition is met, **Then** the target unlocks (rules are additive).
3. **Given** a rule is created via code at runtime, **When** queried, **Then** it is indistinguishable from an editor-configured rule in behavior.

---

### User Story 7 - Character Upgrade Progression (Priority: P3)

As a game designer, I want to model character upgrade trees where each character has branches and levels that unlock independently (via purchase, gameplay, or mixed conditions), so that the plugin handles RPG-style progression natively.

**Why this priority**: This is a specific application of the core system rather than a new capability, but it validates that the many-to-many model handles hierarchical/branched progression.

**Independent Test**: Configure a character with 2 branches, each with 3 levels. Set different unlock conditions per level (some via purchase, some via gameplay). Verify each level unlocks independently based on its own conditions.

**Acceptance Scenarios**:

1. **Given** Character A, Branch 2, Level 3 requires a purchase, **When** the purchase completes, **Then** only that specific level unlocks (not other branches or levels).
2. **Given** Character B, Level 1 requires passing game Level 40, **When** Level 40 is passed, **Then** Character B Level 1 unlocks and other characters are unaffected.
3. **Given** a character upgrade requires both a purchase AND a gameplay condition, **When** only one is met, **Then** the upgrade remains locked.

---

### Edge Cases

- What happens when a data source is not yet registered but a condition references it? The system MUST report a clear error at configuration time (editor) or evaluation time (runtime).
- How does the system handle concurrent triggers that together satisfy a compound condition? The system MUST evaluate atomically — if two events arrive in rapid succession, the compound condition MUST resolve correctly regardless of order.
- What happens when an unlock is granted but the target is already unlocked? The operation MUST be idempotent — no error, no duplicate reward.
- What happens when a data source value decreases (e.g., coins spent) after an unlock was granted? Already-granted unlocks MUST remain granted (no revocation unless explicitly configured).
- What happens when a cascade chain has more than 10 levels of depth? The system MUST resolve up to a configurable maximum depth and report an error if exceeded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST support defining unlock rules where one condition (trigger) can unlock multiple targets.
- **FR-002**: The system MUST support defining unlock rules where one target can require multiple conditions (triggers), even of different types.
- **FR-003**: The system MUST support compound conditions using AND logic (all conditions must be met).
- **FR-004**: The system MUST support compound conditions using OR logic (any condition must be met).
- **FR-005**: The system MUST support nesting compound conditions (e.g., "(A AND B) OR C").
- **FR-006**: The system MUST allow conditions to reference different data sources (player progress, in-game stats, currency, ally data).
- **FR-007**: The system MUST allow unlock rules to be configured through editor UI elements (inspector, scene nodes).
- **FR-008**: The system MUST allow unlock rules to be created, modified, and removed via code at runtime.
- **FR-009**: The system MUST notify external systems when an unlock state changes (locked → unlocked, progress updated).
- **FR-010**: The system MUST support writing data back to data sources when an unlock is granted (e.g., grant coins, mark achievement).
- **FR-011**: The system MUST support cascading unlocks — an unlock event can itself satisfy conditions for further unlocks.
- **FR-012**: The system MUST detect circular dependencies in unlock chains and report them as errors.
- **FR-013**: The system MUST support threshold-based conditions (e.g., "enemies killed >= 100", "coins >= 1000").
- **FR-014**: The system MUST support boolean-state conditions (e.g., "Level 4 passed = true", "item purchased = true").
- **FR-015**: The system MUST treat unlock operations as idempotent — unlocking an already-unlocked target produces no error and no duplicate side effects.
- **FR-016**: Unlocks MUST be permanent by default — a decrease in the triggering value (e.g., spending coins) MUST NOT revoke a previously granted unlock.

### Key Entities

- **Unlock Rule**: Defines the relationship between one or more conditions and one or more targets. The core "wire" of the system.
- **Condition**: A single evaluable check against a data source (e.g., "coins >= 1000", "level 4 passed"). Can be boolean-state or threshold-based.
- **Compound Condition**: A group of conditions combined with AND/OR logic, supporting nesting.
- **Unlock Target**: The thing being unlocked — a level, achievement, character upgrade, or any game element identified by a key.
- **Data Source**: An external provider of game state that conditions read from and unlock effects write to. Examples: player progress tracker, currency system, in-game stats counter, ally level registry.
- **Unlock Effect**: An action performed when an unlock is granted — writing data back to a data source (e.g., grant coins, mark achievement complete).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A game designer can configure a new unlock rule (single condition, single target) in under 2 minutes using the editor.
- **SC-002**: A game designer can configure a compound condition rule (2+ conditions with AND/OR) in under 5 minutes using the editor.
- **SC-003**: A developer can create an equivalent unlock rule via code in under 10 lines of code.
- **SC-004**: The system correctly resolves a cascade chain of at least 5 levels deep within a single frame.
- **SC-005**: Circular dependency detection catches 100% of direct and indirect cycles and reports them with the full cycle path.
- **SC-006**: All unlock evaluations are idempotent — running the same trigger twice produces identical final state.
- **SC-007**: The system handles at least 200 active unlock rules simultaneously without perceptible delay during gameplay.

## Assumptions

- The plugin is consumed by Godot 4.6 projects; it does not need to support earlier Godot versions.
- Data sources are provided by the consuming game — the plugin defines an interface/contract for data sources but does not implement specific ones (e.g., it does not include a coins system, but it can connect to one).
- Persistence (saving/loading unlock state) is the responsibility of the consuming game's save system; the plugin provides the current state for serialization but does not manage save files.
- The editor UI for configuring rules uses Godot's built-in inspector and scene tree — no custom dock or editor window is required for v1.
- "Purchase" conditions represent an in-game purchase event (not real-money microtransactions); no payment processing integration is in scope.
- The plugin operates in a single-player context; multiplayer state synchronization is out of scope.

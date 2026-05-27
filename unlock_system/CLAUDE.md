# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Unlock System** — a Godot 4.6 project (Forward Plus renderer, Jolt Physics 3D). The Godot project root is one level up (`../project.godot`). This subdirectory (`unlock_system/`) contains the SpecKit planning artifacts and Claude Code configuration.

## Project Structure

```
UnlockSystem/              ← Godot project root (project.godot lives here)
├── project.godot
├── icon.svg
└── unlock_system/         ← SpecKit + Claude Code config (this directory)
    ├── CLAUDE.md
    ├── .specify/          ← SpecKit templates, workflows, constitution
    └── .claude/skills/    ← SpecKit skill definitions
```

## Commands

### Running the project
```sh
# Replace with actual path if different
/Applications/Godot.app/Contents/MacOS/Godot --path /Volumes/Fer/RespaldoFER/Documentos/DiabloHumaStudio/UnlockSystem
```

### Running tests
```sh
<godot-binary> --headless --path /Volumes/Fer/RespaldoFER/Documentos/DiabloHumaStudio/UnlockSystem --script tests/test_<name>.gd
```

### Import new files (generate .uid sidecars)
```sh
<godot-binary> --headless --path /Volumes/Fer/RespaldoFER/Documentos/DiabloHumaStudio/UnlockSystem --import
```

## Planning Workflow (SpecKit)

This project uses SpecKit for feature planning. The workflow is:
1. `/speckit-specify` — Create feature spec from description
2. `/speckit-clarify` — Identify underspecified areas
3. `/speckit-plan` — Generate implementation plan
4. `/speckit-tasks` — Generate ordered tasks
5. `/speckit-implement` — Execute the plan

Use `/speckit-constitution` to define project principles before starting feature work.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->

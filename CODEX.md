# CODEX.md — wtml

## Scope

This file contains Codex-specific collaboration rules for this repository.
Project facts such as language design, syntax, and examples are maintained in `README.md` and `spec.md`.

## Canonical Documents

- `README.md` — project overview and quick introduction
- `spec.md` — current language specification
- `memo.txt` — older design notes in Japanese; use as background only when needed

## Repository Notes

- The project is in an early design/bootstrap phase.
- The implementation language is OCaml.
- The compiler target is a Lisp VM.

## Codex Workflow

- Feature branches for Codex-assisted work use the `codex/` prefix.
- Keep repository facts synchronized with `README.md` and `spec.md` rather than duplicating them here.
- When a rule in this file conflicts with a canonical project document, prefer the canonical document for project behavior and this file only for Codex-specific workflow.

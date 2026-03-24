# Workspace Agent Guidance

This file captures repo-specific working rules for agents collaborating in this workspace.

## Git

- Use conventional commit-style prefixes for all commit titles.
- Preferred prefixes:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `chore:` for maintenance or repo housekeeping
  - `test:` for test-only changes
  - `docs:` for documentation-only changes
  - `refactor:` for behavior-preserving code reshaping
- Do not create bare commit titles such as `Add X`; use `feat: add X` instead.
- Keep commits scoped to a single logical step whenever possible.
- Do not include unrelated user files in commits.
- Leave untracked or unrelated files alone unless explicitly asked to handle them.

## Versioning

- Use Semantic Versioning.
- Track the current package version in the repo root `VERSION` file.
- Track release notes in `CHANGELOG.md`.
- For every commit, explicitly decide whether the change requires a version bump.
- If a bump is needed, update both:
  - `VERSION`
  - the top `Unreleased` or new release section in `CHANGELOG.md`
- Bump rules:
  - `MAJOR` for breaking public API or CLI contract changes
  - `MINOR` for backward-compatible features
  - `PATCH` for backward-compatible fixes, docs-affecting packaging changes, or release housekeeping tied to published artifacts
- While the library is pre-1.0, prefer starting from `0.1.0` and still avoid casual breaking changes.
- If a commit is purely local workflow guidance and does not affect the library or release artifacts, note that no bump is needed.

## Quality Gates

- Before each commit:
  - run `swift test`
  - run coverage checks if code changed
  - maintain 100% line coverage for library files under `Sources/SyntaxKit`
- If a planned step cannot meet the coverage gate yet, finish the step before committing.

## Planning and Delivery

- Work through the plan one step at a time.
- After each completed step:
  - update `plan.md`
  - verify tests and coverage
  - commit the step
- Keep parsing and rendering decoupled.
- Keep CLI behavior layered on top of public library APIs.

## Editing

- Prefer focused, minimal edits.
- Add tests with each behavior change.
- Do not revert user changes unless explicitly asked.

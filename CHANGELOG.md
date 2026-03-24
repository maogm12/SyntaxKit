# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project uses Semantic Versioning.

## [Unreleased]

## [0.1.0] - 2026-03-24

### Added

- Pure Swift TextMate grammar loading for plist-based `.tmLanguage` files
- Grammar registry and include resolution for repository, self, and external grammar references
- Line-oriented parser that emits normalized syntax spans with scope stacks
- CLI commands for `validate`, `parse`, `parse --json`, and `preview`
- tmTheme loading for plist-based `.tmTheme` files
- Theme resolution layered on parser spans with prefix matching, specificity handling, and global fallback
- Fixture-driven tests using the bundled JSON grammar and Monokai theme
- Workspace guidance in `agent.md`
- Root `VERSION` file for release tracking

# Changelog

All notable changes to ShieldTax will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-03-26

**Milestone M1: Scaffold + Core Tracking**

### Added
- Ace3 addon scaffold (AceAddon, AceEvent, AceConsole, AceDB)
- Warrior class guard (locale-independent, uses classToken)
- Shield slot detection and validation (INVTYPE_SHIELD check)
- Shield durability monitoring via `UPDATE_INVENTORY_DURABILITY`
- Combat state tracking via `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED`
- Death guard: durability loss near death attributed to "Death Tax" separately
- Equipment change detection filtered to shield slot
- Gold cost estimation formula from item quality and effective ilvl
- `GetDetailedItemLevelInfo` support for upgraded item levels
- Fallback cost estimation for uncached items
- Gold formatting utility (copper → "Xg Ys Zc")
- `/shieldtax` and `/st` slash command aliases with help and version stubs
- SavedVariables schema with global (lifetime stats) and profile (settings) scopes
- busted test framework with comprehensive WoW API mock
- Test coverage for Tracker (class guard, shield detection, combat attribution, death guard)
- Test coverage for CostCalculator (formula accuracy, fallbacks, formatting)
- CurseForge pkgmeta.yaml with Ace3 externals

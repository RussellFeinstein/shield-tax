# Changelog

All notable changes to ShieldTax will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] — 2026-03-26

**Milestone M2: Sound, Display, and Statistics**

### Added
- SoundManager with configurable sound effects (coin, money_open, register, coins, none)
- Sound throttle via `GetTime()` to prevent spam during large pulls
- On-screen gold counter display frame (draggable, position saved per-profile)
- Display shows current dungeon cost and session cost with shield icon
- "No shield equipped" inactive state on display for Arms/Fury warriors
- Session statistics (local table, resets on logout/reload)
- Dungeon statistics with auto-detection (M+ via `CHALLENGE_MODE_START`/`COMPLETED`, regular dungeons via `PLAYER_ENTERING_WORLD` + `IsInInstance`)
- Dungeon history ring buffer (last 50 dungeons, circular with O(1) eviction)
- Death Tax tracked and displayed separately from Shield Tax
- Tooltip on display hover showing dungeon/session/lifetime stats and shield durability %
- Full slash command suite: `/st sound`, `/st session`, `/st lifetime`, `/st reset`, `/st move`, `/st lock`, `/st minimap`
- Test coverage for SoundManager (throttle, mute, effect keys)
- Test coverage for Stats (session/dungeon accumulation, ring buffer eviction, history sorting)
- Test coverage for Display (init, toggle, update)

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

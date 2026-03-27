# Changelog

All notable changes to ShieldTax will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] — 2026-03-26

**Milestone M4: Content-Type Tracking**

### Added
- Content-type detection: classifies combat as M+, Raid, Dungeon, Open World, or Other
- Per-content-type lifetime stats (Shield Tax breakdown by M+ vs Raid vs Open World etc.)
- Per-content-type session stats
- Content type recorded on dungeon history entries
- `/st content` — view and toggle tracking per content type (e.g., disable open world tracking)
- `/st stats` — view Shield Tax breakdown by content type
- `/st lifetime` now shows per-content breakdown when data exists
- Display tooltip shows per-content-type cost breakdown
- Content toggle settings in profile (default: all enabled)
- Test coverage for content classification, toggles, per-type stats accumulation

## [0.3.0] — 2026-03-26

**Milestone M3: Chat Reporting, LDB, and Polish**

### Added
- Chat reporting via `/st report [party|guild|say|raid]` with 7 humorous randomized templates
- Dungeon history via `/st history` (last 5 dungeons with costs and Death Tax)
- Milestone announcements at real WoW gold sink thresholds (100g, 5K Master Riding, 10K Wooly Mammoth, 20K Tundra Mammoth, 120K Yak, 5M Brutosaur)
- LibDataBroker minimap button via LibDBIcon (left-click toggles display, right-click shows help)
- Minimap tooltip with dungeon/session/lifetime stats and shield durability %
- `/st minimap` now actually toggles the minimap icon (previously was a no-op)
- Test coverage for ChatReporter (report channels, template substitution, message variety, milestones, history)

## [0.2.1] — 2026-03-26

### Fixed
- Mock `IsInInstance()` now returns both values (fixes dungeon detection testing)
- Mock `PlaySound` captures channel argument (verifies correct sound channel)
- Mock `FireEvent` passes event name as first arg (matches real AceEvent-3.0)
- Keystone completion message now includes Death Tax
- Zero/negative-cost events filtered out (no phantom sounds)
- Post-resurrection durability re-snapshot prevents phantom costs
- Display frame creation deferred during combat lockdown
- Display updates after all reset commands
- `C_Item.GetItemInfo` guarded for potential 12.0 removal
- Help text includes all sound options

### Added
- `test_core.lua` covering slash commands, resets, event callbacks
- Dungeon detection event path tests

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

# Changelog

All notable changes to ShieldTax will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] — 2026-03-27

### Fixed
- Shield repair cost severely undercounted (~11x too low) — was using an armor-only formula that doesn't apply to shields
- Now reads exact repair cost from WoW Tooltip API (`C_TooltipInfo.GetInventoryItem`) instead of estimating
- Old armor formula kept as fallback if Tooltip API is unavailable

## [1.0.4] — 2026-03-27

### Fixed
- Grant `contents: write` permission to release workflow so GitHub Releases are created

## [1.0.3] — 2026-03-27

### Fixed
- Add `move-folders` to `pkgmeta.yaml` so BigWigs packager finds the TOC in the `ShieldTax/` subdirectory

## [1.0.2] — 2026-03-27

### Added
- GitHub Actions workflow for automatic CurseForge packaging on tag push
- Manual changelog directive in `pkgmeta.yaml` — CurseForge now shows the curated changelog

## [1.0.1] — 2026-03-27

### Changed
- Removed "Cha-ching" catchphrase from TOC notes, README, and chat report template
- Chat report template now ends with "Please Blizz." instead

## [1.0.0] — 2026-03-27

### Changed
- Shield durability % displayed on frame next to title (moved from tooltip)
- Death Tax shown below Lifetime Total in tooltip (was above, causing confusion)
- Chat report templates use natural grammar ("this dungeon", "this raid", "today")
- Content toggle immediately shows/hides display frame
- Removed extra tooltip spacing

## [0.5.2] — 2026-03-26

### Fixed
- CONTENT_LABELS deduplicated to single source in Tracker module (was in 3 files)
- Display.lua titleText variable shadowing
- MinimapButton LDB text now content-aware (matches display frame)
- Stale README commands and sound options
- Stale CLAUDE.md session data description

## [0.5.1] — 2026-03-26

### Changed
- Content toggles are now display filters, not tracking blockers — data always records
- Disabled content types hidden from display frame and tooltip
- Disabled content types excluded from displayed lifetime total
- Frame auto-hides when current content type is disabled

## [0.5.0] — 2026-03-26

### Changed
- Redesigned display frame: gold "Shield Tax" title header with shield icon
- Current content type and cost shown on frame (e.g., "Open World: 5g", "M+: 12g")
- Lifetime total replaces session on frame
- Dynamic frame width based on text content
- Redesigned tooltip: clean "Lifetime Breakdown" with per-content costs
- Removed session from all user-facing surfaces

## [0.4.2] — 2026-03-26

### Fixed
- Session and dungeon data now persists through `/reload` (stored in SavedVariables)
- Session resets on fresh login, dungeon resets on instance change
- Display refreshes on instance enter/leave
- Restored currentInstanceName on reload to prevent false dungeon resets

## [0.4.1] — 2026-03-26

### Fixed
- Death guard race condition: added UnitIsDeadOrGhost fallback when UPDATE_INVENTORY_DURABILITY fires before PLAYER_DEAD
- Dungeon counter no longer resets on death in instances (zone change within same instance now ignored)
- Replaced missing custom sound files (register, coins) with built-in WoW sounds (auction, levelup)
- Reset all now clears byContent stats
- Display refreshes on shield equip/unequip

## [0.4.0] — 2026-03-26

### Added
- Content-type detection: classifies combat as M+, Raid, Dungeon, Open World, or Other
- Per-content-type lifetime and session stats
- Content type recorded on dungeon history entries
- `/st content` — view and toggle content-type display filters
- `/st stats` — view Shield Tax breakdown by content type
- `/st lifetime` shows per-content breakdown

## [0.3.0] — 2026-03-26

### Added
- Chat reporting via `/st report [party|guild|say|raid]` with 7 humorous randomized templates
- Dungeon history via `/st history` (last 5 dungeons)
- Milestone announcements at real gold sink thresholds (100g, 5K, 10K, 20K, 120K, 5M)
- LibDataBroker minimap button (left-click toggles display, right-click shows help)
- Minimap tooltip with stats summary

## [0.2.0] — 2026-03-26

### Added
- SoundManager with configurable sound effects and throttle
- On-screen gold counter display frame (draggable, position saved)
- Session, dungeon, and lifetime statistics with Death Tax tracked separately
- Dungeon auto-detection (M+ and regular dungeons/raids)
- Dungeon history ring buffer (last 50)
- Full slash command suite
- Audit fixes: mock accuracy, event signatures, edge cases

## [0.1.0] — 2026-03-26

### Added
- Ace3 addon scaffold (AceAddon, AceEvent, AceConsole, AceDB)
- Warrior class guard (locale-independent, uses classToken)
- Shield slot detection and validation (INVTYPE_SHIELD check)
- Shield durability monitoring via `UPDATE_INVENTORY_DURABILITY`
- Combat state tracking via `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED`
- Death guard with both `PLAYER_ALIVE` and `PLAYER_UNGHOST` for all resurrection paths
- Gold cost estimation formula from item quality and effective ilvl
- Gold formatting utility
- `/shieldtax` and `/st` slash command aliases
- busted test framework with WoW API mock
- CurseForge pkgmeta.yaml with Ace3 externals

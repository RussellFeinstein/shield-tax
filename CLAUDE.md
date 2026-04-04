# ShieldTax — Project Notes

## Architecture

WoW addon that tracks shield durability cost for Warriors. Built on Ace3 framework.

### Key Files
- `ShieldTax/Core.lua` — AceAddon bootstrap, class/spec guards, slash commands, DB schema
- `ShieldTax/Tracker.lua` — Combat state + `UPDATE_INVENTORY_DURABILITY` monitoring
- `ShieldTax/CostCalculator.lua` — Repair cost via Tooltip API (`C_TooltipInfo`) + armor formula fallback
- `ShieldTax/SoundManager.lua` — Sound playback with throttle (M2)
- `ShieldTax/Display.lua` — Movable gold counter frame (M2)
- `ShieldTax/Stats.lua` — Session/dungeon/lifetime statistics (M2)
- `ShieldTax/ChatReporter.lua` — Chat report templates + milestone announcements (M3)
- `ShieldTax/Options.lua` — AceConfig-3.0 settings panel (ESC > Options > AddOns)

### Detection Pipeline (12.0 compatible — no CLEU)
1. `PLAYER_REGEN_DISABLED`/`ENABLED` → combat state flag
2. `UPDATE_INVENTORY_DURABILITY` → shield slot durability delta
3. In-combat + durability decreased + not dead → Shield Tax event
4. CostCalculator reads exact repair cost delta via `C_TooltipInfo.GetInventoryItem` (falls back to armor formula if unavailable)

### Key Design Decisions
- **No CLEU:** Removed in Patch 12.0. Uses durability + combat state instead.
- **Class guard:** `UnitClass("player")` second return value (locale-independent token)
- **Spec guard:** `GetSpecializationInfo()` checks for Protection (specID 73). Modules only activate for Prot spec. `PLAYER_SPECIALIZATION_CHANGED` handles runtime spec switches.
- **Shield slot:** `GetInventorySlotInfo("SecondaryHandSlot")` — not hardcoded 17
- **Death guard:** Both `PLAYER_ALIVE` and `PLAYER_UNGHOST` needed for all res paths
- **Settings scope:** `profile` (per-character), stats scope: `global` (cross-character)
- **Session/dungeon data:** Persisted in SavedVariables (`charData.currentSession`, `charData.currentDungeon`). Survives /reload. Session resets on fresh login. Dungeon resets on instance change.
- **Content labels:** Shared via `Tracker.CONTENT_LABELS` — single source of truth for display names
- **Content toggles:** Display filters only — data always records regardless of toggle state

## Testing
- Framework: busted (Lua 5.1)
- Config: `.busted` file sets pattern to `test_` prefix and ROOT to `tests/`
- Run: `busted` from repo root (no args needed)
- Mock: `tests/wow_api_mock.lua` — mocks WoW API surface for testing outside WoW
- Setup: LuaRocks 3.x win32 package + VS Build Tools (see README)

## Version
- Authoritative version: `ShieldTax.toc` `## Version:` field
- Also in: `Core.lua` (`ShieldTax.VERSION`), `CHANGELOG.md`, `README.md`
- Bump all on every commit

## Build & Distribution
- `pkgmeta.yaml` for CurseForge BigWigs packager
- Ace3 libs are externals (fetched by packager, not committed)
- `.gitignore` excludes `ShieldTax/Libs/`

## CI/CD
- GitHub Actions workflow: `.github/workflows/release.yml`
- Triggers on tag push (`v*`)
- Uses `BigWigsMods/packager@v2` to build and upload to CurseForge
- Also creates a GitHub Release with the packaged zip
- Requires `CF_API_KEY` secret in GitHub repo settings (CurseForge API token)

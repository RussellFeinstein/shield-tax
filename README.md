# ShieldTax

**Track the hidden gold cost of Shield Block.** Cha-ching!

Warriors pay a per-press tax on their core active mitigation that no other tank class does. Every time you block, your shield has a chance to lose durability — costing you roughly **25 gold per M+ dungeon** just for pressing Shield Block.

ShieldTax makes this invisible cost visible (and audible) with a running gold counter and a satisfying cha-ching every time your shield takes the hit.

## Features

- **Real-time shield durability tracking** during combat
- **Gold cost estimation** based on item level and quality
- **Sound effects** when your shield loses durability (configurable: coin jingle, cash register, mute)
- **Death Tax** tracked separately — deaths don't inflate your Shield Block cost
- **Warrior-only** — silently inactive on other classes
- **12.0 (Midnight) compatible** — no CLEU dependency

### Sound & Display (v0.4.0)

- On-screen gold counter display (draggable frame with dungeon + session cost)
- Configurable sound effects: coin jingle, cash register, coin drop, money bag, or mute
- Sound throttle prevents spam on large pulls
- Session / dungeon / lifetime statistics with Death Tax tracked separately
- Dungeon auto-detection (M+ keystones and regular dungeons/raids)
- Dungeon history (last 50, ring buffer)

### Content-Type Tracking (v0.4.0)

- Track Shield Tax by content type: M+, Raid, Dungeon, Open World, Other
- `/st stats` — view cost breakdown by content type
- `/st content` — toggle tracking per content type (e.g., disable open world)
- Lifetime, session, and dungeon history all record content type
- Display tooltip shows per-content breakdown

### Chat & Social (v0.4.0)

- `/st report` — share your Shield Tax in party/guild/say chat with randomized humorous messages
- `/st history` — view your last 5 dungeon Shield Tax costs
- Minimap button via LibDataBroker (left-click toggles display, right-click for help)
- Milestone announcements at real gold sink thresholds: Master Riding (5K), Wooly Mammoth (10K), Tundra Mammoth (20K), Grand Expedition Yak (120K), Brutosaur (5M)

### Future (v2.0.0 — Tank Tax)

- Expand to all tank specs (Paladin, DK, DH, Druid, Monk)
- Track total tanking durability cost across all armor slots
- Cross-class comparison

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/shieldtax) (coming soon) or clone this repo
2. Copy the `ShieldTax/` folder to your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Log in on a Warrior character — the addon activates automatically

## Commands

| Command | Action |
|---------|--------|
| `/st` | Toggle display frame |
| `/st sound [coin\|register\|coins\|none]` | Set sound effect |
| `/st sound test` | Play current sound |
| `/st session` | Print session stats |
| `/st lifetime` | Print lifetime stats |
| `/st reset` | Reset dungeon counter |
| `/st reset session` | Reset session counter |
| `/st content [type]` | Toggle content-type tracking |
| `/st stats` | Shield Tax by content type |
| `/st report [party\|guild\|say]` | Share Shield Tax in chat |
| `/st history` | Last 5 dungeon costs |
| `/st reset all` | Reset ALL data |
| `/st move` / `/st lock` | Unlock/lock display position |
| `/st minimap` | Toggle minimap icon |
| `/st version` | Show addon version |
| `/st help` | List all commands |

## How It Works

ShieldTax monitors your shield's durability via the `UPDATE_INVENTORY_DURABILITY` event. When durability decreases while you're in combat (and you haven't just died), it calculates the repair cost using your shield's item level and quality, plays a sound, and adds the cost to your running tally.

**Cost formula:** `(effectiveItemLevel - 32.5) × qualityMultiplier` silver per durability point

| Quality | Multiplier |
|---------|-----------|
| Uncommon (Green) | 0.02 |
| Rare (Blue) | 0.025 |
| Epic (Purple) | 0.05 |

*Note: This formula is approximate. Actual shield repair costs may vary slightly. Reputation discounts at vendors are not factored in.*

## Development

### Requirements

- Lua 5.1 (included in the LuaRocks win32 package)
- [busted](https://lunarmodules.github.io/busted/) (test framework)
- Visual Studio Build Tools (for compiling busted's native dependencies)

### Setup (Windows)

1. Install [Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/) with the "Desktop development with C++" workload
2. Download the [LuaRocks win32 legacy package](https://luarocks.org/releases/) (includes Lua 5.1)
3. Extract and run `install.bat /L` from a **Developer Command Prompt for VS 2022** (Run as Administrator)
4. `luarocks install busted`

### Running Tests

```bash
cd shield-tax
busted
```

### Project Structure

```
shield-tax/
├── ShieldTax/           # WoW addon (copy this to Interface/AddOns/)
│   ├── ShieldTax.toc    # Addon manifest
│   ├── Core.lua         # Init, class guard, slash commands
│   ├── Tracker.lua      # Durability monitoring + combat state
│   ├── CostCalculator.lua  # Gold cost formula
│   ├── SoundManager.lua # Sound effects + throttle
│   ├── Stats.lua        # Session/dungeon/lifetime stats
│   ├── Display.lua      # On-screen gold counter frame
│   ├── ChatReporter.lua # Chat reports + milestones
│   └── MinimapButton.lua # LibDataBroker minimap icon
├── tests/               # busted tests (not included in addon)
│   ├── wow_api_mock.lua # WoW API mock layer
│   ├── test_tracker.lua
│   ├── test_cost_calculator.lua
│   ├── test_sound_manager.lua
│   ├── test_stats.lua
│   ├── test_display.lua
│   ├── test_core.lua
│   └── test_chat_reporter.lua
├── pkgmeta.yaml         # CurseForge packager config
├── CHANGELOG.md
└── README.md
```

## License

[MIT](LICENSE)

## Version

0.4.0

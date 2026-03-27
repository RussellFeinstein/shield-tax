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

### Coming Soon (v0.2.0+)

- On-screen gold counter display (draggable frame)
- Session / dungeon / lifetime statistics
- Sound throttle for large pulls
- Dungeon auto-detection (M+ and regular)

### Coming in v0.3.0

- `/st report` — share your Shield Tax in party/guild chat with humorous messages
- Minimap button (LibDataBroker)
- Milestone announcements at gold sink thresholds (Tundra Mammoth, Yak, Brutosaur)

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
| `/st version` | Show addon version |
| `/st help` | List all commands |

*More commands available in v0.2.0+*

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
│   └── CostCalculator.lua  # Gold cost formula
├── tests/               # busted tests (not included in addon)
│   ├── wow_api_mock.lua # WoW API mock layer
│   ├── test_tracker.lua
│   └── test_cost_calculator.lua
├── pkgmeta.yaml         # CurseForge packager config
├── CHANGELOG.md
└── README.md
```

## License

[MIT](LICENSE)

## Version

0.1.0

# RothShinyBuffs

Galaxy-style art for Blizzard-owned player buff and debuff buttons on World of Warcraft Retail 12.1. The addon preserves Blizzard Edit Mode, aura assignment, visibility, duration, layout, tooltip, and restricted-state ownership.

## Compatibility

- Game: World of Warcraft Retail / Midnight 12.1.0
- Interface: `120100`
- Version: `0.5.0`
- Verified Blizzard source baseline: `12.1.0.69497`
- Author: Galaxy (Roth UI) / Neomorph
- SavedVariables: `RothShinyBuffsDB`
- Bundled libraries: LibStub, CallbackHandler-1.0, LibSharedMedia-3.0
- External dependencies: none

## Installation

Copy `RothShinyBuffs` into `World of Warcraft/_retail_/Interface/AddOns/`, enable it, and reload the UI.

Open **Options → AddOns → RothShinyBuffs**. Use Blizzard Edit Mode to position and size the underlying BuffFrame and DebuffFrame containers.

## Retail 12.1 aura-safety model

Patch 12.1 makes aura assignment and managed aura objects restricted data. RothShinyBuffs therefore does not discover or follow active aura buttons.

The runtime styles only source-confirmed slots that Blizzard creates during `AuraFrameMixin:AuraFrame_OnLoad()`:

- `BuffFrame.auraFrames[1..32]`;
- `DebuffFrame.auraFrames[1..16]`;
- `DeadlyDebuffFrame.Debuff` when available.

The addon deliberately does not:

- register `UNIT_AURA`;
- read `hasValidInfo`, `isExample`, `isAuraAnchor`, icon texture, button visibility, alpha, aura data, or pool membership;
- call `EnumerateActive`, `GetChildren`, or `GetNumChildren`;
- touch private aura anchors;
- hide or replace Blizzard-owned border/state regions;
- create textures or change icon crop/overlay geometry in combat.

Settings changes during combat set one pending apply flag and are applied on `PLAYER_REGEN_ENABLED`. Addon state is stored in a weak-key table so Blizzard slots are not retained after release.

## Visual modes

- **Galaxy Strip** — eight-tile border using the bundled strip texture;
- **Full Border** — one stretched border texture;
- optional addon-owned background;
- configurable icon crop, border/background outsets, colors, and LibSharedMedia names.

The retired Masque path is intentionally removed. It mirrored live Blizzard icon texture/assignment state and depended on active-button discovery, which is outside the safe 12.1 static-slot contract.

## Commands

- `/rsb` — show static-slot count and pending state;
- `/rsb toggle` — enable or disable addon-owned art;
- `/rsb reset` — reset settings;
- `/rsb config` — open the Settings category.

Disabling the addon hides its textures and restores the icon texture coordinates captured before styling.

## Validation status

`core.lua`, `options.lua`, and `tests/test_static_slots.lua` pass `texlua --luaconly`. The regression verifies that:

- no textures or geometry are created in combat;
- exactly 49 source-confirmed public slots are styled in the mock source topology;
- private debuff anchors are skipped;
- no `UNIT_AURA`, active-pool enumeration, live texture read, or visibility query occurs;
- a combat-time crop change applies after regen;
- disabling restores the original icon crop.

A live Retail client smoke test remains required for buffs, debuffs, Edit Mode examples, deadly debuffs, both visual modes, media/color controls, combat transitions, pooled/reloaded frames, and taint/forbidden-action logging.

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Agent guide](AGENT_GUIDE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
- [WoW addon engineering knowledge base](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb)

## License

Licensed under the [MIT License](LICENSE). Bundled libraries remain under their own notices.

# RothShinyBuffs agent guide

## Start here

[`RothShinyBuffs.toc`](RothShinyBuffs.toc) is the definitive load contract. Retail 12.1 loads bundled LibStub, CallbackHandler-1.0 and LibSharedMedia-3.0, then `core.lua`, then `options.lua`.

Target contract:

- Retail / Midnight `12.1.0`;
- Interface `120100`;
- verified Blizzard source baseline `12.1.0.69497`;
- one SavedVariables root: `RothShinyBuffsDB`;
- no external addon dependency.

## Why the runtime is static-slot only

Pinned Blizzard source defines `BUFF_MAX_DISPLAY = 32` and `DEBUFF_MAX_DISPLAY = 16`. `AuraFrameMixin:AuraFrame_OnLoad()` pre-creates ordinary aura buttons in `self.auraFrames`, then appends private aura anchors separately.

Patch 12.1 makes aura assignment and managed aura presentation restricted. Therefore the addon must not discover currently active buttons through pools, visibility, `hasValidInfo`, icon texture contents, examples, layout state, or private-anchor state.

The only allowed slot sources are:

```text
BuffFrame.auraFrames[1..32]
DebuffFrame.auraFrames[1..16]
DeadlyDebuffFrame.Debuff
```

A slot is accepted only when `button.Icon` is an accessible Texture supporting `SetTexCoord`. Do not broaden this to aliases, pool scans or child-tree searches without new source/runtime evidence.

## Runtime map

### Defaults and media

`EnsureDefaults` owns schema/default migration and removes the retired `useMasque` key. Numeric geometry values are bounded, colors are copied as ordinary four-number arrays, and mode is closed to `galaxy_strip` or `full_border`.

`RegisterBuiltInMedia` registers the bundled strip, border and background textures with LibSharedMedia. `ResolveConfig` resolves stored media names with explicit bundled fallbacks.

### Slot presentation

`StyleSourceConfirmedSlots` calls `StyleArray` with fixed limits. It does not use `#auraFrames` and does not visit DebuffFrame entries after index 16, so appended private aura anchors are excluded by construction.

`StyleSlot`:

1. validates only the source-confirmed `button.Icon` object type;
2. creates weakly tracked addon-owned textures outside combat;
3. captures original icon texture coordinates once;
4. applies crop and background;
5. applies either the full-border texture or eight strip tiles;
6. leaves every Blizzard-owned region, script, event, tooltip, parent, size and visibility property untouched.

`HideState` hides addon-owned textures and restores captured icon coordinates. Do not modify Blizzard Border, DebuffBorder, IconBorder, Duration, Count, Cooldown or aura frame alpha as a substitute.

### Combat and lifecycle

`ApplySettings` is the only apply boundary. During combat it sets `pendingApply` and returns without frame/texture creation or geometry/crop mutation. `PLAYER_REGEN_ENABLED` applies the latest SavedVariables state once.

The event frame registers only:

```text
ADDON_LOADED
PLAYER_LOGIN
PLAYER_ENTERING_WORLD
PLAYER_REGEN_ENABLED
```

`ADDON_LOADED Blizzard_BuffFrame` retries the same fixed-slot apply after the Blizzard addon becomes available. There is no aura-state listener.

### Settings

`options.lua` registers a current canvas category through `Settings.RegisterCanvasLayoutCategory`. The canvas exposes enabled state, border/background visibility, visual mode, crop, geometry, LibSharedMedia names, colors and reset.

Every setter writes SavedVariables and calls `_G.RothShinyBuffs_ApplySettings`. The core remains the sole runtime owner and enforces combat deferral.

The color picker prefers `ColorPickerFrame:SetupColorPickerAndShow` and has a compatibility fallback. No Masque option remains.

## Hard invariants

- Never register `UNIT_AURA` for styling.
- Never inspect raw `AuraData`, `auraInfo`, `hasValidInfo`, `isExample`, `isAuraAnchor`, button visibility, alpha, icon texture, child count, layout count or active pool membership.
- Never call `EnumerateActive`, `GetChildren`, `GetNumChildren`, `C_UnitAuras`, or `AuraUtil.ForEachAura`.
- Never use managed aura objects as visibility/layout/event/focus side channels.
- Never create addon textures or change crop/geometry in combat.
- Never hide Blizzard aura state regions to force one visual owner.
- Keep `styledSlots` weak-keyed.
- Keep source-confirmed limits at 32 buffs and 16 debuffs unless a newer pinned Blizzard source changes the constants.
- Keep private anchors excluded by numeric range and icon validation, not by reading their state fields.
- Do not restore the Masque bridge without a new design that does not copy or follow active aura state.

## State

Durable keys:

- `configVersion`;
- `enabled`, `showBorder`, `showBG`;
- `mode`;
- `iconCrop`, `edgeSize`, `outset`, `bgOutset`;
- `bgColor`, `borderColor`;
- `stripBorderName`, `borderName`, `bgName`.

Runtime-only state:

- resolved media/config cache;
- weak slot-to-overlay map;
- original icon texture coordinates;
- initialization and pending-apply flags;
- Settings category ID.

## Commands

```text
/rsb
/rsb toggle
/rsb reset
/rsb config
```

The status output reports only the number of statically accepted public slots and whether an apply is pending. It does not report active aura count.

## Change routing

- defaults, access gates, media and slot styling: `core.lua`;
- fixed-slot limits and lifecycle: `core.lua`;
- Settings canvas and color/media controls: `options.lua`;
- offline regression: `tests/test_static_slots.lua`;
- metadata/load order/dependencies: `RothShinyBuffs.toc`;
- durable visual explanation: README and architecture.

## Verification

From the repository root:

```sh
texlua --luaconly core.lua
texlua --luaconly options.lua
texlua --luaconly tests/test_static_slots.lua
texlua tests/test_static_slots.lua
```

Expected runtime result:

```text
PASS: only fixed public aura slots are styled; active aura state is never scanned; combat apply is deferred
```

Static source checks should find no runtime occurrences of:

```text
UNIT_AURA
EnumerateActive
GetChildren
GetNumChildren
hasValidInfo
isExample
GetTexture(
IsShown(
C_UnitAuras
AuraUtil.ForEachAura
Masque
C_Timer
```

The only retained `useMasque` occurrence may be the migration assignment `DB.useMasque = nil`.

In the target client, test normal buffs/debuffs, Edit Mode example auras, DeadlyDebuffFrame, both modes, media/color controls, enable/disable/reset, login/reload/world transitions, combat-time setting changes, private aura scenarios, and `/console taintLog 1` plus Lua error capture.

Static/mocked evidence does not prove live visual layering or restricted-object behavior. Record the exact build and scenario for each result.

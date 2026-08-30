# RothShinyBuffs architecture

## Ownership

`core.lua` is the runtime and static-slot presentation owner. It initializes/sanitizes `RothShinyBuffsDB`, registers bundled media, resolves LibSharedMedia names, tracks addon-owned textures in a weak-key table, styles only source-confirmed public aura slots, restores icon texture coordinates on disable, routes slash commands, and defers settings application during combat.

`options.lua` is the Settings canvas owner. It exposes enablement, visual mode, border/background visibility, icon crop, geometry, media names, colors, and reset. Every setter writes SavedVariables and invokes the single `_G.RothShinyBuffs_ApplySettings` runtime boundary.

Blizzard remains the authority for aura parsing, filtering, assignment, visibility, duration, tooltip, sorting, layout, Edit Mode, private auras, and restricted state.

## Load order

```text
RothShinyBuffs.toc
  -> Libs/LibStub/LibStub.lua
  -> Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
  -> Libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua
  -> core.lua
  -> options.lua
```

The path capitalization matches the repository tree. Masque is not a dependency in the Retail 12.1 runtime.

## Source-confirmed slot boundary

Pinned Blizzard build `12.1.0.69497` defines:

```text
BUFF_MAX_DISPLAY = 32
DEBUFF_MAX_DISPLAY = 16
```

`AuraFrameMixin:AuraFrame_OnLoad()` pre-creates those ordinary `AuraButtonTemplate` slots in `self.auraFrames`. Debuff private aura anchors are appended separately after the first 16 buttons.

RothShinyBuffs therefore uses fixed numeric ranges instead of discovering active frames:

```text
BuffFrame.auraFrames[1..32]
DebuffFrame.auraFrames[1..16]
DeadlyDebuffFrame.Debuff
```

A candidate is styled only when its source-confirmed `button.Icon` is an accessible Texture object supporting `SetTexCoord`. This naturally excludes the appended private aura anchors without reading `isAuraAnchor`.

The runtime does not inspect array length, active pool membership, aura assignment, visibility, alpha, texture contents, examples, or private-aura state.

## Presentation state

Each accepted slot receives only addon-owned Texture regions:

- optional background on `BACKGROUND`;
- either one full border on `OVERLAY` or eight Galaxy strip tiles on `OVERLAY`;
- icon texture coordinates are cropped using persisted ordinary numeric settings.

Blizzard-owned icon, duration, count, border, cooldown, tooltip, scripts, events, parent, size, and layout remain untouched. Addon textures anchor to the Blizzard icon so Edit Mode/layout changes propagate naturally.

The weak-key `styledSlots` table stores runtime-only references and the original icon texture coordinates. Disabling the addon hides addon-owned regions and restores the captured coordinates.

## Combat and lifecycle

`ApplySettings` resolves ordinary configuration, then:

1. if combat is active, sets `pendingApply` and returns without creation or geometry mutation;
2. outside combat, applies the current settings to the fixed source-confirmed slots;
3. reapplies any still-accessible previously captured slot without querying Blizzard active state.

Events are limited to:

- `ADDON_LOADED` for this addon and `Blizzard_BuffFrame`;
- `PLAYER_LOGIN`;
- `PLAYER_ENTERING_WORLD`;
- `PLAYER_REGEN_ENABLED`.

There is no `UNIT_AURA`, timer, ticker, `OnUpdate`, frame-tree scan, or active-pool callback.

## Retired Masque path

The 12.0 implementation created a second icon surface for Masque, copied Blizzard's current icon texture, followed active button discovery, and hid original regions. That required observing live assignment/presentation state. The integration is removed rather than replaced with a misleading or unsafe fallback.

## Evidence boundary

`tests/test_static_slots.lua` proves the fixed-slot, no-active-scan, private-anchor exclusion, combat-deferral, and crop-restore contract against mocks. It does not prove current-client object access, visual layering, Edit Mode example behavior, private-aura restrictions, or taint behavior. Those remain live-client gates.

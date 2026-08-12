# RothShinyBuffs agent guide

## Start here

Read [`RothShinyBuffs.toc`](RothShinyBuffs.toc), then [`core.lua`](core.lua) and [`options.lua`](options.lua). `core.lua` is the runtime owner; `options.lua` only builds Settings UI and calls the two exported core functions `RothShinyBuffs_EnsureDefaults` and `RothShinyBuffs_ApplySettings`.

TOC release metadata is `0.40` (`RothShinyBuffs.toc`, `## Version`).

## Load order and execution path

The TOC loads embedded `LibStub`, `CallbackHandler-1.0`, and `LibSharedMedia-3.0`, followed by `core.lua`, then `options.lua`. `core.lua` creates/merges `RothShinyBuffsDB`, registers built-in media, resolves the current media, and registers `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `UNIT_AURA`, and `ADDON_LOADED`. `PLAYER_LOGIN` schedules three delayed scans; `UNIT_AURA` for `player` queues a throttled scan; `ADDON_LOADED` queues a scan when `Blizzard_BuffFrame` becomes available.

Complete `loadedFiles` inventory (root `docs/addon-architecture.json`, in execution order):

```text
libs/LibStub/LibStub.lua
libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua
core.lua
options.lua
```

The render path is `RequestUpdate` -> `DoUpdate` -> `GetAuraContainers` -> `ScanContainer` -> `StyleButton`. Active aura buttons are discovered from Blizzard aura pools/tables. Non-Masque mode creates `RSB_OverlayFrame` with either `RSB_Strip` or `RSB_Full`; Masque mode creates `RSB_MSQFrame`, hides the original icon and feeds the overlay to `MSQ_Group`.

## State and surfaces

- SavedVariables: `RothShinyBuffsDB` (`enabled`, `useMasque`, `mode`, border/background visibility, geometry, media names, colors, `configVersion`).
- Options: Blizzard Settings category named `RothShinyBuffs`; no slash command is registered.
- Public runtime anchors: `RothShinyBuffs_EnsureDefaults`, `RothShinyBuffs_ApplySettings`.
- Bundled media is registered under `Interface\\AddOns\\RothShinyBuffs\\media\\`; do not replace these names with arbitrary paths in settings.

## Dependencies and relationships

`LibSharedMedia-3.0` is bundled and requires the bundled `LibStub`/`CallbackHandler-1.0`. `Masque` is an optional external dependency declared in the TOC; failure to load it intentionally falls back to local overlays. The addon touches Blizzard's aura button presentation only and deliberately does not move or resize Blizzard aura containers. No checked-in addon in this workspace calls RothShinyBuffs APIs.

Falsification notes: the addon has no slash command, no `COMBAT_LOG_EVENT_UNFILTERED` registration, no Cooldown Manager (CDM) integration, and no permanent `OnUpdate` loop. The only optional render bridge is Masque; the only bundled media library is LibSharedMedia.

## Change routing

- Change detection, throttling, aura pools, overlay geometry, Masque bridge, or render semantics in [`core.lua`](core.lua).
- Change controls/default display and Settings registration in [`options.lua`](options.lua); route every setter through `RothShinyBuffs_ApplySettings`.
- Change bundled visual assets under [`media/`](media/), and update the LSM registration and option defaults together.
- Change SavedVariables schema only with a migration/version policy; `EnsureDefaults` currently fills missing keys but does not migrate renamed keys.

## Invariants and risks

- Never own Blizzard aura-container layout; Edit Mode remains the layout authority.
- `UNIT_AURA` is throttled (`MIN_REQ_INTERVAL = 0.30`) and uses a short timer; do not add a permanent `OnUpdate` loop.
- Do not style example/invalid buttons or call `GetTexture` on absent icons.
- In Masque mode local borders/backgrounds are hidden and the original icon is alpha-hidden; when changing this, preserve the no-double-render invariant.
- Aura button frames are Blizzard-owned. Hiding borders/setting icon alpha can become taint-sensitive if protected frames are touched; verify with `ADDON_ACTION_BLOCKED` and in-combat testing.
- The code assumes Blizzard aura containers expose one of the known pool/table fields. A client UI refactor can silently reduce coverage.

## Verification

1. Confirm TOC file order and all referenced files exist.
2. Parse all Lua with the repository's Lua 5.1 check.
3. In-game: `/reload`; open Settings; toggle `enabled`, mode, colors, geometry, and Masque; inspect player buffs/debuffs through `UNIT_AURA`, `PLAYER_LOGIN`, and `Blizzard_BuffFrame` load timing.
4. Verify no aura container moves/resizes, no duplicate borders appear, and no `ADDON_ACTION_BLOCKED`/Lua errors occur in combat.
5. With Masque absent, confirm local overlay fallback; with Masque enabled, confirm `RSB_MSQFrame` is the only visual path.

## Uncertain or version-sensitive claims

The exact Blizzard aura pool field names and the availability of `Settings.RegisterCanvasLayoutCategory` are build-sensitive; the implementation has fallbacks but they require live-client verification. `LibSharedMedia` availability is expected because it is bundled, but the silent fallback path remains intentionally defensive.

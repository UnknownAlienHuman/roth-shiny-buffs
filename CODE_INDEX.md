# RothShinyBuffs code index

| File or directory | Responsibility |
|---|---|
| `RothShinyBuffs.toc` | Retail 12.1 metadata, bundled library paths, SavedVariables and definitive load order |
| `core.lua` | Defaults/migration, accessibility gates, LibSharedMedia registration/resolution, fixed public slot ranges, addon-owned background/border textures, crop restore, slash commands and combat-deferred apply |
| `options.lua` | Current Blizzard canvas Settings category for visual mode, crop, geometry, media, colors and reset |
| `tests/test_static_slots.lua` | Mocked regression for 32 buff slots, 16 debuff slots, DeadlyDebuffFrame, private-anchor exclusion, no active-state scan and combat deferral |
| `Libs/` | Bundled LibStub, CallbackHandler-1.0 and LibSharedMedia-3.0 |
| `media/` | Bundled Galaxy strip, full-border and background textures |

`RothShinyBuffsDB` is the only persistent state. Detailed ownership and the 12.1 source boundary are in [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`AGENT_GUIDE.md`](AGENT_GUIDE.md).

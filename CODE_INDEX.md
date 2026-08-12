# Code index

| File or directory | Responsibility / exact anchors |
| --- | --- |
| [`core.lua`](core.lua) | `EnsureDefaults`, `ResolveMedia`, `StyleButton`, `ScanContainer`, `DoUpdate`, `RequestUpdate`, `RothShinyBuffs_ApplySettings`; owns DB, event frame, overlays and Masque bridge |
| [`options.lua`](options.lua) | `RegisterPanel`, `Build`, `Refresh`, control setters; writes DB then invokes `RothShinyBuffs_ApplySettings` |
| [`libs/`](libs/) | bundled `LibStub`, `CallbackHandler-1.0`, `LibSharedMedia-3.0` |
| [`media/`](media/) | bundled border/background textures registered by `RegisterBuiltInMedia` |

Entry is TOC-driven; there is no slash command or separate service layer. `RothShinyBuffsDB` is the only persistent state.

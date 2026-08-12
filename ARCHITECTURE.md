# Architecture

The TOC load order is `libs/LibStub/LibStub.lua` -> `libs/CallbackHandler-1.0/CallbackHandler-1.0.lua` -> `libs/LibSharedMedia-3.0/LibSharedMedia-3.0.lua` -> [`core.lua`](core.lua) -> [`options.lua`](options.lua). The core creates `RothShinyBuffsDB`, registers bundled media, and exposes `RothShinyBuffs_EnsureDefaults`/`RothShinyBuffs_ApplySettings` for the options file.

Runtime flow: `PLAYER_LOGIN`/`PLAYER_ENTERING_WORLD`/`UNIT_AURA`/`ADDON_LOADED` -> `RequestUpdate` (0.30 s throttle, 0.05 s timer) -> `DoUpdate` -> known Blizzard aura containers and active pools -> `StyleButton`. The style branch is either local `RSB_Strip`/`RSB_Full` overlays or the optional Masque `RSB_MSQFrame`; Blizzard container layout is never changed.

`RothShinyBuffsDB` is account-wide and contains visual settings only. The Settings category in [`options.lua`](options.lua) writes those fields and always reapplies the core. Masque is a TOC-declared optional dependency; LibStub, CallbackHandler, and LibSharedMedia are bundled.

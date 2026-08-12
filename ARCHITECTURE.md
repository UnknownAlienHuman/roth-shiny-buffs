# Architecture

`core.lua` owns defaults, `RothShinyBuffsDB`, aura-button discovery, styling, and event-driven refresh. It can use embedded LibSharedMedia for visual assets and conditionally initializes Masque. `options.lua` builds the addon category and calls the settings-application function exposed by the core.

Embedded libraries are vendored under `libs/` and are loaded before `core.lua` and `options.lua` by the TOC. The addon changes button presentation; it does not own layout of the Blizzard aura containers.

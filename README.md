# cc_multichar

Drag-and-drop FiveM character selector for **Qbox / QBCore / ESX**.

Click a character in the scene to play as them; click an empty slot (faded random ped with a "+" on hover) to create one via your existing creator resource. No bundled spawn picker, no bundled creation UI — we hand off to your framework.

## Install

1. Drop into `resources/`.
2. Start `oxmysql` before this resource.
3. `ensure cc_multichar` in `server.cfg`.
4. Edit `config/config.lua` — at minimum: `Config.Scene.anchor`, `Config.Slots`, and `Config.Handlers.onCreateCharacter`.

## Hooks

| Hook | When | Default |
| --- | --- | --- |
| `Config.Handlers.onCharacterSelected` | After we log the player in via the framework adapter | `mode = 'framework'` — does nothing extra; your framework's spawn resource takes over via its native login event |
| `Config.Handlers.onCreateCharacter` | When an empty slot is clicked | `mode = 'event'` — fires `cc_multichar:createRequested` (server) + `cc_multichar:client:createRequested` (client) |

After your creator resource saves a new character, call `exports.cc_multichar:Reopen(src)` to bring the player back to a refreshed selector.

## Exports

| Export | Purpose |
| --- | --- |
| `exports.cc_multichar:OpenForPlayer(src)` | Open the selector for a player (use with `Config.AutoOpenOnJoin = false`) |
| `exports.cc_multichar:Reopen(src)` | Refresh the selector after a new character is saved |

# cc_multichar

A **drag-and-drop character selector** for FiveM. You see all your characters as peds in a cinematic scene. Click a character to play as them. Click an empty slot (a faded random ped with a "+" on hover) to create a new character via your framework's existing creator.

No bundled spawn picker. No bundled character creation UI. We log the player in via the framework adapter and re-fire its native login event, so your existing spawn resource (qbx_spawn, qb-spawn, esx_spawn, etc.) just works.

## Features

- Multi-framework: auto-detects Qbox / QBCore / ESX, falls back to standalone via data providers
- One ensemble cinematic scene; layout is a config function so you can place peds anywhere
- Empty slots rendered as random translucent peds with a "+" marker on hover
- Click-to-select via cursor + 3D head-projection (no fiddly raycasts, no UI to build)
- Private routing-bucket per session — other players never see your scene
- Hand-off hooks: `Config.Handlers.onCharacterSelected` and `Config.Handlers.onCreateCharacter` in `framework` / `event` / `export` modes
- Slot precedence chain: data provider → DB row → per-license config → ace tier → default
- Server-authoritative, rate-limited events, structured logger

## Install

1. Drop the resource into `resources/`.
2. Start `oxmysql` before this resource (or wire the data providers in `config/config.lua`).
3. Add to `server.cfg`:
   ```
   ensure cc_multichar
   ```
4. Edit `config/config.lua` — at minimum review `Config.Slots`, `Config.Scene.anchor`, and `Config.Handlers`.

That's it. No `npm install`, no build step.

## Configuration

Everything lives in `config/config.lua` with inline comments for every option. The five sections you'll actually edit:

| Section | What it controls |
| --- | --- |
| `Config.Slots` | How many characters each player gets (default + ace tiers + DB overrides) |
| `Config.Scene` | The cinematic scene: anchor, camera, weather, time, ped layout function |
| `Config.EmptySlot` | Random peds + opacity + "+" marker for unused slots |
| `Config.Handlers.onCharacterSelected` | What to do after a character is logged in (default: re-fire framework's native login event) |
| `Config.Handlers.onCreateCharacter` | What to do when an empty slot is clicked (default: fire `cc_multichar:createRequested` for your resource to handle) |

## Hand-off examples

**Use your existing framework spawn resource (default):**
```lua
Config.Handlers.onCharacterSelected = {
  mode = 'framework',
  framework = {
    qbox   = 'qbx_core:server:onPlayerLoaded',
    qbcore = 'QBCore:Server:OnPlayerLoaded',
    esx    = 'esx:playerLoaded',
  },
}
```

**Trigger your own spawn picker:**
```lua
-- In your spawn resource:
AddEventHandler('cc_multichar:characterSelected', function(src, character)
  exports['my_spawn_resource']:OpenPicker(src, character)
end)
```
```lua
-- In config.lua:
Config.Handlers.onCharacterSelected.mode = 'event'
```

**Open your own character creator:**
```lua
-- In your creator resource, listening for the empty-slot click:
AddEventHandler('cc_multichar:client:createRequested', function(slotIndex)
  -- Your UI for name/DOB/appearance ...
  -- When done, save the character, then:
  TriggerServerEvent('my_resource:saveCharacter', data)
end)

-- And on the server, after saving:
exports.cc_multichar:Reopen(src)  -- refreshes our selector with the new character
```

## Exports

| Export | When to call |
| --- | --- |
| `exports.cc_multichar:OpenForPlayer(src)` | Manually open the selector for a player (use when `AutoOpenOnJoin = false`) |
| `exports.cc_multichar:Reopen(src)` | After your creator resource finishes saving, refresh the selector so the new character is visible |

## Tested against

- Qbox / qbx_core
- QBCore (latest)
- ESX 1.x (with esx_multicharacter-style identifier suffixing)

For other frameworks, wire `Config.DataProviders` in `config/config.lua`.

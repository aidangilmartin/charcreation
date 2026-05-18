# cc_multichar

Cinematic multi-character selector for FiveM. Auto-detects **Qbox**, **QBCore**, and **ESX**, with a config-first setup and a React-based NUI.

## Features

- Multi-framework adapter (Qbox / QBCore / ESX / standalone via data providers)
- Cinematic random rotating scenes with live ped preview in-world
- Spawn picker (last location, apartments, static points, job points)
- Built-in name/DOB/gender/nationality create form, then hands off to an appearance editor (illenium-appearance / qb-clothing / your custom export)
- Slot count resolved from: config default → ace permission tier → per-license DB override
- Type-to-confirm character deletion
- Server-authoritative selection, rate limiting, audit logging (with optional Discord webhook)

## Install

1. Drop the resource into `resources/`.
2. Ensure `oxmysql` starts before this resource.
3. Build the React NUI:
   ```sh
   cd ui
   npm install
   npm run build
   ```
   This emits to `html/` (which `fxmanifest.lua` serves).
4. Edit `config/*.lua` to taste.
5. Add to `server.cfg`:
   ```
   ensure cc_multichar
   ```

## Configuration

| File | Purpose |
| --- | --- |
| `config/core.lua` | Framework override, slots precedence, appearance/creator exports, data provider hooks |
| `config/scenes.lua` | Cinematic scene presets (location, camera, animation, weather, time) |
| `config/spawn.lua` | Static spawn points, apartments, job spawns, last-location toggle |
| `config/ui.lua` | Theme colors, displayed fields, validation rules, text strings |
| `config/security.lua` | Rate limits, audit logging |

### Slot precedence

1. `Config.DataProviders.customGetSlotOverride(src, license)`
2. Row in `cc_multichar_slots` table (auto-created if `ensureSchemaOnStart`)
3. `Config.Slots.perLicense[license]`
4. First matching `Config.Slots.aceTiers` entry (`IsPlayerAceAllowed`)
5. `Config.Slots.default`

### Data providers

Override any of these in `config/core.lua` to support non-standard schemas:
- `customLoadCharacters(src, license)` → array of normalized characters
- `customCreateCharacter(src, license, info)` → created character row
- `customDeleteCharacter(src, license, cid)` → boolean
- `customGetLastLocation(src, cid)` → vec4
- `customGetAppearance(src, cid)` → appearance table
- `customLoginCharacter(src, character)` → custom framework login

## Exports

- `exports.cc_multichar:OpenForPlayer(src)` — open the selector for a given player.

## NUI development

Vite dev server isn't useful inside FiveM (it doesn't expose `GetParentResourceName`), so develop the UI by running `npm run build` and reloading the resource. To work on UI in a browser, mock `window.GetParentResourceName` and post messages manually.

## Tested against

- Qbox / qbx_core
- QBCore (latest)
- ESX 1.x with esx_multicharacter-style identifier suffixing

For other frameworks, wire data providers in `config/core.lua`.

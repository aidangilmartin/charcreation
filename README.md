# cc_multichar

Cinematic multicharacter selector for FiveM with automatic Qbox/QBCore detection and config-first setup.

## Highlights
- Fullscreen modern minimal NUI.
- Config-driven slots, scenarios, spawn locations, and security.
- Random immersive scenario preset on load.
- Server-issued delete token validation.
- Spawn picker hook and creator export handoff.
- Compatibility shim switch for legacy integrations.

## Config files
- `config/core.lua`
- `config/ui.lua`
- `config/spawn.lua`
- `config/scenarios.lua`
- `config/security.lua`

## Notes
This scaffold provides architecture and secure flow points. Wire DB queries and ownership checks in `server/main.lua` before production.

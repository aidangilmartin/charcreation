# cc_multichar

Cinematic multicharacter selector for FiveM with automatic Qbox/QBCore detection and config-first setup.

## Stable release checklist (v1)
- Ensure `oxmysql` is started **or** implement `Config.DataProviders.customLoadCharacters`.
- Verify `Config.Security`, `Config.Slots`, and `Config.Spawn` are valid; strict mode blocks unsafe startup.
- Set character creator export in `config/core.lua`.
- Validate spawn points and last-location handling in your DB schema.

## Runtime behavior
- Server-authoritative character selection/spawn approval.
- Token-validated character delete with ownership check (`citizenid + license`).
- Rate-limit protection and audit logging hooks.
- Cleanup on player drop and resource stop.

## Config files
- `config/core.lua`
- `config/ui.lua`
- `config/spawn.lua`
- `config/scenarios.lua`
- `config/security.lua`

## Notes
- Angular NUI is currently loaded from `esm.sh`; for full production hardening, bundle Angular locally in resource files.

# Changelog

## v2.0.0
- Stripped back to a drag-and-drop selector. No bundled UI, no React, no build step.
- One ensemble scene; characters and empty slots are rendered as peds in-world.
- Empty slots show as random reduced-alpha peds with a 3D "+" on hover.
- Click handling is server-authoritative; cursor + screen-projected head bones replace raycast hover.
- Two clean hand-off hooks: `onCharacterSelected` (default re-fires framework login) and `onCreateCharacter` (fires an event for your resource).
- Routing-bucket isolation kept so other players don't see the scene.
- Multi-framework adapter (Qbox / QBCore / ESX / standalone) kept.
- Logging simplified, single configuration file at `config/config.lua`.

## v1.0.0
- Initial full implementation with React+Vite UI, scenario engine, spawn picker, /switch, Discord presence. Superseded by v2.

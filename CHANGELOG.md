# Changelog

## v1.0.0
- Full rewrite of the resource.
- Multi-framework support: Qbox, QBCore, ESX (with custom data provider hooks for anything else).
- React + Vite NUI replacing the previous vanilla JS / Angular-CDN approach.
- Cinematic scene system with weighted-random rotation, live in-world ped preview, and appearance loading via configurable export (illenium-appearance / qb-clothing).
- Spawn picker after character select: last location, apartments, static points, job points; supports fly-to camera preview on hover.
- Built-in create form (firstname / lastname / DOB / gender / nationality), then hands off to an appearance editor.
- Type-to-confirm character deletion (replaces server-issued token flow).
- Slots resolved via precedence chain: data provider → DB override table → per-license config → ace tier → default.
- Server-authoritative state machine; rate-limited events; optional Discord audit webhook.

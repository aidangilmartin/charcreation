# Release Checklist

## Pre-deploy
- [ ] `cd ui && npm install && npm run build` produces `html/index.html` + `html/assets/*`.
- [ ] `oxmysql` is started before `cc_multichar` in `server.cfg`.
- [ ] `Config.Database.adapter` matches your install (`oxmysql` or `custom`).
- [ ] `Config.CharacterCreator` points at a real `(resource, export)` pair that opens your appearance editor.
- [ ] `Config.Scenarios.scenarios` reviewed; coordinates safe and stable.
- [ ] `Config.Spawn.staticPoints` (and optional apartments) reviewed.
- [ ] If using ESX, confirm multichar identifier-suffix convention or wire a custom data provider.

## Smoke test
- [ ] Selector opens after connect with the correct character count and slot count.
- [ ] Clicking a different scene character selects that ped (with their clothing if configured).
- [ ] Empty-slot click opens the create form; submitting hands off to the appearance editor; finishing returns to spawn picker.
- [ ] Spawn picker fly-to preview animates between options when `previewFlyTo = true`.
- [ ] Selecting a spawn fades, finalizes the framework login, and drops the player at the right coords.
- [ ] Delete with a wrong name fails; delete with the exact name removes the character and refreshes the list.
- [ ] Rate limits reject rapid spam events in `audit` output.
- [ ] Resource restart mid-selection clears NUI focus and ped preview cleanly.

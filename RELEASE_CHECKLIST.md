# Release Checklist

## Pre-deploy
- [ ] `oxmysql` starts before `cc_multichar` in `server.cfg`.
- [ ] `Config.Scene.anchor` + `camera` reviewed; camera frames all expected peds.
- [ ] `Config.Slots` values reviewed.
- [ ] `Config.Handlers.onCharacterSelected.mode` matches how you want spawn handled.
- [ ] `Config.Handlers.onCreateCharacter.mode` and your creator-resource event wired up.
- [ ] If on ESX, confirm multichar identifier-suffix convention or wire `customLoadCharacters`.

## Smoke test
- [ ] Selector opens after connect with the correct character + slot count.
- [ ] Each character ped renders with their saved appearance (if `Config.Appearance.applyToPreview = true`).
- [ ] Empty slots appear as faded random peds.
- [ ] Hovering a character ped shows their name + job; clicking logs them in.
- [ ] Hovering an empty slot shows the "+"; clicking triggers your creator.
- [ ] After click-to-play, the player ends up in-world via your framework's spawn resource.
- [ ] After click-to-create + creator-resource finishes + `exports.cc_multichar:Reopen(src)`, the selector reopens with the new character.
- [ ] Resource restart mid-selection cleans up peds and restores routing bucket 0.

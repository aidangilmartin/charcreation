local inUI = false
local sessionCharacters = {}
local sessionAppearances = {}
local introSkipThread = 0
local lastDiscordAppId = nil

local function clog(...)
  local args = { ... }
  for i = 1, #args do args[i] = tostring(args[i]) end
  Log.debug('selector', table.concat(args, ' '))
end

local function shutdownLoadscreen()
  if GetIsLoadingScreenActive and GetIsLoadingScreenActive() then
    ShutdownLoadingScreenNui()
  end
  ShutdownLoadingScreen()
end

local function applyDiscordPresence(serverName)
  local cfg = Config.Discord
  if not cfg or not cfg.enabled or not cfg.appId or cfg.appId == '' then return end
  SetDiscordAppId(cfg.appId)
  lastDiscordAppId = cfg.appId
  if cfg.largeImage and cfg.largeImage ~= '' then
    SetDiscordRichPresenceAsset(cfg.largeImage)
    if cfg.largeImageText and cfg.largeImageText ~= '' then
      SetDiscordRichPresenceAssetText(cfg.largeImageText)
    end
  end
  if cfg.smallImage and cfg.smallImage ~= '' then
    SetDiscordRichPresenceAssetSmall(cfg.smallImage)
    if cfg.smallImageText and cfg.smallImageText ~= '' then
      SetDiscordRichPresenceAssetSmallText(cfg.smallImageText)
    end
  end
  local state = cfg.text.state or 'Picking a character'
  local details = (cfg.text.details ~= '' and cfg.text.details) or serverName or ''
  SetRichPresence(details ~= '' and (details .. ' — ' .. state) or state)
end

local function clearDiscordPresence()
  if not Config.Discord or not Config.Discord.enabled or not Config.Discord.clearOnSpawn then return end
  SetRichPresence('')
end

local function startIntroSkipWatcher()
  if not Config.IntroSkip or not Config.IntroSkip.enabled then return end
  introSkipThread = introSkipThread + 1
  local thisRun = introSkipThread
  local control = Config.IntroSkip.controlId or 22
  local holdMs = Config.IntroSkip.holdMs or 600
  local hint = Config.IntroSkip.hintText
  if hint and hint ~= '' then sendUI('introHint', { text = hint }) end
  Log.debug('selector', 'intro skip watcher armed (control=%d holdMs=%d)', control, holdMs)
  CreateThread(function()
    local heldSince = nil
    -- Auto-hide hint after 8 seconds
    SetTimeout(8000, function() sendUI('introHint', { text = nil }) end)
    while inUI and thisRun == introSkipThread do
      if IsControlPressed(0, control) then
        heldSince = heldSince or GetGameTimer()
        if GetGameTimer() - heldSince >= holdMs then
          Log.info('selector', 'intro skip requested by hold')
          Scene.RequestSkipIntro()
          sendUI('introHint', { text = nil })
          return
        end
      else
        heldSince = nil
      end
      Wait(50)
    end
  end)
end

local function sendUI(action, data)
  SendNUIMessage({ action = action, data = data })
end

local function resolveScenarioById(id)
  for _, s in ipairs(Config.Scenarios.scenarios or {}) do
    if s.id == id then return s end
  end
  return Config.Scenarios.empty
end

RegisterNetEvent('cc_multichar:client:requestOpen', function()
  TriggerServerEvent('cc_multichar:server:requestOpen')
end)

RegisterNetEvent('cc_multichar:client:open', function(payload)
  Overlay.LogNetwork('in', 'client:open')
  Log.info('selector', 'open received chars=%d scenario=%s', #(payload.characters or {}), tostring(payload.scenarioId))
  shutdownLoadscreen()
  sessionCharacters = payload.characters or {}
  sessionAppearances = payload.appearances or {}

  local scenario = resolveScenarioById(payload.scenarioId)
  Scenarios.Start(scenario, sessionCharacters, sessionAppearances)
  Hover.Start()

  SetNuiFocus(true, true)
  inUI = true
  sendUI('open', payload)
  applyDiscordPresence(payload.ui and payload.ui.serverName)
  startIntroSkipWatcher()
end)

RegisterNetEvent('cc_multichar:client:deleteResult', function(result)
  if result and result.ok then
    sessionCharacters = result.characters or sessionCharacters
    -- Restart the scenario so the deleted character's ped disappears
    local scenario = Scenarios.Current() and Scenarios.Current().scenario or Config.Scenarios.empty
    Scenarios.Start(scenario, sessionCharacters, sessionAppearances)
    Hover.SetSelectedCid(nil)
  end
  sendUI('deleteResult', result)
end)

RegisterNetEvent('cc_multichar:client:createResult', function(result)
  sendUI('createResult', result)
end)

RegisterNetEvent('cc_multichar:client:openSpawnPicker', function(data)
  if not data then return end
  sendUI('spawnPicker', data)
end)

RegisterNetEvent('cc_multichar:client:spawnApproved', function(payload)
  if not payload or not payload.coords then return end
  sendUI('close', nil)
  SetNuiFocus(false, false)
  inUI = false
  introSkipThread = introSkipThread + 1
  Spawn.Finalize(payload.coords)
  clearDiscordPresence()
  if payload.character then
    TriggerEvent(Config.LoginHooks.generic.client, payload.character, payload.coords)
  end
end)

RegisterNetEvent('cc_multichar:client:switchRejected', function(reason)
  sendUI('switchRejected', { reason = reason })
end)

RegisterNetEvent('cc_multichar:client:stats', function(payload)
  sendUI('stats', payload)
end)

RegisterNUICallback('requestStats', function(data, cb)
  if data and data.cid then
    TriggerServerEvent('cc_multichar:server:requestStats', data.cid)
  end
  cb({ ok = true })
end)

RegisterNetEvent('cc_multichar:client:switchPrepare', function()
  -- Server is preparing to switch us. Just acknowledge; selector will reopen.
end)

RegisterNetEvent('cc_multichar:client:switchSafeZoneCheck', function(rules)
  local ped = PlayerPedId()
  local function fail(reason)
    TriggerServerEvent('cc_multichar:server:switchSafeZoneAck', { ok = false, reason = reason })
  end
  if rules.blockDead and IsEntityDead(ped) then return fail('dead') end
  if rules.blockInVehicle and IsPedInAnyVehicle(ped, false) then return fail('in_vehicle') end
  if rules.blockInCombat and (IsPedInCombat(ped, 0) or GetPlayerWantedLevel(PlayerId()) > 0) then return fail('in_combat') end
  if rules.blockCuffed and IsPedCuffed(ped) then return fail('cuffed') end
  if rules.blockWhileSwimming and IsPedSwimming(ped) then return fail('swimming') end
  TriggerServerEvent('cc_multichar:server:switchSafeZoneAck', { ok = true })
end)

RegisterNetEvent('cc_multichar:client:beginCreator', function(data)
  if not data or not data.resource or not data.export then return end
  SetNuiFocus(false, false)
  inUI = false
  Hover.Stop()
  Scenarios.Stop()

  -- Move the live player ped to the anchor of the (now-ended) scenario so the
  -- appearance editor has a body to customize. We're not in a scene anymore so
  -- just put them at a safe creator spot.
  local ped = PlayerPedId()
  local anchor = Config.Scenarios.empty.anchor
  SetEntityCoords(ped, anchor.x, anchor.y, anchor.z, false, false, false, false)
  SetEntityHeading(ped, anchor.w or 0.0)
  SetEntityVisible(ped, true, false)

  local invocation = Config.CharacterCreator.invocation or 'callback'

  CreateThread(function()
    local exportRef = exports[data.resource][data.export]
    if not exportRef then
      clog('appearance export not found:', data.resource, data.export)
      TriggerServerEvent('cc_multichar:server:appearanceComplete')
      return
    end

    if invocation == 'manual' then
      pcall(exportRef)
      return
    end

    if invocation == 'callback' then
      local done = false
      local ok, err = pcall(function()
        exportRef(function() done = true end)
      end)
      if not ok then clog('appearance callback failed:', err); done = true end
      while not done do Wait(100) end
    else
      local ok, err = pcall(exportRef)
      if not ok then clog('appearance blocking failed:', err) end
    end

    TriggerServerEvent('cc_multichar:server:appearanceComplete')
  end)
end)

-- NUI callbacks -----------------------------------------------------------

RegisterNUICallback('ready', function(_, cb) cb({ ok = true }) end)

RegisterNUICallback('cursor', function(data, cb)
  if data then Hover.SetCursor(data.x, data.y) end
  cb({ ok = true })
end)

RegisterNUICallback('selectClick', function(_, cb)
  local cid = Hover.HoveredCid()
  if cid then
    Hover.SetSelectedCid(cid)
    local character
    for _, c in ipairs(sessionCharacters) do
      if c.cid == cid then character = c; break end
    end
    sendUI('selected', { cid = cid, character = character })
  end
  cb({ ok = true })
end)

RegisterNUICallback('clearSelection', function(_, cb)
  Hover.SetSelectedCid(nil)
  sendUI('selected', { cid = nil })
  cb({ ok = true })
end)

RegisterNUICallback('playCharacter', function(data, cb)
  if data and data.cid then
    TriggerServerEvent('cc_multichar:server:selectCharacter', data.cid)
  end
  cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
  TriggerServerEvent('cc_multichar:server:deleteCharacter', data.cid, data.typedName)
  cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(data, cb)
  TriggerServerEvent('cc_multichar:server:createCharacter', data.info)
  cb({ ok = true })
end)

RegisterNUICallback('beginCreatorAppearance', function(_, cb)
  TriggerServerEvent('cc_multichar:server:beginCreatorAppearance')
  cb({ ok = true })
end)

RegisterNUICallback('selectSpawn', function(data, cb)
  TriggerServerEvent('cc_multichar:server:selectSpawn', data.spawnId)
  cb({ ok = true })
end)

CreateThread(function()
  if not Config.AutoOpenOnJoin then return end
  Wait(Config.AutoOpenDelayMs or 1500)
  TriggerServerEvent('cc_multichar:server:requestOpen')
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  Hover.Stop()
  Scenarios.Stop()
  SetNuiFocus(false, false)
end)

-- /switch: open a focused confirm modal; user confirms, server runs cooldown
-- + safe-zone checks; if all pass, the server re-opens the selector.
local switchConfirmOpen = false

local function openSwitchConfirm()
  if switchConfirmOpen or inUI then return end
  switchConfirmOpen = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'switchConfirm', data = {
    cooldownSeconds = Config.Switch and Config.Switch.cooldownSeconds or 60,
  } })
end

local function closeSwitchConfirm()
  switchConfirmOpen = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'switchConfirmClose' })
end

RegisterCommand(Config.Switch and Config.Switch.command or 'switch', function()
  if not Config.Switch or not Config.Switch.enabled then return end
  openSwitchConfirm()
end, false)

RegisterNUICallback('confirmSwitch', function(_, cb)
  closeSwitchConfirm()
  TriggerServerEvent('cc_multichar:server:requestSwitch')
  cb({ ok = true })
end)

RegisterNUICallback('cancelSwitch', function(_, cb)
  closeSwitchConfirm()
  cb({ ok = true })
end)

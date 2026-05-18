local inUI = false
local sessionCharacters = {}
local sessionAppearances = {}

local function clog(...)
  if not Config.Debug then return end
  local args = { ... }
  for i = 1, #args do args[i] = tostring(args[i]) end
  print(('[cc_multichar][client] %s'):format(table.concat(args, ' ')))
end

local function shutdownLoadscreen()
  if GetIsLoadingScreenActive and GetIsLoadingScreenActive() then
    ShutdownLoadingScreenNui()
  end
  ShutdownLoadingScreen()
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
  shutdownLoadscreen()
  sessionCharacters = payload.characters or {}
  sessionAppearances = payload.appearances or {}

  local scenario = resolveScenarioById(payload.scenarioId)
  Scenarios.Start(scenario, sessionCharacters, sessionAppearances)
  Hover.Start()

  SetNuiFocus(true, true)
  inUI = true
  sendUI('open', payload)
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
  Spawn.Finalize(payload.coords)
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

local inUI = false
local sessionCharacters = {}

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

local function openSelectorWithScene(payload)
  shutdownLoadscreen()
  sessionCharacters = payload.characters or {}
  Scene.Setup()
  -- Pick a sensible default preview ped
  local first = sessionCharacters[1]
  if first then
    Preview.Spawn(first.gender, nil)
    TriggerServerEvent('cc_multichar:server:requestPreview', first.cid)
  else
    Preview.Spawn('m', nil)
  end
  SetNuiFocus(true, true)
  inUI = true
  sendUI('open', payload)
end

RegisterNetEvent('cc_multichar:client:requestOpen', function()
  TriggerServerEvent('cc_multichar:server:requestOpen')
end)

RegisterNetEvent('cc_multichar:client:open', openSelectorWithScene)

RegisterNetEvent('cc_multichar:client:applyPreview', function(data)
  if not inUI or not data then return end
  Preview.Spawn(data.gender or 'm', data.appearance)
end)

RegisterNetEvent('cc_multichar:client:deleteResult', function(result)
  if result and result.ok then
    sessionCharacters = result.characters or sessionCharacters
  end
  sendUI('deleteResult', result)
end)

RegisterNetEvent('cc_multichar:client:createResult', function(result)
  if result and result.ok and result.character then
    sessionCharacters[#sessionCharacters + 1] = result.character
    Preview.Spawn(result.character.gender or 'm', nil)
  end
  sendUI('createResult', result)
end)

RegisterNetEvent('cc_multichar:client:openSpawnPicker', function(data)
  if not data then return end
  if data.character then
    Preview.Spawn(data.character.gender or 'm', data.appearance)
  end
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
  Preview.Clear()
  -- Move the live player ped to the scene position so the appearance editor
  -- has a body to work on.
  local scene = Scene.Active()
  if scene then
    local ped = PlayerPedId()
    SetEntityCoords(ped, scene.ped.x, scene.ped.y, scene.ped.z, false, false, false, false)
    SetEntityHeading(ped, scene.ped.w)
    SetEntityVisible(ped, true, false)
  end

  local invocation = Config.CharacterCreator.invocation or 'callback'

  CreateThread(function()
    local exportRef = exports[data.resource][data.export]
    if not exportRef then
      clog('appearance export not found:', data.resource, data.export)
      TriggerServerEvent('cc_multichar:server:appearanceComplete')
      return
    end

    if invocation == 'manual' then
      -- Caller will trigger FinishAppearance themselves.
      pcall(exportRef)
      return
    end

    if invocation == 'callback' then
      local done = false
      local ok, err = pcall(function()
        exportRef(function() done = true end)
      end)
      if not ok then
        clog('appearance callback export failed:', err)
        done = true
      end
      while not done do Wait(100) end
    else
      local ok, err = pcall(exportRef)
      if not ok then clog('appearance blocking export failed:', err) end
    end

    TriggerServerEvent('cc_multichar:server:appearanceComplete')
  end)
end)

RegisterNUICallback('ready', function(_, cb) cb({ ok = true }) end)

RegisterNUICallback('selectCharacter', function(data, cb)
  TriggerServerEvent('cc_multichar:server:selectCharacter', data.cid)
  cb({ ok = true })
end)

RegisterNUICallback('previewCharacter', function(data, cb)
  TriggerServerEvent('cc_multichar:server:requestPreview', data.cid)
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

RegisterNUICallback('previewSpawn', function(data, cb)
  if data and data.coords and Config.Spawn.previewFlyTo then
    Scene.FlyTo(data.coords, Config.Spawn.previewFlyDurationMs)
  end
  cb({ ok = true })
end)

CreateThread(function()
  if not Config.AutoOpenOnJoin then return end
  Wait(Config.AutoOpenDelayMs or 1500)
  TriggerServerEvent('cc_multichar:server:requestOpen')
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  Preview.Clear()
  Scene.Teardown()
  SetNuiFocus(false, false)
end)

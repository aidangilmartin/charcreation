local inUI = false


local function shutdownLoadscreen()
  if GetIsLoadingScreenActive and GetIsLoadingScreenActive() then
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
  else
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
  end
end

local function loadAnim(dict)
  if not HasAnimDictLoaded(dict) then
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
  end
end

local function playScenePreset()
  local presets = Config.Scene.presets
  if not presets or #presets == 0 then return end
  local preset = presets[math.random(1, #presets)]

  DoScreenFadeOut(250)
  while not IsScreenFadedOut() do Wait(0) end

  local c = preset.interior.coords
  RequestCollisionAtCoord(c.x, c.y, c.z)
  SetEntityCoords(PlayerPedId(), c.x, c.y, c.z)
  FreezeEntityPosition(PlayerPedId(), true)
  SetEntityVisible(PlayerPedId(), false, false)

  NetworkOverrideClockTime(preset.time.hour, preset.time.minute, 0)
  SetWeatherTypeNowPersist(preset.weather)

  local camPos = preset.interior.cam
  local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, preset.interior.heading, 60.0, false, 0)
  PointCamAtCoord(cam, c.x, c.y, c.z)
  SetCamActive(cam, true)
  RenderScriptCams(true, true, 500, true, true)

  local ped = PlayerPedId()
  local anim = preset.scenario.playerAnims[math.random(1, #preset.scenario.playerAnims)]
  loadAnim(anim.dict)
  TaskPlayAnim(ped, anim.dict, anim.name, 4.0, 4.0, -1, 1, 0.0, false, false, false)

  DoScreenFadeIn(450)
end

RegisterNetEvent('cc_multichar:client:requestOpen', function()
  TriggerServerEvent('cc_multichar:server:open')
end)

RegisterNetEvent('cc_multichar:client:open', function(payload)
  shutdownLoadscreen()
  playScenePreset()
  SetNuiFocus(true, true)
  inUI = true
  SendNUIMessage({ action = 'open', payload = payload, ui = Config.UI })
end)

RegisterNetEvent('cc_multichar:client:openSpawnPicker', function(data)
  local options = data and data.options or {}
  SendNUIMessage({ action = 'spawnPicker', options = options, previewFlyTo = data and data.previewFlyTo })
end)

RegisterNetEvent('cc_multichar:client:spawnApproved', function(selected)
  local c = selected and selected.coords
  if c then
    DoScreenFadeOut(250)
    while not IsScreenFadedOut() do Wait(0) end
    SetEntityVisible(PlayerPedId(), true, false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityCoords(PlayerPedId(), c.x, c.y, c.z)
    SetEntityHeading(PlayerPedId(), c.w or 0.0)
    RenderScriptCams(false, true, 500, true, true)
    DoScreenFadeIn(350)
  end
end)

RegisterNetEvent('cc_multichar:client:beginCreator', function(resource, exportName)
  local ok, err = pcall(function()
    exports[resource][exportName]()
  end)
  if not ok and Config.Debug then
    print(('Creator export failed: %s'):format(err))
  end
end)

RegisterNUICallback('selectCharacter', function(data, cb)
  TriggerServerEvent('cc_multichar:server:selectCharacter', data.cid)
  cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
  TriggerServerEvent('cc_multichar:server:deleteCharacter', data.cid, data.token)
  cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(_, cb)
  TriggerServerEvent('cc_multichar:server:beginCreate')
  cb({ ok = true })
end)

RegisterNUICallback('selectSpawn', function(data, cb)
  TriggerServerEvent('cc_multichar:server:selectSpawn', data.spawnId)
  cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb)
  SetNuiFocus(false, false)
  inUI = false
  cb({ ok = true })
end)

CreateThread(function()
  Wait(2000)
  TriggerServerEvent('cc_multichar:server:open')
end)

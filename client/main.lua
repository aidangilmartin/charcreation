-- Client main: NUI focus, event bridge, click handler.

local inUI = false

local function openSelector(payload)
  if inUI then return end
  inUI = true

  Hover.SetCharacters(payload.characters or {})
  Scene.Begin()
  PedSetup.Start(payload.characters or {}, payload.appearances or {}, payload.slots or 0)
  Hover.Start()

  -- NUI focus shows the cursor (the HTML page itself is just a click catcher).
  -- SetNuiFocus(hasFocus, hasCursor)
  SetNuiFocus(true, true)
  -- Tell the page to start forwarding clicks.
  SendNUIMessage({ action = 'open' })

  Log.info('selector', 'opened chars=%d slots=%d',
           #(payload.characters or {}), payload.slots or 0)
end

local function closeSelector()
  if not inUI then return end
  inUI = false

  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })

  Hover.Stop()
  PedSetup.Stop()
  Scene.End()

  Log.debug('selector', 'closed')
end

-- Server -> client events --------------------------------------------------

RegisterNetEvent('cc_multichar:client:open', function(payload)
  openSelector(payload)
end)

RegisterNetEvent('cc_multichar:client:close', function(_)
  closeSelector()
end)

-- NUI -> client callbacks --------------------------------------------------

-- The minimal HTML page calls this when the body is clicked. Lua decides
-- what was clicked based on the currently-hovered ped.
RegisterNUICallback('click', function(_, cb)
  cb({ ok = true })
  if not inUI then return end
  local ped = Hover.HoveredPed()
  if not ped or not DoesEntityExist(ped) then return end

  if PedSetup.IsEmptySlot(ped) then
    local slot = PedSetup.SlotIndexFor(ped)
    Log.info('selector', 'click empty slot %s', tostring(slot))
    TriggerServerEvent('cc_multichar:server:createCharacter', slot)
  else
    local cid = PedSetup.PedToCid(ped)
    if cid then
      Log.info('selector', 'click character cid=%s', tostring(cid))
      TriggerServerEvent('cc_multichar:server:selectCharacter', cid)
    end
  end
end)

RegisterNUICallback('ready', function(_, cb) cb({ ok = true }) end)

-- Auto-open shortly after spawn ---------------------------------------------

CreateThread(function()
  if not Config.AutoOpenOnJoin then return end
  Wait(Config.AutoOpenDelayMs or 1500)
  TriggerServerEvent('cc_multichar:server:requestOpen')
end)

-- Clean up on resource stop ------------------------------------------------

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  closeSelector()
end)

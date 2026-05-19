local Sessions, Rate = {}, {}
local ServerReady = false

local STATE = { IDLE = 'idle', SELECTING = 'selecting', FINISHED = 'finished' }

local function audit(event, src, message)
  Log.warn('security', '[%s] src=%s msg=%s', event, tostring(src), tostring(message))
end

local function nowMs() return GetGameTimer() end

local function eventAllowed(src, name)
  local cfg = Config.Security.rateLimit
  local ev = cfg.byEvent[name] or {}
  local window = ev.windowMs or cfg.windowMs
  local maxCalls = ev.maxCalls or cfg.maxCalls
  Rate[src] = Rate[src] or {}
  local slot = Rate[src][name]
  local t = nowMs()
  if not slot or t - slot.s > window then
    Rate[src][name] = { s = t, c = 1 }
    return true
  end
  slot.c = slot.c + 1
  if slot.c > maxCalls then audit('rate_limit', src, name); return false end
  return true
end

local function ensureSession(src)
  if Sessions[src] then return Sessions[src] end
  local adapter = CC.Adapter()
  local license = adapter and adapter.getIdentifier(src)
  Sessions[src] = { src = src, license = license, state = STATE.IDLE, characters = {} }
  return Sessions[src]
end

local function buildAppearancesFor(src, characters)
  local out = {}
  for _, c in ipairs(characters) do
    local a = Characters.GetAppearance(src, c.cid)
    if a then out[c.cid] = a end
  end
  return out
end

local function findCharacter(session, cid)
  for i = 1, #(session.characters or {}) do
    if tostring(session.characters[i].cid) == tostring(cid) then return session.characters[i] end
  end
end

local function openSelector(src)
  if not ServerReady then audit('blocked', src, 'server not ready'); return end
  local s = ensureSession(src)
  if Config.Security.requireAuthenticatedSession and not s.license then
    audit('blocked', src, 'no license identifier'); return
  end

  s.state = STATE.SELECTING
  s.characters = Characters.Load(src, s.license) or {}
  local slots = Slots.For(src, s.license)
  local appearances = buildAppearancesFor(src, s.characters)
  local bucket = Instance.Enter(src)

  Log.info('selector', 'open src=%s chars=%d slots=%d bucket=%s',
           src, #s.characters, slots, tostring(bucket))

  TriggerClientEvent('cc_multichar:client:open', src, {
    characters  = s.characters,
    appearances = appearances,
    slots       = slots,
  })
end

-- Lifecycle ----------------------------------------------------------------

local function startCheck()
  Log.info('resource', 'starting cc_multichar v2.0.0')
  if Config.Database.adapter == 'oxmysql' and not DB.Available() then
    Log.warn('db', 'oxmysql is not started — character data will not load until it is')
  end
  DB.EnsureSchema()
  Log.info('framework', 'detected: %s', CC.DetectFramework())
  ServerReady = true
end

AddEventHandler('onResourceStart', function(res)
  if res == GetCurrentResourceName() then startCheck() end
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then Sessions, Rate = {}, {} end
end)

AddEventHandler('playerDropped', function()
  Sessions[source], Rate[source] = nil, nil
end)

-- Events from the client ---------------------------------------------------

RegisterNetEvent('cc_multichar:server:requestOpen', function()
  local src = source
  if not eventAllowed(src, 'open') then return end
  openSelector(src)
end)

RegisterNetEvent('cc_multichar:server:selectCharacter', function(cid)
  local src = source
  if not eventAllowed(src, 'selectCharacter') then return end
  local s = ensureSession(src)
  if s.state ~= STATE.SELECTING then return end

  local char = findCharacter(s, cid)
  if not char then audit('invalid_cid', src, cid); return end

  -- 1. Log the character in via the framework adapter
  local adapter = CC.Adapter()
  local handled = false
  if type(Config.DataProviders.customLoginCharacter) == 'function' then
    local ok, ret = pcall(Config.DataProviders.customLoginCharacter, src, char)
    if ok and ret then handled = true end
  end
  if not handled then adapter.login(src, char.cid) end

  -- 2. Release routing bucket before the spawn happens
  Instance.Leave(src)
  s.state = STATE.FINISHED

  -- 3. Tell the client to tear down the scene and exit NUI focus
  TriggerClientEvent('cc_multichar:client:close', src, { character = char })

  -- 4. Hand off to the user's spawn flow.
  --    mode='framework' is a no-op: adapter.login() already fired the
  --    framework's native login event, which the framework's own spawn
  --    resource is listening for. Doing anything more would double-fire.
  local h = Config.Handlers.onCharacterSelected
  if h.mode == 'event' then
    TriggerEvent(h.event, src, char)
    if h.clientEvent and h.clientEvent ~= '' then
      TriggerClientEvent(h.clientEvent, src, char)
    end
  elseif h.mode == 'export' and h.export.resource ~= '' and h.export.name ~= '' then
    local ok, err = pcall(function() exports[h.export.resource][h.export.name](src, char) end)
    if not ok then Log.error('selector', 'export call failed: %s', err) end
  end
end)

RegisterNetEvent('cc_multichar:server:createCharacter', function(slotIndex)
  local src = source
  if not eventAllowed(src, 'createCharacter') then return end
  local s = ensureSession(src)
  if s.state ~= STATE.SELECTING then return end

  -- Slot bounds check
  local slots = Slots.For(src, s.license)
  if (#(s.characters or {})) >= slots then
    audit('slots_full', src, slotIndex)
    return
  end

  Log.info('selector', 'create requested src=%s slot=%s', src, tostring(slotIndex))

  -- Release the player from the bucket and tell the client to tear down
  -- the scene so the framework's creator UI runs in the main world.
  Instance.Leave(src)
  s.state = STATE.IDLE
  TriggerClientEvent('cc_multichar:client:close', src, {})

  local h = Config.Handlers.onCreateCharacter
  if h.mode == 'framework' then
    local fw = CC.DetectFramework()
    local evt = h.framework[fw]
    if evt and evt ~= '' then
      Log.info('selector', 'firing framework creator event %s', evt)
      TriggerClientEvent(evt, src, slotIndex)
    end
  elseif h.mode == 'event' then
    TriggerEvent(h.event, src, slotIndex)
    if h.clientEvent and h.clientEvent ~= '' then
      TriggerClientEvent(h.clientEvent, src, slotIndex)
    end
  elseif h.mode == 'export' and h.export.resource ~= '' and h.export.name ~= '' then
    local ok, err = pcall(function() exports[h.export.resource][h.export.name](src, slotIndex) end)
    if not ok then Log.error('selector', 'export call failed: %s', err) end
  end
end)

-- Public exports -----------------------------------------------------------

-- Open the selector for a specific player. Useful for queue/whitelist flows
-- that disable AutoOpenOnJoin and trigger us manually.
exports('OpenForPlayer', function(src) openSelector(src) end)

-- After your creator resource finishes saving a new character, call this to
-- bring the player back to the selector with the new character visible.
exports('Reopen', function(src) openSelector(src) end)


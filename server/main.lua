local Sessions, Rate = {}, {}
local ServerReady = false

-- State machine.
--   IDLE       : no selector open
--   SELECTING  : selector is open; awaiting click
--   PROCESSING : a click is in flight (login / handoff in progress)
--   FINISHED   : character is logged in; player is in-world
local STATE = {
  IDLE       = 'idle',
  SELECTING  = 'selecting',
  PROCESSING = 'processing',
  FINISHED   = 'finished',
}

local function audit(event, src, message)
  Log.warn('security', '[%s] src=%s msg=%s', event, tostring(src), tostring(message))
end

-- =========================================================================
-- Validation primitives
-- =========================================================================

local function isLicense(id)
  return type(id) == 'string' and id:sub(1, 8) == 'license:' and #id <= 96
end

local function isCidString(v)
  if type(v) ~= 'string' then return false end
  if #v == 0 or #v > 64 then return false end
  -- Allow alphanumerics, dashes, colons, underscores.
  return v:match('^[%w%-:_]+$') ~= nil
end

local function isInteger(v) return type(v) == 'number' and v == math.floor(v) end

-- =========================================================================
-- Rate limiting
-- =========================================================================

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
  if slot.c > maxCalls then
    audit('rate_limit', src, name)
    return false
  end
  return true
end

-- =========================================================================
-- Sessions
-- =========================================================================

local function ensureSession(src)
  if Sessions[src] then return Sessions[src] end
  local adapter = CC.Adapter()
  local license = adapter and adapter.getIdentifier(src)
  Sessions[src] = {
    src = src,
    license = license,
    state = STATE.IDLE,
    characters = {},
    slots = 0,
  }
  return Sessions[src]
end

local function findCharacter(session, cid)
  for i = 1, #(session.characters or {}) do
    if tostring(session.characters[i].cid) == cid then
      return session.characters[i]
    end
  end
end

-- =========================================================================
-- Auth / state gate (call at the top of every player-driven event)
-- =========================================================================

local function gate(src, eventName, requiredState)
  if not ServerReady then audit('blocked', src, 'server not ready'); return nil end
  if not eventAllowed(src, eventName) then return nil end
  local s = ensureSession(src)
  if Config.Security.requireAuthenticatedSession and not isLicense(s.license) then
    audit('blocked', src, 'no license identifier')
    return nil
  end
  if requiredState and s.state ~= requiredState then
    audit('bad_state', src, ('event=%s state=%s want=%s'):format(eventName, s.state, requiredState))
    return nil
  end
  return s
end

-- =========================================================================
-- Open / build payload
-- =========================================================================

local function buildAppearancesFor(src, characters)
  local out = {}
  for _, c in ipairs(characters) do
    local a = Characters.GetAppearance(src, c.cid)
    if a then out[c.cid] = a end
  end
  return out
end

local function openSelector(src)
  if not ServerReady then audit('blocked', src, 'server not ready'); return end
  local s = ensureSession(src)
  if Config.Security.requireAuthenticatedSession and not isLicense(s.license) then
    audit('blocked', src, 'no license identifier'); return
  end
  -- Only IDLE or FINISHED players may open. PROCESSING/SELECTING are mid-flow.
  if s.state ~= STATE.IDLE and s.state ~= STATE.FINISHED then
    audit('open_blocked', src, 'state=' .. s.state); return
  end

  s.state = STATE.SELECTING
  s.characters = Characters.Load(src, s.license) or {}

  -- Resolve slots and clamp at hardMax so a tier misconfig can't blow up
  -- the scene with 9999 peds.
  local slots = Slots.For(src, s.license)
  local hardMax = Config.Slots.hardMax or 12
  if slots > hardMax then slots = hardMax end
  -- If a player somehow has more existing characters than the slot count,
  -- show all of them.
  if #s.characters > slots then slots = #s.characters end
  s.slots = slots

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

-- =========================================================================
-- Lifecycle
-- =========================================================================

local function startCheck()
  Log.info('resource', 'starting cc_multichar')
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

-- =========================================================================
-- Client -> server events
-- =========================================================================

RegisterNetEvent('cc_multichar:server:requestOpen', function()
  local src = source
  if not ServerReady then audit('blocked', src, 'server not ready'); return end
  if not eventAllowed(src, 'open') then return end
  openSelector(src)
end)

RegisterNetEvent('cc_multichar:server:selectCharacter', function(rawCid)
  local src = source
  if type(rawCid) ~= 'string' or not isCidString(rawCid) then
    audit('bad_arg', src, 'selectCharacter cid not a valid string'); return
  end

  local s = gate(src, 'selectCharacter', STATE.SELECTING)
  if not s then return end

  local char = findCharacter(s, rawCid)
  if not char then audit('invalid_cid', src, rawCid); return end

  -- Lock the session before any awaits so a second concurrent event from the
  -- same source can't re-enter login.
  s.state = STATE.PROCESSING

  local handled = false
  if type(Config.DataProviders.customLoginCharacter) == 'function' then
    local ok, ret = pcall(Config.DataProviders.customLoginCharacter, src, char)
    if ok and ret then handled = true end
  end
  if not handled then
    local adapter = CC.Adapter()
    if adapter and adapter.login then
      local ok, err = pcall(adapter.login, src, char.cid)
      if not ok then
        Log.error('framework', 'adapter login failed: %s', tostring(err))
        s.state = STATE.SELECTING -- allow retry
        audit('login_failed', src, char.cid)
        return
      end
    end
  end

  Instance.Leave(src)
  s.state = STATE.FINISHED
  TriggerClientEvent('cc_multichar:client:close', src, {})

  local h = Config.Handlers.onCharacterSelected
  if h.mode == 'event' then
    TriggerEvent(h.event, src, char)
    if h.clientEvent and h.clientEvent ~= '' then
      TriggerClientEvent(h.clientEvent, src, char)
    end
  elseif h.mode == 'export' and h.export.resource ~= '' and h.export.name ~= '' then
    local ok, err = pcall(function()
      exports[h.export.resource][h.export.name](src, char)
    end)
    if not ok then Log.error('selector', 'export call failed: %s', tostring(err)) end
  end
end)

RegisterNetEvent('cc_multichar:server:createCharacter', function(rawSlot)
  local src = source

  -- Slot index must be a positive integer.
  if not isInteger(rawSlot) or rawSlot < 1 then
    audit('bad_arg', src, 'createCharacter slot not a positive integer'); return
  end

  local s = gate(src, 'createCharacter', STATE.SELECTING)
  if not s then return end

  -- Slot must be an EMPTY slot: above the number of existing characters but
  -- within the configured slot count.
  if rawSlot <= #s.characters or rawSlot > s.slots then
    audit('invalid_slot', src, ('slot=%d chars=%d slots=%d'):format(rawSlot, #s.characters, s.slots))
    return
  end

  Log.info('selector', 'create requested src=%s slot=%d', src, rawSlot)

  s.state = STATE.PROCESSING
  Instance.Leave(src)
  s.state = STATE.IDLE
  TriggerClientEvent('cc_multichar:client:close', src, {})

  local h = Config.Handlers.onCreateCharacter
  if h.mode == 'event' then
    TriggerEvent(h.event, src, rawSlot)
    if h.clientEvent and h.clientEvent ~= '' then
      TriggerClientEvent(h.clientEvent, src, rawSlot)
    end
  elseif h.mode == 'export' and h.export.resource ~= '' and h.export.name ~= '' then
    local ok, err = pcall(function()
      exports[h.export.resource][h.export.name](src, rawSlot)
    end)
    if not ok then Log.error('selector', 'export call failed: %s', tostring(err)) end
  end
end)

-- =========================================================================
-- Exports
-- =========================================================================

exports('OpenForPlayer', function(src)
  if type(src) ~= 'number' then return end
  openSelector(src)
end)

exports('Reopen', function(src)
  if type(src) ~= 'number' then return end
  -- Force-reset state so a re-open after creation works even if the previous
  -- flow left state in an unexpected place.
  if Sessions[src] then Sessions[src].state = STATE.IDLE end
  openSelector(src)
end)

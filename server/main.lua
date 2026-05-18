local Sessions, Rate = {}, {}
local ServerReady = false

local STATE = {
  IDLE         = 'idle',
  SELECTING    = 'selecting',
  CREATING     = 'creating',
  SPAWN_SELECT = 'spawn_select',
  FINISHED     = 'finished',
}

local function dlog(...)
  if not Config.Debug then return end
  local args = { ... }
  for i = 1, #args do args[i] = tostring(args[i]) end
  print(('[cc_multichar][server] %s'):format(table.concat(args, ' ')))
end

local function audit(event, src, message)
  local cfg = Config.Security and Config.Security.audit
  if not cfg or not cfg.enabled then return end
  local line = ('[cc_multichar][%s] src=%s msg=%s'):format(event, tostring(src), tostring(message))
  if cfg.print then print(line) end
  if cfg.webhook and cfg.webhook ~= '' then
    PerformHttpRequest(cfg.webhook, function() end, 'POST',
      json.encode({ content = line }),
      { ['Content-Type'] = 'application/json' })
  end
end

local function ensureSession(src)
  local s = Sessions[src]
  if s then return s end
  local license = CC.Adapter().getIdentifier(src)
  s = {
    src = src,
    license = license,
    state = STATE.IDLE,
    characters = {},
    allowedSpawns = {},
    selectedCid = nil,
    pendingCharacter = nil,
  }
  Sessions[src] = s
  return s
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
  if slot.c > maxCalls then
    audit('rate_limit', src, name)
    return false
  end
  return true
end

local function startCheck()
  if Config.Database.adapter == 'oxmysql' and not DB.Available() then
    print('^3[cc_multichar] oxmysql is not started — character data will not load until it is.^0')
  end
  DB.EnsureSchema()
  ServerReady = true
  dlog('ready framework=' .. CC.DetectFramework())
end

local function buildSpawnOptions(session, character)
  local options = {}
  for _, p in ipairs(Config.Spawn.staticPoints or {}) do
    options[#options + 1] = {
      id = 'static:' .. tostring(p.id),
      label = p.label,
      description = p.description,
      kind = 'static',
      coords = p.coords,
    }
  end

  local jobPoints = (Config.Spawn.jobPoints or {})[character and character.job and character.job:lower() or '']
  if jobPoints then
    for _, p in ipairs(jobPoints) do
      options[#options + 1] = {
        id = 'job:' .. tostring(p.id),
        label = p.label,
        description = p.description,
        kind = 'job',
        coords = p.coords,
      }
    end
  end

  if type(Config.Spawn.customApartmentResolver) == 'function' then
    local ok, resolved = pcall(Config.Spawn.customApartmentResolver, session.src, character)
    if ok and type(resolved) == 'table' then
      for _, p in ipairs(resolved) do
        options[#options + 1] = {
          id = 'apt:' .. tostring(p.id),
          label = p.label,
          description = p.description,
          kind = 'apartment',
          coords = p.coords,
        }
      end
    end
  else
    for _, p in ipairs(Config.Spawn.apartmentPoints or {}) do
      options[#options + 1] = {
        id = 'apt:' .. tostring(p.id),
        label = p.label,
        description = p.description,
        kind = 'apartment',
        coords = p.coords,
      }
    end
  end

  if Config.Spawn.includeLastLocation then
    local last = Characters.GetLastLocation(session.src, character.cid)
    if last then
      table.insert(options, 1, {
        id = 'last',
        label = 'Last Location',
        description = 'Where you logged off',
        kind = 'last',
        coords = last,
      })
    end
  end

  session.allowedSpawns = options
  return options
end

local function pickScenarioId(characterCount)
  local pool = Config.Scenarios.scenarios or {}
  if characterCount == 0 then
    return (Config.Scenarios.empty and Config.Scenarios.empty.id) or 'empty_intro'
  end
  -- Filter by min/maxChars
  local candidates = {}
  for _, s in ipairs(pool) do
    local min = s.minChars or 1
    local max = s.maxChars or 8
    if characterCount >= min and characterCount <= max then
      candidates[#candidates + 1] = s
    end
  end
  if #candidates == 0 then
    return (Config.Scenarios.empty and Config.Scenarios.empty.id) or 'empty_intro'
  end
  -- Weighted random
  local total = 0
  for _, s in ipairs(candidates) do total = total + (s.weight or 1) end
  local roll = math.random() * total
  local acc = 0
  for _, s in ipairs(candidates) do
    acc = acc + (s.weight or 1)
    if roll <= acc then return s.id end
  end
  return candidates[#candidates].id
end

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
  if Config.Security.requireAuthenticatedSession and not s.license then
    audit('blocked', src, 'no license identifier')
    return
  end
  s.state = STATE.SELECTING
  local characters = Characters.Load(src, s.license) or {}
  s.characters = characters
  local slots = Slots.For(src, s.license)
  local scenarioId = pickScenarioId(#characters)
  local appearances = buildAppearancesFor(src, characters)
  dlog('open src=' .. src .. ' chars=' .. #characters .. ' slots=' .. slots .. ' scenario=' .. scenarioId)
  TriggerClientEvent('cc_multichar:client:open', src, {
    framework = CC.DetectFramework(),
    characters = characters,
    appearances = appearances,
    slots = slots,
    scenarioId = scenarioId,
    ui = Config.UI,
    sceneTimings = Config.SceneTimings,
  })
end

AddEventHandler('onResourceStart', function(res)
  if res ~= GetCurrentResourceName() then return end
  startCheck()
end)

AddEventHandler('onResourceStop', function(res)
  if res == GetCurrentResourceName() then
    Sessions, Rate = {}, {}
  end
end)

AddEventHandler('playerDropped', function()
  local src = source
  Sessions[src], Rate[src] = nil, nil
end)

RegisterNetEvent('cc_multichar:server:requestOpen', function()
  local src = source
  if not eventAllowed(src, 'open') then return end
  openSelector(src)
end)

-- Look up a character on the server (don't trust client-supplied data).
local function findCharacterByCid(session, cid)
  for i = 1, #(session.characters or {}) do
    if tostring(session.characters[i].cid) == tostring(cid) then
      return session.characters[i]
    end
  end
  if session.pendingCharacter and tostring(session.pendingCharacter.cid) == tostring(cid) then
    return session.pendingCharacter
  end
end

RegisterNetEvent('cc_multichar:server:selectCharacter', function(cid)
  local src = source
  if not eventAllowed(src, 'selectCharacter') then return end
  local s = ensureSession(src)
  if s.state ~= STATE.SELECTING then return end

  local char = findCharacterByCid(s, cid)
  if not char then
    audit('invalid_cid', src, cid)
    return
  end

  s.selectedCid = tostring(cid)
  s.state = STATE.SPAWN_SELECT
  local options = buildSpawnOptions(s, char)
  if #options == 0 then
    audit('no_spawns', src, 'no options')
    return
  end

  local appearance = Characters.GetAppearance(src, char.cid)
  TriggerClientEvent('cc_multichar:client:openSpawnPicker', src, {
    character = char,
    appearance = appearance,
    options = options,
    previewFlyTo = Config.Spawn.previewFlyTo,
    previewFlyDurationMs = Config.Spawn.previewFlyDurationMs,
  })
end)

RegisterNetEvent('cc_multichar:server:selectSpawn', function(spawnId)
  local src = source
  if not eventAllowed(src, 'selectSpawn') then return end
  local s = ensureSession(src)
  if s.state ~= STATE.SPAWN_SELECT then return end

  local selected
  for i = 1, #s.allowedSpawns do
    if s.allowedSpawns[i].id == spawnId then selected = s.allowedSpawns[i]; break end
  end
  if not selected then
    audit('invalid_spawn', src, spawnId)
    return
  end

  local char = findCharacterByCid(s, s.selectedCid)
  if not char then return end

  -- Hand the character to the framework
  local adapter = CC.Adapter()
  if char._seed then
    adapter.login(src, nil, char._seed)
  else
    adapter.login(src, char.cid)
  end

  s.state = STATE.FINISHED
  TriggerClientEvent('cc_multichar:client:spawnApproved', src, {
    coords = selected.coords,
    character = char,
  })
end)

RegisterNetEvent('cc_multichar:server:deleteCharacter', function(cid, typedName)
  local src = source
  if not eventAllowed(src, 'deleteCharacter') then return end
  if not Config.Security.allowDelete then return end

  local s = ensureSession(src)
  if s.state ~= STATE.SELECTING then return end

  local char = findCharacterByCid(s, cid)
  if not char then audit('invalid_cid', src, cid); return end

  if tostring(typedName or ''):lower() ~= tostring(char.name or ''):lower() then
    audit('delete_name_mismatch', src, ('cid=%s typed=%s'):format(tostring(cid), tostring(typedName)))
    TriggerClientEvent('cc_multichar:client:deleteResult', src, { ok = false, reason = 'name_mismatch' })
    return
  end

  local ok = Characters.Delete(src, s.license, char.cid)
  if not ok then
    audit('delete_failed', src, cid)
    TriggerClientEvent('cc_multichar:client:deleteResult', src, { ok = false, reason = 'db_error' })
    return
  end

  -- Refresh
  s.characters = Characters.Load(src, s.license) or {}
  audit('delete_ok', src, cid)
  TriggerClientEvent('cc_multichar:client:deleteResult', src, {
    ok = true,
    cid = char.cid,
    characters = s.characters,
  })
end)

RegisterNetEvent('cc_multichar:server:createCharacter', function(info)
  local src = source
  if not eventAllowed(src, 'createCharacter') then return end
  local s = ensureSession(src)
  if s.state ~= STATE.SELECTING then return end

  if type(info) ~= 'table' then return end
  local v = Config.UI.validation
  local function isStr(x) return type(x) == 'string' end
  local function trim(x) return (x:gsub('^%s+', ''):gsub('%s+$', '')) end

  if not isStr(info.firstname) or not isStr(info.lastname) then return end
  info.firstname = trim(info.firstname)
  info.lastname = trim(info.lastname)
  if #info.firstname < v.minNameLength or #info.firstname > v.maxNameLength then return end
  if #info.lastname  < v.minNameLength or #info.lastname  > v.maxNameLength then return end
  if not isStr(info.dob) or not info.dob:match('^%d%d%d%d%-%d%d%-%d%d$') then return end
  if info.gender ~= 'm' and info.gender ~= 'f' then return end

  -- Slot check
  local slots = Slots.For(src, s.license)
  if #(s.characters or {}) >= slots then
    TriggerClientEvent('cc_multichar:client:createResult', src, { ok = false, reason = 'slots_full' })
    return
  end

  local created = Characters.Create(src, s.license, info)
  if not created then
    TriggerClientEvent('cc_multichar:client:createResult', src, { ok = false, reason = 'create_failed' })
    return
  end

  s.pendingCharacter = created
  s.state = STATE.CREATING
  s.selectedCid = created.cid

  audit('create_ok', src, created.cid)
  TriggerClientEvent('cc_multichar:client:createResult', src, { ok = true, character = created })
end)

RegisterNetEvent('cc_multichar:server:beginCreatorAppearance', function()
  local src = source
  if not eventAllowed(src, 'beginCreator') then return end
  local s = ensureSession(src)
  if s.state ~= STATE.CREATING or not s.pendingCharacter then return end
  TriggerClientEvent('cc_multichar:client:beginCreator', src, {
    resource = Config.CharacterCreator.resource,
    export = Config.CharacterCreator.export,
    character = s.pendingCharacter,
  })
end)

RegisterNetEvent('cc_multichar:server:appearanceComplete', function()
  local src = source
  local s = ensureSession(src)
  if s.state ~= STATE.CREATING or not s.pendingCharacter then return end
  -- After appearance, go to spawn select
  s.state = STATE.SPAWN_SELECT
  s.characters[#s.characters + 1] = s.pendingCharacter
  local options = buildSpawnOptions(s, s.pendingCharacter)
  TriggerClientEvent('cc_multichar:client:openSpawnPicker', src, {
    character = s.pendingCharacter,
    options = options,
    previewFlyTo = Config.Spawn.previewFlyTo,
    previewFlyDurationMs = Config.Spawn.previewFlyDurationMs,
  })
end)

exports('OpenForPlayer', function(src)
  TriggerClientEvent('cc_multichar:client:requestOpen', src)
end)

-- For "manual" invocation appearance editors: call this from your editor
-- when the player is done customizing.
exports('FinishAppearance', function(src)
  local s = ensureSession(src)
  if s.state == STATE.CREATING and s.pendingCharacter then
    TriggerEvent('cc_multichar:server:appearanceComplete', src)
    -- Run inline so we get the right `source`.
    s.state = STATE.SPAWN_SELECT
    s.characters[#s.characters + 1] = s.pendingCharacter
    local options = buildSpawnOptions(s, s.pendingCharacter)
    TriggerClientEvent('cc_multichar:client:openSpawnPicker', src, {
      character = s.pendingCharacter,
      options = options,
      previewFlyTo = Config.Spawn.previewFlyTo,
      previewFlyDurationMs = Config.Spawn.previewFlyDurationMs,
    })
  end
end)

local Sessions, Rate = {}, {}
local ServerReady = true

local function nowMs() return GetGameTimer() end

local function dlog(msg)
  if Config.Debug then
    print(('[cc_multichar][debug] %s'):format(tostring(msg)))
  end
end

local function audit(event, src, message)
  local cfg = Config.Security and Config.Security.audit
  if not cfg or not cfg.enabled then return end
  local payload = ('[cc_multichar][%s] src=%s msg=%s'):format(event, tostring(src), tostring(message))
  if cfg.print then print(payload) end
end

local function randomToken(len)
  local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  local out = {}
  for i = 1, len do
    local idx = math.random(1, #chars)
    out[i] = chars:sub(idx, idx)
  end
  return table.concat(out)
end

local function hasDb()
  return Config.Database.adapter == 'oxmysql' and GetResourceState('oxmysql') == 'started'
end

local function strictFail(msg)
  ServerReady = false
  print(('^1[cc_multichar] %s^0'):format(msg))
end

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
  if slot.c > maxCalls then audit('rate_limit', src, name) end
  return slot.c <= maxCalls
end

local function ensureSession(src)
  local id = CC.GetIdentifier(src)
  Sessions[src] = Sessions[src] or { identifier = id, state = 'idle', deleteToken = nil, deleteTokenExpiry = 0, selectedCid = nil, allowedSpawns = {}, characters = {} }
  return Sessions[src]
end

local function validateConfig()
  if type(Config.Security) ~= 'table' or type(Config.Spawn) ~= 'table' or type(Config.Slots) ~= 'table' then
    strictFail('Missing Security/Spawn/Slots config tables')
    return
  end
  if type(Config.Slots.default) ~= 'number' or Config.Slots.default < 1 then strictFail('Config.Slots.default must be >= 1') end
  if type(Config.Security.tokenLength) ~= 'number' or Config.Security.tokenLength < 4 then strictFail('Config.Security.tokenLength must be >= 4') end
  if type(Config.Spawn.staticPoints) ~= 'table' then strictFail('Config.Spawn.staticPoints must be a table') end
  for i, p in ipairs(Config.Spawn.staticPoints) do
    if not p.id or not p.label or not p.coords then strictFail(('Invalid spawn point at index %d'):format(i)) break end
  end
  if Config.Release.strictMode and Config.Database.adapter == 'oxmysql' and not hasDb() and type(Config.DataProviders.customLoadCharacters) ~= 'function' then
    strictFail('oxmysql adapter selected but oxmysql resource is not started and no custom loader is provided')
  end
end

local function query(sql, params)
  if not hasDb() then return nil end
  return MySQL.query.await(sql, params or {})
end
local function scalar(sql, params)
  if not hasDb() then return nil end
  return MySQL.scalar.await(sql, params or {})
end
local function execute(sql, params)
  if not hasDb() then return 0 end
  return MySQL.update.await(sql, params or {}) or 0
end

local function buildCharacters(src)
  local s = ensureSession(src)
  dlog(('open requested src=%s state=%s id=%s'):format(src, tostring(s.state), tostring(s.identifier)))
  if type(Config.DataProviders.customLoadCharacters) == 'function' then
    return Config.DataProviders.customLoadCharacters(src, s.identifier) or {}
  end
  local rows = query('SELECT citizenid, charinfo, money, job, metadata FROM players WHERE license = ? ORDER BY last_updated DESC', { s.identifier }) or {}
  local out = {}
  for i=1,#rows do
    local r = rows[i]
    local charinfo = type(r.charinfo) == 'string' and json.decode(r.charinfo) or (r.charinfo or {})
    local money = type(r.money) == 'string' and json.decode(r.money) or (r.money or {})
    local job = type(r.job) == 'string' and json.decode(r.job) or (r.job or {})
    local metadata = type(r.metadata) == 'string' and json.decode(r.metadata) or (r.metadata or {})
    out[#out+1] = { cid=tostring(r.citizenid), name=((charinfo.firstname or 'Unknown')..' '..(charinfo.lastname or 'Citizen')), dob=charinfo.birthdate or 'Unknown', gender=charinfo.gender or 'Unknown', nationality=charinfo.nationality or 'Unknown', job=job.name or 'unemployed', bank=tonumber(money.bank) or 0, cash=tonumber(money.cash) or 0, playtime=tonumber(metadata.playtime) or 0 }
  end
  return out
end

local function buildSpawnOptions(session)
  local options = {}
  for _,p in ipairs(Config.Spawn.staticPoints or {}) do
    options[#options+1] = { id=tostring(p.id), label=tostring(p.label), coords=p.coords, kind='static' }
  end
  if Config.Spawn.includeLastLocation then
    options[#options+1] = { id='last', label='Last Location', kind='last', dynamic=true }
  end
  session.allowedSpawns = options
  return options
end

local function getLastLocation(cid)
  if type(Config.DataProviders.customGetLastLocation) == 'function' then return Config.DataProviders.customGetLastLocation(nil, cid) end
  local posJson = scalar('SELECT position FROM players WHERE citizenid = ? LIMIT 1', { cid })
  if type(posJson) ~= 'string' then return nil end
  local ok, pos = pcall(json.decode, posJson)
  if not ok or type(pos) ~= 'table' then return nil end
  if pos.x and pos.y and pos.z then return vec4(pos.x+0.0,pos.y+0.0,pos.z+0.0,pos.w and (pos.w+0.0) or 0.0) end
  return nil
end

AddEventHandler('onResourceStart', function(res) if res == GetCurrentResourceName() then validateConfig() end end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then Sessions, Rate = {}, {} end end)
AddEventHandler('playerDropped', function() Sessions[source], Rate[source] = nil, nil end)

RegisterNetEvent('cc_multichar:server:open', function()
  local src = source
  if not ServerReady then audit('blocked',src,'server not ready'); return end
  if not eventAllowed(src, 'open') then return end
  local s = ensureSession(src)
  if Config.Security.requireAuthenticatedSession and not s.identifier then return end
  s.deleteToken = randomToken(Config.Security.tokenLength)
  s.deleteTokenExpiry = os.time() + Config.Security.tokenTTLSeconds
  s.state = 'selecting'
  local characters = buildCharacters(src)
  dlog(('open built characters src=%s count=%s'):format(src, #characters))
  s.characters = characters
  TriggerClientEvent('cc_multichar:client:open', src, { framework=CC.DetectFramework(), token=s.deleteToken, characters=characters, slots=Config.Slots.default })
end)

RegisterNetEvent('cc_multichar:server:selectCharacter', function(cid)
  local src = source
  if not ServerReady or not eventAllowed(src,'selectCharacter') then return end
  local s = ensureSession(src); if s.state ~= 'selecting' then dlog(('selectCharacter blocked bad state src=%s state=%s'):format(src, tostring(s.state))); return end
  local chars = s.characters or {}
  if #chars == 0 then
    chars = buildCharacters(src)
    s.characters = chars
  end
  local found = false
  for i=1,#chars do if tostring(chars[i].cid)==tostring(cid) then found=true break end end
  if not found then dlog(('selectCharacter cid not found src=%s cid=%s cached=%s'):format(src, tostring(cid), #chars)); audit('invalid_cid',src,cid); return end
  s.selectedCid = tostring(cid); s.state='spawn_select'
  local options = buildSpawnOptions(s)
  dlog(('selectCharacter spawn options src=%s count=%s'):format(src, #options))
  if #options == 0 then audit('no_spawns', src, 'no spawn options configured'); return end
  TriggerClientEvent('cc_multichar:client:openSpawnPicker', src, { options=options, previewFlyTo=Config.Spawn.previewFlyTo })
end)

RegisterNetEvent('cc_multichar:server:selectSpawn', function(spawnId)
  local src = source
  if not ServerReady or not eventAllowed(src,'selectSpawn') then return end
  local s = ensureSession(src); if s.state ~= 'spawn_select' then dlog(('selectSpawn blocked bad state src=%s state=%s'):format(src, tostring(s.state))); return end
  local selected
  for i=1,#s.allowedSpawns do if s.allowedSpawns[i].id == spawnId then selected=s.allowedSpawns[i] break end end
  if not selected then dlog(('selectSpawn invalid src=%s spawnId=%s allowed=%s'):format(src, tostring(spawnId), #s.allowedSpawns)); audit('invalid_spawn',src,spawnId); return end
  if selected.id == 'last' then local loc = getLastLocation(s.selectedCid); if not loc then dlog(('selectSpawn last location missing src=%s cid=%s'):format(src, tostring(s.selectedCid))); return end; selected = { id='last', label='Last Location', coords=loc, kind='last' } end
  s.state='finished'; dlog(('spawn approved src=%s spawn=%s'):format(src, tostring(selected.id))); TriggerClientEvent('cc_multichar:client:spawnApproved', src, selected)
end)

RegisterNetEvent('cc_multichar:server:deleteCharacter', function(cid, token)
  local src = source
  if not ServerReady or not eventAllowed(src,'deleteCharacter') then return end
  local s = ensureSession(src); if s.state ~= 'selecting' then dlog(('delete blocked bad state src=%s state=%s'):format(src, tostring(s.state))); return end
  if tostring(token or '') ~= tostring(s.deleteToken or '') or os.time() > s.deleteTokenExpiry then dlog(('delete token fail src=%s cid=%s supplied=%s expected=%s expiry=%s now=%s'):format(src, tostring(cid), tostring(token), tostring(s.deleteToken), tostring(s.deleteTokenExpiry), tostring(os.time()))); audit('token_fail',src,cid); return end
  local ok = false
  if type(Config.DataProviders.customDeleteCharacter) == 'function' then ok = Config.DataProviders.customDeleteCharacter(src, s.identifier, tostring(cid)) == true
  else ok = execute('DELETE FROM players WHERE citizenid = ? AND license = ?', { tostring(cid), s.identifier }) > 0 end
  if not ok then dlog(('delete failed src=%s cid=%s id=%s'):format(src, tostring(cid), tostring(s.identifier))); audit('delete_fail',src,cid); return end
  s.deleteToken=nil; s.deleteTokenExpiry=0
  dlog(('delete success src=%s cid=%s'):format(src, tostring(cid)))
  TriggerClientEvent('cc_multichar:client:deletedCharacter', src, tostring(cid))
end)

RegisterNetEvent('cc_multichar:server:beginCreate', function()
  local src = source
  if not ServerReady or not eventAllowed(src,'beginCreate') then return end
  local s = ensureSession(src); if s.state ~= 'selecting' then return end
  local c = Config.CharacterCreation.export
  if c and c.resource and c.name then TriggerClientEvent('cc_multichar:client:beginCreator', src, c.resource, c.name) end
end)

exports('OpenForPlayer', function(src) TriggerClientEvent('cc_multichar:client:requestOpen', src) end)

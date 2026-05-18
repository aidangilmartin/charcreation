local Sessions = {}

local function randomToken(len)
  local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  local out = {}
  for i = 1, len do
    local idx = math.random(1, #chars)
    out[#out+1] = chars:sub(idx, idx)
  end
  return table.concat(out)
end

local function ensureSession(src)
  Sessions[src] = Sessions[src] or {
    authenticated = true,
    deleteToken = nil,
    deleteTokenExpiry = 0,
    selectedCid = nil,
  }
  return Sessions[src]
end

AddEventHandler('playerDropped', function()
  Sessions[source] = nil
end)

lib = lib or {}

RegisterNetEvent('cc_multichar:server:open', function()
  local src = source
  local s = ensureSession(src)
  if Config.Security.requireAuthenticatedSession and not s.authenticated then return end

  local token = randomToken(Config.Security.tokenLength)
  s.deleteToken = token
  s.deleteTokenExpiry = os.time() + Config.Security.tokenTTLSeconds

  -- Placeholder character payload; replace with DB adapter.
  local payload = {
    framework = CC.DetectFramework(),
    token = token,
    characters = {}
  }

  TriggerClientEvent('cc_multichar:client:open', src, payload)
end)

RegisterNetEvent('cc_multichar:server:deleteCharacter', function(cid, providedToken)
  local src = source
  local s = ensureSession(src)
  if not Config.Security.allowDelete then return end
  if type(cid) ~= 'string' and type(cid) ~= 'number' then return end
  if not s.deleteToken or os.time() > s.deleteTokenExpiry then return end
  if tostring(providedToken or '') ~= tostring(s.deleteToken) then return end

  -- TODO: server-side ownership check + DB delete
  s.deleteToken = nil
  TriggerClientEvent('cc_multichar:client:deletedCharacter', src, cid)
end)

RegisterNetEvent('cc_multichar:server:selectCharacter', function(cid)
  local src = source
  local s = ensureSession(src)
  if type(cid) ~= 'string' and type(cid) ~= 'number' then return end

  s.selectedCid = cid
  TriggerClientEvent('cc_multichar:client:openSpawnPicker', src)
end)

RegisterNetEvent('cc_multichar:server:beginCreate', function()
  local src = source
  local creator = Config.CharacterCreation.export
  if creator and creator.resource and creator.name then
    TriggerClientEvent('cc_multichar:client:beginCreator', src, creator.resource, creator.name)
  end
end)

exports('OpenForPlayer', function(src)
  TriggerClientEvent('cc_multichar:client:requestOpen', src)
end)

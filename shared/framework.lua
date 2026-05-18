-- Framework detection and a small adapter so the rest of the resource
-- doesn't care which framework is loaded. Most data calls are server-only;
-- on the client we just expose detect().

CC = CC or {}

local detected

local function isStarted(res)
  return GetResourceState(res) == 'started'
end

function CC.DetectFramework()
  if detected then return detected end
  local override = Config and Config.Framework
  if override and override ~= 'auto' then
    detected = override
    return detected
  end
  if isStarted('qbx_core') then
    detected = 'qbox'
  elseif isStarted('qb-core') then
    detected = 'qbcore'
  elseif isStarted('es_extended') then
    detected = 'esx'
  else
    detected = 'standalone'
  end
  return detected
end

function CC.IsServer()
  return IsDuplicityVersion and IsDuplicityVersion()
end

-- Server-only adapter. Loaded lazily so the client side doesn't try to require
-- server-only resources.
if CC.IsServer() then
  local adapter

  local function loadAdapter()
    local fw = CC.DetectFramework()
    if fw == 'qbox' then
      adapter = {
        name = 'qbox',
        getIdentifier = function(src)
          local p = exports.qbx_core:GetPlayer(src)
          if p and p.PlayerData then return p.PlayerData.license end
          for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            if id:sub(1, 8) == 'license:' then return id end
          end
        end,
        login = function(src, citizenid, newData)
          -- qbx_core fires player:setCardId via Login
          return exports.qbx_core:Login(src, citizenid, newData)
        end,
        logout = function(src) return exports.qbx_core:Logout(src) end,
      }
    elseif fw == 'qbcore' then
      local QBCore = exports['qb-core']:GetCoreObject()
      adapter = {
        name = 'qbcore',
        core = QBCore,
        getIdentifier = function(src)
          for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            if id:sub(1, 8) == 'license:' then return id end
          end
        end,
        login = function(src, citizenid, newData)
          if citizenid then
            return QBCore.Player.Login(src, citizenid)
          end
          return QBCore.Player.Login(src, false, newData)
        end,
        logout = function(src)
          local p = QBCore.Functions.GetPlayer(src)
          if p then p.Functions.Save() end
        end,
      }
    elseif fw == 'esx' then
      local ESX = exports['es_extended']:getSharedObject()
      adapter = {
        name = 'esx',
        core = ESX,
        getIdentifier = function(src)
          for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            if id:sub(1, 8) == 'license:' then return id end
          end
        end,
        login = function(src, citizenid)
          -- ESX multichar implementations use identifier suffixing.
          -- Real login is handled by your ESX multichar resource via event.
          TriggerEvent('esx:onPlayerJoined', src, citizenid)
        end,
        logout = function(src)
          local xPlayer = ESX.GetPlayerFromId(src)
          if xPlayer then ESX.SavePlayer(xPlayer) end
        end,
      }
    else
      adapter = {
        name = 'standalone',
        getIdentifier = function(src)
          for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
            if id:sub(1, 8) == 'license:' then return id end
          end
        end,
        login = function(_, _, _) end,
        logout = function(_) end,
      }
    end
    return adapter
  end

  function CC.Adapter()
    if not adapter then loadAdapter() end
    return adapter
  end
end

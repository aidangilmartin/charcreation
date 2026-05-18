CC = CC or {}

local frameworkName

function CC.DetectFramework()
  if Config.Framework and Config.Framework ~= 'auto' then return Config.Framework end
  if frameworkName then return frameworkName end

  if GetResourceState('qbx_core') == 'started' then
    frameworkName = 'qbox'
  elseif GetResourceState('qb-core') == 'started' then
    frameworkName = 'qbcore'
  else
    frameworkName = 'unknown'
  end
  return frameworkName
end

function CC.GetCoreObject()
  local fw = CC.DetectFramework()
  if fw == 'qbcore' then
    return exports['qb-core']:GetCoreObject()
  end
  return nil
end

function CC.GetIdentifier(src)
  local ids = GetPlayerIdentifiers(src)
  for i = 1, #ids do
    if ids[i]:find('license:') == 1 then return ids[i] end
  end
  return ids[1]
end

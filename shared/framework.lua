CC = CC or {}

function CC.DetectFramework()
  if Config.Framework and Config.Framework ~= 'auto' then return Config.Framework end

  if GetResourceState('qbx_core') == 'started' then return 'qbox' end
  if GetResourceState('qb-core') == 'started' then return 'qbcore' end
  return 'unknown'
end

function CC.GetFrameworkObject()
  local fw = CC.DetectFramework()
  if fw == 'qbox' then
    return exports.qbx_core
  elseif fw == 'qbcore' then
    return exports['qb-core']:GetCoreObject()
  end
end

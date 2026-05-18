-- Per-session routing bucket isolation.
--
-- When a player opens the selector we move them into a dedicated routing
-- bucket so:
--   - Other players can't see the cinematic scene (peds, vehicles, props).
--   - Other players can't see the (invisible) player ped on the radar.
--   - World population in the player's bucket is suppressed so ambient cars
--     don't drive through the police chase / robbery / etc.
-- On spawn we move them back to bucket 0 before the client teleport.

Instance = Instance or {}

local sessions = {} -- src -> { bucket = N, original = N }
local nextBucketId = nil

local function ensureNextBucket()
  if nextBucketId then return end
  local cfg = Config.RoutingBucket
  nextBucketId = (cfg and cfg.bucketOffset) or 100000
end

-- Configure a freshly-assigned bucket according to user config.
local function applyBucketSettings(bucket)
  local cfg = Config.RoutingBucket or {}
  if cfg.populationEnabled == false then
    SetRoutingBucketPopulationEnabled(bucket, false)
  else
    SetRoutingBucketPopulationEnabled(bucket, true)
  end
  if cfg.entityLockdown and cfg.entityLockdown ~= '' then
    -- 'strict' | 'relaxed' | 'inactive'
    SetRoutingBucketEntityLockdownMode(bucket, cfg.entityLockdown)
  end
end

function Instance.Enter(src)
  if not Config.RoutingBucket or not Config.RoutingBucket.enabled then
    Log.debug('session', 'routing bucket isolation disabled; src=%s stays in current bucket', src)
    return nil
  end
  ensureNextBucket()
  local existing = sessions[src]
  if existing then
    Log.debug('session', 'src=%s already in bucket %d', src, existing.bucket)
    return existing.bucket
  end

  local original = GetPlayerRoutingBucket(src) or 0
  local bucket = nextBucketId
  nextBucketId = nextBucketId + 1

  applyBucketSettings(bucket)
  SetPlayerRoutingBucket(src, bucket)
  sessions[src] = { bucket = bucket, original = original }
  Log.info('session', 'src=%s entered selector bucket=%d (was %d)', src, bucket, original)
  return bucket
end

function Instance.Leave(src)
  local s = sessions[src]
  if not s then return end
  local target = (Config.RoutingBucket and Config.RoutingBucket.restoreToBucketOnSpawn) or 0
  SetPlayerRoutingBucket(src, target)
  Log.info('session', 'src=%s left selector bucket=%d -> %d', src, s.bucket, target)
  sessions[src] = nil
end

function Instance.Current(src)
  local s = sessions[src]
  return s and s.bucket or nil
end

-- Cleanup on disconnect / resource stop.
AddEventHandler('playerDropped', function()
  local src = source
  if sessions[src] then
    Log.debug('session', 'src=%s dropped while in bucket=%d', src, sessions[src].bucket)
    sessions[src] = nil
  end
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for src, s in pairs(sessions) do
    SetPlayerRoutingBucket(src, 0)
    Log.debug('session', 'resource stopping; src=%s restored to bucket 0 (was %d)', src, s.bucket)
  end
  sessions = {}
end)

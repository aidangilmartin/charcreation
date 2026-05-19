-- Per-session routing-bucket isolation.
-- Other players cannot see the cinematic scene; ambient world traffic is
-- suppressed in the bucket.

Instance = Instance or {}

local sessions = {}
local nextBucketId

local function nextBucket()
  if not nextBucketId then
    nextBucketId = (Config.RoutingBucket and Config.RoutingBucket.bucketOffset) or 100000
  end
  local id = nextBucketId
  nextBucketId = nextBucketId + 1
  return id
end

function Instance.Enter(src)
  if not Config.RoutingBucket or not Config.RoutingBucket.enabled then return nil end
  if sessions[src] then return sessions[src].bucket end

  local original = GetPlayerRoutingBucket(src) or 0
  local bucket = nextBucket()

  if Config.RoutingBucket.populationEnabled == false then
    SetRoutingBucketPopulationEnabled(bucket, false)
  end
  if Config.RoutingBucket.entityLockdown and Config.RoutingBucket.entityLockdown ~= '' then
    SetRoutingBucketEntityLockdownMode(bucket, Config.RoutingBucket.entityLockdown)
  end
  SetPlayerRoutingBucket(src, bucket)

  sessions[src] = { bucket = bucket, original = original }
  Log.info('session', 'src=%s -> bucket=%d (was %d)', src, bucket, original)
  return bucket
end

function Instance.Leave(src)
  local s = sessions[src]
  if not s then return end
  local target = (Config.RoutingBucket and Config.RoutingBucket.restoreToBucketOnSpawn) or 0
  SetPlayerRoutingBucket(src, target)
  Log.info('session', 'src=%s bucket %d -> %d', src, s.bucket, target)
  sessions[src] = nil
end

AddEventHandler('playerDropped', function() sessions[source] = nil end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  for src, _ in pairs(sessions) do SetPlayerRoutingBucket(src, 0) end
  sessions = {}
end)

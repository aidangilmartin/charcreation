Spawn = Spawn or {}

local previewThread = 0

local function normalizeCoords(coords)
  if not coords or not coords.x or not coords.y or not coords.z then return nil end
  return {
    x = coords.x + 0.0,
    y = coords.y + 0.0,
    z = coords.z + 0.0,
    w = (coords.w or coords.heading or 0.0) + 0.0,
  }
end

local function previewCameraTarget(coords)
  local heading = math.rad((coords.w or 0.0) + 180.0)
  local distance = 28.0
  local height = 16.0
  return vector3(
    coords.x + math.sin(heading) * distance,
    coords.y + math.cos(heading) * distance,
    coords.z + height
  ), vector3(coords.x, coords.y, coords.z + 1.2)
end

function Spawn.Preview(coords, durationMs)
  if not (Config.Spawn and Config.Spawn.previewFlyTo) then return end
  local cam = Scene.ActiveCam()
  if not cam then return end

  local targetCoords = normalizeCoords(coords)
  if not targetCoords then return end

  previewThread = previewThread + 1
  local thisRun = previewThread
  local from = GetCamCoord(cam)
  local to, lookAt = previewCameraTarget(targetCoords)
  local duration = math.max(tonumber(durationMs) or Config.Spawn.previewFlyDurationMs or 1200, 1)
  local startTime = GetGameTimer()

  RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)

  CreateThread(function()
    while Scene.ActiveCam() == cam and thisRun == previewThread do
      local elapsed = GetGameTimer() - startTime
      local t = math.min(elapsed / duration, 1.0)
      local eased = 1.0 - ((1.0 - t) * (1.0 - t))

      SetCamCoord(
        cam,
        from.x + (to.x - from.x) * eased,
        from.y + (to.y - from.y) * eased,
        from.z + (to.z - from.z) * eased
      )
      PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)

      if t >= 1.0 then break end
      Wait(0)
    end
  end)
end

function Spawn.Finalize(coords)
  previewThread = previewThread + 1
  DoScreenFadeOut(Config.SceneTimings.spawnFadeOutMs)
  while not IsScreenFadedOut() do Wait(0) end

  Hover.Stop()
  Scenarios.Stop()

  Scene.ShowPlayerPed(coords)

  Wait(250)
  DoScreenFadeIn(Config.SceneTimings.spawnFadeInMs)
end

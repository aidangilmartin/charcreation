-- Scene management: scripted camera + weather + time + fades.

Scene = Scene or {}

local activeCam
local active = false

local function destroyCam()
  if activeCam then
    DestroyCam(activeCam, true)
    activeCam = nil
  end
end

function Scene.IsActive() return active end
function Scene.Cam() return activeCam end

local function hidePlayerPed()
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetPlayerControl(PlayerId(), false, 0)
  SetEntityVisible(ped, false, false)
  SetEntityCollision(ped, false, false)
end

local function showPlayerPed()
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  SetPlayerControl(PlayerId(), true, 0)
  SetEntityVisible(ped, true, false)
  SetEntityCollision(ped, true, true)
end

function Scene.Begin()
  if active then Scene.End() end
  active = true

  DoScreenFadeOut(Config.Scene.fadeOutMs)
  while not IsScreenFadedOut() do Wait(0) end

  -- Ambient
  NetworkOverrideClockTime(Config.Scene.hour, Config.Scene.minute, 0)
  SetWeatherTypePersist(Config.Scene.weather)
  SetWeatherTypeNow(Config.Scene.weather)
  SetWeatherTypeNowPersist(Config.Scene.weather)

  -- Move the player to the anchor, hide them
  hidePlayerPed()
  local a = Config.Scene.anchor
  RequestCollisionAtCoord(a.x, a.y, a.z)
  SetEntityCoords(PlayerPedId(), a.x, a.y, a.z, false, false, false, false)

  -- Camera
  destroyCam()
  local c = Config.Scene.camera
  activeCam = CreateCamWithParams(
    'DEFAULT_SCRIPTED_CAMERA',
    c.position.x, c.position.y, c.position.z,
    0.0, 0.0, 0.0, c.fov or 40.0, false, 0
  )
  PointCamAtCoord(activeCam, c.lookAt.x, c.lookAt.y, c.lookAt.z)
  SetCamActive(activeCam, true)
  RenderScriptCams(true, false, 0, true, true)

  -- Suppress HUD while active
  CreateThread(function()
    while active do
      HideHudAndRadarThisFrame()
      Wait(0)
    end
  end)

  Wait(150)
  DoScreenFadeIn(Config.Scene.fadeInMs)

  Log.debug('scene', 'began')
end

function Scene.End()
  if not active then return end
  active = false
  destroyCam()
  RenderScriptCams(false, false, 0, true, true)
  ClearOverrideWeather()
  ClearWeatherTypePersist()
  NetworkClearClockTimeOverride()
  showPlayerPed()
  Log.debug('scene', 'ended')
end

-- Camera-space helpers used by the hover module.
function Scene.WorldToScreen(world)
  -- GetScreenCoordFromWorldCoord returns onScreen, x, y in 0..1 range.
  local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
  return onScreen, x, y
end

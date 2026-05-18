Scene = Scene or {}

local activeCam
local activeScene
local sequenceIndex = 0

local function pickScene()
  local scenes = Config.Scenes.scenes
  if not scenes or #scenes == 0 then return nil end
  local strategy = Config.Scenes.pickStrategy or 'weighted-random'

  if strategy == 'fixed' then
    return scenes[Config.Scenes.fixedIndex] or scenes[1]
  end

  if strategy == 'sequential' then
    sequenceIndex = (sequenceIndex % #scenes) + 1
    return scenes[sequenceIndex]
  end

  -- Weighted random
  local total = 0
  for _, s in ipairs(scenes) do total = total + (s.weight or 1) end
  local roll = math.random() * total
  local acc = 0
  for _, s in ipairs(scenes) do
    acc = acc + (s.weight or 1)
    if roll <= acc then return s end
  end
  return scenes[#scenes]
end

local function loadAnimDict(dict)
  if not dict then return end
  if HasAnimDictLoaded(dict) then return end
  RequestAnimDict(dict)
  local deadline = GetGameTimer() + 5000
  while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
end

function Scene.Active() return activeScene end

function Scene.Setup()
  local scene = pickScene()
  if not scene then return nil end

  DoScreenFadeOut(Config.SceneTimings.fadeOutMs)
  while not IsScreenFadedOut() do Wait(0) end

  local ped = PlayerPedId()
  RequestCollisionAtCoord(scene.ped.x, scene.ped.y, scene.ped.z)
  SetEntityCoords(ped, scene.ped.x, scene.ped.y, scene.ped.z, false, false, false, false)
  SetEntityHeading(ped, scene.ped.w)
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetPlayerControl(PlayerId(), false, 0)
  SetEntityVisible(ped, false, false)

  NetworkOverrideClockTime(scene.hour, scene.minute, 0)
  SetWeatherTypePersist(scene.weather)
  SetWeatherTypeNow(scene.weather)
  SetWeatherTypeNowPersist(scene.weather)

  if activeCam then
    DestroyCam(activeCam, true)
    activeCam = nil
  end

  local cam = scene.camera
  activeCam = CreateCamWithParams(
    'DEFAULT_SCRIPTED_CAMERA',
    cam.position.x, cam.position.y, cam.position.z,
    0.0, 0.0, 0.0, cam.fov or 40.0, false, 0
  )
  PointCamAtCoord(activeCam, cam.lookAt.x, cam.lookAt.y, cam.lookAt.z)
  SetCamActive(activeCam, true)
  RenderScriptCams(true, false, 0, true, true)

  if scene.animation then
    loadAnimDict(scene.animation.dict)
  end

  HideHudAndRadarThisFrame()
  CreateThread(function()
    while activeScene do
      HideHudAndRadarThisFrame()
      Wait(0)
    end
  end)

  activeScene = scene
  Wait(150)
  DoScreenFadeIn(Config.SceneTimings.fadeInMs)
  return scene
end

function Scene.PlayPedAnimation(ped)
  if not activeScene or not activeScene.animation then return end
  loadAnimDict(activeScene.animation.dict)
  TaskPlayAnim(ped, activeScene.animation.dict, activeScene.animation.name,
    4.0, -4.0, -1, 1, 0.0, false, false, false)
end

function Scene.FlyTo(target, durationMs)
  if not activeCam or not target then return end
  local newCam = CreateCamWithParams(
    'DEFAULT_SCRIPTED_CAMERA',
    target.x, target.y, target.z + 12.0,
    -20.0, 0.0, 0.0, 50.0, false, 0
  )
  PointCamAtCoord(newCam, target.x, target.y, target.z)
  SetCamActiveWithInterp(newCam, activeCam, durationMs or 1200, 1, 1)
  Wait(durationMs or 1200)
  DestroyCam(activeCam, true)
  activeCam = newCam
end

function Scene.Teardown()
  if activeCam then
    DestroyCam(activeCam, true)
    activeCam = nil
  end
  RenderScriptCams(false, false, 0, true, true)
  ClearOverrideWeather()
  ClearWeatherTypePersist()
  NetworkClearClockTimeOverride()
  activeScene = nil
end

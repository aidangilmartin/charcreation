Scene = Scene or {}

local activeCam
local activeScenario
local timelineThread = 0
local activeAudioScene = nil
local soundLoopThread = 0
local skipIntroRequested = false

local function destroyCam()
  if activeCam then
    DestroyCam(activeCam, true)
    activeCam = nil
  end
end

function Scene.ActiveCam() return activeCam end
function Scene.ActiveScenario() return activeScenario end

function Scene.SetAmbient(scenario)
  NetworkOverrideClockTime(scenario.hour or 12, scenario.minute or 0, 0)
  SetWeatherTypePersist(scenario.weather or 'CLEAR')
  SetWeatherTypeNow(scenario.weather or 'CLEAR')
  SetWeatherTypeNowPersist(scenario.weather or 'CLEAR')
  Scene.StartAmbientAudio(scenario)
end

function Scene.StartAmbientAudio(scenario)
  Scene.StopAmbientAudio()
  local ambient = scenario.ambient
  if not ambient then return end

  if ambient.audioScene and ambient.audioScene ~= '' then
    StartAudioScene(ambient.audioScene)
    activeAudioScene = ambient.audioScene
  end

  if ambient.sounds and #ambient.sounds > 0 then
    soundLoopThread = soundLoopThread + 1
    local thisRun = soundLoopThread
    local anchor = scenario.anchor
    local anyLoop = false
    for _, s in ipairs(ambient.sounds) do if s.loop then anyLoop = true; break end end
    CreateThread(function()
      repeat
        for _, s in ipairs(ambient.sounds) do
          if not (activeScenario and thisRun == soundLoopThread) then return end
          local id = GetSoundId()
          PlaySoundFromCoord(id, s.name, anchor.x, anchor.y, anchor.z, s.set, false, 0, false)
          Wait(s.intervalMs or 4000)
          StopSound(id)
          ReleaseSoundId(id)
        end
      until not anyLoop or not (activeScenario and thisRun == soundLoopThread)
    end)
  end
end

function Scene.StopAmbientAudio()
  if activeAudioScene then
    StopAudioScene(activeAudioScene)
    activeAudioScene = nil
  end
  soundLoopThread = soundLoopThread + 1
end

function Scene.HidePlayerPed()
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  SetEntityInvincible(ped, true)
  SetPlayerControl(PlayerId(), false, 0)
  SetEntityVisible(ped, false, false)
  SetEntityCollision(ped, false, false)
end

function Scene.ShowPlayerPed(coords)
  local ped = PlayerPedId()
  if coords then
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
  end
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  SetPlayerControl(PlayerId(), true, 0)
  SetEntityVisible(ped, true, false)
  SetEntityCollision(ped, true, true)
end

function Scene.SetupCamera(scenario)
  destroyCam()
  local cam = scenario.camera
  activeCam = CreateCamWithParams(
    'DEFAULT_SCRIPTED_CAMERA',
    cam.position.x, cam.position.y, cam.position.z,
    0.0, 0.0, 0.0, cam.fov or 40.0, false, 0
  )
  PointCamAtCoord(activeCam, cam.lookAt.x, cam.lookAt.y, cam.lookAt.z)
  SetCamActive(activeCam, true)
  RenderScriptCams(true, false, 0, true, true)
end

function Scene.Begin(scenario)
  if activeScenario then Scene.End() end
  activeScenario = scenario
  skipIntroRequested = false

  DoScreenFadeOut(Config.SceneTimings.fadeOutMs)
  while not IsScreenFadedOut() do Wait(0) end

  Scene.SetAmbient(scenario)
  Scene.HidePlayerPed()
  RequestCollisionAtCoord(scenario.anchor.x, scenario.anchor.y, scenario.anchor.z)
  local ped = PlayerPedId()
  SetEntityCoords(ped, scenario.anchor.x, scenario.anchor.y, scenario.anchor.z, false, false, false, false)
  Scene.SetupCamera(scenario)

  CreateThread(function()
    while activeScenario do
      HideHudAndRadarThisFrame()
      Wait(0)
    end
  end)

  Wait(150)
  local fadeIn = skipIntroRequested and 120 or Config.SceneTimings.fadeInMs
  DoScreenFadeIn(fadeIn)
end

function Scene.End()
  activeScenario = nil
  timelineThread = timelineThread + 1
  Scene.StopAmbientAudio()
  destroyCam()
  RenderScriptCams(false, false, 0, true, true)
  ClearOverrideWeather()
  ClearWeatherTypePersist()
  NetworkClearClockTimeOverride()
  skipIntroRequested = false
end

function Scene.RequestSkipIntro()
  skipIntroRequested = true
end

function Scene.IsSkipRequested() return skipIntroRequested end

-- Camera moves -------------------------------------------------------------

local function rotMatrixForward(rot)
  local rx, rz = math.rad(rot.x), math.rad(rot.z)
  local cx = math.cos(rx)
  return vector3(-math.sin(rz) * cx, math.cos(rz) * cx, math.sin(rx))
end

function Scene.CamForward()
  if not activeCam then return vector3(0, 1, 0) end
  return rotMatrixForward(GetCamRot(activeCam, 2))
end

function Scene.RunTimeline(timeline, ctx)
  if not timeline or #timeline == 0 then return end
  timelineThread = timelineThread + 1
  local thisRun = timelineThread

  CreateThread(function()
    local start = GetGameTimer()
    local fired = {}
    while activeScenario and thisRun == timelineThread do
      local now = GetGameTimer() - start
      for i, ev in ipairs(timeline) do
        if not fired[i] and now >= (ev.at or 0) then
          fired[i] = true
          Scene.RunTimelineEvent(ev, ctx)
        end
      end
      Wait(100)
    end
  end)
end

local function getTrackTarget(target, ctx)
  if target == 'anchor' then
    return vector3(ctx.scenario.anchor.x, ctx.scenario.anchor.y, ctx.scenario.anchor.z)
  end
  if type(target) == 'string' then
    if target:sub(1, 8) == 'vehicle:' then
      local veh = ctx.vehicles[target:sub(9)]
      if veh and DoesEntityExist(veh) then
        return GetEntityCoords(veh)
      end
    elseif target:sub(1, 5) == 'role:' then
      local p = ctx.roles[target:sub(6)]
      if p and DoesEntityExist(p) then return GetEntityCoords(p) end
    end
  end
  return nil
end

function Scene.RunTimelineEvent(ev, ctx)
  if ev.kind == 'cameraOrbit' then
    local center = getTrackTarget(ev.around or 'anchor', ctx)
    if not center then return end
    local duration = ev.durationMs or 8000
    local radius = ev.radius or 5.0
    local height = ev.height or 1.5
    local startTime = GetGameTimer()
    local thisRun = timelineThread
    CreateThread(function()
      while activeCam and activeScenario and thisRun == timelineThread do
        if skipIntroRequested then
          local x = center.x + radius
          SetCamCoord(activeCam, x, center.y, center.z + height)
          PointCamAtCoord(activeCam, center.x, center.y, center.z)
          break
        end
        local elapsed = GetGameTimer() - startTime
        local t = math.min(elapsed / duration, 1.0)
        local angle = t * math.pi * 2
        local x = center.x + math.cos(angle) * radius
        local y = center.y + math.sin(angle) * radius
        local z = center.z + height
        SetCamCoord(activeCam, x, y, z)
        PointCamAtCoord(activeCam, center.x, center.y, center.z)
        if t >= 1.0 then break end
        Wait(0)
      end
    end)
  elseif ev.kind == 'cameraDolly' then
    local from = GetCamCoord(activeCam)
    local to = ev.to
    local duration = ev.durationMs or 6000
    local startTime = GetGameTimer()
    local thisRun = timelineThread
    CreateThread(function()
      while activeCam and activeScenario and thisRun == timelineThread do
        if skipIntroRequested then
          SetCamCoord(activeCam, to.x, to.y, to.z)
          break
        end
        local elapsed = GetGameTimer() - startTime
        local t = math.min(elapsed / duration, 1.0)
        local s = 1.0 - math.cos(t * math.pi / 2.0) -- ease-out
        local x = from.x + (to.x - from.x) * s
        local y = from.y + (to.y - from.y) * s
        local z = from.z + (to.z - from.z) * s
        SetCamCoord(activeCam, x, y, z)
        if t >= 1.0 then break end
        Wait(0)
      end
    end)
  elseif ev.kind == 'cameraTrack' then
    local thisRun = timelineThread
    local startTime = GetGameTimer()
    local duration = ev.durationMs or 10000
    CreateThread(function()
      while activeCam and activeScenario and thisRun == timelineThread do
        local elapsed = GetGameTimer() - startTime
        if elapsed >= duration then break end
        local center = getTrackTarget(ev.target, ctx)
        if center then
          local off = ev.offset or vector3(5, 5, 2)
          SetCamCoord(activeCam, center.x + off.x, center.y + off.y, center.z + off.z)
          PointCamAtCoord(activeCam, center.x, center.y, center.z)
        end
        Wait(0)
      end
    end)
  end
end

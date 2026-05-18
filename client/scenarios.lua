Scenarios = Scenarios or {}

-- Currently-running scenario context, exposed for the hover module.
local current = nil

function Scenarios.Current() return current end

local function loadModel(model)
  local hash = type(model) == 'string' and joaat(model) or model
  if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
  RequestModel(hash)
  local deadline = GetGameTimer() + 8000
  while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
  if not HasModelLoaded(hash) then return nil end
  return hash
end

local function loadAnim(dict)
  if not dict then return end
  if HasAnimDictLoaded(dict) then return end
  RequestAnimDict(dict)
  local deadline = GetGameTimer() + 5000
  while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
end

local function loadWeapon(hash)
  if not hash then return end
  local h = type(hash) == 'string' and joaat(hash) or hash
  RequestWeaponAsset(h, 31, 0)
  local deadline = GetGameTimer() + 3000
  while not HasWeaponAssetLoaded(h) and GetGameTimer() < deadline do Wait(0) end
  return h
end

local function offsetFromAnchor(anchor, offset)
  -- offset is a vec4 in anchor-local space (heading is absolute)
  return vector4(
    anchor.x + (offset.x or 0.0),
    anchor.y + (offset.y or 0.0),
    anchor.z + (offset.z or 0.0),
    offset.w or anchor.w or 0.0
  )
end

local function applyAppearance(ped, appearance)
  if not appearance or not Config.Appearance.applyToPreview then return end
  local cfg = Config.Appearance.loader
  if not cfg or not cfg.resource or not cfg.setter then return end
  if GetResourceState(cfg.resource) ~= 'started' then return end
  pcall(function()
    exports[cfg.resource][cfg.setter](nil, ped, appearance)
  end)
end

local function createPed(modelHash, coords, headingDeg)
  local ped = CreatePed(2, modelHash, coords.x, coords.y, coords.z, headingDeg, false, true)
  if not DoesEntityExist(ped) then return nil end
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  SetPedCanRagdoll(ped, false)
  SetPedFleeAttributes(ped, 0, false)
  SetPedCombatAttributes(ped, 17, true)
  FreezeEntityPosition(ped, false)
  SetEntityVisible(ped, true, false)
  return ped
end

local function playPedAnim(ped, animation)
  if not animation or not animation.dict or not animation.name then return end
  loadAnim(animation.dict)
  TaskPlayAnim(
    ped, animation.dict, animation.name,
    4.0, -4.0, -1,
    animation.flag or 1,
    0.0, false, false, false
  )
end

local function giveWeapon(ped, weapon)
  if not weapon then return end
  local hash = loadWeapon(weapon)
  if not hash then return end
  GiveWeaponToPed(ped, hash, 250, false, true)
  SetCurrentPedWeapon(ped, hash, true)
end

-- Vehicles ----------------------------------------------------------------

local function spawnVehicle(name, def, anchor, ctx)
  local hash = loadModel(def.model)
  if not hash then return nil end
  local coords = offsetFromAnchor(anchor, def.offset or vector4(0, 0, 0, 0))
  local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, false, true)
  SetModelAsNoLongerNeeded(hash)
  if not DoesEntityExist(veh) then return nil end

  SetVehicleOnGroundProperly(veh)
  SetVehicleEngineOn(veh, true, true, false)
  if def.primaryColor or def.secondaryColor then
    SetVehicleColours(veh, def.primaryColor or 0, def.secondaryColor or 0)
  end
  if def.siren then
    SetVehicleSiren(veh, true)
    SetVehHasMutedSirens(veh, false)
  end
  if def.options and def.options.hoodOpen then
    SetVehicleDoorOpen(veh, 4, false, false)
  end

  ctx.vehicles[name] = veh
  return veh
end

local function seatPedsInVehicles(scenario, ctx)
  if not scenario.vehicles then return end
  for vehName, def in pairs(scenario.vehicles) do
    local veh = ctx.vehicles[vehName]
    if veh then
      local driverPed
      if def.driverRole then
        driverPed = ctx.roles[def.driverRole]
      elseif def.driverRoleIndex then
        driverPed = ctx.players[def.driverRoleIndex]
      end
      if driverPed and DoesEntityExist(driverPed) then
        SetPedIntoVehicle(driverPed, veh, -1)
      end

      if def.passengerRoles then
        local nextSeat = 0
        local passengerIdx = 1
        for _, roleRef in ipairs(def.passengerRoles) do
          local ped
          if type(roleRef) == 'string' then
            ped = ctx.roles[roleRef]
          elseif type(roleRef) == 'number' then
            -- numeric ref: index into player chars (skipping driver)
            local target = roleRef
            local skip = def.driverRoleIndex and 1 or 0
            ped = ctx.players[1 + skip + target]
            passengerIdx = passengerIdx + 1
          end
          if ped and DoesEntityExist(ped) then
            SetPedIntoVehicle(ped, veh, nextSeat)
            nextSeat = nextSeat + 1
          else
            nextSeat = nextSeat + 1
          end
        end
      end

      -- Tasks: drive ahead or pursue
      if def.task then
        if def.task.kind == 'driveAhead' and driverPed then
          local fwd = GetEntityForwardVector(veh)
          local pos = GetEntityCoords(veh)
          local target = pos + fwd * (def.task.distance or 200.0)
          TaskVehicleDriveToCoordLongrange(driverPed, veh,
            target.x, target.y, target.z,
            def.task.speed or 25.0,
            def.task.flags or 537001984,
            10.0)
        elseif def.task.kind == 'pursue' then
          local targetVeh = ctx.vehicles[def.task.target]
          if targetVeh and driverPed and DoesEntityExist(targetVeh) then
            TaskVehicleChase(driverPed, targetVeh)
            SetTaskVehicleChaseBehaviorFlag(driverPed, 1, true)
            SetDriveTaskCruiseSpeed(driverPed, def.task.speed or 35.0)
          end
        end
      end
    end
  end
end

-- Props -------------------------------------------------------------------

local function spawnProps(scenario, ctx)
  if not scenario.props then return end
  for _, p in ipairs(scenario.props) do
    local hash = loadModel(p.model)
    if hash then
      local coords = vector3(
        scenario.anchor.x + (p.offset and p.offset.x or 0.0),
        scenario.anchor.y + (p.offset and p.offset.y or 0.0),
        scenario.anchor.z + (p.offset and p.offset.z or 0.0)
      )
      local obj = CreateObject(hash, coords.x, coords.y, coords.z, false, true, false)
      SetModelAsNoLongerNeeded(hash)
      if DoesEntityExist(obj) then
        SetEntityHeading(obj, p.heading or 0.0)
        FreezeEntityPosition(obj, true)
        ctx.props[#ctx.props + 1] = obj
      end
    end
  end
end

-- Role spawning -----------------------------------------------------------

local function spawnPlayersRole(role, scenario, characters, appearances, ctx)
  local total = #characters
  if total == 0 then return end
  for i, character in ipairs(characters) do
    local localOffset = role.layout and role.layout(i, total) or vector4(0, 0, -1, 0)
    local coords = offsetFromAnchor(scenario.anchor, localOffset)
    local appearance = appearances and appearances[character.cid]
    local modelName = (appearance and appearance.model) or (character.gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    local hash = loadModel(modelName)
    if hash then
      local ped = createPed(hash, coords, localOffset.w or 0.0)
      SetModelAsNoLongerNeeded(hash)
      if ped then
        applyAppearance(ped, appearance)
        playPedAnim(ped, role.animation)
        if role.weapon then giveWeapon(ped, role.weapon) end
        ctx.players[i] = ped
        ctx.pedToCid[ped] = character.cid
      end
    end
  end
end

local function spawnNpcRole(name, role, scenario, ctx)
  local hash = loadModel(role.model)
  if not hash then return end
  local localOffset = role.offset or vector4(0, 0, -1, 0)
  local coords = offsetFromAnchor(scenario.anchor, localOffset)
  local ped = createPed(hash, coords, localOffset.w or 0.0)
  SetModelAsNoLongerNeeded(hash)
  if ped then
    playPedAnim(ped, role.animation)
    if role.weapon then giveWeapon(ped, role.weapon) end
    ctx.roles[name] = ped
  end
end

-- Public ------------------------------------------------------------------

function Scenarios.Pick(scenarios)
  if not scenarios or #scenarios == 0 then return nil end
  local cfg = Config.Scenarios
  local strategy = cfg.pickStrategy or 'weighted-random'

  if strategy == 'fixed' then
    return scenarios[cfg.fixedIndex or 1] or scenarios[1]
  end

  if strategy == 'sequential' then
    cfg._seqIdx = ((cfg._seqIdx or 0) % #scenarios) + 1
    return scenarios[cfg._seqIdx]
  end

  local total = 0
  for _, s in ipairs(scenarios) do total = total + (s.weight or 1) end
  local roll = math.random() * total
  local acc = 0
  for _, s in ipairs(scenarios) do
    acc = acc + (s.weight or 1)
    if roll <= acc then return s end
  end
  return scenarios[#scenarios]
end

function Scenarios.Start(scenario, characters, appearances)
  Scenarios.Stop()
  local t = Log.timer('scenario', 'start ' .. (scenario and scenario.id or 'nil'))

  Log.info('scenario', 'starting %s with %d chars', scenario and scenario.id or 'nil', characters and #characters or 0)
  Scene.Begin(scenario)

  local ctx = {
    scenario = scenario,
    players = {},      -- index -> ped (matches characters[] order)
    roles = {},        -- npc role name -> ped
    vehicles = {},     -- vehicle name -> entity
    props = {},        -- entity list
    pedToCid = {},     -- ped -> character cid (for click detection)
  }

  spawnProps(scenario, ctx)

  -- Spawn player-character peds first (so vehicle seating can reference them)
  if scenario.roles and scenario.roles.players then
    spawnPlayersRole(scenario.roles.players, scenario, characters or {}, appearances or {}, ctx)
  end

  -- Spawn NPC roles
  if scenario.roles then
    for name, role in pairs(scenario.roles) do
      if role.kind == 'npc' then
        spawnNpcRole(name, role, scenario, ctx)
      end
    end
  end

  -- Spawn vehicles & seat peds
  if scenario.vehicles then
    for vehName, def in pairs(scenario.vehicles) do
      spawnVehicle(vehName, def, scenario.anchor, ctx)
    end
    Wait(50)
    seatPedsInVehicles(scenario, ctx)
  end

  -- Run choreography
  Scene.RunTimeline(scenario.timeline, ctx)

  current = ctx
  if Config.Logging.performance and Config.Logging.performance.logScenarioStartup then
    local pedCount = 0; for _ in pairs(ctx.players) do pedCount = pedCount + 1 end
    local npcCount = 0; for _ in pairs(ctx.roles) do npcCount = npcCount + 1 end
    local vehCount = 0; for _ in pairs(ctx.vehicles) do vehCount = vehCount + 1 end
    Log.info('scenario', 'started %s (peds=%d npcs=%d veh=%d props=%d)', scenario.id, pedCount, npcCount, vehCount, #ctx.props)
  end
  t()
  return ctx
end

function Scenarios.Stop()
  if not current then
    Scene.End()
    return
  end

  local id = current.scenario and current.scenario.id or '?'
  for _, ped in pairs(current.players) do
    if DoesEntityExist(ped) then DeleteEntity(ped) end
  end
  for _, ped in pairs(current.roles) do
    if DoesEntityExist(ped) then DeleteEntity(ped) end
  end
  for _, veh in pairs(current.vehicles) do
    if DoesEntityExist(veh) then DeleteEntity(veh) end
  end
  for _, obj in ipairs(current.props) do
    if DoesEntityExist(obj) then DeleteEntity(obj) end
  end

  current = nil
  Scene.End()
  Log.debug('scenario', 'stopped %s', id)
end

function Scenarios.PedToCid(ped) return current and current.pedToCid[ped] end
function Scenarios.PlayerPeds() return current and current.players or {} end

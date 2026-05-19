-- Spawns and tears down the ensemble of player-character peds and
-- empty-slot peds. The result is queryable: PedSetup.PedToCid(ped),
-- PedSetup.IsEmptySlot(ped), PedSetup.AllPeds().

PedSetup = PedSetup or {}

local current = nil

local function loadModel(model)
  local hash = type(model) == 'string' and joaat(model) or model
  if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
  RequestModel(hash)
  local deadline = GetGameTimer() + 6000
  while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
  if not HasModelLoaded(hash) then return nil end
  return hash
end

local function loadAnim(dict)
  if not dict or HasAnimDictLoaded(dict) then return end
  RequestAnimDict(dict)
  local deadline = GetGameTimer() + 5000
  while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
end

local function offsetFromAnchor(anchor, off)
  return vector4(anchor.x + (off.x or 0), anchor.y + (off.y or 0), anchor.z + (off.z or 0),
                 off.w or anchor.w or 0.0)
end

local function applyAppearance(ped, appearance)
  if not appearance or not Config.Appearance.applyToPreview then return end
  local cfg = Config.Appearance.loader
  if not cfg or not cfg.resource or not cfg.setter then return end
  if GetResourceState(cfg.resource) ~= 'started' then return end
  pcall(function() exports[cfg.resource][cfg.setter](nil, ped, appearance) end)
end

local function createPed(modelHash, coords, heading)
  -- CreatePed(pedType, modelHash, x, y, z, heading, isNetwork, scriptHostPed)
  local ped = CreatePed(2, modelHash, coords.x, coords.y, coords.z, heading, false, true)
  if not DoesEntityExist(ped) then return nil end
  SetEntityInvincible(ped, true)
  SetBlockingOfNonTemporaryEvents(ped, true)
  FreezeEntityPosition(ped, true)
  SetPedCanRagdoll(ped, false)
  return ped
end

local function playIdle(ped)
  local anim = Config.Scene.animation
  if not anim or not anim.dict or not anim.name then return end
  loadAnim(anim.dict)
  -- TaskPlayAnim(ped, dict, name, blendIn, blendOut, dur, flag, playbackRate, lockX, lockY, lockZ)
  TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, -1, 1, 0.0, false, false, false)
end

local function spawnCharacterPed(index, total, character, appearance)
  local off = Config.Scene.layout(index, total)
  local coords = offsetFromAnchor(Config.Scene.anchor, off)
  local model = (appearance and appearance.model)
    or (character.gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
  local hash = loadModel(model)
  if not hash then return nil end
  local ped = createPed(hash, coords, off.w or 0.0)
  SetModelAsNoLongerNeeded(hash)
  if not ped then return nil end
  applyAppearance(ped, appearance)
  playIdle(ped)
  return ped
end

local function spawnEmptySlotPed(index, total)
  local models = Config.EmptySlot.pedModels or { 'a_m_y_hipster_01' }
  local model = models[math.random(1, #models)]
  local hash = loadModel(model)
  if not hash then return nil end
  local off = Config.Scene.layout(index, total)
  local coords = offsetFromAnchor(Config.Scene.anchor, off)
  local ped = createPed(hash, coords, off.w or 0.0)
  SetModelAsNoLongerNeeded(hash)
  if not ped then return nil end
  -- SetEntityAlpha(entity, alpha, skin)
  SetEntityAlpha(ped, Config.EmptySlot.alpha or 110, false)
  playIdle(ped)
  return ped
end

function PedSetup.Start(characters, appearances, slots)
  PedSetup.Stop()
  characters = characters or {}
  appearances = appearances or {}
  slots = math.max(slots or 0, #characters)

  local ctx = {
    pedToCid = {},       -- ped -> cid (character peds)
    emptySlots = {},     -- index -> ped (empty-slot peds)
    pedToSlotIndex = {}, -- ped -> 1-indexed slot index (empty slots)
    allPeds = {},        -- all spawned peds for quick iteration
  }

  -- Spawn character peds in their slot indexes (1..#characters)
  for i, character in ipairs(characters) do
    local ped = spawnCharacterPed(i, slots, character, appearances[character.cid])
    if ped then
      ctx.pedToCid[ped] = character.cid
      ctx.allPeds[#ctx.allPeds + 1] = ped
    end
  end

  -- Empty slot peds occupy the remaining indexes
  for i = #characters + 1, slots do
    local ped = spawnEmptySlotPed(i, slots)
    if ped then
      ctx.emptySlots[i] = ped
      ctx.pedToSlotIndex[ped] = i
      ctx.allPeds[#ctx.allPeds + 1] = ped
    end
  end

  current = ctx
  Log.debug('scene', 'peds spawned chars=%d empty=%d total=%d', #characters, slots - #characters, slots)
  return ctx
end

function PedSetup.Stop()
  if not current then return end
  for _, ped in ipairs(current.allPeds) do
    if DoesEntityExist(ped) then DeleteEntity(ped) end
  end
  current = nil
end

function PedSetup.PedToCid(ped) return current and current.pedToCid[ped] end
function PedSetup.IsEmptySlot(ped) return current and current.pedToSlotIndex[ped] ~= nil end
function PedSetup.SlotIndexFor(ped) return current and current.pedToSlotIndex[ped] end
function PedSetup.AllPeds() return current and current.allPeds or {} end
function PedSetup.PedToCharacter(cid)
  -- Helper for the hover label
  if not current then return nil end
  for ped, c in pairs(current.pedToCid) do
    if c == cid then return ped end
  end
end

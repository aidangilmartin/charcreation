Preview = Preview or {}

local previewPed
local pendingApplyToken = 0

local function loadModel(model)
  local hash = type(model) == 'string' and joaat(model) or model
  if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
  RequestModel(hash)
  local deadline = GetGameTimer() + 6000
  while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
  if not HasModelLoaded(hash) then return nil end
  return hash
end

local function destroyPreview()
  if previewPed and DoesEntityExist(previewPed) then
    DeleteEntity(previewPed)
  end
  previewPed = nil
end

local function applyAppearance(ped, appearance)
  if not appearance then return end
  local cfg = Config.Appearance.loader
  if not cfg or not cfg.resource or not cfg.setter then return end
  if GetResourceState(cfg.resource) ~= 'started' then return end
  pcall(function()
    exports[cfg.resource][cfg.setter](nil, ped, appearance)
  end)
end

function Preview.Spawn(gender, appearance)
  local token = pendingApplyToken + 1
  pendingApplyToken = token

  local model = (appearance and appearance.model) or (gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
  local scene = Scene.Active()
  if not scene then return end

  local hash = loadModel(model)
  if not hash then return end

  destroyPreview()
  previewPed = CreatePed(2, hash, scene.ped.x, scene.ped.y, scene.ped.z - 1.0, scene.ped.w, false, true)
  SetModelAsNoLongerNeeded(hash)
  if not DoesEntityExist(previewPed) then return end

  FreezeEntityPosition(previewPed, true)
  SetEntityInvincible(previewPed, true)
  SetBlockingOfNonTemporaryEvents(previewPed, true)
  SetEntityVisible(previewPed, true, false)

  if appearance then applyAppearance(previewPed, appearance) end
  Scene.PlayPedAnimation(previewPed)

  -- If a newer request came in mid-load, drop this ped.
  if token ~= pendingApplyToken then destroyPreview() end
end

function Preview.Clear()
  pendingApplyToken = pendingApplyToken + 1
  destroyPreview()
end

Hover = Hover or {}

local active = false
local hoveredCid = nil
local hoveredPed = nil
local selectedCid = nil
local lastNuiX, lastNuiY = 0.5, 0.5

local function screenToWorldRay(cam, ndcX, ndcY)
  -- ndcX, ndcY in [-1, 1]. Build a ray from cam through that point.
  local camPos = GetCamCoord(cam)
  local camRot = GetCamRot(cam, 2)
  local fov = math.rad(GetCamFov(cam))

  local cosX = math.cos(math.rad(camRot.x))
  local sinX = math.sin(math.rad(camRot.x))
  local cosZ = math.cos(math.rad(camRot.z))
  local sinZ = math.sin(math.rad(camRot.z))

  local forward = vector3(-sinZ * cosX, cosZ * cosX, sinX)
  local right   = vector3(cosZ, sinZ, 0.0)
  local up      = vector3(-sinZ * sinX, cosZ * sinX, -cosX)  -- pitch-up direction
  -- (note: GTA's coordinate handedness; for screen-up we negate the Z term)
  up = vector3(sinZ * sinX, -cosZ * sinX, cosX)

  local _, screenW, screenH = 0, GetActiveScreenResolution()
  local aspect = screenW / screenH
  local tanHalf = math.tan(fov / 2.0)

  local dir = forward + right * (ndcX * tanHalf * aspect) + up * (ndcY * tanHalf)
  dir = dir / #(dir)
  return camPos, dir
end

local function raycastForPed(cam)
  if not cam then return nil end
  -- Map [0,1] cursor coords to NDC [-1,1] with vertical flip
  local ndcX = (lastNuiX - 0.5) * 2.0
  local ndcY = (0.5 - lastNuiY) * 2.0

  local origin, dir = screenToWorldRay(cam, ndcX, ndcY)
  local target = origin + dir * 50.0

  local ray = StartShapeTestRay(origin.x, origin.y, origin.z, target.x, target.y, target.z, 12, PlayerPedId(), 0)
  local _, hit, _, _, entity = GetShapeTestResult(ray)
  if hit == 1 and entity ~= 0 and IsEntityAPed(entity) then
    return entity
  end
  return nil
end

function Hover.Start()
  if active then return end
  active = true
  CreateThread(function()
    while active do
      local cam = Scene.ActiveCam()
      if cam then
        local hit = raycastForPed(cam)
        local cid = hit and Scenarios.PedToCid(hit)
        if cid ~= hoveredCid then
          hoveredCid = cid
          hoveredPed = hit
          SendNUIMessage({ action = 'hovered', data = { cid = cid } })
        end
      end
      Wait(80)
    end
  end)

  -- Draw a marker over hovered + selected peds each frame
  CreateThread(function()
    while active do
      Wait(0)
      if Config.Selection.drawHoverMarker then
        local function drawMarkerOnPed(ped, color)
          if not ped or not DoesEntityExist(ped) then return end
          local pos = GetEntityCoords(ped)
          local h = Config.Selection.hoverMarkerHeightOffset or 1.05
          DrawMarker(
            2, -- chevron pointing down
            pos.x, pos.y, pos.z + h,
            0, 0, 0, 0, 0, 0,
            0.3, 0.3, 0.3,
            color[1], color[2], color[3], color[4],
            true, true, 2, false, nil, nil, false
          )
        end
        if hoveredPed and hoveredCid ~= selectedCid then
          drawMarkerOnPed(hoveredPed, Config.Selection.hoverOutline)
        end
        if selectedCid then
          for _, ped in pairs(Scenarios.PlayerPeds()) do
            if DoesEntityExist(ped) and Scenarios.PedToCid(ped) == selectedCid then
              drawMarkerOnPed(ped, Config.Selection.selectedOutline)
              break
            end
          end
        end
      end
    end
  end)
end

function Hover.Stop()
  active = false
  hoveredCid = nil
  hoveredPed = nil
  selectedCid = nil
end

function Hover.SetCursor(x, y)
  if type(x) == 'number' then lastNuiX = math.max(0, math.min(1, x)) end
  if type(y) == 'number' then lastNuiY = math.max(0, math.min(1, y)) end
end

function Hover.HoveredCid() return hoveredCid end
function Hover.SetSelectedCid(cid) selectedCid = cid end
function Hover.SelectedCid() return selectedCid end

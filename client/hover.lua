-- Hover detection + 3D drawing for the in-scene selector.
-- We don't raycast; instead we project each ped's head to screen and check
-- the distance to the cursor. Much simpler and more reliable than raycasting
-- through reduced-alpha peds.

Hover = Hover or {}

local active = false
local hoveredPed = nil
local sessionCharacters = {}

local function drawText3D(world, text, scale, color)
  local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
  if not onScreen then return end
  SetTextScale(0.0, scale or 0.4)
  SetTextFont(4)
  SetTextProportional(true)
  SetTextColour(color[1], color[2], color[3], color[4])
  SetTextDropshadow(0, 0, 0, 0, 255)
  SetTextEdge(2, 0, 0, 0, 150)
  SetTextDropShadow()
  SetTextOutline()
  SetTextEntry('STRING')
  SetTextCentre(true)
  AddTextComponentString(text)
  DrawText(x, y)
end

local function drawMarker(pos, color)
  -- Type 2 = downward chevron
  DrawMarker(
    2,
    pos.x, pos.y, pos.z,
    0, 0, 0,                -- direction
    0, 0, 0,                -- rotation
    0.3, 0.3, 0.3,          -- scale
    color[1], color[2], color[3], color[4],
    true, true, 2,          -- bobUpAndDown, faceCamera, p19
    false, nil, nil, false
  )
end

local function distanceSqOnScreen(world, cursorX, cursorY)
  local onScreen, x, y = GetScreenCoordFromWorldCoord(world.x, world.y, world.z)
  if not onScreen then return math.huge end
  local w, h = GetActiveScreenResolution()
  local sx = x * w
  local sy = y * h
  local dx = sx - cursorX
  local dy = sy - cursorY
  return dx * dx + dy * dy
end

local function pickHoveredPed()
  if not Scene.IsActive() then return nil end
  local cx, cy = GetNuiCursorPosition()
  local best, bestDist = nil, (Config.Hover.hitRadiusPx ^ 2)
  for _, ped in ipairs(PedSetup.AllPeds()) do
    if DoesEntityExist(ped) then
      -- Head bone for screen projection
      local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
      local d = distanceSqOnScreen(head, cx, cy)
      if d < bestDist then best, bestDist = ped, d end
    end
  end
  return best
end

function Hover.HoveredPed() return hoveredPed end

function Hover.Start()
  if active then return end
  active = true
  hoveredPed = nil

  -- Tick the hover pick on a loose interval
  CreateThread(function()
    while active do
      hoveredPed = pickHoveredPed()
      Wait(50)
    end
  end)

  -- Per-frame draw of markers + labels
  CreateThread(function()
    while active do
      Wait(0)
      if hoveredPed and DoesEntityExist(hoveredPed) then
        local pos = GetEntityCoords(hoveredPed)
        if PedSetup.IsEmptySlot(hoveredPed) then
          -- 3D "+" above the empty-slot ped
          local plus = Config.EmptySlot.plus
          local height = plus.heightOffset or 1.05
          drawText3D(
            vector3(pos.x, pos.y, pos.z + height + 0.4),
            plus.text or '+',
            plus.scale or 1.8,
            plus.color or { 255, 220, 130, 230 }
          )
          drawMarker(
            vector3(pos.x, pos.y, pos.z + (Config.Hover.labelHeightOffset or 1.05)),
            Config.EmptySlot.hoverTint or { 255, 220, 130, 200 }
          )
        else
          local cid = PedSetup.PedToCid(hoveredPed)
          local char
          for _, c in ipairs(sessionCharacters) do
            if c.cid == cid then char = c; break end
          end
          if char then
            drawText3D(
              vector3(pos.x, pos.y, pos.z + (Config.Hover.labelHeightOffset or 1.05) + 0.45),
              char.name,
              0.5,
              { 255, 255, 255, 230 }
            )
            drawText3D(
              vector3(pos.x, pos.y, pos.z + (Config.Hover.labelHeightOffset or 1.05) + 0.18),
              char.job or '',
              0.35,
              { 200, 200, 200, 200 }
            )
          end
          drawMarker(
            vector3(pos.x, pos.y, pos.z + (Config.Hover.labelHeightOffset or 1.05)),
            Config.Hover.charHoverTint or { 0, 220, 255, 200 }
          )
        end
      end
    end
  end)
end

function Hover.Stop()
  active = false
  hoveredPed = nil
end

function Hover.SetCharacters(characters) sessionCharacters = characters or {} end

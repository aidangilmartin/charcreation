-- In-game debug overlay for the character selector. Toggled by the control
-- specified in Config.Logging.overlay.toggleControl. Renders live state on
-- screen so you don't have to alt-tab to the console while testing.

Overlay = Overlay or {}

local visible = false
local fpsSamples = {}
local recentNet = {}

local function pushNet(line)
  recentNet[#recentNet + 1] = ('%s | %s'):format(os.date('%H:%M:%S'), line)
  while #recentNet > 5 do table.remove(recentNet, 1) end
end

function Overlay.LogNetwork(direction, eventName)
  pushNet(('%s %s'):format(direction == 'in' and '<--' or '-->', eventName))
end

local function drawText(x, y, text, scale)
  SetTextFont(4)
  SetTextScale(scale or 0.32, scale or 0.32)
  SetTextColour(255, 255, 255, 220)
  SetTextOutline()
  SetTextEntry('STRING')
  AddTextComponentString(tostring(text))
  DrawText(x, y)
end

CreateThread(function()
  while true do
    local cfg = Config.Logging and Config.Logging.overlay
    if cfg and cfg.enabled then
      if IsControlJustPressed(0, cfg.toggleControl or 244) then
        visible = not visible
      end
    end

    if visible and cfg and cfg.enabled then
      table.insert(fpsSamples, 1.0 / math.max(GetFrameTime(), 0.0001))
      while #fpsSamples > 30 do table.remove(fpsSamples, 1) end
      local fps = 0
      for _, v in ipairs(fpsSamples) do fps = fps + v end
      fps = fps / #fpsSamples

      local scale = cfg.fontScale or 0.32
      local y = 0.05
      local function row(line) drawText(0.01, y, line, scale); y = y + 0.022 end

      row('~y~cc_multichar debug')
      if cfg.showFps then row(('fps: %.0f  frame: %.1fms'):format(fps, GetFrameTime() * 1000)) end

      if cfg.showScenario then
        local current = Scenarios and Scenarios.Current()
        if current then
          local s = current.scenario
          row(('scenario: %s'):format(s and s.id or '?'))
          local nPlayers = 0; for _ in pairs(current.players) do nPlayers = nPlayers + 1 end
          local nRoles = 0;   for _ in pairs(current.roles) do nRoles = nRoles + 1 end
          local nVeh = 0;     for _ in pairs(current.vehicles) do nVeh = nVeh + 1 end
          row(('  peds: %d  npcs: %d  vehicles: %d  props: %d'):format(nPlayers, nRoles, nVeh, #current.props))
        else
          row('scenario: (none)')
        end
      end

      if cfg.showHover then
        row(('hover cid: %s'):format(Hover and Hover.HoveredCid() or '-'))
      end
      if cfg.showSelection then
        row(('selected cid: %s'):format(Hover and Hover.SelectedCid() or '-'))
      end
      if cfg.showNetwork and #recentNet > 0 then
        row('recent events:')
        for _, line in ipairs(recentNet) do row('  ' .. line) end
      end
    end

    Wait(0)
  end
end)

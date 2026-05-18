Slots = Slots or {}

-- Precedence (highest wins, falling back down):
--   1. customGetSlotOverride(src, license) data provider
--   2. DB row in slotOverridesTable
--   3. Config.Slots.perLicense[license]
--   4. Highest ace permission tier the player has from Config.Slots.aceTiers
--   5. Config.Slots.default
function Slots.For(src, license)
  if type(Config.DataProviders.customGetSlotOverride) == 'function' then
    local ok, override = pcall(Config.DataProviders.customGetSlotOverride, src, license)
    if ok and type(override) == 'number' and override > 0 then return override end
  end

  if DB.Available() and license then
    local row = DB.Scalar(
      ('SELECT slots FROM `%s` WHERE license = ? LIMIT 1'):format(Config.Database.slotOverridesTable),
      { license }
    )
    if type(row) == 'number' and row > 0 then return row end
  end

  local perLicense = Config.Slots.perLicense or {}
  if license and perLicense[license] and perLicense[license] > 0 then
    return perLicense[license]
  end

  for _, tier in ipairs(Config.Slots.aceTiers or {}) do
    if IsPlayerAceAllowed(src, tier.ace) and tier.slots > 0 then
      return tier.slots
    end
  end

  return Config.Slots.default or 4
end

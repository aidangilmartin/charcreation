Slots = Slots or {}

function Slots.For(src, license)
  if type(Config.DataProviders.customGetSlotOverride) == 'function' then
    local ok, n = pcall(Config.DataProviders.customGetSlotOverride, src, license)
    if ok and type(n) == 'number' and n > 0 then return n end
  end

  if DB.Available() and license then
    local row = DB.Scalar(
      ('SELECT slots FROM `%s` WHERE license = ? LIMIT 1'):format(Config.Database.slotOverridesTable),
      { license }
    )
    if type(row) == 'number' and row > 0 then return row end
  end

  local pl = Config.Slots.perLicense or {}
  if license and pl[license] and pl[license] > 0 then return pl[license] end

  for _, tier in ipairs(Config.Slots.aceTiers or {}) do
    if IsPlayerAceAllowed(src, tier.ace) and tier.slots > 0 then return tier.slots end
  end

  return Config.Slots.default or 4
end

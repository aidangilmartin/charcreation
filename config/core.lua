Config = Config or {}

Config.Debug = false

Config.Framework = 'auto' -- auto | qbox | qbcore | esx | standalone

Config.AutoOpenOnJoin = true
Config.AutoOpenDelayMs = 1500

Config.Slots = {
  default = 4,
  aceTiers = {
    { ace = 'group.admin',    slots = 8 },
    { ace = 'cc.donator.t3',  slots = 7 },
    { ace = 'cc.donator.t2',  slots = 6 },
    { ace = 'cc.donator.t1',  slots = 5 },
  },
  perLicense = {},
}

Config.Database = {
  adapter = 'oxmysql',
  slotOverridesTable = 'cc_multichar_slots',
  ensureSchemaOnStart = true,
}

Config.Appearance = {
  applyToPreview = true,
  loader = {
    resource = 'illenium-appearance',
    export = 'getPedAppearance',
    setter = 'setPedAppearance',
  },
  qbClothingFallback = true,
}

Config.CharacterCreator = {
  resource = 'illenium-appearance',
  export = 'startPlayerCustomization',
  -- 'callback': export(function() ... end)  e.g. illenium-appearance, fivem-appearance
  -- 'blocking': export()                    yields until the editor finishes
  -- 'manual':   the editor calls exports.cc_multichar:FinishAppearance(src) when done
  invocation = 'callback',
}

Config.DataProviders = {
  customLoadCharacters     = nil,
  customCreateCharacter    = nil,
  customDeleteCharacter    = nil,
  customGetLastLocation    = nil,
  customGetAppearance      = nil,
  customLoginCharacter     = nil,
  customGetSlotOverride    = nil,
}

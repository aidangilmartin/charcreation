Config = Config or {}

Config.Framework = 'auto' -- auto | qbox | qbcore
Config.Debug = false
Config.EnableCompatShim = true

Config.Slots = {
  default = 4,
  byLicense = {
    -- ['license:xxxxxxxx'] = 6,
  },
  byGroup = {
    -- admin = 8,
    -- mod = 6,
  }
}

Config.CharacterCreation = {
  export = {
    resource = 'your_creator',
    name = 'OpenCreator'
  }
}

Config.DataProviders = {
  useFrameworkDefaults = true,
  -- override = function(src, character) return { bank = 0, cash = 0, playtime = 0, job = 'Unemployed' } end
}

Config = Config or {}

Config.Framework = 'auto' -- auto | qbox | qbcore
Config.Debug = false
Config.EnableCompatShim = true

Config.Release = {
  strictMode = true,
}

Config.Slots = {
  default = 4,
  byLicense = {},
  byGroup = {}
}

Config.CharacterCreation = {
  export = {
    resource = 'your_creator',
    name = 'OpenCreator'
  }
}

Config.Database = {
  adapter = 'oxmysql', -- oxmysql | custom
}

Config.DataProviders = {
  useFrameworkDefaults = true,
  override = nil,
  customLoadCharacters = nil,
  customDeleteCharacter = nil,
  customGetLastLocation = nil,
  customGetJob = nil,
}

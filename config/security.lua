Config = Config or {}

Config.Security = {
  requireAuthenticatedSession = true,
  allowDelete = true,

  audit = {
    enabled = true,
    print = true,
    webhook = '', -- discord webhook URL, optional
  },

  rateLimit = {
    windowMs = 8000,
    maxCalls = 12,
    byEvent = {
      open            = { windowMs = 6000,  maxCalls = 4 },
      selectCharacter = { windowMs = 6000,  maxCalls = 8 },
      deleteCharacter = { windowMs = 10000, maxCalls = 3 },
      createCharacter = { windowMs = 15000, maxCalls = 5 },
      selectSpawn     = { windowMs = 5000,  maxCalls = 6 },
      beginCreator    = { windowMs = 10000, maxCalls = 3 },
    },
  },
}

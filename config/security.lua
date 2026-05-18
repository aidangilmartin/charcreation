Config = Config or {}

Config.Security = {
  requireAuthenticatedSession = true,
  tokenLength = 7,
  tokenTTLSeconds = 120,
  allowDelete = true,
  audit = {
    enabled = true,
    print = true,
    webhook = ''
  },
  rateLimit = {
    windowMs = 8000,
    maxCalls = 12,
    byEvent = {
      open = { windowMs = 6000, maxCalls = 4 },
      selectCharacter = { windowMs = 6000, maxCalls = 8 },
      deleteCharacter = { windowMs = 10000, maxCalls = 3 },
      beginCreate = { windowMs = 8000, maxCalls = 4 },
      selectSpawn = { windowMs = 5000, maxCalls = 6 },
    }
  }
}

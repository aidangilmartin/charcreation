Config = Config or {}

Config.Security = {
  requireAuthenticatedSession = true,
  tokenLength = 7,
  tokenTTLSeconds = 120,
  eventWindowSeconds = 10,
  allowDelete = true,
}

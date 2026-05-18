--[[
  cc_multichar — Security configuration
  ---------------------------------------------------------------------------
  Rate limits and audit logging. Every net event the server accepts goes
  through `eventAllowed(src, name)` first; if the player exceeds the
  configured budget within the window, the event is dropped and an audit
  entry is emitted.

  Tuning rules of thumb:
    - `open` is the only event normally called by automation (auto-open on
      connect, /switch). Keep its budget low.
    - `selectCharacter` can fire on every click — give it more headroom.
    - `deleteCharacter` and `createCharacter` are destructive. Keep tight.
]]

Config = Config or {}

Config.Security = {

  -- ===========================================================================
  -- Identity gate
  -- ===========================================================================
  -- When true, any event from a player without a valid `license:` identifier
  -- is silently dropped. Disable only for local testing.
  requireAuthenticatedSession = true,

  -- Master toggle for character deletion. When false, even valid delete
  -- requests are refused — useful for season events / permadeath modes.
  allowDelete = true,

  -- ===========================================================================
  -- Audit logging
  -- ===========================================================================
  -- enabled       Master toggle.
  -- print         Send audit lines to the FXServer console (also routes
  --               through Log.warn('audit', ...) so file/webhook sinks work).
  -- webhook       Optional Discord webhook URL. Used only for audit events.
  --               To forward all logs (not just audit), use
  --               Config.Logging.sinks.webhook instead.
  audit = {
    enabled = true,
    print = true,
    webhook = '',
  },

  -- ===========================================================================
  -- Rate limiting
  -- ===========================================================================
  -- windowMs / maxCalls
  --   Default budget for events that don't have a `byEvent` override.
  --
  -- byEvent[name] = { windowMs, maxCalls }
  --   Per-event overrides. The event name is the second segment of
  --   cc_multichar:server:<name>, e.g. 'selectCharacter'.
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
      requestStats    = { windowMs = 5000,  maxCalls = 8 },
      requestSwitch   = { windowMs = 60000, maxCalls = 3 },
    },
  },
}

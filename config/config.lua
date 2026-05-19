Config = Config or {}

-- Framework: 'auto' | 'qbox' | 'qbcore' | 'esx' | 'standalone'
Config.Framework = 'auto'

Config.Debug = false
Config.AutoOpenOnJoin = true
Config.AutoOpenDelayMs = 1500

-- Slot precedence (highest wins):
--   customGetSlotOverride -> cc_multichar_slots DB row -> perLicense -> aceTiers -> default
Config.Slots = {
  default = 4,
  aceTiers = {
    { ace = 'group.admin',   slots = 8 },
    { ace = 'cc.donator.t3', slots = 7 },
    { ace = 'cc.donator.t2', slots = 6 },
    { ace = 'cc.donator.t1', slots = 5 },
  },
  perLicense = {},
  -- Hard cap so a misconfigured tier can't spawn 9999 peds.
  hardMax = 12,
}

Config.Database = {
  adapter = 'oxmysql',
  slotOverridesTable = 'cc_multichar_slots',
  ensureSchemaOnStart = true,
}

-- One ensemble scene. The layout fn places each character + empty slot.
Config.Scene = {
  weather = 'EXTRASUNNY',
  hour = 19,
  minute = 30,
  anchor = vector4(-1037.04, -2731.99, 19.45, 240.0),
  camera = {
    position = vector3(-1041.5, -2728.0, 21.0),
    lookAt   = vector3(-1037.04, -2731.99, 20.5),
    fov = 38.0,
  },
  animation = {
    dict = 'amb@world_human_drinking@beer@male@idle_a',
    name = 'idle_a',
  },
  layout = function(i, total)
    local angle = ((i - 1) / math.max(total, 1)) * math.pi * 2
    local r = 1.7
    return vector4(math.cos(angle) * r, math.sin(angle) * r, -1.0,
                   (angle * 180.0 / math.pi) + 180.0)
  end,
  fadeOutMs = 400,
  fadeInMs  = 600,
}

Config.EmptySlot = {
  pedModels = {
    'a_m_y_business_01', 'a_m_y_business_02', 'a_m_y_hipster_01',
    'a_f_y_business_01', 'a_f_y_business_02', 'a_f_y_hipster_01',
    'a_m_y_skater_01',   'a_f_y_tourist_01',
  },
  alpha = 110,                      -- 0..255
  plus = {
    text = '+',
    scale = 1.8,
    color = { 255, 220, 130, 230 }, -- rgba 0..255
    heightOffset = 1.05,
  },
  hoverTint = { 255, 220, 130, 200 },
}

Config.Appearance = {
  applyToPreview = true,
  loader = {
    resource = 'illenium-appearance',
    setter   = 'SetPedAppearance',
  },
}

Config.Hover = {
  hitRadiusPx = 80,
  charHoverTint = { 0, 220, 255, 200 },
  labelHeightOffset = 1.05,
}

Config.RoutingBucket = {
  enabled = true,
  bucketOffset = 100000,
  populationEnabled = false,
  entityLockdown = 'inactive',   -- 'inactive' | 'relaxed' | 'strict'
  restoreToBucketOnSpawn = 0,
}

-- After we log the character in via the framework adapter, the framework's
-- native onPlayerLoaded event has already fired (the adapter call does it),
-- which any framework-native spawn resource is listening for.
--   'framework' = no-op (recommended)
--   'event'     = TriggerEvent(event, src, character) + TriggerClientEvent(clientEvent, src, character)
--   'export'    = exports[export.resource][export.name](src, character)
--
-- The empty-slot click fires onCreateCharacter; your creator resource
-- handles the UI, saves the new row, then calls exports.cc_multichar:Reopen(src).
Config.Handlers = {
  onCharacterSelected = {
    mode = 'framework',
    event = 'cc_multichar:characterSelected',
    clientEvent = 'cc_multichar:client:characterSelected',
    export = { resource = '', name = '' },
  },
  onCreateCharacter = {
    mode = 'event',
    event = 'cc_multichar:createRequested',
    clientEvent = 'cc_multichar:client:createRequested',
    export = { resource = '', name = '' },
  },
}

-- Optional overrides for any of these (server-side):
--   customLoadCharacters(src, license)   -> { character, ... }
--   customGetAppearance(src, cid)        -> appearance table | nil
--   customLoginCharacter(src, character) -> boolean (true skips adapter.login)
--   customGetSlotOverride(src, license)  -> number | nil
Config.DataProviders = {
  customLoadCharacters  = nil,
  customGetAppearance   = nil,
  customLoginCharacter  = nil,
  customGetSlotOverride = nil,
}

Config.Security = {
  -- Reject events from players without a license:* identifier.
  requireAuthenticatedSession = true,
  rateLimit = {
    windowMs = 8000,
    maxCalls = 12,
    byEvent = {
      open            = { windowMs = 6000,  maxCalls = 4 },
      selectCharacter = { windowMs = 6000,  maxCalls = 8 },
      createCharacter = { windowMs = 15000, maxCalls = 5 },
    },
  },
}

Config.Logging = {
  level = 'info',                  -- trace | debug | info | warn | error
  categories = {                   -- per-category override; false=inherit, 'off'=silent
    resource   = 'info',
    framework  = 'info',
    session    = 'debug',
    db         = 'debug',
    scene      = 'debug',
    selector   = 'info',
    security   = 'info',
  },
  console = { enabled = true, color = true, prefix = 'cc_multichar' },
}

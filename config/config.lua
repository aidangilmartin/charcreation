--[[
  ============================================================================
  cc_multichar — drag-and-drop character selector configuration
  ============================================================================
  Every option in this file is documented inline. Read top to bottom.

  Design intent
    - We show a cinematic scene with one ped per character.
    - You click a ped to play as that character.
    - Empty slots show as faded random peds with a "+" on hover; clicking one
      hands off to your framework's existing character creation flow.
    - After selecting a character we log them in via the framework adapter
      and (by default) re-fire the framework's native login event so your
      existing spawn resource — qbx_spawn, qb-spawn, esx_spawn, whatever —
      picks up from there. No spawn picker is bundled with this resource.

  Hand-off points (Config.Handlers)
    - onCharacterSelected : what to do server-side once a character is logged in
    - onCreateCharacter   : what to fire when the player clicks an empty slot

  Both can run in 'framework' (re-fire native event), 'event' (fire your event),
  or 'export' (call your export) mode. Examples for every framework below.
]]

Config = Config or {}

-- ============================================================================
-- General
-- ============================================================================

-- 'auto' detects the framework by checking GetResourceState at runtime.
-- Force a specific binding if auto-detection picks the wrong one.
--   'auto' | 'qbox' | 'qbcore' | 'esx' | 'standalone'
Config.Framework = 'auto'

-- Master debug flag. When true, the logger's effective floor becomes 'debug'.
Config.Debug = false

-- When true, the selector opens automatically `AutoOpenDelayMs` after the
-- player connects (post-loadscreen). Disable if another resource (queue,
-- MOTD, whitelist) needs to run first; trigger us manually with
--   exports.cc_multichar:OpenForPlayer(src)
Config.AutoOpenOnJoin = true
Config.AutoOpenDelayMs = 1500


-- ============================================================================
-- Slots
-- ============================================================================
-- Slot count is resolved per-player using this precedence (highest wins):
--   1. Config.DataProviders.customGetSlotOverride(src, license)
--   2. row in `cc_multichar_slots` DB table for that license
--   3. Config.Slots.perLicense[license]
--   4. first matching Config.Slots.aceTiers entry (IsPlayerAceAllowed)
--   5. Config.Slots.default
Config.Slots = {
  default = 4,

  -- Add ace rules in server.cfg, e.g.
  --   add_ace identifier.fivem:1234 cc.donator.t2 allow
  aceTiers = {
    { ace = 'group.admin',   slots = 8 },
    { ace = 'cc.donator.t3', slots = 7 },
    { ace = 'cc.donator.t2', slots = 6 },
    { ace = 'cc.donator.t1', slots = 5 },
  },

  -- Hard-coded per-license overrides (useful for local testing).
  --   ['license:abcd...'] = 10,
  perLicense = {},
}


-- ============================================================================
-- Database
-- ============================================================================
Config.Database = {
  -- 'oxmysql' (Recommended) or 'custom' if you wire all DataProviders below.
  adapter = 'oxmysql',
  -- Auto-created on resource start. Schema: license PK, slots INT, note, ts.
  slotOverridesTable = 'cc_multichar_slots',
  ensureSchemaOnStart = true,
}


-- ============================================================================
-- The scene (singular)
-- ============================================================================
-- One scenario is used for every selector session. It is laid out as an
-- ensemble: every character + every empty slot becomes one ped placed by
-- the layout function.
--
-- The layout function receives (index, total) where total includes both
-- existing characters and empty slots, and returns a vector4 offset from
-- the scene anchor.
Config.Scene = {
  -- Time and weather override while the selector is open.
  weather = 'EXTRASUNNY',
  hour = 19,
  minute = 30,

  -- Where the ensemble stands. Absolute world coordinates (vec4).
  anchor = vector4(-1037.04, -2731.99, 19.45, 240.0),

  -- Camera. vec3 position + vec3 lookAt. fov is degrees (35..50 is cinematic).
  camera = {
    position = vector3(-1041.5, -2728.0, 21.0),
    lookAt   = vector3(-1037.04, -2731.99, 20.5),
    fov = 38.0,
  },

  -- Idle animation for every ped in the scene. Both character peds and
  -- empty-slot peds use this; the dict is loaded once.
  animation = {
    dict = 'amb@world_human_drinking@beer@male@idle_a',
    name = 'idle_a',
  },

  -- Ensemble layout. i is 1-indexed; total is the configured slot count.
  -- Returns a vector4 offset from anchor (x, y, z, heading).
  layout = function(i, total)
    local angle = ((i - 1) / math.max(total, 1)) * math.pi * 2
    local r = 1.7
    return vector4(math.cos(angle) * r, math.sin(angle) * r, -1.0,
                   (angle * 180.0 / math.pi) + 180.0)
  end,

  -- Screen-fade timings (ms) when entering / leaving the scene.
  fadeOutMs = 400,
  fadeInMs  = 600,
  spawnFadeOutMs = 500,
  spawnFadeInMs  = 800,
}


-- ============================================================================
-- Empty slots
-- ============================================================================
-- For every unused slot we spawn a random ped at reduced opacity. Hovering
-- shows a 3D "+" above them; clicking triggers Config.Handlers.onCreateCharacter.
Config.EmptySlot = {
  -- Ped models picked from at random per empty slot.
  pedModels = {
    'a_m_y_business_01',
    'a_m_y_business_02',
    'a_m_y_hipster_01',
    'a_f_y_business_01',
    'a_f_y_business_02',
    'a_f_y_hipster_01',
    'a_m_y_skater_01',
    'a_f_y_tourist_01',
  },

  -- Transparency for empty-slot peds. 0 = invisible, 255 = opaque.
  alpha = 110,

  -- 3D "+" text shown above an empty slot when hovered.
  plus = {
    text = '+',
    scale = 1.8,          -- DrawText scale; bigger = larger glyph
    color = { 255, 220, 130, 230 },  -- {r, g, b, a}
    heightOffset = 1.05,  -- world-units above ped origin
  },

  -- Outline tint applied via marker over the hovered empty slot.
  --   { r, g, b, a }   0..255
  hoverTint = { 255, 220, 130, 200 },
}


-- ============================================================================
-- Appearance preview (rendering the character's saved clothes on their ped)
-- ============================================================================
-- When the scene spawns a character ped, we optionally call into an
-- external appearance resource to dress the ped in their saved outfit.
-- If applyToPreview is false the ped uses default freemode clothing.
Config.Appearance = {
  applyToPreview = true,
  loader = {
    -- Common modern installs: illenium-appearance, fivem-appearance, bl_appearance.
    resource = 'illenium-appearance',
    setter   = 'setPedAppearance',
  },
}


-- ============================================================================
-- Hover / click detection
-- ============================================================================
Config.Hover = {
  -- Pixel radius around a ped's head for the cursor to register a hover.
  -- Higher = more forgiving but more likely to overlap between adjacent peds.
  hitRadiusPx = 80,

  -- Highlight tint over the hovered character ped (RGBA 0..255).
  charHoverTint = { 0, 220, 255, 200 },

  -- World-units above ped origin for the floating name label.
  labelHeightOffset = 1.05,
}


-- ============================================================================
-- Routing-bucket isolation
-- ============================================================================
-- While the selector is open the player is placed in a private routing
-- bucket so other players don't see the scene (peds, animations) and
-- ambient world traffic is suppressed for cinematic clarity.
Config.RoutingBucket = {
  enabled = true,
  bucketOffset = 100000,            -- buckets start at this id and increment
  populationEnabled = false,        -- suppress ambient NPCs / vehicles
  entityLockdown = 'inactive',      -- 'inactive' | 'relaxed' | 'strict'
  restoreToBucketOnSpawn = 0,       -- bucket the player returns to on spawn
}


-- ============================================================================
-- Hand-off recipes — wire the script into YOUR framework / spawn resource
-- ============================================================================
--
-- These two hooks define what happens at the two decision points:
--   1. "the player picked a character"
--   2. "the player clicked an empty slot to create one"
--
-- Each hook supports three modes:
--   'framework' — use the framework default below. For onCharacterSelected
--                 we just log the player in via the framework adapter and
--                 re-fire the native login event so existing spawn
--                 resources (qbx_spawn, qb-spawn, esx_spawn, etc.) take
--                 over. For onCreateCharacter we fire the most common
--                 community event for the detected framework.
--   'event'     — fire a custom Lua event you handle in your own resource
--   'export'    — call a custom export
--
-- For 'event' and 'export' you provide the name yourself.
Config.Handlers = {

  -- ===========================================================================
  -- Fires AFTER cc_multichar has logged the player in via the framework
  -- adapter and (if enabled) re-fired the framework's native login event.
  -- The selected character is still in their routing bucket UNTIL your spawn
  -- resource teleports them; we release the bucket as part of the login step.
  -- ===========================================================================
  onCharacterSelected = {
    -- 'framework' | 'event' | 'export'
    --
    -- 'framework' is a no-op: the adapter's framework.login() call has
    -- already fired the framework's native onPlayerLoaded event, which
    -- your existing spawn resource (qbx_spawn, qb-spawn, esx_spawn) is
    -- already listening for. This is the right choice for most servers.
    --
    -- 'event' fires `event` server-side with (src, character) AND
    -- `clientEvent` client-side with (character). Use this if you have a
    -- custom spawn resource that listens for our event.
    --
    -- 'export' calls exports[resource][name](src, character) server-side.
    mode = 'framework',

    event = 'cc_multichar:characterSelected',
    clientEvent = 'cc_multichar:client:characterSelected',

    export = { resource = '', name = '' },
  },

  -- ===========================================================================
  -- Fires when an empty slot is clicked. Your resource should open its
  -- creation flow (name + DOB + appearance editor), save the character,
  -- and then call `exports.cc_multichar:Reopen(src)` to refresh our
  -- selector with the new character visible.
  -- ===========================================================================
  onCreateCharacter = {
    mode = 'event', -- 'event' | 'export' | 'framework'

    -- For mode = 'event': we fire client-side AND server-side.
    --   Client side receives no arguments.
    --   Server side receives (src, slotIndex).
    event = 'cc_multichar:createRequested',
    clientEvent = 'cc_multichar:client:createRequested',

    -- For mode = 'export':
    --   server: exports[resource][name](src, slotIndex)
    --   client: exports[resource][name](slotIndex)
    export = { resource = '', name = '' },

    -- Framework defaults for mode == 'framework'.
    -- Most communities don't have a single "open creator" event so the
    -- defaults below point at popular conventions — adjust to match your
    -- install or just use mode = 'event' and wire your own resource.
    framework = {
      qbox   = 'qbx_core:client:openCreator',
      qbcore = 'qb-multicharacter:client:createCharacter',
      esx    = 'esx_multicharacter:openCreationMenu',
    },
  },
}


-- ============================================================================
-- Data providers (override built-in framework paths)
-- ============================================================================
-- Each function below is optional. When set, it fully replaces the built-in
-- implementation. Useful for non-standard schemas, in-memory tests, etc.
--
-- All run server-side.
--   customLoadCharacters(src, license)   -> array of character records
--   customDeleteCharacter(src, license, cid) -> boolean
--   customGetAppearance(src, cid)        -> appearance table (or nil)
--   customLoginCharacter(src, character) -> boolean (replaces adapter.login)
--   customGetSlotOverride(src, license)  -> number or nil
Config.DataProviders = {
  customLoadCharacters  = nil,
  customDeleteCharacter = nil,
  customGetAppearance   = nil,
  customLoginCharacter  = nil,
  customGetSlotOverride = nil,
}


-- ============================================================================
-- Security
-- ============================================================================
Config.Security = {
  requireAuthenticatedSession = true, -- drop events from players w/o a license
  audit = { enabled = true, print = true },
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


-- ============================================================================
-- Logging
-- ============================================================================
-- See shared/log.lua for the API: Log.debug('cat', 'fmt', ...) etc.
Config.Logging = {
  -- 'trace' | 'debug' | 'info' | 'warn' | 'error'
  level = 'info',

  -- Per-category override. Set to a level name, false (inherit), or 'off'.
  categories = {
    resource   = 'info',
    framework  = 'info',
    session    = 'debug',
    db         = 'debug',
    characters = 'debug',
    scene      = 'debug',
    hover      = 'info',
    selector   = 'info',
    security   = 'info',
  },

  console = { enabled = true, color = true, prefix = 'cc_multichar' },
}

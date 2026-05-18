--[[
  cc_multichar — Core configuration
  ---------------------------------------------------------------------------
  This file controls the resource at the highest level: which framework to
  bind to, how slots are allocated, where the appearance editor lives, and
  what hooks are fired when a character is selected.

  Every option below is documented inline. If a section is large it gets
  its own file (scenarios.lua, spawn.lua, ui.lua, security.lua, logging.lua).
]]

Config = Config or {}

-- =============================================================================
-- Framework binding
-- =============================================================================
-- 'auto'        : detect at runtime by checking GetResourceState for known cores
-- 'qbox'        : force qbx_core integration (modern QBCore fork)
-- 'qbcore'      : force qb-core integration
-- 'esx'         : force es_extended integration (uses identifier-suffix multichar)
-- 'standalone'  : no framework. You must wire all DataProviders below.
Config.Framework = 'auto'

-- =============================================================================
-- Auto-open on connect
-- =============================================================================
-- When true, the client requests the selector to open `AutoOpenDelayMs` ms
-- after this resource starts (post-loadscreen). Disable if another resource
-- (queue, mlo loader, MOTD) needs to run first.
Config.AutoOpenOnJoin = true
Config.AutoOpenDelayMs = 1500

-- =============================================================================
-- Character slot allocation
-- =============================================================================
-- Slots are resolved per-player using this precedence chain (highest first):
--   1. DataProviders.customGetSlotOverride(src, license)  if defined
--   2. row in `cc_multichar_slots` DB table for that license
--   3. Config.Slots.perLicense[license]                   exact match
--   4. first Config.Slots.aceTiers entry where IsPlayerAceAllowed matches
--   5. Config.Slots.default                               fallback
Config.Slots = {
  -- Baseline slots for everyone.
  default = 4,

  -- Tiered by ace permission. Evaluated top-to-bottom; first match wins.
  -- Add your ace rules to server.cfg, e.g.
  --   add_ace identifier.fivem:1234 cc.donator.t2 allow
  aceTiers = {
    { ace = 'group.admin',    slots = 8 },
    { ace = 'cc.donator.t3',  slots = 7 },
    { ace = 'cc.donator.t2',  slots = 6 },
    { ace = 'cc.donator.t1',  slots = 5 },
  },

  -- Hard-coded overrides by license. Useful for testing; the DB table is
  -- recommended for production so you don't redeploy config to grant slots.
  --   ['license:abcd1234...'] = 10,
  perLicense = {},
}

-- =============================================================================
-- Database
-- =============================================================================
-- adapter
--   'oxmysql'   : use the oxmysql resource (Recommended). Must start before us.
--   'custom'    : skip oxmysql entirely; you must wire all DataProviders below.
--
-- slotOverridesTable
--   Table name auto-created on resource start when ensureSchemaOnStart=true.
--   Schema: license VARCHAR(64) PK, slots INT, note VARCHAR(255), updated_at TS
--
-- ensureSchemaOnStart
--   Create the slot-overrides table if it doesn't exist. Safe to keep on.
Config.Database = {
  adapter = 'oxmysql',
  slotOverridesTable = 'cc_multichar_slots',
  ensureSchemaOnStart = true,
}

-- =============================================================================
-- Appearance loader (for the in-scene ped preview)
-- =============================================================================
-- The scenario engine spawns a ped per character. To render that ped with
-- the character's saved clothes/face/hair, we call into an external
-- appearance resource. illenium-appearance and fivem-appearance share this
-- export shape; qb-clothing uses a different one we fall back to.
--
-- applyToPreview
--   Master toggle. Set false to show only freemode peds with default clothes.
--
-- loader.resource / setter
--   The export `exports[resource][setter](nil, ped, appearance)` is called to
--   apply a fetched appearance table to a preview ped.
--
-- qbClothingFallback
--   If illenium-appearance data isn't available, server-side Characters.GetAppearance
--   falls back to querying `playerskins` (qb-clothing schema). Set false to disable.
Config.Appearance = {
  applyToPreview = true,
  loader = {
    resource = 'illenium-appearance',
    export   = 'getPedAppearance',
    setter   = 'setPedAppearance',
  },
  qbClothingFallback = true,
}

-- =============================================================================
-- Character creator handoff
-- =============================================================================
-- After the create form (name/DOB/gender/nationality) is submitted we hand
-- control to an external appearance editor for face & clothing. The editor
-- finishes asynchronously, then we resume with the spawn picker.
--
-- invocation
--   'callback' (Recommended for illenium-appearance, fivem-appearance):
--               export(function() ... end) — we pass a completion callback.
--   'blocking': export()                    — call yields until customize ends.
--   'manual'  : export()                    — user's editor calls
--               exports.cc_multichar:FinishAppearance(src) when finished.
Config.CharacterCreator = {
  resource = 'illenium-appearance',
  export   = 'startPlayerCustomization',
  invocation = 'callback',
}

-- =============================================================================
-- Data provider overrides
-- =============================================================================
-- Each entry below is optional. When set, the function fully replaces the
-- built-in framework path. Useful for:
--   - non-standard DB schemas
--   - multi-database routing
--   - faked/in-memory backends for testing
--
-- All functions are invoked server-side.
--
-- Signatures:
--   customLoadCharacters(src, license)
--     -> table[] of characters with fields: cid, firstname, lastname, name,
--        dob, gender ('m'|'f'), nationality, job, bank, cash, playtime
--
--   customCreateCharacter(src, license, info)
--     info = { firstname, lastname, dob, gender, nationality }
--     -> table — the same shape as a load result, representing the new char
--
--   customDeleteCharacter(src, license, cid)
--     -> boolean (true on success)
--
--   customGetLastLocation(src, cid)
--     -> vector4 or { x, y, z, w } or nil
--
--   customGetAppearance(src, cid)
--     -> table matching your appearance resource's expected shape, or nil
--
--   customLoginCharacter(src, character)
--     -> boolean. If not provided, the framework adapter (Qbox/QBCore/ESX)
--        handles login automatically.
--
--   customGetSlotOverride(src, license)
--     -> integer slot count, or nil to fall through to next precedence
--
--   customGetExtendedStats(src, cid)
--     -> table of stats to render on the character panel (see Config.Stats)
Config.DataProviders = {
  customLoadCharacters     = nil,
  customCreateCharacter    = nil,
  customDeleteCharacter    = nil,
  customGetLastLocation    = nil,
  customGetAppearance      = nil,
  customLoginCharacter     = nil,
  customGetSlotOverride    = nil,
  customGetExtendedStats   = nil,
}

-- =============================================================================
-- Login hooks
-- =============================================================================
-- Fired after a character successfully spawns. Other resources subscribe to
-- these events to trigger phone init, blip setup, inventory sync, etc.
--
-- generic.server fires with (src, character, spawnCoords)
-- generic.client fires with (character, spawnCoords)
--
-- fireNativeFrameworkEvent
--   When true we ALSO re-fire the active framework's own login event:
--     qbox    -> qbx_core:server:onPlayerLoaded
--     qbcore  -> QBCore:Server:OnPlayerLoaded
--     esx     -> esx:playerLoaded
--   so existing resources written against those events just work.
Config.LoginHooks = {
  generic = {
    server = 'cc_multichar:characterSelected',
    client = 'cc_multichar:client:characterReady',
  },
  fireNativeFrameworkEvent = true,
}

-- =============================================================================
-- Discord rich presence
-- =============================================================================
-- Presence is set during the selector phase only and (optionally) cleared
-- after spawn so other resources can manage it from there on.
--
-- enabled       Master toggle.
-- appId         Your Discord application id. Empty string disables presence.
-- largeImage    Asset key uploaded to your Discord app's Rich Presence Assets.
-- largeImageText Hover text on the large image.
-- smallImage / smallImageText  Same, for the corner overlay icon.
-- text.state    Right-side text. Default "Picking a character".
-- text.details  Left-side text. Falls back to Config.UI.serverName when empty.
-- clearOnSpawn  Clear our presence when the player spawns (Recommended true).
Config.Discord = {
  enabled = true,
  appId = '',
  largeImage = 'cc_logo',
  largeImageText = '',
  smallImage = '',
  smallImageText = '',
  text = {
    state = 'Picking a character',
    details = '',
  },
  clearOnSpawn = true,
}

-- =============================================================================
-- /switch — mid-game character switching
-- =============================================================================
-- When enabled, the player can run /switch to return to the selector without
-- disconnecting. The flow:
--   1. Client opens a focused NUI confirm modal.
--   2. On confirm, server checks cooldown.
--   3. Server asks the client to evaluate safe-zone rules.
--   4. On safe ack, server saves+logs out the current character and reopens
--      the selector.
--
-- cooldownSeconds   Time after a successful switch before another is allowed.
-- requireConfirm    Show the modal. False = instant on /switch (staff use).
-- safeZone.*        Rules evaluated client-side and acked back to server.
-- safeZone.customCheck  function(src) returning ok:bool, reason:string?
Config.Switch = {
  enabled = true,
  command = 'switch',
  cooldownSeconds = 60,
  requireConfirm = true,
  safeZone = {
    blockInCombat       = true,
    blockInVehicle      = true,
    blockCuffed         = true,
    blockDead           = true,
    blockWhileSwimming  = true,
    customCheck = nil,
  },
}

-- =============================================================================
-- Cinematic skip (hold key to fast-forward intro)
-- =============================================================================
-- enabled       Master toggle.
-- controlId     FiveM control index for the hold key. Defaults to 22 (SPACE/SPRINT).
--               See: https://docs.fivem.net/docs/game-references/controls/
-- holdMs        How long the key must be held to commit the skip (debounces taps).
-- hintText      Text rendered onscreen during the intro. Empty = no hint.
Config.IntroSkip = {
  enabled = true,
  controlId = 22,
  holdMs = 600,
  hintText = 'Hold [SPACE] to skip intro',
}

-- =============================================================================
-- Private instance (routing bucket isolation)
-- =============================================================================
-- While the selector is open the player is moved into a dedicated routing
-- bucket. Effects:
--   - Other players cannot see the cinematic scene (peds, vehicles, props).
--   - Other players cannot see the player ped or their blip.
--   - With populationEnabled=false, ambient world traffic is suppressed in
--     the bucket so no NPC sedans drive through the police chase scene.
--
-- enabled
--   Master toggle. When false, players stay in their current bucket and
--   nearby players may see scene entities. Recommended: true.
--
-- bucketOffset
--   Buckets are allocated sequentially starting at this value. Choose a
--   number high enough to not collide with other resources that use
--   routing buckets (e.g. mlo loaders, properties, gangs). Default 100000.
--
-- populationEnabled
--   When false, suppresses NPC + vehicle population in the bucket.
--   Strongly recommended for cinematic clarity. Default false.
--
-- entityLockdown
--   GTA routing-bucket entity lockdown mode for the bucket:
--     'inactive' (default): no extra restrictions
--     'relaxed'           : only the bucket's owner can create networked entities
--     'strict'            : no networked entity creation at all
--   For a cinematic selector with only LOCAL entities, 'inactive' is fine.
--   Set 'strict' if you want a belt-and-suspenders guarantee that nothing
--   leaks out of the bucket. Default 'inactive'.
--
-- restoreToBucketOnSpawn
--   Bucket the player is moved to when they finalize spawn. 0 (default)
--   is the main world. Override to a custom bucket if your server runs
--   tiered shards / instances.
Config.RoutingBucket = {
  enabled = true,
  bucketOffset = 100000,
  populationEnabled = false,
  entityLockdown = 'inactive',
  restoreToBucketOnSpawn = 0,
}

-- =============================================================================
-- Extended stats panel
-- =============================================================================
-- Toggles which rows appear on the character panel after click-selection.
-- Each toggle independently controls a stat row; setting false hides it.
--
-- Standard pack — pulled from the players.metadata / players.money / players.job
-- columns (QBCore/Qbox) or equivalent (ESX).
Config.Stats = {
  showPlaytime       = true,
  showLastSeen       = true,
  showJobRank        = true,
  showMoney          = true,
  showKD             = true,
  showDistanceDriven = true,

  -- Asset & record pack — pulled from the common QBCore-ecosystem tables.
  -- If your server uses different table names, override via
  -- Config.DataProviders.customGetExtendedStats.
  showOwnedVehicles   = true,
  showFavoriteVehicle = true,
  showOwnedProperties = true,
  showCriminalRecord  = true,
}

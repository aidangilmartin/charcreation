--[[
  cc_multichar — Logging configuration
  ---------------------------------------------------------------------------
  A structured, multi-sink logger used throughout the resource. Read this
  file top to bottom: every option is documented inline with its type,
  default, accepted values, and what it controls at runtime.

  How logs are emitted
    Log.trace(category, fmt, ...)   -- noisy per-frame detail (hover ticks, etc.)
    Log.debug(category, fmt, ...)   -- step-by-step lifecycle info
    Log.info(category, fmt, ...)    -- high-level milestones (open, spawn, login)
    Log.warn(category, fmt, ...)    -- recoverable problems
    Log.error(category, fmt, ...)   -- unrecoverable errors / audit-worthy
    Log.timer(category, label)      -- returns fn() to stop and log elapsed ms
    Log.dump(category, label, tbl)  -- pretty-prints a table at debug level

  Levels are filtered globally (Config.Logging.level) and per-category
  (Config.Logging.categories). Categories below their threshold are dropped
  cheaply with no string formatting cost.
]]

Config = Config or {}

Config.Logging = {
  -- =========================================================================
  -- Global minimum level. Anything below this is dropped resource-wide.
  --
  -- Values: 'trace' | 'debug' | 'info' | 'warn' | 'error'
  -- Default: 'info'
  --
  -- Suggested use:
  --   'trace' — diagnosing a single bug, only briefly. Floods the console.
  --   'debug' — active development. See every state transition.
  --   'info'  — production-quiet. Milestones only.
  --   'warn'  — only show problems.
  --   'error' — silent unless something breaks.
  -- =========================================================================
  level = 'info',

  -- =========================================================================
  -- Per-category overrides. A category log only fires if its effective level
  -- (max(global, category)) is at-or-below the call's level.
  --
  -- Set a category to:
  --   false / nil — inherit the global level
  --   a level name — raise that category to its own threshold
  --   'off'       — fully silence that category, even at trace
  --
  -- The categories below are the ones the resource actually emits. Adding
  -- new ones in code is free; unknown categories inherit the global level.
  -- =========================================================================
  categories = {
    -- Lifecycle ----------------------------------------------------------
    resource   = 'info',   -- onResourceStart/Stop, config validation
    framework  = 'info',   -- detected framework, adapter calls
    session    = 'debug',  -- per-player session state transitions
    network    = 'debug',  -- inbound/outbound events between server & client

    -- Data ---------------------------------------------------------------
    db         = 'debug',  -- queries, query timing, query errors
    characters = 'debug',  -- load / create / delete / appearance
    slots      = 'info',   -- slot resolution per player

    -- Visuals ------------------------------------------------------------
    scene      = 'debug',  -- scene begin/end, cam moves, weather/time
    scenario   = 'debug',  -- scenario pick, role spawning, vehicle seating
    hover      = 'info',   -- raycasts can spam at trace; keep info+
    spawn      = 'debug',  -- spawn picker → finalize handoff
    audio      = 'debug',  -- ambient SFX scenes, sound loops

    -- Flow ---------------------------------------------------------------
    selector   = 'info',   -- open / close / re-open
    creator    = 'debug',  -- create form → appearance editor handoff
    switch     = 'info',   -- /switch flow, safe-zone outcomes
    discord    = 'debug',  -- presence updates

    -- Safety -------------------------------------------------------------
    security   = 'info',   -- rate-limits, invalid cids, ace checks
    audit      = 'warn',   -- audit-worthy events (rate limit blocks, etc.)
  },

  -- =========================================================================
  -- Where logs go. Multiple sinks can be enabled at once.
  -- =========================================================================
  sinks = {
    -- Standard `print` to the FXServer console / F8 client console.
    --   color: ANSI-color codes auto-applied per level (^1 red, ^3 yellow, ^5 blue, ^2 green).
    --   prefix: appended to every line, e.g. "[cc_multichar][debug][scene]"
    console = {
      enabled = true,
      color = true,
      prefix = 'cc_multichar',
      -- Include the source line in messages (file:line). Lightly expensive.
      includeSource = false,
    },

    -- Server-only file sink. Rotates by size; appended to from server only.
    -- Path is relative to the resource folder. Set enabled=false to disable.
    file = {
      enabled = false,
      path = 'logs/cc_multichar.log',
      maxBytes = 2 * 1024 * 1024, -- 2 MB before rotating to .log.1
      keep = 3,                   -- keep .log.1, .log.2, .log.3
      flushEveryLine = false,     -- safer but slower
    },

    -- Server-only Discord webhook. Posts errors + audit events. Optional.
    webhook = {
      enabled = false,
      url = '',
      -- Only forward at or above this level
      minLevel = 'warn',
      username = 'cc_multichar',
      avatarUrl = '',
      -- Don't spam: aggregate identical messages within this window
      dedupeWindowMs = 5000,
    },
  },

  -- =========================================================================
  -- Performance & diagnostics
  -- =========================================================================
  performance = {
    -- Wrap DB queries in Log.timer and emit slow-query warnings.
    logSlowQueries = true,
    slowQueryThresholdMs = 25,

    -- Log scenario startup timing (model load, ped/vehicle spawn, total).
    logScenarioStartup = true,

    -- Log hover raycast hit-rate (every 10 seconds while in selector).
    logHoverStats = false,
  },

  -- =========================================================================
  -- Client-side in-game debug overlay. Hold a key combo to show live state:
  -- active scenario id, hovered cid, selected cid, FPS, ped count, sound loop.
  -- =========================================================================
  overlay = {
    enabled = false,
    toggleControl = 244, -- INPUT_INTERACTION_MENU (M by default)
    fontScale = 0.32,
    showFps = true,
    showHover = true,
    showSelection = true,
    showScenario = true,
    showNetwork = true, -- last 5 inbound/outbound events
  },

  -- =========================================================================
  -- Boot-time config sanity check. Prints a summary of detected framework,
  -- DB availability, slot tier list, scenario count, and any missing required
  -- values. Useful when something is silently wrong.
  -- =========================================================================
  validateOnBoot = true,
}

-- Backwards-compat: keep Config.Debug as a master switch for 'verbose mode'.
-- When true, raises the global level to 'debug' if it would otherwise be 'info'.
-- Keep at false for production.
Config.Debug = false

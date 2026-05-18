-- Structured logger with levels, categories, and pluggable sinks.
-- See config/logging.lua for the user-facing knobs.

Log = Log or {}

local LEVELS = { trace = 10, debug = 20, info = 30, warn = 40, error = 50, off = 100 }
local LEVEL_COLOR = {
  trace = '^5', -- blue
  debug = '^7', -- white
  info  = '^2', -- green
  warn  = '^3', -- yellow
  error = '^1', -- red
}

local function levelValue(name)
  if not name then return LEVELS.info end
  return LEVELS[name] or LEVELS.info
end

local function effectiveLevel(category)
  local cfg = Config.Logging
  if not cfg then return LEVELS.info end
  local global = levelValue(cfg.level)
  if Config.Debug and global > LEVELS.debug then global = LEVELS.debug end
  if not category then return global end
  local cat = cfg.categories and cfg.categories[category]
  if cat == false or cat == nil then return global end
  if cat == 'off' then return LEVELS.off end
  return math.max(global, levelValue(cat))
end

local isServer = IsDuplicityVersion and IsDuplicityVersion() or false

-- Sink: console -----------------------------------------------------------

local function consoleSink(level, category, message)
  local cfg = Config.Logging and Config.Logging.sinks and Config.Logging.sinks.console
  if not cfg or not cfg.enabled then return end
  local color = cfg.color and LEVEL_COLOR[level] or ''
  local reset = cfg.color and '^0' or ''
  local prefix = cfg.prefix or 'cc_multichar'
  print(('%s[%s][%s][%s]%s %s'):format(color, prefix, level, category or 'general', reset, message))
end

-- Sink: file (server only) ------------------------------------------------

local fileHandle
local fileSize = 0

local function ensureFileHandle()
  if not isServer then return nil end
  local cfg = Config.Logging and Config.Logging.sinks and Config.Logging.sinks.file
  if not cfg or not cfg.enabled or not cfg.path or cfg.path == '' then return nil end
  if fileHandle then return fileHandle end

  local resPath = GetResourcePath(GetCurrentResourceName())
  local fullPath = resPath .. '/' .. cfg.path
  -- Make directory if needed (best-effort; ignores errors)
  local dir = fullPath:match('^(.+)/[^/]+$')
  if dir then os.execute(('mkdir -p "%s" 2>/dev/null || mkdir "%s" 2>NUL'):format(dir, dir:gsub('/', '\\'))) end
  fileHandle = io.open(fullPath, 'a+')
  if fileHandle then
    fileHandle:seek('end')
    fileSize = fileHandle:seek() or 0
  end
  return fileHandle
end

local function rotateFile()
  local cfg = Config.Logging.sinks.file
  if not fileHandle then return end
  fileHandle:close()
  fileHandle = nil
  local resPath = GetResourcePath(GetCurrentResourceName())
  local base = resPath .. '/' .. cfg.path
  for i = (cfg.keep or 3) - 1, 1, -1 do
    os.rename(base .. '.' .. i, base .. '.' .. (i + 1))
  end
  os.rename(base, base .. '.1')
  fileSize = 0
end

local function fileSink(level, category, message)
  if not isServer then return end
  local cfg = Config.Logging and Config.Logging.sinks and Config.Logging.sinks.file
  if not cfg or not cfg.enabled then return end
  local fh = ensureFileHandle()
  if not fh then return end
  local line = ('%s | %-5s | %-10s | %s\n'):format(os.date('!%Y-%m-%dT%H:%M:%SZ'), level, category or 'general', message)
  fh:write(line)
  if cfg.flushEveryLine then fh:flush() end
  fileSize = fileSize + #line
  if cfg.maxBytes and fileSize >= cfg.maxBytes then rotateFile() end
end

-- Sink: webhook (server only) --------------------------------------------

local webhookLastSeen = {}

local function webhookSink(level, category, message)
  if not isServer then return end
  local cfg = Config.Logging and Config.Logging.sinks and Config.Logging.sinks.webhook
  if not cfg or not cfg.enabled or not cfg.url or cfg.url == '' then return end
  if levelValue(level) < levelValue(cfg.minLevel or 'warn') then return end

  local key = level .. '|' .. (category or '') .. '|' .. message
  local now = GetGameTimer()
  local last = webhookLastSeen[key]
  if last and (now - last) < (cfg.dedupeWindowMs or 5000) then return end
  webhookLastSeen[key] = now

  local body = json.encode({
    username = cfg.username,
    avatar_url = cfg.avatarUrl ~= '' and cfg.avatarUrl or nil,
    content = ('[%s][%s] %s'):format(level, category or 'general', message),
  })
  PerformHttpRequest(cfg.url, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

-- Public API --------------------------------------------------------------

local function formatMessage(fmt, ...)
  local n = select('#', ...)
  if n == 0 then return tostring(fmt) end
  local ok, formatted = pcall(string.format, fmt, ...)
  if ok then return formatted end
  local parts = { tostring(fmt) }
  for i = 1, n do parts[i + 1] = tostring(select(i, ...)) end
  return table.concat(parts, ' ')
end

local function emit(level, category, fmt, ...)
  local lvl = levelValue(level)
  if lvl < effectiveLevel(category) then return end
  local message = formatMessage(fmt, ...)
  consoleSink(level, category, message)
  fileSink(level, category, message)
  webhookSink(level, category, message)
end

function Log.trace(category, fmt, ...) emit('trace', category, fmt, ...) end
function Log.debug(category, fmt, ...) emit('debug', category, fmt, ...) end
function Log.info(category, fmt, ...)  emit('info',  category, fmt, ...) end
function Log.warn(category, fmt, ...)  emit('warn',  category, fmt, ...) end
function Log.error(category, fmt, ...) emit('error', category, fmt, ...) end

function Log.timer(category, label)
  local start = GetGameTimer()
  return function(extraFmt, ...)
    local elapsed = GetGameTimer() - start
    local extra = extraFmt and (' ' .. formatMessage(extraFmt, ...)) or ''
    local slow = Config.Logging.performance and Config.Logging.performance.slowQueryThresholdMs or 25
    if elapsed >= slow then
      Log.warn(category, '%s took %dms%s', label, elapsed, extra)
    else
      Log.debug(category, '%s took %dms%s', label, elapsed, extra)
    end
    return elapsed
  end
end

local function dumpTable(tbl, indent)
  indent = indent or ''
  if type(tbl) ~= 'table' then return tostring(tbl) end
  local lines = { '{' }
  for k, v in pairs(tbl) do
    local key = type(k) == 'number' and ('[' .. k .. ']') or tostring(k)
    if type(v) == 'table' then
      lines[#lines + 1] = indent .. '  ' .. key .. ' = ' .. dumpTable(v, indent .. '  ')
    else
      local sval = type(v) == 'string' and ('"' .. v .. '"') or tostring(v)
      lines[#lines + 1] = indent .. '  ' .. key .. ' = ' .. sval
    end
  end
  lines[#lines + 1] = indent .. '}'
  return table.concat(lines, '\n')
end

function Log.dump(category, label, tbl)
  if levelValue('debug') < effectiveLevel(category) then return end
  Log.debug(category, '%s = %s', label, dumpTable(tbl))
end

-- Boot-time sanity check -------------------------------------------------

function Log.ValidateConfig()
  if not Config.Logging or not Config.Logging.validateOnBoot then return end
  local problems = {}

  local function check(cond, msg) if not cond then problems[#problems + 1] = msg end end

  check(type(Config.Slots) == 'table', 'Config.Slots is missing')
  check(type(Config.Spawn) == 'table', 'Config.Spawn is missing')
  check(type(Config.Spawn.staticPoints) == 'table' and #Config.Spawn.staticPoints > 0,
        'Config.Spawn.staticPoints is empty — players will have no spawn option')
  check(type(Config.Scenarios) == 'table' and type(Config.Scenarios.scenarios) == 'table' and #Config.Scenarios.scenarios > 0,
        'Config.Scenarios.scenarios is empty — no scenes to display')
  check(type(Config.Security) == 'table' and type(Config.Security.rateLimit) == 'table',
        'Config.Security.rateLimit is missing')
  check(type(Config.UI) == 'table' and type(Config.UI.theme) == 'table',
        'Config.UI / Config.UI.theme is missing')

  if Config.CharacterCreator and (Config.CharacterCreator.resource == 'illenium-appearance' or Config.CharacterCreator.resource == 'qb-clothing') then
    if GetResourceState and GetResourceState(Config.CharacterCreator.resource) ~= 'started' then
      Log.warn('resource', 'CharacterCreator resource "%s" is not started — Create flow will fail.', Config.CharacterCreator.resource)
    end
  end

  Log.info('resource', 'config validation: %d issue(s) found', #problems)
  for _, p in ipairs(problems) do Log.error('resource', 'config issue: %s', p) end
end

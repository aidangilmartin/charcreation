-- Minimal structured logger.
--
-- Usage
--   Log.trace('hover', 'cursor %d %d', x, y)
--   Log.debug('scene', 'started')
--   Log.info('selector', 'open src=%s chars=%d', src, n)
--   Log.warn('db', 'slow query: %s', sql)
--   Log.error('framework', 'no adapter for %s', name)

Log = Log or {}

local LEVELS = { trace = 10, debug = 20, info = 30, warn = 40, error = 50, off = 100 }
local LEVEL_COLOR = { trace = '^5', debug = '^7', info = '^2', warn = '^3', error = '^1' }

local function levelValue(name) return LEVELS[name or 'info'] or LEVELS.info end

local function effectiveLevel(category)
  local cfg = Config and Config.Logging
  if not cfg then return LEVELS.info end
  local floor = levelValue(cfg.level)
  if Config.Debug and floor > LEVELS.debug then floor = LEVELS.debug end
  if not category then return floor end
  local cat = cfg.categories and cfg.categories[category]
  if cat == false or cat == nil then return floor end
  if cat == 'off' then return LEVELS.off end
  return math.max(floor, levelValue(cat))
end

local function format(fmt, ...)
  if select('#', ...) == 0 then return tostring(fmt) end
  local ok, res = pcall(string.format, fmt, ...)
  if ok then return res end
  local parts = { tostring(fmt) }
  for i = 1, select('#', ...) do parts[i + 1] = tostring(select(i, ...)) end
  return table.concat(parts, ' ')
end

local function emit(level, category, fmt, ...)
  if levelValue(level) < effectiveLevel(category) then return end
  local cfg = Config.Logging.console or {}
  if not cfg.enabled then return end
  local color = cfg.color and LEVEL_COLOR[level] or ''
  local reset = cfg.color and '^0' or ''
  local prefix = cfg.prefix or 'cc_multichar'
  print(('%s[%s][%s][%s]%s %s'):format(color, prefix, level, category or 'general', reset, format(fmt, ...)))
end

function Log.trace(c, f, ...) emit('trace', c, f, ...) end
function Log.debug(c, f, ...) emit('debug', c, f, ...) end
function Log.info(c, f, ...)  emit('info',  c, f, ...) end
function Log.warn(c, f, ...)  emit('warn',  c, f, ...) end
function Log.error(c, f, ...) emit('error', c, f, ...) end

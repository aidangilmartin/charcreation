DB = DB or {}

local function hasOx()
  return Config.Database.adapter == 'oxmysql' and GetResourceState('oxmysql') == 'started'
end

function DB.Available()
  return hasOx()
end

local function timed(label, fn)
  if not (Config.Logging and Config.Logging.performance and Config.Logging.performance.logSlowQueries) then
    return fn()
  end
  local t = Log.timer('db', label)
  local result = fn()
  t()
  return result
end

function DB.Query(sql, params)
  if not hasOx() then return nil end
  Log.trace('db', 'query: %s', sql)
  return timed('query', function() return MySQL.query.await(sql, params or {}) end)
end

function DB.Scalar(sql, params)
  if not hasOx() then return nil end
  Log.trace('db', 'scalar: %s', sql)
  return timed('scalar', function() return MySQL.scalar.await(sql, params or {}) end)
end

function DB.Insert(sql, params)
  if not hasOx() then return 0 end
  Log.trace('db', 'insert: %s', sql)
  return timed('insert', function() return MySQL.insert.await(sql, params or {}) or 0 end)
end

function DB.Execute(sql, params)
  if not hasOx() then return 0 end
  Log.trace('db', 'execute: %s', sql)
  return timed('execute', function() return MySQL.update.await(sql, params or {}) or 0 end)
end

function DB.EnsureSchema()
  if not Config.Database.ensureSchemaOnStart or not hasOx() then return end
  local table = Config.Database.slotOverridesTable
  DB.Execute(([[
    CREATE TABLE IF NOT EXISTS `%s` (
      `license` VARCHAR(64) NOT NULL,
      `slots` INT NOT NULL,
      `note` VARCHAR(255) NULL,
      `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]]):format(table))
end

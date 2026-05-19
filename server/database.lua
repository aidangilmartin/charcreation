DB = DB or {}

local function hasOx()
  return Config.Database.adapter == 'oxmysql' and GetResourceState('oxmysql') == 'started'
end

function DB.Available() return hasOx() end

function DB.Query(sql, params)
  if not hasOx() then return nil end
  return MySQL.query.await(sql, params or {})
end

function DB.Scalar(sql, params)
  if not hasOx() then return nil end
  return MySQL.scalar.await(sql, params or {})
end

function DB.Execute(sql, params)
  if not hasOx() then return 0 end
  return MySQL.update.await(sql, params or {}) or 0
end

function DB.EnsureSchema()
  if not Config.Database.ensureSchemaOnStart or not hasOx() then return end
  local t = Config.Database.slotOverridesTable
  DB.Execute(([[
    CREATE TABLE IF NOT EXISTS `%s` (
      `license`    VARCHAR(64) NOT NULL,
      `slots`      INT NOT NULL,
      `note`       VARCHAR(255) NULL,
      `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (`license`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  ]]):format(t))
end

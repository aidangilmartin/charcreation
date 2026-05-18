Characters = Characters or {}

local function decodeJson(value, fallback)
  if value == nil then return fallback end
  if type(value) ~= 'string' then return value end
  local ok, decoded = pcall(json.decode, value)
  if ok and decoded ~= nil then return decoded end
  return fallback
end

local function uuidLite()
  return string.format(
    '%x%x%x%x',
    math.random(0, 0xffff),
    math.random(0, 0xffff),
    math.random(0, 0xffff),
    os.time() & 0xffff
  )
end

local function makeCitizenId()
  -- QBCore-style: 3 letters + 5 digits
  local letters = ''
  for _ = 1, 3 do
    letters = letters .. string.char(math.random(65, 90))
  end
  return letters .. tostring(math.random(10000, 99999))
end

-- Returns a list of normalized characters for the player.
function Characters.Load(src, license)
  if type(Config.DataProviders.customLoadCharacters) == 'function' then
    local ok, rows = pcall(Config.DataProviders.customLoadCharacters, src, license)
    if ok and type(rows) == 'table' then return rows end
  end

  local fw = CC.DetectFramework()
  if fw == 'qbox' or fw == 'qbcore' then
    local rows = DB.Query(
      'SELECT citizenid, charinfo, money, job, metadata, position FROM players WHERE license = ? ORDER BY last_updated DESC',
      { license }
    ) or {}
    local out = {}
    for i = 1, #rows do
      local r = rows[i]
      local info = decodeJson(r.charinfo, {}) or {}
      local money = decodeJson(r.money, {}) or {}
      local job = decodeJson(r.job, {}) or {}
      local meta = decodeJson(r.metadata, {}) or {}
      out[#out + 1] = {
        cid = tostring(r.citizenid),
        firstname = info.firstname or 'Unknown',
        lastname = info.lastname or 'Citizen',
        name = ((info.firstname or 'Unknown') .. ' ' .. (info.lastname or 'Citizen')),
        dob = info.birthdate or 'Unknown',
        gender = info.gender == 1 and 'f' or 'm',
        nationality = info.nationality or 'Unknown',
        job = job.label or job.name or 'Unemployed',
        bank = tonumber(money.bank) or 0,
        cash = tonumber(money.cash) or 0,
        playtime = tonumber(meta.playtime) or 0,
      }
    end
    return out
  end

  if fw == 'esx' then
    -- ESX multichar convention: identifier is license + ':' + slot index
    local rows = DB.Query(
      "SELECT identifier, firstname, lastname, dateofbirth, sex, accounts, job FROM users WHERE identifier LIKE CONCAT(?, ':%')",
      { license }
    ) or {}
    local out = {}
    for i = 1, #rows do
      local r = rows[i]
      local accounts = decodeJson(r.accounts, {}) or {}
      out[#out + 1] = {
        cid = tostring(r.identifier),
        firstname = r.firstname or 'Unknown',
        lastname = r.lastname or 'Citizen',
        name = ((r.firstname or 'Unknown') .. ' ' .. (r.lastname or 'Citizen')),
        dob = r.dateofbirth or 'Unknown',
        gender = r.sex or 'm',
        nationality = 'Unknown',
        job = r.job or 'Unemployed',
        bank = tonumber(accounts.bank) or 0,
        cash = tonumber(accounts.money) or 0,
        playtime = 0,
      }
    end
    return out
  end

  return {}
end

function Characters.Delete(src, license, cid)
  if type(Config.DataProviders.customDeleteCharacter) == 'function' then
    local ok, deleted = pcall(Config.DataProviders.customDeleteCharacter, src, license, cid)
    if ok then return deleted == true end
  end

  local fw = CC.DetectFramework()
  if fw == 'qbox' or fw == 'qbcore' then
    -- Cascade delete from common dependent tables. Extend as needed.
    DB.Execute('DELETE FROM player_vehicles WHERE citizenid = ?', { cid })
    DB.Execute('DELETE FROM playerskins WHERE citizenid = ?', { cid })
    DB.Execute('DELETE FROM player_houses WHERE citizenid = ?', { cid })
    DB.Execute('DELETE FROM apartments WHERE citizenid = ?', { cid })
    DB.Execute('DELETE FROM bank_accounts_new WHERE id = ?', { cid })
    return DB.Execute('DELETE FROM players WHERE citizenid = ? AND license = ?', { cid, license }) > 0
  end

  if fw == 'esx' then
    DB.Execute('DELETE FROM owned_vehicles WHERE owner = ?', { cid })
    DB.Execute('DELETE FROM user_licenses WHERE owner = ?', { cid })
    return DB.Execute('DELETE FROM users WHERE identifier = ?', { cid }) > 0
  end

  return false
end

function Characters.Create(src, license, info)
  if type(Config.DataProviders.customCreateCharacter) == 'function' then
    local ok, created = pcall(Config.DataProviders.customCreateCharacter, src, license, info)
    if ok and type(created) == 'table' then return created end
  end

  local fw = CC.DetectFramework()
  local cid

  if fw == 'qbox' then
    -- qbx_core.Login handles new character creation when newData is provided.
    cid = makeCitizenId()
    local adapter = CC.Adapter()
    if adapter and adapter.login then
      local newData = {
        citizenid = cid,
        charinfo = {
          firstname = info.firstname,
          lastname = info.lastname,
          birthdate = info.dob,
          gender = info.gender == 'f' and 1 or 0,
          nationality = info.nationality,
        },
      }
      -- We don't actually Login during creation flow — server records
      -- the seed and we'll spawn after appearance & spawn select.
      return {
        cid = cid,
        firstname = info.firstname,
        lastname = info.lastname,
        name = info.firstname .. ' ' .. info.lastname,
        dob = info.dob,
        gender = info.gender,
        nationality = info.nationality,
        job = 'Unemployed',
        bank = 0,
        cash = 0,
        playtime = 0,
        _seed = newData,
      }
    end
  elseif fw == 'qbcore' then
    cid = makeCitizenId()
    return {
      cid = cid,
      firstname = info.firstname,
      lastname = info.lastname,
      name = info.firstname .. ' ' .. info.lastname,
      dob = info.dob,
      gender = info.gender,
      nationality = info.nationality,
      job = 'Unemployed',
      bank = 0, cash = 0, playtime = 0,
      _seed = {
        citizenid = cid,
        charinfo = {
          firstname = info.firstname,
          lastname = info.lastname,
          birthdate = info.dob,
          gender = info.gender == 'f' and 1 or 0,
          nationality = info.nationality,
        },
      },
    }
  elseif fw == 'esx' then
    -- Determine next free slot suffix
    local rows = DB.Query("SELECT identifier FROM users WHERE identifier LIKE CONCAT(?, ':%')", { license }) or {}
    local nextSlot = (#rows) + 1
    local identifier = license .. ':' .. tostring(nextSlot)
    DB.Insert(
      'INSERT INTO users (identifier, accounts, firstname, lastname, dateofbirth, sex) VALUES (?, ?, ?, ?, ?, ?)',
      {
        identifier,
        json.encode({ money = 0, bank = 0, black_money = 0 }),
        info.firstname,
        info.lastname,
        info.dob,
        info.gender,
      }
    )
    return {
      cid = identifier,
      firstname = info.firstname, lastname = info.lastname,
      name = info.firstname .. ' ' .. info.lastname,
      dob = info.dob, gender = info.gender, nationality = info.nationality or 'Unknown',
      job = 'Unemployed', bank = 0, cash = 0, playtime = 0,
    }
  end

  return nil
end

function Characters.GetLastLocation(src, cid)
  if type(Config.DataProviders.customGetLastLocation) == 'function' then
    local ok, loc = pcall(Config.DataProviders.customGetLastLocation, src, cid)
    if ok and type(loc) == 'vector4' then return loc end
    if ok and type(loc) == 'table' and loc.x and loc.y and loc.z then
      return vec4(loc.x + 0.0, loc.y + 0.0, loc.z + 0.0, (loc.w or loc.heading or 0.0) + 0.0)
    end
  end

  local fw = CC.DetectFramework()
  if fw == 'qbox' or fw == 'qbcore' then
    local raw = DB.Scalar('SELECT position FROM players WHERE citizenid = ? LIMIT 1', { cid })
    local pos = decodeJson(raw, nil)
    if type(pos) == 'table' and pos.x and pos.y and pos.z then
      return vec4(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, (pos.w or 0.0) + 0.0)
    end
  end

  return nil
end

function Characters.GetExtendedStats(src, cid)
  if type(Config.DataProviders.customGetExtendedStats) == 'function' then
    local ok, stats = pcall(Config.DataProviders.customGetExtendedStats, src, cid)
    if ok and type(stats) == 'table' then return stats end
  end

  if not DB.Available() then return {} end

  local stats = {}
  local cfg = Config.Stats or {}
  local fw = CC.DetectFramework()

  if fw == 'qbox' or fw == 'qbcore' then
    local row = DB.Query('SELECT charinfo, metadata, money, job, last_updated FROM players WHERE citizenid = ? LIMIT 1', { cid })
    if row and row[1] then
      local r = row[1]
      local meta = decodeJson(r.metadata, {}) or {}
      local money = decodeJson(r.money, {}) or {}
      local job = decodeJson(r.job, {}) or {}

      if cfg.showPlaytime then stats.playtimeMinutes = tonumber(meta.playtime) or 0 end
      if cfg.showLastSeen then stats.lastSeen = r.last_updated end
      if cfg.showJobRank then
        stats.jobName = job.label or job.name
        stats.jobGrade = job.grade and (job.grade.name or job.grade.level)
      end
      if cfg.showMoney then
        stats.cash = tonumber(money.cash) or 0
        stats.bank = tonumber(money.bank) or 0
      end
      if cfg.showKD then
        local kills = tonumber(meta.kills) or 0
        local deaths = tonumber(meta.deaths) or 0
        stats.kills = kills; stats.deaths = deaths
        stats.kd = deaths > 0 and (kills / deaths) or kills
      end
      if cfg.showDistanceDriven then stats.distanceDrivenKm = tonumber(meta.distanceDriven) or 0 end

      if cfg.showOwnedVehicles then
        stats.ownedVehicles = DB.Scalar('SELECT COUNT(*) FROM player_vehicles WHERE citizenid = ?', { cid }) or 0
      end
      if cfg.showFavoriteVehicle then
        local fav = DB.Query([[
          SELECT vehicle, COUNT(*) AS c FROM player_vehicles
          WHERE citizenid = ? GROUP BY vehicle ORDER BY c DESC LIMIT 1
        ]], { cid })
        if fav and fav[1] then stats.favoriteVehicle = fav[1].vehicle end
      end
      if cfg.showOwnedProperties then
        local houses = DB.Scalar('SELECT COUNT(*) FROM player_houses WHERE citizenid = ?', { cid }) or 0
        local apts = DB.Scalar('SELECT COUNT(*) FROM apartments WHERE citizenid = ?', { cid }) or 0
        stats.ownedProperties = (tonumber(houses) or 0) + (tonumber(apts) or 0)
      end
      if cfg.showCriminalRecord then
        -- mdt-style citations table; fallback gracefully if missing
        local ok, count = pcall(DB.Scalar, 'SELECT COUNT(*) FROM mdt_citations WHERE citizenid = ?', { cid })
        if ok and type(count) == 'number' then stats.citations = count end
      end
    end
  elseif fw == 'esx' then
    local row = DB.Query('SELECT job_grade FROM users WHERE identifier = ? LIMIT 1', { cid })
    if row and row[1] then
      if cfg.showJobRank then stats.jobGrade = row[1].job_grade end
    end
    if cfg.showOwnedVehicles then
      stats.ownedVehicles = DB.Scalar('SELECT COUNT(*) FROM owned_vehicles WHERE owner = ?', { cid }) or 0
    end
  end

  return stats
end

function Characters.GetAppearance(src, cid)
  if type(Config.DataProviders.customGetAppearance) == 'function' then
    local ok, a = pcall(Config.DataProviders.customGetAppearance, src, cid)
    if ok and type(a) == 'table' then return a end
  end

  if not DB.Available() then return nil end

  -- illenium-appearance schema
  local row = DB.Query('SELECT * FROM player_outfits WHERE citizenid = ? AND outfitname = ? LIMIT 1', { cid, 'default' })
  if row and row[1] and row[1].model then
    return {
      model = row[1].model,
      components = decodeJson(row[1].components, {}),
      props = decodeJson(row[1].props, {}),
      headBlend = decodeJson(row[1].headBlend, {}),
      headOverlays = decodeJson(row[1].headOverlays, {}),
      hair = decodeJson(row[1].hair, {}),
      faceFeatures = decodeJson(row[1].faceFeatures, {}),
      eyeColor = row[1].eyeColor,
    }
  end

  -- qb-clothing schema (playerskins + skinid -> player_outfits maybe)
  if Config.Appearance.qbClothingFallback then
    local row2 = DB.Query('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { cid })
    if row2 and row2[1] then
      return { model = row2[1].model, qbSkin = decodeJson(row2[1].skin, {}) }
    end
  end

  return nil
end

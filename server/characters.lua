Characters = Characters or {}

local function decodeJson(value, fallback)
  if value == nil then return fallback end
  if type(value) ~= 'string' then return value end
  local ok, decoded = pcall(json.decode, value)
  if ok and decoded ~= nil then return decoded end
  return fallback
end

-- Return a normalized list of characters for the given license.
function Characters.Load(src, license)
  if type(Config.DataProviders.customLoadCharacters) == 'function' then
    local ok, rows = pcall(Config.DataProviders.customLoadCharacters, src, license)
    if ok and type(rows) == 'table' then return rows end
  end

  local fw = CC.DetectFramework()

  if fw == 'qbox' or fw == 'qbcore' then
    local rows = DB.Query(
      'SELECT citizenid, charinfo, money, job FROM players WHERE license = ? ORDER BY last_updated DESC',
      { license }
    ) or {}
    local out = {}
    for i = 1, #rows do
      local r = rows[i]
      local info = decodeJson(r.charinfo, {}) or {}
      local money = decodeJson(r.money, {}) or {}
      local job = decodeJson(r.job, {}) or {}
      out[#out + 1] = {
        cid       = tostring(r.citizenid),
        firstname = info.firstname or 'Unknown',
        lastname  = info.lastname or 'Citizen',
        name      = ((info.firstname or 'Unknown') .. ' ' .. (info.lastname or 'Citizen')),
        gender    = info.gender == 1 and 'f' or 'm',
        job       = job.label or job.name or 'Unemployed',
        bank      = tonumber(money.bank) or 0,
        cash      = tonumber(money.cash) or 0,
      }
    end
    return out
  end

  if fw == 'esx' then
    local rows = DB.Query(
      "SELECT identifier, firstname, lastname, sex, accounts, job FROM users WHERE identifier LIKE CONCAT(?, ':%')",
      { license }
    ) or {}
    local out = {}
    for i = 1, #rows do
      local r = rows[i]
      local accounts = decodeJson(r.accounts, {}) or {}
      out[#out + 1] = {
        cid       = tostring(r.identifier),
        firstname = r.firstname or 'Unknown',
        lastname  = r.lastname or 'Citizen',
        name      = ((r.firstname or 'Unknown') .. ' ' .. (r.lastname or 'Citizen')),
        gender    = r.sex or 'm',
        job       = r.job or 'Unemployed',
        bank      = tonumber(accounts.bank) or 0,
        cash      = tonumber(accounts.money) or 0,
      }
    end
    return out
  end

  return {}
end

function Characters.GetAppearance(src, cid)
  if type(Config.DataProviders.customGetAppearance) == 'function' then
    local ok, a = pcall(Config.DataProviders.customGetAppearance, src, cid)
    if ok and type(a) == 'table' then return a end
  end

  if not DB.Available() then return nil end

  -- illenium-appearance schema (modern installs)
  local rows = DB.Query(
    'SELECT model, components, props, headBlend, headOverlays, hair, faceFeatures, eyeColor FROM player_outfits WHERE citizenid = ? AND outfitname = ? LIMIT 1',
    { cid, 'default' }
  )
  if rows and rows[1] and rows[1].model then
    local r = rows[1]
    return {
      model = r.model,
      components   = decodeJson(r.components, {}),
      props        = decodeJson(r.props, {}),
      headBlend    = decodeJson(r.headBlend, {}),
      headOverlays = decodeJson(r.headOverlays, {}),
      hair         = decodeJson(r.hair, {}),
      faceFeatures = decodeJson(r.faceFeatures, {}),
      eyeColor     = r.eyeColor,
    }
  end

  -- qb-clothing fallback
  local rows2 = DB.Query('SELECT model, skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', { cid })
  if rows2 and rows2[1] then
    return { model = rows2[1].model, qbSkin = decodeJson(rows2[1].skin, {}) }
  end

  return nil
end

Config = Config or {}

Config.Spawn = {
  -- Show "spawn from your last logged-out location" entry
  includeLastLocation = true,
  -- Fall back to first staticPoint if last location is missing
  fallbackToFirstStatic = true,
  -- Show a fly-cam preview of the spawn while it's highlighted in the picker
  previewFlyTo = true,
  previewFlyDurationMs = 1200,

  -- Static spawn points everyone gets
  staticPoints = {
    { id = 'legion', label = 'Legion Square',  description = 'Downtown Los Santos',         coords = vec4(215.76, -920.18, 30.69, 248.76) },
    { id = 'pier',   label = 'Del Perro Pier', description = 'Beachside, west side of map', coords = vec4(-1827.21, -1224.16, 13.02, 137.93) },
    { id = 'sandy',  label = 'Sandy Shores',   description = 'Desert town, Blaine County',  coords = vec4(1888.95, 3720.89, 32.47, 122.44) },
    { id = 'paleto', label = 'Paleto Bay',     description = 'Far north, small town',       coords = vec4(-275.62, 6226.85, 31.49, 222.95) },
  },

  -- Apartment-style spawns. Resolved per-character from apartment metadata if you wire
  -- in customApartmentResolver, otherwise everyone sees these as static options.
  apartmentPoints = {
    { id = 'apt_alta',     label = 'Alta Apartments',     description = 'Vinewood condo',     coords = vec4(-269.4, -957.2, 31.2, 205.0) },
    { id = 'apt_dellperro',label = 'Del Perro Heights',   description = 'Coastal apartments', coords = vec4(-1467.86, -541.32, 73.44, 49.21) },
    { id = 'apt_morning',  label = 'Morningwood Studio',  description = 'Quiet 1-bed',        coords = vec4(-787.34, -163.21, 37.56, 122.05) },
  },

  -- Optional job-keyed spawn points. Resolved against the character's job.
  jobPoints = {
    -- police = {
    --   { id = 'mrpd', label = 'Mission Row PD', description = 'Police HQ', coords = vec4(428.95, -984.52, 30.71, 88.75) }
    -- },
  },

  -- Plug your own apartment resolver (e.g. qbx_properties / qb-apartments).
  -- function(src, character) -> { { id, label, coords, description } }
  customApartmentResolver = nil,
}

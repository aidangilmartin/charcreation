--[[
  cc_multichar — Spawn configuration
  ---------------------------------------------------------------------------
  Controls the spawn picker shown after a character is selected. Players see
  a list of spawn options on the left and a fly-cam preview on the right.

  Spawn options are aggregated in this order:
    1. Last logged-out location (if includeLastLocation = true and found)
    2. All staticPoints
    3. All apartmentPoints (or customApartmentResolver(src, character) if set)
    4. Any jobPoints[character.job:lower()] entries

  Each entry needs at minimum: id, label, coords (vec4 x,y,z,heading).
]]

Config = Config or {}

Config.Spawn = {

  -- ===========================================================================
  -- Last location
  -- ===========================================================================
  -- includeLastLocation
  --   When true, an entry "Last Location" is added to the top of the list
  --   using the character's saved logout position (server.Characters.GetLastLocation).
  --
  -- fallbackToFirstStatic
  --   If the last location cannot be resolved (e.g. new character, bad data),
  --   the picker silently substitutes the first staticPoint. Disable to
  --   leave the picker without a last-location entry instead.
  includeLastLocation = true,
  fallbackToFirstStatic = true,

  -- ===========================================================================
  -- Fly-to preview camera
  -- ===========================================================================
  -- previewFlyTo
  --   When true, hovering an option on the picker animates the cam to fly
  --   from the scenario anchor to the spawn coords (held for the
  --   selection duration). When false, the cam stays at the scenario.
  --
  -- previewFlyDurationMs
  --   Time for the dolly between camera positions.
  previewFlyTo = true,
  previewFlyDurationMs = 1200,

  -- ===========================================================================
  -- Static spawn points (available to everyone)
  -- ===========================================================================
  -- Add as many as you like. Order matters — first entry is the default focus.
  -- description is shown on the picker's detail panel as flavor text.
  staticPoints = {
    { id = 'legion', label = 'Legion Square',
      description = 'Downtown Los Santos',
      coords = vec4(215.76, -920.18, 30.69, 248.76) },

    { id = 'pier',   label = 'Del Perro Pier',
      description = 'Beachside, west side of map',
      coords = vec4(-1827.21, -1224.16, 13.02, 137.93) },

    { id = 'sandy',  label = 'Sandy Shores',
      description = 'Desert town, Blaine County',
      coords = vec4(1888.95, 3720.89, 32.47, 122.44) },

    { id = 'paleto', label = 'Paleto Bay',
      description = 'Far north, small town',
      coords = vec4(-275.62, 6226.85, 31.49, 222.95) },
  },

  -- ===========================================================================
  -- Apartment spawn points
  -- ===========================================================================
  -- By default these are shown to every character. If your server tracks
  -- per-character apartment ownership, wire `customApartmentResolver` below
  -- to return only the apartments the character actually owns.
  apartmentPoints = {
    { id = 'apt_alta',     label = 'Alta Apartments',     description = 'Vinewood condo',     coords = vec4(-269.4, -957.2, 31.2, 205.0) },
    { id = 'apt_dellperro',label = 'Del Perro Heights',   description = 'Coastal apartments', coords = vec4(-1467.86, -541.32, 73.44, 49.21) },
    { id = 'apt_morning',  label = 'Morningwood Studio',  description = 'Quiet 1-bed',        coords = vec4(-787.34, -163.21, 37.56, 122.05) },
  },

  -- ===========================================================================
  -- Job-keyed spawn points
  -- ===========================================================================
  -- Keyed by lowercased character.job. If the character's job matches a key
  -- below, those entries are appended to the picker.
  --
  -- Example:
  --   police = {
  --     { id = 'mrpd', label = 'Mission Row PD', description = 'Police HQ',
  --       coords = vec4(428.95, -984.52, 30.71, 88.75) }
  --   },
  --   ambulance = {
  --     { id = 'pillbox', label = 'Pillbox Hospital', description = 'EMS HQ',
  --       coords = vec4(298.45, -584.62, 43.26, 70.5) }
  --   },
  jobPoints = {},

  -- ===========================================================================
  -- Custom apartment resolver
  -- ===========================================================================
  -- If set, this function replaces `apartmentPoints` entirely. It is called
  -- per-character with (src, character) and should return a list of points
  -- (same shape: { id, label, coords, description }).
  --
  -- Useful when integrating with qbx_properties / qb-apartments / etc.
  -- Example:
  --   customApartmentResolver = function(src, character)
  --     local owned = exports['qbx_properties']:GetOwnedByCid(character.cid)
  --     local out = {}
  --     for _, prop in ipairs(owned) do
  --       out[#out+1] = { id = 'prop:'..prop.id, label = prop.label, coords = prop.coords }
  --     end
  --     return out
  --   end,
  customApartmentResolver = nil,
}

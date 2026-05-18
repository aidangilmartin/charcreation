--[[
  cc_multichar — Scenario definitions
  ---------------------------------------------------------------------------
  A "scenario" is a declarative description of one cinematic scene shown by
  the selector. The server picks ONE scenario per session (weighted-random)
  and ships its id to the client, which spawns all the entities, runs the
  choreography timeline, and lets the player click any character ped to
  select that character.

  Scenarios are ensemble — every player character appears in the scene via
  the special `players` role. NPCs, vehicles and props fill out the rest.

  ===========================================================================
  Scenario shape
  ===========================================================================
    id          string  unique identifier (used for the random pick + skip+
                        debugging)
    weight      number  relative selection probability when pickStrategy is
                        'weighted-random' (default 1)
    minChars    number  scenario only available when char count >= this
    maxChars    number  scenario only available when char count <= this
    weather     string  GTA weather id ('CLEAR', 'EXTRASUNNY', 'CLOUDS', etc.)
    hour/minute number  in-game clock override
    anchor      vec4    absolute world position. All offsets below are relative.
    camera = {
      position  vec3   absolute world position of the camera
      lookAt    vec3   absolute world position the camera points at
      fov       number 25..90 (45 looks "natural", 35 is cinematic)
    }
    ambient = {
      audioScene  string  native GTA audio scene name (StartAudioScene)
      sounds      list    optional looping one-shot sounds; each entry is
                          { set, name, intervalMs, loop }
    }
    roles = {
      <name> = { kind = 'players', layout = fn(i,total) -> vec4, animation, weapon },
      <name> = { kind = 'npc', model, offset = vec4, animation, weapon, flag },
    }
    vehicles = {
      <name> = {
        model, primaryColor, secondaryColor, siren, offset = vec4,
        driverRole = '<roleName>',   -- OR
        driverRoleIndex = <int>,     -- index into the players list
        passengerRoles = { ... },    -- list of role names or numeric player indexes
        task = { kind = 'driveAhead' | 'pursue', speed, distance, target, flags }
        options = { hoodOpen = true }
      }
    }
    props = { { model, offset = vec3, heading = number } }
    timeline = list of timed events. Each entry has `at` (ms from scenario
               start) and a `kind`:
                 - 'cameraOrbit'  { radius, height, durationMs, around }
                 - 'cameraDolly'  { to = vec3, durationMs }
                 - 'cameraTrack'  { target = 'anchor'|'role:X'|'vehicle:X',
                                    offset = vec3, durationMs }

  ===========================================================================
  Picking a scenario
  ===========================================================================
    pickStrategy = 'weighted-random' | 'sequential' | 'fixed'
      weighted-random: standard. Higher weight = more likely.
      sequential:      cycles through the pool in order each open.
      fixed:           always plays Config.Scenarios.scenarios[fixedIndex].

  ===========================================================================
  empty
  ===========================================================================
  Special scenario played when the player has zero characters. No ensemble,
  just a camera at a scenic spot to make the "no characters yet" experience
  feel intentional.
]]

Config = Config or {}

Config.Scenarios = {
  pickStrategy = 'weighted-random',
  fixedIndex = 1,

  scenarios = {
    -- BBQ -----------------------------------------------------------------
    {
      id = 'bbq',
      weight = 3,
      weather = 'EXTRASUNNY', hour = 19, minute = 45,
      -- Ambient SFX. `audioScene` activates a native GTA audio scene; `sounds`
      -- plays looping one-shots near the anchor on an interval. Tune per scene.
      ambient = {
        audioScene = 'BIKER_FORMATION_RIDE_AUDIO_SCENE',
        sounds = {},
      },
      anchor = vector4(-1037.04, -2731.99, 19.45, 240.0),
      camera = {
        position = vector3(-1041.5, -2728.0, 21.0),
        lookAt   = vector3(-1037.04, -2731.99, 20.5),
        fov = 38.0,
      },
      props = {
        { model = 'prop_bbq_3',      offset = vector3(1.4,  0.6, -1.0), heading = 30.0 },
        { model = 'prop_beach_fire', offset = vector3(-1.8, -0.4, -1.0), heading = 0.0 },
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            local angle = ((i - 1) / math.max(total, 1)) * math.pi * 2
            local r = 1.7
            return vector4(math.cos(angle) * r, math.sin(angle) * r, -1.0,
                           (angle * 180.0 / math.pi) + 180.0)
          end,
          animation = { dict = 'amb@world_human_drinking@beer@male@idle_a', name = 'idle_a' },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraOrbit', radius = 5.5, height = 1.7, durationMs = 14000, around = 'anchor' },
      },
    },

    -- Fishing -------------------------------------------------------------
    {
      id = 'fishing',
      weight = 3,
      weather = 'CLEAR', hour = 18, minute = 15,
      ambient = {
        audioScene = 'MP_LEADERBOARD_SCENE',
        sounds = {},
      },
      anchor = vector4(-1827.21, -1224.16, 13.02, 137.93),
      camera = {
        position = vector3(-1823.7, -1219.8, 15.0),
        lookAt   = vector3(-1828.5, -1226.0, 13.6),
        fov = 42.0,
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            local stride = 1.4
            local center = (total - 1) / 2.0
            return vector4((i - 1 - center) * stride, 0.0, -1.0, 220.0)
          end,
          animation = { dict = 'amb@world_human_stand_fishing@idle_a', name = 'idle_a' },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraDolly', to = vector3(-1821.5, -1218.0, 15.8), durationMs = 14000 },
      },
    },

    -- Mechanic garage ----------------------------------------------------
    {
      id = 'mechanic_garage',
      weight = 2,
      weather = 'OVERCAST', hour = 14, minute = 0,
      ambient = {
        audioScene = 'CAR_MOD_GARAGE_FILTER_SCENE',
        sounds = {},
      },
      anchor = vector4(-337.7, -136.3, 39.0, 250.0),
      camera = {
        position = vector3(-333.5, -133.5, 40.2),
        lookAt   = vector3(-338.0, -137.0, 39.6),
        fov = 38.0,
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            local stride = 2.2
            local center = (total - 1) / 2.0
            return vector4((i - 1 - center) * stride, 0.0, -1.0, 250.0)
          end,
          animation = { dict = 'mini@repair', name = 'fixing_a_player' },
        },
      },
      vehicles = {
        carA = {
          model = 'sultan', primaryColor = 12, secondaryColor = 12,
          offset = vector4(0.0, 1.8, -1.0, 160.0),
          options = { hoodOpen = true },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraOrbit', radius = 5.0, height = 1.9, durationMs = 14000, around = 'anchor' },
      },
    },

    -- Hospital ------------------------------------------------------------
    {
      id = 'hospital',
      weight = 1,
      weather = 'OVERCAST', hour = 22, minute = 0,
      ambient = {
        audioScene = 'MP_REST_HOSP_SCENE',
        sounds = {},
      },
      anchor = vector4(307.7, -1433.2, 30.5, 180.0),
      camera = {
        position = vector3(309.3, -1430.8, 31.8),
        lookAt   = vector3(307.6, -1434.0, 31.0),
        fov = 36.0,
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            local stride = 1.8
            local center = (total - 1) / 2.0
            return vector4((i - 1 - center) * stride, 0.0, -1.0, 180.0)
          end,
          animation = { dict = 'amb@world_human_clipboard@male@idle_a', name = 'idle_a' },
        },
        medic = {
          kind = 'npc', model = 's_m_m_doctor_01',
          offset = vector4(1.6, -0.6, -1.0, 270.0),
          animation = { dict = 'amb@medic@standing@kneel@idle_a', name = 'idle_a' },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraDolly', to = vector3(309.7, -1430.0, 32.0), durationMs = 12000 },
      },
    },

    -- Desert drug deal ----------------------------------------------------
    {
      id = 'desert_drug_deal',
      weight = 2,
      weather = 'EXTRASUNNY', hour = 17, minute = 30,
      ambient = {
        audioScene = 'DLC_HEISTS_FINALE_SCREEN_SCENE',
        sounds = {},
      },
      anchor = vector4(1864.0, 3683.0, 33.6, 120.0),
      camera = {
        position = vector3(1867.0, 3685.5, 34.9),
        lookAt   = vector3(1863.5, 3682.0, 34.0),
        fov = 38.0,
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            local angle = ((i - 1) / math.max(total, 1)) * math.pi * 2
            local r = 1.4
            return vector4(math.cos(angle) * r, math.sin(angle) * r, -1.0,
                           (angle * 180.0 / math.pi) + 180.0)
          end,
          animation = { dict = 'mp_common', name = 'givetake1_a' },
        },
        buyer = {
          kind = 'npc', model = 'g_m_y_lost_01',
          offset = vector4(2.5, 1.5, -1.0, 300.0),
          animation = { dict = 'mp_common', name = 'givetake1_b' },
        },
        lookout = {
          kind = 'npc', model = 'g_m_y_lost_02',
          offset = vector4(-3.0, -1.5, -1.0, 60.0),
          animation = { dict = 'amb@world_human_aa_smoke@male@idle_a', name = 'idle_a' },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraOrbit', radius = 5.5, height = 1.8, durationMs = 13000, around = 'anchor' },
      },
    },

    -- Store robbery -------------------------------------------------------
    {
      id = 'store_robbery',
      weight = 2,
      weather = 'CLOUDS', hour = 23, minute = 10,
      ambient = {
        audioScene = 'MP_HEIST_TUTORIAL_AUDIO_SCENE',
        sounds = {},
      },
      anchor = vector4(24.5, -1347.3, 29.5, 270.0),
      camera = {
        position = vector3(27.0, -1346.0, 30.6),
        lookAt   = vector3(24.0, -1347.5, 30.0),
        fov = 40.0,
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            local stride = 1.3
            local center = (total - 1) / 2.0
            return vector4((i - 1 - center) * stride, 0.0, -1.0, 270.0)
          end,
          animation = { dict = 'anim@amb@business@meth@meth_idle_seller@', name = 'meth_idle_seller_pointing_v1_idle' },
          weapon = 'WEAPON_PISTOL',
        },
        clerk = {
          kind = 'npc', model = 'mp_m_shopkeep_01',
          offset = vector4(-2.0, 0.2, -1.0, 90.0),
          animation = { dict = 'random@arrests', name = 'kneeling_arrest_get_up', flag = 1 },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraDolly', to = vector3(25.5, -1346.0, 30.7), durationMs = 12000 },
      },
    },

    -- Police chase --------------------------------------------------------
    {
      id = 'police_chase',
      weight = 2,
      weather = 'CLEAR', hour = 1, minute = 30,
      -- Cruiser siren is automatic via vehicles.cruiser.siren = true.
      ambient = {
        audioScene = 'CAR_CHASE_AUDIO_SCENE',
        sounds = {},
      },
      anchor = vector4(-1840.0, 440.0, 117.0, 90.0),
      camera = {
        position = vector3(-1825.0, 455.0, 120.0),
        lookAt   = vector3(-1840.0, 440.0, 117.0),
        fov = 50.0,
      },
      roles = {
        players = {
          kind = 'players',
          -- Placed in/around the getaway vehicle by vehicle.passengerRoles below.
          -- Layout still required for ped spawn coords before they enter the car.
          layout = function(i, total)
            return vector4(0.0, -1.5 - i * 0.4, -1.0, 90.0)
          end,
          animation = nil,
        },
        cop = {
          kind = 'npc', model = 's_m_y_cop_01',
          offset = vector4(-12.0, -2.0, -1.0, 90.0),
        },
      },
      vehicles = {
        getaway = {
          model = 'sultan', primaryColor = 0, secondaryColor = 0,
          offset = vector4(0.0, 0.0, -1.0, 90.0),
          driverRoleIndex = 1,   -- driver = first character
          passengerRoles = { 0, 1, 2 }, -- passenger seats for chars #2, #3, #4
          task = { kind = 'driveAhead', speed = 30.0, distance = 250.0 },
        },
        cruiser = {
          model = 'police', siren = true,
          offset = vector4(-12.0, -1.0, -1.0, 90.0),
          driverRole = 'cop',
          task = { kind = 'pursue', target = 'getaway', speed = 35.0 },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraTrack', target = 'vehicle:getaway', offset = vector3(8.0, 5.0, 3.0), durationMs = 15000 },
      },
    },

    -- Drive-by ------------------------------------------------------------
    {
      id = 'drive_by',
      weight = 1,
      weather = 'CLEAR', hour = 0, minute = 45,
      ambient = {
        audioScene = 'CAR_CHASE_AUDIO_SCENE',
        sounds = {},
      },
      anchor = vector4(-1300.0, -390.0, 36.7, 200.0),
      camera = {
        position = vector3(-1297.5, -388.0, 37.6),
        lookAt   = vector3(-1300.0, -390.0, 37.4),
        fov = 42.0,
      },
      roles = {
        players = {
          kind = 'players',
          layout = function(i, total)
            return vector4(0.0, -1.5 - i * 0.4, -1.0, 200.0)
          end,
          weapon = 'WEAPON_MICROSMG',
        },
        driver = {
          kind = 'npc', model = 'g_m_y_ballaeast_01',
        },
      },
      vehicles = {
        ride = {
          model = 'sultan', primaryColor = 0, secondaryColor = 0,
          offset = vector4(0.0, 0.0, -1.0, 200.0),
          driverRole = 'driver',
          passengerRoles = { -1, 0, 1 }, -- front-pass first, then back seats for chars
          task = { kind = 'driveAhead', speed = 20.0, distance = 130.0 },
        },
      },
      timeline = {
        { at = 0, kind = 'cameraTrack', target = 'vehicle:ride', offset = vector3(3.5, 2.5, 1.4), durationMs = 13000 },
      },
    },
  },

  -- Used when the player has zero characters
  empty = {
    id = 'empty_intro',
    weather = 'EXTRASUNNY', hour = 18, minute = 30,
    anchor = vector4(-169.1, 489.7, 137.41, 197.0),
    camera = {
      position = vector3(-167.5, 487.2, 138.2),
      lookAt   = vector3(-169.1, 489.7, 137.9),
      fov = 42.0,
    },
    timeline = {
      { at = 0, kind = 'cameraOrbit', radius = 4.0, height = 1.5, durationMs = 20000, around = 'anchor' },
    },
  },
}

Config.SceneTimings = {
  fadeOutMs = 400,
  fadeInMs  = 700,
  spawnFadeOutMs = 500,
  spawnFadeInMs  = 800,
}

Config.Selection = {
  -- Visual feedback on hovered/selected ped
  hoverOutline = { 0, 220, 255, 220 },    -- cyan
  selectedOutline = { 232, 194, 117, 255 },-- accent gold
  -- World-space marker above the hovered/selected ped
  drawHoverMarker = true,
  hoverMarkerHeightOffset = 1.05,
}

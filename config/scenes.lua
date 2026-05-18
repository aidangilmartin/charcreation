Config = Config or {}

-- Rotating cinematic scenes for the character selector.
-- One is picked at random each time the selector opens.
-- Use weight to bias selection (higher = more likely).
Config.Scenes = {
  pickStrategy = 'weighted-random', -- weighted-random | sequential | fixed
  fixedIndex = 1,
  scenes = {
    {
      id = 'vinewood_hills_mansion',
      weight = 3,
      weather = 'EXTRASUNNY',
      hour = 18, minute = 30,
      -- Where the preview ped stands
      ped = vector4(-169.1, 489.7, 137.41, 197.0),
      -- Camera position + the point it looks at
      camera = {
        position = vector3(-167.5, 487.2, 138.1),
        lookAt   = vector3(-169.1, 489.7, 137.9),
        fov = 42.0,
      },
      animation = {
        dict = 'anim@heists@heist_corona@team_idles@male_a',
        name = 'idle',
      },
    },
    {
      id = 'vinewood_sign',
      weight = 2,
      weather = 'CLEAR',
      hour = 20, minute = 0,
      ped = vector4(710.95, 1199.32, 325.94, 286.0),
      camera = {
        position = vector3(712.5, 1198.2, 326.4),
        lookAt   = vector3(710.95, 1199.32, 326.6),
        fov = 40.0,
      },
      animation = { dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a', name = 'idle_a' },
    },
    {
      id = 'del_perro_beach',
      weight = 2,
      weather = 'CLEAR',
      hour = 19, minute = 30,
      ped = vector4(-1633.05, -1009.05, 13.15, 130.0),
      camera = {
        position = vector3(-1634.7, -1008.0, 13.8),
        lookAt   = vector3(-1633.05, -1009.05, 13.7),
        fov = 38.0,
      },
      animation = { dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a', name = 'idle_a' },
    },
    {
      id = 'observatory_rooftop',
      weight = 1,
      weather = 'CLEAR',
      hour = 22, minute = 15,
      ped = vector4(-438.4, 1077.5, 352.4, 65.0),
      camera = {
        position = vector3(-437.0, 1078.5, 353.0),
        lookAt   = vector3(-438.4, 1077.5, 353.0),
        fov = 42.0,
      },
      animation = { dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a', name = 'idle_a' },
    },
    {
      id = 'mission_row_pd',
      weight = 1,
      weather = 'OVERCAST',
      hour = 9, minute = 0,
      ped = vector4(434.7, -979.4, 30.71, 9.0),
      camera = {
        position = vector3(434.6, -978.0, 31.3),
        lookAt   = vector3(434.7, -979.4, 31.2),
        fov = 40.0,
      },
      animation = { dict = 'amb@world_human_stand_impatient@male@no_sign@idle_a', name = 'idle_a' },
    },
  },
}

-- Fade timings (ms)
Config.SceneTimings = {
  fadeOutMs = 400,
  fadeInMs  = 600,
  spawnFadeOutMs = 500,
  spawnFadeInMs  = 800,
}

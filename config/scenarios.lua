Config = Config or {}

Config.Scene = {
  maxDisplayedPeds = 4,
  immersiveExtras = true,
  presets = {
    {
      id = 'penthouse_night',
      label = 'Penthouse Meeting',
      interior = {
        coords = vec3(-785.13, 315.79, 187.91),
        cam = vec3(-781.24, 320.11, 189.80),
        heading = 210.0,
      },
      weather = 'CLEAR',
      time = { hour = 23, minute = 15 },
      scenario = {
        playerAnims = {
          { dict = 'amb@world_human_partying@female@partying_beer@base', name = 'base' },
          { dict = 'anim@amb@nightclub@peds@', name = 'rcmme_amanda1_stand_loop_cop' },
          { dict = 'amb@world_human_leaning@male@wall@back@foot_up@base', name = 'base' },
          { dict = 'amb@world_human_smoking@male@male_a@enter', name = 'enter' },
        },
        extras = {
          { model = 'a_m_y_business_01', anim = { dict = 'amb@world_human_clipboard@male@base', name = 'base' } },
          { model = 'a_f_y_business_02', anim = { dict = 'amb@world_human_stand_mobile@female@text@base', name = 'base' } }
        }
      }
    },
    {
      id = 'studio_day',
      label = 'Creative Studio',
      interior = {
        coords = vec3(-1002.0, -477.8, 50.0),
        cam = vec3(-1008.0, -474.4, 52.0),
        heading = 247.0,
      },
      weather = 'EXTRASUNNY',
      time = { hour = 11, minute = 35 },
      scenario = {
        playerAnims = {
          { dict = 'amb@world_human_hang_out_street@male_b@idle_a', name = 'idle_a' },
          { dict = 'amb@world_human_stand_impatient@male@no_sign@base', name = 'base' },
          { dict = 'anim@heists@heist_corona@single_team', name = 'single_team_loop_boss' },
          { dict = 'amb@world_human_stand_mobile@male@text@base', name = 'base' },
        },
        extras = {
          { model = 'ig_talina', anim = { dict = 'amb@world_human_tourist_map@male@base', name = 'base' } }
        }
      }
    }
  }
}

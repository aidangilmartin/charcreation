Spawn = Spawn or {}

function Spawn.Finalize(coords)
  DoScreenFadeOut(Config.SceneTimings.spawnFadeOutMs)
  while not IsScreenFadedOut() do Wait(0) end

  Preview.Clear()
  Scene.Teardown()

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, false)
  SetEntityInvincible(ped, false)
  SetPlayerControl(PlayerId(), true, 0)
  SetEntityVisible(ped, true, false)

  RequestCollisionAtCoord(coords.x, coords.y, coords.z)
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
  SetEntityHeading(ped, coords.w or 0.0)

  -- Let the framework finish loading player data before fading back in.
  Wait(250)
  DoScreenFadeIn(Config.SceneTimings.spawnFadeInMs)
end

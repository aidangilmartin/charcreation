Spawn = Spawn or {}

function Spawn.Finalize(coords)
  DoScreenFadeOut(Config.SceneTimings.spawnFadeOutMs)
  while not IsScreenFadedOut() do Wait(0) end

  Hover.Stop()
  Scenarios.Stop()

  Scene.ShowPlayerPed(coords)

  Wait(250)
  DoScreenFadeIn(Config.SceneTimings.spawnFadeInMs)
end

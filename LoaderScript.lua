local Games = {
    [10769787444] = { Name = "Above", File = "above.lua" },
    [10769552054] = { Name = "Urban Reload", File = "urban-reload.lua", KeyFiles = { "SlimeHub/UrbanReload/key.txt" } },
    [10767494536] = { Name = "Hike For Eggs", File = "hike-for-eggs.lua" },
    [10766972131] = { Name = "Throw Food For Animals", File = "throw-food-for-animals.lua" },
    [10772281976] = { Name = "Unstable SMP FFA", File = "unstable-smp-ffa.lua" },
    [7174773198] = { Name = "Vox Seas", File = "vox-seas.lua" },
    [10775182046] = { Name = "Throw a seed", File = "throw-a-seed.lua" },
    [10774784939] = { Name = "Shoot Arrows For Animals", File = "shoot-arrows-for-animals.lua" },
}

local ok, core = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/core/loader.lua"))()
end)
if ok and type(core) == "function" then
    core(Games)
else
    warn("[Slime Hub] Could not load the loader core: " .. tostring(core))
end

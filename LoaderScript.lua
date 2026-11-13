local Scripts = {
    [10769787444] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/Aboverb.lua", -- Above
    [10769552054] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/urban%20reload.lua", --urban reload
    [110432290690507] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/hikeforeggs", --hikeforeggs
}

local scriptUrl = Scripts[game.GameId]

if not scriptUrl then
    warn("Slime Hub does not support this game yet. Game ID: " .. tostring(game.GameId))
    return
end

local success, errorMessage = pcall(function()
    local source = game:HttpGet(scriptUrl)
    local runScript, compileError = loadstring(source)
    assert(runScript, compileError)
    runScript()
end)

if not success then
    warn("Failed to load Slime Hub: " .. tostring(errorMessage))
end

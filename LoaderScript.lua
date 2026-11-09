local Scripts = {
    [10769787444] = "loadstring(game:HttpGet("https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/Aboverb.lua"))()", --above
    [987654321] = "https://your-domain/scripts/other-game.lua",
}

local scriptUrl = Scripts[game.GameId]

if not scriptUrl then
    warn("Slime Hub does not support this game yet.")
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

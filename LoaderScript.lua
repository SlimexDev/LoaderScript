local Scripts = {
    [10769787444] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/Aboverb.lua", -- Above
    [10769552054] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/urban%20reload.lua", --urban reload
    [10767494536] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/hikeforeggs", --hikeforeggs
    [10766972131] = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/ThrowFoodForAnimals", --ThrowFoodForAnimals
}

-- File key SlimeUI luu theo Folder cua tung game (mac dinh "SlimeHub/key.txt")
local KeyFiles = {
    [10769552054] = "SlimeHub/UrbanReload/key.txt",
}

local WebhookScript = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/webhook.lua"
local LogTimeout = 300 -- giay: hub chua load xong (dang lay key) thi van gui log tam

local scriptUrl = Scripts[game.GameId]

if not scriptUrl then
    warn("Slime Hub does not support this game yet. Game ID: " .. tostring(game.GameId))
    return
end

-- Webhook log: loi o day khong lam hong viec load hub
local SendLog
pcall(function()
    SendLog = loadstring(game:HttpGet(WebhookScript))()
end)

local function Log(status, color, err)
    if type(SendLog) == "function" then
        task.spawn(pcall, SendLog, {
            Status = status,
            Color = color,
            Error = err,
            KeyFile = KeyFiles[game.GameId] or "SlimeHub/key.txt",
        })
    end
end

-- Hub chi chay xong sau khi nhap key; qua LogTimeout ma chua xong thi gui log tam,
-- khi load xong van gui them log "Loaded" co key
local finished = false
task.delay(LogTimeout, function()
    if not finished then
        Log("Executed (not loaded yet)", 0xFAA61A)
    end
end)

local success, errorMessage = pcall(function()
    local source = game:HttpGet(scriptUrl)
    local runScript, compileError = loadstring(source)
    assert(runScript, compileError)
    runScript()
end)
finished = true

if success then
    Log("Loaded", 0x57F287)
else
    Log("Load failed", 0xED4245, tostring(errorMessage))
    warn("Failed to load Slime Hub: " .. tostring(errorMessage))
end

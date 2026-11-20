local Repo = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/"
local RunApi = "https://slimehub-key.slimehub-keysystem.workers.dev/api/run"
local Games = {
    [10769787444] = { Name = "Above", File = "Aboverb.lua" },
    [10769552054] = { Name = "Urban Reload", File = "urban%20reload.lua", KeyFiles = { "SlimeHub/UrbanReload/key.txt" } },
    [10767494536] = { Name = "Hike For Eggs", File = "hikeforeggs" },
    [10766972131] = { Name = "Throw Food For Animals", File = "ThrowFoodForAnimals" },
    [10772281976] = { Name = "Unstable SMP FFA", File = "unstable%20smp%20ffa" },
}
local DefaultKeyFile = "SlimeHub/key.txt"
local KeyWatchSeconds = 600 -- cho nguoi choi lay key toi da 10 phut

local function Notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", { Title = "Slime Hub", Text = text, Duration = 8 })
    end)
end

local function UrlEncode(s)
    return (tostring(s):gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end
local function PlayerInfo(extra)
    local info = {}
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        info.u = player.UserId
        info.p = player.Name
        info.d = player.DisplayName
    end)
    pcall(function()
        if typeof(identifyexecutor) == "function" then
            local name, version = identifyexecutor()
            info.x = version and (tostring(name) .. " " .. tostring(version)) or tostring(name)
        elseif typeof(getexecutorname) == "function" then
            info.x = tostring(getexecutorname())
        end
    end)
    for k, v in pairs(extra or {}) do
        info[k] = v
    end
    return info
end
local function Count(event, params)
    local url = RunApi .. "?e=" .. event .. "&g=" .. tostring(game.GameId)
    for name, value in pairs(params or {}) do
        url = url .. "&" .. name .. "=" .. UrlEncode(value)
    end
    local ok, body = pcall(game.HttpGet, game, url)
    return ok and type(body) == "string" and body:find('"ok":true', 1, true) ~= nil
end

local function ReadKey(info)
    if typeof(isfile) ~= "function" or typeof(readfile) ~= "function" then
        return nil
    end
    local paths = table.clone(info.KeyFiles or {})
    table.insert(paths, DefaultKeyFile)
    for _, path in ipairs(paths) do
        local ok, saved = pcall(function()
            return isfile(path) and readfile(path) or nil
        end)
        saved = ok and type(saved) == "string" and saved:match("^%s*(.-)%s*$") or nil
        if saved and saved ~= "" then
            return saved
        end
    end
    return nil
end
local function Download(url)
    local lastError
    for attempt = 1, 3 do
        local ok, body = pcall(game.HttpGet, game, url)
        if ok and type(body) == "string" and body ~= "" and not body:match("^%s*<") and not body:match("^404: Not Found") then
            return body
        end
        lastError = ok and ("bad response: " .. tostring(body):sub(1, 40)) or tostring(body)
        task.wait(attempt)
    end
    error("could not download the script (" .. tostring(lastError) .. ")", 0)
end

local info = Games[game.GameId]
if not info then
    Notify("This game is not supported yet.")
    warn("[Slime Hub] This game is not supported yet. Game ID: " .. tostring(game.GameId))
    return
end

task.spawn(Count, "start", { n = info.Name })

local loadFailed = false
task.spawn(function()
    local tried
    local deadline = os.clock() + KeyWatchSeconds
    while not loadFailed and os.clock() < deadline do
        local key = ReadKey(info)
        if key and key ~= tried then
            tried = key
            if Count("key", PlayerInfo({ k = key })) then
                return
            end
        end
        task.wait(5)
    end
end)

local success, errorMessage = pcall(function()
    local runScript, compileError = loadstring(Download(Repo .. info.File))
    assert(runScript, compileError)
    runScript()
end)

if not success then
    loadFailed = true
    task.spawn(Count, "fail", PlayerInfo({ err = tostring(errorMessage):sub(1, 300) }))
    Notify("Failed to load. Try again or report it in Discord.")
    warn("[Slime Hub] Failed to load: " .. tostring(errorMessage))
end

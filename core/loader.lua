local Repo = "https://raw.githubusercontent.com/SlimexDev/LoaderScript/refs/heads/main/game/"
local RunApi = "https://slimehub-key.slimehub-keysystem.workers.dev/api/run"
local DefaultKeyFile = "SlimeHub/key.txt"
local KeyWatchSeconds = 600
local LoopWindow = 15

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

local function ExecutorName()
    local ok, name, version = pcall(function()
        if typeof(identifyexecutor) == "function" then
            return identifyexecutor()
        elseif typeof(getexecutorname) == "function" then
            return getexecutorname()
        end
    end)
    if not ok or name == nil then
        return nil
    end
    return version and (tostring(name) .. " " .. tostring(version)) or tostring(name)
end

local function PlayerInfo(extra)
    local info = {}
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        info.u = player.UserId
        info.p = player.Name
        info.d = player.DisplayName
    end)
    info.x = ExecutorName()
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

local function PickFile(info)
    local executor = (ExecutorName() or ""):lower()
    if info.Xeno and executor:find("xeno", 1, true) then
        return info.Xeno
    end
    return info.File
end

return function(Games)
    local info = Games[game.GameId]
    if not info then
        Notify("This game is not supported yet.")
        warn("[Slime Hub] This game is not supported yet. Game ID: " .. tostring(game.GameId))
        return
    end

    -- Chong lap: script game goi lai loader ngay khi vua duoc loader tai = GAME_ID trong script sai.
    local env = (typeof(getgenv) == "function" and getgenv()) or _G
    local active = env.SlimeLoaderActive
    if active and active.GameId == game.GameId and os.clock() - active.Time < LoopWindow then
        env.SlimeLoaderActive = nil
        Notify("Script/game ID mismatch. Please report it in Discord.")
        warn("[Slime Hub] " .. tostring(active.File) .. " does not accept Game ID " .. tostring(game.GameId) .. " (check GAME_ID in the script).")
        return
    end

    local file = PickFile(info)
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
        local runScript, compileError = loadstring(Download(Repo .. file))
        assert(runScript, compileError)
        env.SlimeLoaderActive = { GameId = game.GameId, File = file, Time = os.clock() }
        runScript()
    end)
    env.SlimeLoaderActive = nil

    if not success then
        loadFailed = true
        task.spawn(Count, "fail", PlayerInfo({ err = tostring(errorMessage):sub(1, 300) }))
        Notify("Failed to load. Try again or report it in Discord.")
        warn("[Slime Hub] Failed to load: " .. tostring(errorMessage))
    end
end

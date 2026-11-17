-- Slime Hub: gui log ve Discord webhook moi lan chay script.
-- LoaderScript.lua tai file nay va goi: SendLog({ Status = "...", Color = 0x00ff00, KeyFile = "..." })
-- Gui: game, server, vi tri trong game, quoc gia, nguoi choi, HWID, key, executor, thoi gian.

local WEBHOOK_URL = "https://discord.com/api/webhooks/1572114546091622430/lmZsdkdxpj4Dutg8hcyvaRHYk_SaiJ7nyT3RNtEvqtMw7LXy6IRg3HuOpQ2fjdTqlh-Y"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local function Try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then
        return a, b
    end
    return nil
end

local function Text(v, fallback)
    v = v ~= nil and tostring(v) or ""
    if v == "" then
        return fallback or "unknown"
    end
    return v
end

-- Executor co ham request khac nhau
local function GetRequest()
    local env = (type(getgenv) == "function" and getgenv()) or {}
    return env.request or env.http_request
        or (type(request) == "function" and request)
        or (type(http_request) == "function" and http_request)
        or (type(syn) == "table" and syn.request)
        or (type(fluxus) == "table" and fluxus.request)
        or (type(http) == "table" and http.request)
end

-- Cung thu tu voi SlimeUI KeySystem de HWID trung voi HWID tren key server
local function GetHwid()
    if typeof(gethwid) == "function" then
        local h = Try(gethwid)
        if h ~= nil and tostring(h) ~= "" then
            return tostring(h)
        end
    end
    return Text(Try(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end))
end

local function GetExecutor()
    if typeof(identifyexecutor) == "function" then
        local name, version = Try(identifyexecutor)
        if name then
            return version and (tostring(name) .. " " .. tostring(version)) or tostring(name)
        end
    end
    if typeof(getexecutorname) == "function" then
        return Text(Try(getexecutorname))
    end
    return "unknown"
end

local function ReadKey(keyFile)
    local env = (type(getgenv) == "function" and getgenv()) or {}
    local injected = env.SlimeKey or rawget(_G, "SlimeKey")
    if type(injected) == "table" and injected.Key then
        return tostring(injected.Key)
    end
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        for _, path in ipairs({ keyFile, "SlimeHub/key.txt" }) do
            if path then
                local saved = Try(function()
                    return isfile(path) and readfile(path) or nil
                end)
                saved = saved and saved:match("^%s*(.-)%s*$")
                if saved and saved ~= "" then
                    return saved
                end
            end
        end
    end
    return "none"
end

local function GetGameName()
    local info = Try(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    return type(info) == "table" and Text(info.Name, "Roblox") or "Roblox"
end

local function GetPosition(player)
    local pos = Try(function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        return root and root.Position
    end)
    if not pos then
        return "no character"
    end
    return string.format("%.0f, %.0f, %.0f", pos.X, pos.Y, pos.Z)
end

local function GetCountry(player)
    return Text(Try(function()
        return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(player)
    end))
end

local function Cut(s, n)
    s = tostring(s)
    return #s > n and (s:sub(1, n - 3) .. "...") or s
end

return function(opts)
    opts = opts or {}
    if WEBHOOK_URL == "" or WEBHOOK_URL:find("PASTE_", 1, true) then
        return false, "webhook url not set"
    end
    local send = GetRequest()
    if not send then
        return false, "executor has no request function"
    end

    local player = Players.LocalPlayer
    local now = os.time()
    local players = #Players:GetPlayers() .. "/" .. Text(Players.MaxPlayers, "?")

    local function Field(name, value, inline)
        return { name = name, value = Cut(Text(value), 1024), inline = inline ~= false }
    end

    local embed = {
        title = Cut(Text(opts.Status, "Script executed") .. " · " .. GetGameName(), 256),
        color = opts.Color or 0x5865F2,
        fields = {
            Field("Player", string.format("%s (@%s)\nID: %d", player.DisplayName, player.Name, player.UserId)),
            Field("Executor", "`" .. GetExecutor() .. "`"),
            Field("Time", string.format("<t:%d:F>\n%s", now, os.date("!%Y-%m-%d %H:%M:%S UTC", now))),
            Field("Key", "`" .. ReadKey(opts.KeyFile) .. "`"),
            Field("HWID", "`" .. GetHwid() .. "`", false),
            Field("Game", string.format("Place ID: %d\nGame ID: %d", game.PlaceId, game.GameId)),
            Field("Location", string.format("Country: %s\nPosition: %s", GetCountry(player), GetPosition(player))),
            Field("Server", string.format("Players: %s\nJob ID: `%s`", players, Text(game.JobId, "studio")), false),
        },
        footer = { text = "Slime Hub Logger" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ", now),
    }
    if opts.Error then
        table.insert(embed.fields, Field("Error", "```" .. Cut(opts.Error, 1000) .. "```", false))
    end

    local res = Try(send, {
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({ username = "Slime Hub", embeds = { embed } }),
    })
    local code = type(res) == "table" and tonumber(res.StatusCode) or nil
    return code ~= nil and code >= 200 and code < 300, code
end

while not game:IsLoaded() do task.wait() end
while game.GameId == 0 do task.wait() end

local ps = game:GetService("Players")
while not ps.LocalPlayer do task.wait() end
local me = ps.LocalPlayer

getgenv().testhook = {
    repo = "https://raw.githubusercontent.com/beiley/martial-law/main/",
    games = {
        default = { name = "project delta", path = "games/project-delta" },
    },
    loaded = false
}

local function grab(path)
    local f = "testhook/" .. path .. ".lua"
    if isfile and isfile(f) then
        return readfile(f)
    end
    return game:HttpGet(testhook.repo .. path .. ".lua")
end

local function use(path)
    return loadstring(grab(path), path)()
end

physics = use("util/physics")
visual  = use("util/visual")
main    = use("util/main")

if queue_on_teleport then
    me.OnTeleport:Connect(function(s)
        if s == Enum.TeleportState.InProgress then
            queue_on_teleport(string.format([[loadstring(game:HttpGet("%sloader.lua"))()]], testhook.repo))
        end
    end)
end

local g = testhook.games[tostring(game.GameId)] or testhook.games.default
local mod = use(g.path)
if type(mod) == "table" and type(mod.init) == "function" then
    mod.init(testhook)
end

testhook.loaded = true

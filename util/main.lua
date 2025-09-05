local cas = game:GetService("ContextActionService")
local uis = game:GetService("UserInputService")
local ts = game:GetService("TeleportService")
local hs = game:GetService("HttpService")
local rs = game:GetService("RunService")
local ps = game:GetService("Players")
local ws = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local stats = game:GetService("Stats")

local main = { default_lighting = {} }

local cam = ws.CurrentCamera
local me = ps.LocalPlayer
local ping = stats.Network.ServerStatsItem["Data Ping"]
local terrain = ws:FindFirstChildOfClass("Terrain")

local xz, yv = Vector3.new(1,0,1), Vector3.new(0,1,0)
local move = {f=0,b=0,l=0,r=0,u=0,d=0}

local function flat(cf) return cf.LookVector * xz, cf.RightVector * xz end
local function norm(v) return v.Magnitude == 0 and v or v.Unit end
local function bind(name, state)
    move[name] = state == Enum.UserInputState.Begin and 1 or 0
    return Enum.ContextActionResult.Pass
end

cas:BindAction("f", bind, false, Enum.KeyCode.W)
cas:BindAction("b", bind, false, Enum.KeyCode.S)
cas:BindAction("l", bind, false, Enum.KeyCode.A)
cas:BindAction("r", bind, false, Enum.KeyCode.D)
cas:BindAction("u", bind, false, Enum.KeyCode.Space)
cas:BindAction("d", bind, false, Enum.KeyCode.LeftShift)

ws:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    cam = ws.CurrentCamera
end)

function main.fps_counter()
    local t0, list = os.clock(), {}
    return function()
        local now = os.clock()
        table.insert(list,1,now)
        while list[#list] and list[#list] < now-1 do
            table.remove(list)
        end
        return os.clock()-t0 >= 1 and #list or #list/(os.clock()-t0)
    end
end

function main.move_dir()
    local look, right = flat(cam.CFrame)
    local z = look * (move.f - move.b)
    local x = right * (move.r - move.l)
    local y = yv * (move.u - move.d)
    return norm(z+x+y)
end

function main.beam(a, b, color)
    local a0 = Instance.new("Attachment")
    a0.CFrame = CFrame.new(a)
    a0.Parent = terrain
    local a1 = Instance.new("Attachment")
    a1.CFrame = CFrame.new(b)
    a1.Parent = terrain
    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(color)
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.FaceCamera = true
    beam.Width0, beam.Width1 = 0.1, 0.1
    beam.Parent = terrain
    rs.Heartbeat:Connect(function()
        beam.Transparency = NumberSequence.new(1)
        a0:Destroy()
        a1:Destroy()
        beam:Destroy()
    end)
    return beam
end

function main.thread_loop(wait_time, fn)
    task.spawn(function()
        while true do
            local d = task.wait(wait_time)
            local ok, err = pcall(fn,d)
            if not ok then break end
            if err=="break" then break end
        end
    end)
end

function main.rejoin()
    if #ps:GetPlayers() <= 1 then
        me:Kick("rejoining")
        task.wait(.5)
        ts:Teleport(game.PlaceId)
    else
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end
end

function main.serverhop()
    local data = hs:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/0?sortOrder=2&excludeFullGames=true&limit=100")).data
    local ids = {}
    for _,v in ipairs(data) do
        if v.id ~= game.JobId then table.insert(ids,v.id) end
    end
    if #ids > 0 then
        ts:TeleportToPlaceInstance(game.PlaceId, ids[math.random(#ids)])
    end
end

function main.save_lighting()
    main.default_lighting = {
        Ambient = lighting.Ambient,
        Brightness = lighting.Brightness,
        ClockTime = lighting.ClockTime,
        ColorShift_Bottom = lighting.ColorShift_Bottom,
        ColorShift_Top = lighting.ColorShift_Top,
        EnvironmentDiffuseScale = lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = lighting.EnvironmentSpecularScale,
        ExposureCompensation = lighting.ExposureCompensation,
        FogColor = lighting.FogColor,
        FogEnd = lighting.FogEnd,
        FogStart = lighting.FogStart,
        GeographicLatitude = lighting.GeographicLatitude,
        GlobalShadows = lighting.GlobalShadows,
        OutdoorAmbient = lighting.OutdoorAmbient,
        ShadowSoftness = lighting.ShadowSoftness
    }
end

function main.restore_lighting()
    for k,v in pairs(main.default_lighting) do
        lighting[k] = v
    end
end

function main.set_lighting(tbl)
    for k,v in pairs(tbl) do
        if lighting[k] ~= nil then
            lighting[k] = v
        end
    end
end

return main

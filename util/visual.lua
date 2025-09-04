local drawing_handler = {}
local player_manager = {}
local esp_renderer = {}
local config = {}

local run_service = game:GetService("RunService")
local players_service = game:GetService("Players")
local workspace_service = game:GetService("Workspace")

local local_player = players_service.LocalPlayer
local camera = workspace_service.CurrentCamera

local active_objects = {}
local player_data = {}
local drawing_pool = {
    squares = {},
    texts = {},
    lines = {}
}

config.enabled_features = {
    box = false,
    healthbar = false,
    name = false,
    distance = false,
    skeleton = false,
    highlight = false
}

config.colors = {
    box = Color3.fromRGB(255, 255, 255),
    healthbar = Color3.fromRGB(0, 255, 0),
    name = Color3.fromRGB(255, 255, 255),
    distance = Color3.fromRGB(255, 255, 255),
    skeleton = Color3.fromRGB(255, 255, 255),
    highlight = Color3.fromRGB(255, 0, 0)
}

config.limits = {
    max_distance = 2000,
    health_bar_width = 2,
    outline_thickness = 3
}

local skeleton_joints = {
    ["LeftFoot"] = "LeftLowerLeg",
    ["LeftLowerLeg"] = "LeftUpperLeg", 
    ["LeftUpperLeg"] = "LowerTorso",
    ["RightFoot"] = "RightLowerLeg",
    ["RightLowerLeg"] = "RightUpperLeg",
    ["RightUpperLeg"] = "LowerTorso",
    ["LeftHand"] = "LeftLowerArm",
    ["LeftLowerArm"] = "LeftUpperArm",
    ["LeftUpperArm"] = "UpperTorso",
    ["RightHand"] = "RightLowerArm",
    ["RightLowerArm"] = "RightUpperArm", 
    ["RightUpperArm"] = "UpperTorso",
    ["LowerTorso"] = "UpperTorso",
    ["UpperTorso"] = "Head"
}

function drawing_handler.get_from_pool(drawing_type)
    local pool = drawing_pool[drawing_type .. "s"]
    if pool and #pool > 0 then
        local obj = table.remove(pool)
        obj.Visible = false
        return obj
    end
    
    local new_obj = Drawing.new(drawing_type == "square" and "Square" or 
                               drawing_type == "text" and "Text" or "Line")
    active_objects[#active_objects + 1] = new_obj
    return new_obj
end

function drawing_handler.return_to_pool(obj, drawing_type)
    if not obj then return end
    
    obj.Visible = false
    local pool = drawing_pool[drawing_type .. "s"]
    if pool then
        pool[#pool + 1] = obj
    end
end

function drawing_handler.setup_box_objects(data)
    data.box_outline = drawing_handler.get_from_pool("square")
    data.box_outline.Color = Color3.new(0, 0, 0)
    data.box_outline.Thickness = config.limits.outline_thickness
    data.box_outline.Filled = false
    
    data.box = drawing_handler.get_from_pool("square")
    data.box.Thickness = 1
    data.box.Filled = false
end

function drawing_handler.setup_health_objects(data)
    data.health_outline = drawing_handler.get_from_pool("square")
    data.health_outline.Color = Color3.new(0, 0, 0)
    data.health_outline.Thickness = 1
    data.health_outline.Filled = true
    
    data.health_bar = drawing_handler.get_from_pool("square") 
    data.health_bar.Thickness = 1
    data.health_bar.Filled = true
end

function drawing_handler.setup_text_objects(data)
    data.name_text = drawing_handler.get_from_pool("text")
    data.name_text.Size = 13
    data.name_text.Center = true
    data.name_text.Outline = true
    data.name_text.OutlineColor = Color3.new(0, 0, 0)
    data.name_text.Font = 2
    
    data.distance_text = drawing_handler.get_from_pool("text")
    data.distance_text.Size = 12
    data.distance_text.Center = true
    data.distance_text.Outline = true
    data.distance_text.OutlineColor = Color3.new(0, 0, 0)
    data.distance_text.Font = 2
end

function drawing_handler.setup_skeleton_objects(data)
    data.skeleton_lines = {}
    for joint_name, _ in pairs(skeleton_joints) do
        local line = drawing_handler.get_from_pool("line")
        line.Thickness = 1
        data.skeleton_lines[joint_name] = line
    end
end

function drawing_handler.cleanup_player_objects(data)
    if data.box then drawing_handler.return_to_pool(data.box, "square") end
    if data.box_outline then drawing_handler.return_to_pool(data.box_outline, "square") end
    if data.health_bar then drawing_handler.return_to_pool(data.health_bar, "square") end
    if data.health_outline then drawing_handler.return_to_pool(data.health_outline, "square") end
    if data.name_text then drawing_handler.return_to_pool(data.name_text, "text") end
    if data.distance_text then drawing_handler.return_to_pool(data.distance_text, "text") end
    
    for _, line in pairs(data.skeleton_lines or {}) do
        drawing_handler.return_to_pool(line, "line")
    end
    
    if data.highlight then
        data.highlight:Destroy()
    end
end

function player_manager.get_character_bounds(character)
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local success, bounding_cf, bounding_size = pcall(function()
        return character:GetBoundingBox()
    end)
    
    if not success then return nil end

    local max_extent = bounding_cf * CFrame.new(bounding_size / 2)
    local min_extent = bounding_cf * CFrame.new(bounding_size / -2)

    local corner_points = {
        Vector3.new(min_extent.Position.X, min_extent.Position.Y, min_extent.Position.Z),
        Vector3.new(min_extent.Position.X, max_extent.Position.Y, min_extent.Position.Z),
        Vector3.new(max_extent.Position.X, max_extent.Position.Y, min_extent.Position.Z),
        Vector3.new(max_extent.Position.X, min_extent.Position.Y, min_extent.Position.Z),
        Vector3.new(max_extent.Position.X, max_extent.Position.Y, max_extent.Position.Z),
        Vector3.new(min_extent.Position.X, max_extent.Position.Y, max_extent.Position.Z),
        Vector3.new(min_extent.Position.X, min_extent.Position.Y, max_extent.Position.Z),
        Vector3.new(max_extent.Position.X, min_extent.Position.Y, max_extent.Position.Z)
    }

    local screen_points = {}
    local all_visible = true
    
    for i, world_point in pairs(corner_points) do
        local screen_point, visible = camera:WorldToViewportPoint(world_point)
        screen_points[i] = screen_point
        if not visible then all_visible = false end
    end

    if not all_visible then return nil end

    local min_x, max_x = math.huge, -math.huge
    local min_y, max_y = math.huge, -math.huge

    for _, point in pairs(screen_points) do
        min_x = math.min(min_x, point.X)
        max_x = math.max(max_x, point.X)
        min_y = math.min(min_y, point.Y)
        max_y = math.max(max_y, point.Y)
    end

    return {
        x = math.floor(min_x),
        y = math.floor(min_y), 
        width = math.floor(max_x - min_x),
        height = math.floor(max_y - min_y)
    }
end

function player_manager.is_character_visible(target_character)
    if not target_character or not target_character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local ray_direction = target_character.HumanoidRootPart.Position - camera.CFrame.Position
    local ray_params = RaycastParams.new()
    ray_params.FilterDescendantsInstances = {camera, local_player.Character}
    ray_params.FilterType = Enum.RaycastFilterType.Blacklist

    local ray_result = workspace_service:Raycast(camera.CFrame.Position, ray_direction, ray_params)
    return ray_result and ray_result.Instance and ray_result.Instance:IsDescendantOf(target_character)
end

function player_manager.get_distance_to_player(target_player)
    if not target_player.Character or not target_player.Character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    if not local_player.Character or not local_player.Character:FindFirstChild("HumanoidRootPart") then
        return math.huge
    end
    
    local target_pos = target_player.Character.HumanoidRootPart.Position
    local local_pos = local_player.Character.HumanoidRootPart.Position
    return (target_pos - local_pos).Magnitude
end

function player_manager.create_player_data(target_player)
    local data = {
        target = target_player,
        box = nil,
        box_outline = nil,
        health_bar = nil,
        health_outline = nil,
        name_text = nil,
        distance_text = nil,
        skeleton_lines = {},
        highlight = nil
    }

    drawing_handler.setup_box_objects(data)
    drawing_handler.setup_health_objects(data)  
    drawing_handler.setup_text_objects(data)
    drawing_handler.setup_skeleton_objects(data)

    return data
end

function esp_renderer.hide_all_elements(data)
    if data.box then data.box.Visible = false end
    if data.box_outline then data.box_outline.Visible = false end
    if data.health_bar then data.health_bar.Visible = false end
    if data.health_outline then data.health_outline.Visible = false end
    if data.name_text then data.name_text.Visible = false end
    if data.distance_text then data.distance_text.Visible = false end
    
    for _, line in pairs(data.skeleton_lines) do
        if line then line.Visible = false end
    end
end

function esp_renderer.render_box_esp(data, bounds)
    if not config.enabled_features.box then
        if data.box then data.box.Visible = false end
        if data.box_outline then data.box_outline.Visible = false end
        return
    end

    data.box_outline.Position = Vector2.new(bounds.x - 1, bounds.y - 1)
    data.box_outline.Size = Vector2.new(bounds.width + 2, bounds.height + 2)
    data.box_outline.Visible = true

    data.box.Position = Vector2.new(bounds.x, bounds.y)
    data.box.Size = Vector2.new(bounds.width, bounds.height)
    data.box.Color = config.colors.box
    data.box.Visible = true
end

function esp_renderer.render_health_esp(data, bounds, humanoid)
    if not config.enabled_features.healthbar or not humanoid then
        if data.health_bar then data.health_bar.Visible = false end
        if data.health_outline then data.health_outline.Visible = false end
        return
    end

    local health_percentage = humanoid.Health / humanoid.MaxHealth
    local bar_height = math.floor(bounds.height * health_percentage)
    local bar_y = bounds.y + (bounds.height - bar_height)

    data.health_outline.Position = Vector2.new(bounds.x - 6, bounds.y - 1)
    data.health_outline.Size = Vector2.new(4, bounds.height + 2)
    data.health_outline.Visible = true

    data.health_bar.Position = Vector2.new(bounds.x - 5, bar_y)
    data.health_bar.Size = Vector2.new(config.limits.health_bar_width, bar_height)
    
    local health_hue = (120 / 360) * health_percentage
    data.health_bar.Color = Color3.fromHSV(health_hue, 1, 1)
    data.health_bar.Visible = true
end

function esp_renderer.render_name_esp(data, bounds)
    if not config.enabled_features.name then
        if data.name_text then data.name_text.Visible = false end
        return
    end

    data.name_text.Position = Vector2.new(bounds.x + bounds.width / 2, bounds.y - 16)
    data.name_text.Text = data.target.Name
    data.name_text.Color = config.colors.name
    data.name_text.Visible = true
end

function esp_renderer.render_distance_esp(data, bounds, distance)
    if not config.enabled_features.distance then
        if data.distance_text then data.distance_text.Visible = false end
        return
    end

    local distance_text = string.format("[%d studs]", math.floor(distance))
    data.distance_text.Position = Vector2.new(bounds.x + bounds.width / 2, bounds.y + bounds.height + 5)
    data.distance_text.Text = distance_text
    data.distance_text.Color = config.colors.distance
    data.distance_text.Visible = true
end

function esp_renderer.render_skeleton_esp(data, character)
    if not config.enabled_features.skeleton then
        for _, line in pairs(data.skeleton_lines) do
            if line then line.Visible = false end
        end
        return
    end

    for joint_name, parent_name in pairs(skeleton_joints) do
        local joint_part = character:FindFirstChild(joint_name)
        local parent_part = character:FindFirstChild(parent_name)
        local line_obj = data.skeleton_lines[joint_name]
        
        if joint_part and parent_part and line_obj then
            local joint_screen, joint_visible = camera:WorldToViewportPoint(joint_part.Position)
            local parent_screen, parent_visible = camera:WorldToViewportPoint(parent_part.Position)
            
            if joint_visible and parent_visible then
                line_obj.From = Vector2.new(joint_screen.X, joint_screen.Y)
                line_obj.To = Vector2.new(parent_screen.X, parent_screen.Y) 
                line_obj.Color = config.colors.skeleton
                line_obj.Visible = true
            else
                line_obj.Visible = false
            end
        end
    end
end

function esp_renderer.render_highlight_esp(data, character)
    if not config.enabled_features.highlight then
        if data.highlight then
            data.highlight:Destroy()
            data.highlight = nil
        end
        return
    end

    if not data.highlight and character then
        data.highlight = Instance.new("Highlight")
        data.highlight.Adornee = character
        data.highlight.FillTransparency = 0.5
        data.highlight.OutlineColor = Color3.new(0, 0, 0)
        data.highlight.OutlineTransparency = 0
        data.highlight.Parent = character
    end

    if data.highlight and data.highlight.Parent then
        if player_manager.is_character_visible(character) then
            data.highlight.FillColor = Color3.fromRGB(255, 0, 0)
        else
            data.highlight.FillColor = Color3.fromRGB(0, 0, 255)
        end
    end
end

local function process_player_esp(target_player)
    if target_player == local_player then return end
    
    local user_id = target_player.UserId
    
    if not player_data[user_id] then
        player_data[user_id] = player_manager.create_player_data(target_player)
    end
    
    local data = player_data[user_id]
    local character = target_player.Character
    
    if not character then
        esp_renderer.hide_all_elements(data)
        if data.highlight then
            data.highlight:Destroy()
            data.highlight = nil
        end
        return
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        esp_renderer.hide_all_elements(data)
        if data.highlight then
            data.highlight:Destroy()
            data.highlight = nil 
        end
        return
    end
    
    local distance = player_manager.get_distance_to_player(target_player)
    if distance > config.limits.max_distance then
        esp_renderer.hide_all_elements(data)
        return
    end
    
    local character_bounds = player_manager.get_character_bounds(character)
    if not character_bounds then
        esp_renderer.hide_all_elements(data)
        return
    end
    
    esp_renderer.render_box_esp(data, character_bounds)
    esp_renderer.render_health_esp(data, character_bounds, humanoid)
    esp_renderer.render_name_esp(data, character_bounds)
    esp_renderer.render_distance_esp(data, character_bounds, distance)
    esp_renderer.render_skeleton_esp(data, character)
    esp_renderer.render_highlight_esp(data, character)
end

local function cleanup_disconnected_players()
    for user_id, data in pairs(player_data) do
        local player_exists = false
        
        for _, active_player in pairs(players_service:GetPlayers()) do
            if active_player.UserId == user_id then
                player_exists = true
                break
            end
        end
        
        if not player_exists then
            drawing_handler.cleanup_player_objects(data)
            player_data[user_id] = nil
        end
    end
end

local function main_render_loop()
    for _, target_player in pairs(players_service:GetPlayers()) do
        process_player_esp(target_player)
    end
    
    cleanup_disconnected_players()
end

run_service.Heartbeat:Connect(main_render_loop)

local visual = {
    player = config.enabled_features,
    colors = config.colors,
    settings = {
        distance_limit = config.limits.max_distance
    }
}

return visual

local physics = {}

local sqrt, acos, atan2, sin, cos = math.sqrt, math.acos, math.atan2, math.sin, math.cos
local pi, abs, floor, ceil = math.pi, math.abs, math.floor, math.ceil

function physics.magnitude(v)
    return sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
end

function physics.sqr_magnitude(v)
    return v.X * v.X + v.Y * v.Y + v.Z * v.Z
end

function physics.unit(v)
    local m = physics.magnitude(v)
    return m == 0 and Vector3.zero or v / m
end

function physics.dot(a, b)
    return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end

function physics.cross(a, b)
    return Vector3.new(
        a.Y * b.Z - a.Z * b.Y,
        a.Z * b.X - a.X * b.Z,
        a.X * b.Y - a.Y * b.X
    )
end

function physics.lerp(a, b, t)
    return a + (b - a) * t
end

function physics.clamp(x, minv, maxv)
    return x < minv and minv or (x > maxv and maxv or x)
end

function physics.angle_between(a, b)
    local d = physics.magnitude(a) * physics.magnitude(b)
    return d == 0 and 0 or acos(physics.dot(a, b) / d)
end

function physics.distance(a, b)
    return physics.magnitude(a - b)
end

function physics.sqr_distance(a, b)
    local d = a - b
    return d.X * d.X + d.Y * d.Y + d.Z * d.Z
end

function physics.trajectory(origin, target_pos, target_vel, projectile_speed, gravity)
    local rel = target_pos - origin
    local t = physics.distance(origin, target_pos) / projectile_speed
    local predicted = target_pos + target_vel * t
    local dir = predicted - origin
    local flat = Vector3.new(dir.X, 0, dir.Z)
    local dist = physics.magnitude(flat)
    local h = dir.Y
    local v2 = projectile_speed * projectile_speed
    local g = gravity or workspace.Gravity
    local root = v2 * v2 - g * (g * dist * dist + 2 * h * v2)
    if root < 0 then return nil end
    local angle = atan2(v2 - sqrt(root), g * dist)
    local vx = cos(angle) * projectile_speed
    local vy = sin(angle) * projectile_speed
    return physics.unit(flat) * vx + Vector3.yAxis * vy
end

return physics

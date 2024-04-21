log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- Parameters

local base_speed = 4
local speed_up = 1.4
local damage_coeff = 0.7
local throw_gravity = 0.25
local throw_speed = -4.5
local hit_distance = 50
local max_ball_bounces = 10


---------

local old_variables = {}
local old_balls = {}

function create_ball(parent)
    -- Grenade is recreated
    local ball = gm.instance_create_depth(parent.x, parent.y, 1, 681)
    ball.parent = parent
    --transform
    ball.gravity = throw_gravity
    ball.vspeed, ball.hspeed =  throw_speed, 0.0
    ball.old_vspeed, ball.old_hspeed= throw_speed, 0.0
    --properties
    ball.bounces = - max_ball_bounces + 3
    ball.is_ball, ball.status = true, "bunted_up"
    ball.damage_coeff = damage_coeff

    old_variables[#old_variables + 1] = get_ball_vars(ball)
    return ball
end

function recreate_ball(old_var, old_index)
    ball = gm.instance_create_depth(old_var.x , old_var.y, 1, 681)
    ball.parent = old_var.par
    -- transform
    ball.gravity = 0
    ball.hspeed, ball.vspeed = -old_var.old_hspeed, old_var.old_vspeed
    ball.old_hspeed, ball.old_vspeed = -old_var.old_hspeed, old_var.old_vspeed
    -- --properties
    ball.bounces = old_var.bounces - 1
    ball.is_ball, ball.status = true, "hit"
    ball.damage_coeff = old_var.damage_coeff

    old_variables[old_index] = get_ball_vars(ball)

    return ball
end

function get_ball_vars(ball)
    return {
        x = ball.x,
        y = ball.y,
        par = ball.parent,
        old_hspeed = ball.old_hspeed, 
        old_vspeed = ball.old_vspeed,
        bounces = ball.bounces,
        status = ball.status,
        is_ball = ball.is_ball,
    }
end

function find_closest_ball(parent)
    local balls, balls_exist = Helper.find_active_instance_all(gm.constants.oEngiGrenade)
    if not balls_exist then return nil end
    local closest_ball = nil
    local distance  = 0 
    local closest_distance = 10000000000
    for i=1, #balls do
        if balls[i].is_ball then
            distance = (balls[i].x - parent.x)*(balls[i].x - parent.x) + (balls[i].y - parent.y)*(balls[i].y - parent.y) -- clean this later
            if distance < closest_distance then 
                closest_distance = distance
                closest_ball = balls[i]
            end
        end
    end
    return closest_ball, math.sqrt(closest_distance)
end

function hit_ball(ball, parent, distance)
    local speed = base_speed
    if distance > hit_distance then return end
    --local speed = (ball.status == "bunted") and base_speed or ball.hspeed * 2
    if ball.status == "hit" then 
        if gm.actor_get_facing_direction(parent) == 180 then -- facing left
            ball.hspeed = - math.abs(ball.old_hspeed) * speed_up
        else -- facing right
            ball.hspeed = math.abs(ball.old_hspeed) * speed_up
        end
        
    else 
        if ball.status == "bunted_top" then speed = speed * 2 end

        if gm.actor_get_facing_direction(parent) == 180 then -- facing left
            ball.hspeed = - speed
        else -- facing right
            ball.hspeed = speed
        end
    end 
    ball.vspeed = 0
    ball.old_vspeed = 0
    ball.old_hspeed = ball.hspeed
    ball.gravity = 0
    ball.damage_coeff = damage_coeff * speed
    ball.status = "hit"
end

find_balls_all = function()
    local balls = {}
    local ball = nil
    for i = 0, gm.instance_number(gm.constants.oEngiGrenade) - 1 do
        ball = gm.instance_find(gm.constants.oEngiGrenade, i)
        if ball.status then table.insert(balls, ball) end
    end
    return balls, #balls > 0
end

function update_balls()
    local balls, balls_exist = find_balls_all(gm.constants.oEngiGrenade)
    --if not balls_exist then return nil end
    for i=1, #balls do
        if balls[i].status == "hit" then
            if math.abs(balls[i].hspeed) < 2 then
                balls[i].x = balls[i].x - 2 * balls[i].old_hspeed
                balls[i].hspeed = - balls[i].old_hspeed
                balls[i].vspeed = balls[i].old_vspeed 
                balls[i].damage_coeff = damage_coeff * math.abs(balls[i].hspeed)
            end
        elseif balls[i].status == "bunted_up" then
            if balls[i].vspeed < -1.0 then
                balls[i].status = "bunted_top"
            end
        elseif balls[i].status == "bunted_top" then
            if balls[i].vspeed > 1.0 then
                balls[i].status = "bunted_down"
            end
        elseif balls[i].status == "bunted_down" then
            if balls[i].vspeed < 1.0 then
                balls[i].status = "grounded"
            end
        elseif balls[i].status == "grounded" then
            balls[i].gravity = 0
            balls[i].hspeed = 0
            balls[i].vspeed = 0
        end
        balls[i].old_hspeed = balls[i].hspeed
    end

    if #old_balls ~= #balls then
        local index = 1
        for old_index = 1, #old_balls do
            if not balls[index] or old_balls[old_index].id ~= balls[index].id then
                local old_ball = old_balls[old_index]
                recreate_ball(old_variables[old_index], old_index)
            else
                index = index + 1
            end
        end
    end
    old_balls = balls
    old_variables = {}
    -- variables[] don't stay on object destroy 
    for i = 1, #balls do
        old_variables[i] = get_ball_vars(balls[i])
    end
end

local client_player = nil
gm.post_script_hook(gm.constants.skill_activate, function(self, other, result, args)
    client_player = Helper.get_client_player() -- get the client
    if self ~= client_player then return end -- is the client using the skill
    if args[1].value == 0 then -- ball throw
        create_ball (client_player)
    end 
    if args[1].value == 1 then -- ball hit
        local ball, distance = find_closest_ball(client_player)
        if ball ~= nil then hit_ball(ball, client_player, distance) end
    end
end)

gm.post_script_hook(gm.constants.__input_system_tick, function() 
    update_balls()
end) 

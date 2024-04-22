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
local custom_id = 0


---------

local old_variables = {}

function create_ball(parent)
    -- Grenade is recreated
    local ball = gm.instance_create_depth(parent.x, parent.y, 1, 681)
    ball.parent = parent
    ball.custom_id = custom_id
    custom_id = custom_id + 1
    --transform
    ball.gravity = throw_gravity
    ball.vspeed, ball.hspeed =  throw_speed, 0.0
    ball.old_vspeed, ball.old_hspeed= throw_speed, 0.0
    --properties
    ball.bounces = - max_ball_bounces + 3
    ball.is_ball, ball.status = true, "bunted_up"
    ball.damage_coeff = damage_coeff

    old_variables[ball.custom_id] = get_ball_vars(ball)
    return ball
end

function recreate_ball(old_var, old_index)
    ball = gm.instance_create_depth(old_var.x - old_var.old_hspeed * 5, old_var.y, 1, 681)
    ball.parent = old_var.par
    ball.custom_id = old_var.custom_id
    -- transform
    ball.gravity = 0
    ball.hspeed, ball.vspeed = -old_var.old_hspeed, old_var.old_vspeed
    ball.old_hspeed, ball.old_vspeed = -old_var.old_hspeed, old_var.old_vspeed
    -- --properties
    ball.bounces = old_var.bounces + 1
    ball.is_ball, ball.status = true, "hit"
    ball.damage_coeff = damage_coeff * math.abs(ball.hspeed)

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
        custom_id = ball.custom_id,
    }
end

function find_closest_ball(parent)
    local balls, balls_exist = Helper.find_active_instance_all(gm.constants.oEngiGrenade)
    if not balls_exist then return nil end
    local closest_ball = nil
    local distance  = 0 
    local closest_distance = 10000000000000
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
    ball.damage_coeff = damage_coeff * math.abs(ball.hspeed)
    ball.status = "hit"
end

function find_balls_all()
    local balls = {}
    local ball = nil
    for i = 0, gm.instance_number(gm.constants.oEngiGrenade) - 1 do
        ball = gm.instance_find(gm.constants.oEngiGrenade, i)
        if ball ~=nil and ball.status then balls[ball.custom_id] = ball end
    end
    return balls, next(balls) ~= nil
end

function update_balls() 
    local balls, balls_exist = find_balls_all()
    if not balls_exist and next(old_variables) == nil then return nil end -- if no old or new balls exist
    
    -- ball bounce and status
    for c_id, ball in pairs(balls) do
        if ball.status == "hit" then
            if math.abs(ball.hspeed) < 2 then
                ball.x = ball.x - 2 * ball.old_hspeed
                ball.hspeed = - ball.old_hspeed
                ball.vspeed = ball.old_vspeed 
                ball.damage_coeff = damage_coeff * math.abs(ball.hspeed)
            end
        elseif ball.status == "bunted_up" then
            if ball.vspeed < -1.0 then
                ball.status = "bunted_top"
            end
        elseif ball.status == "bunted_top" then
            if ball.vspeed > 1.0 then
                ball.status = "bunted_down"
            end
        elseif ball.status == "bunted_down" then
            if ball.vspeed < 1.0 then
                ball.status = "grounded"
            end
        elseif ball.status == "grounded" then
            ball.gravity = 0
            ball.hspeed = 0
            ball.vspeed = 0
        end
        ball.old_hspeed = ball.hspeed
    end

    -- Save ball info and recreate balls when they hit and ennemy
    new_variables = {}
    local index = 1
    for c_id, old_values in pairs(old_variables) do
        if old_values.bounces < 3 -- grenades explode on 3rd bounce
        and old_values.status == "hit" -- don't bounce ball against ennemies if it's bunted
        and not balls[c_id] -- ball doesnt exist anymore
        then
            local reborn_ball = recreate_ball(old_variables[c_id], old_index)
            --print(reborn_ball)
            new_variables[c_id] = get_ball_vars(reborn_ball)
        else
            if balls[c_id] ~= nil then
                new_variables[c_id] = balls[c_id]
                index = index + 1
            end
        end
    end
    for c_id, values in pairs(balls) do
        new_variables[c_id] = get_ball_vars(balls[c_id])
    end
    --debug
    old_variables = new_variables
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

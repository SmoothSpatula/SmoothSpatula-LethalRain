log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- Testing grenades

local grenade_table = {}
local count = 0

-- Parameters

local base_speed = 4
local speed_up = 1.2
local damage_coeff = 5
local throw_gravity = 0.25
local throw_speed = -5
local hit_distance = 100

function create_ball(old, parent)
    -- Grenade is recreated
    if old ~= nil then
        if old.hspeed >0 then
            ball = gm.instance_create_depth(old.x - old.hspeed*5, old.y, 1, 681)
        else
            ball = gm.instance_create_depth(old.x - old.hspeed*5, old.y, 1, 681)
        end
        ball.hspeed = -old.hspeed
        ball.parent = parent
        ball.is_ball = true, 
        print(ball)
        return ball
    else -- Grenade is new and thrown up
        local ball = gm.instance_create_depth(parent.x, parent.y, 1, 681)
        print(parent.y)
        ball.parent = parent
        ball.gravity = throw_gravity
        ball.vspeed =  throw_speed
        ball.bounces = -1000
        ball.is_ball, ball.status = true, "bunted"
        ball.old_vspeed, ball.old_hspeed = throw_speed, 0.0
        ball.damage_coeff = damage_coeff
        print(ball.id)
        --ball.team = 1000
        -- update table info 
        return ball
    end
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
    if distance > hit_distance then return end
    --local speed = (ball.status == "bunted") and base_speed or ball.hspeed * 2
    if ball.status == "hit" then 
        ball.hspeed = -ball.hspeed * speed_up
    else 
        if gm.actor_get_facing_direction(parent) == 180 then -- facing left
            ball.hspeed = -base_speed
        else -- facing right
            ball.hspeed = base_speed
        end
    end 
    ball.vspeed = 0
    ball.old_vspeed = 0
    ball.old_hspeed = ball.hspeed
    ball.gravity = 0
    ball.status = "hit"
end

function update_balls()
    local balls, balls_exist = Helper.find_active_instance_all(gm.constants.oEngiGrenade)
    if not balls_exist then return nil end
    for i=1, #balls do
        if balls[i].is_ball and balls[i].status == "hit" then
            if math.abs(balls[i].hspeed) < 2 then
                balls[i].x = balls[i].x + 5 * balls[i].hspeed
                balls[i].hspeed = - balls[i].old_hspeed
                balls[i].vspeed = balls[i].old_vspeed 
            end
            if math.abs(balls[i].hspeed) < 2 then
                balls[i].y = balls[i].y + 5 * balls[i].vspeed
                balls[i].vspeed = - balls[i].old_vspeed
                balls[i].hspeed = balls[i].old_hspeed 
            end
            balls[i].old_hspeed = balls[i].hspeed
        end
    end
end

function check_grenades()
    for index, grenade in pairs(grenade_table) do
        --print(grenade.c.." - "..count)
        if grenade.c < count and grenade.c >0 then
            grenade.c = -1
            -- x,y, ?, object index
            local inst = nil
            inst = create_ball (grenade.obj, client_player)
            grenade_table[inst.id] = {
                obj = inst,
                c = count
            }
            --table.remove(grenade_table, index) 
            print(#grenade_table)
        end
    end
end

local client_player = nil
gm.post_script_hook(gm.constants.skill_activate, function(self, other, result, args)
    client_player = Helper.get_client_player() -- get the client
    if self ~= client_player then return end -- is the client using the skill
    if args[1].value == 0 then -- ball throw
        create_ball (nil, client_player)
    end 
    if args[1].value == 1 then -- ball hit
        local ball, distance = find_closest_ball(client_player)
        if ball ~= nil then hit_ball(ball, client_player, distance) end
    end
end)


gm.post_script_hook(gm.constants.__input_system_tick, function() 
    update_balls()
end)

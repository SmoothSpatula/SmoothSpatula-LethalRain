log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- ========== Parameters ==========  

local base_speed = 4
local speed_up = 1.4
local damage_coeff = 0.5 -- Ball damage = damage_coeff * ball speed
local throw_gravity = 0.25
local throw_speed = -4.5
local hit_distance = 40
local bunt_distance = 60
local max_ball_bounces = 12
local max_speed = 50
local throw_displacement_x = 10 
local bunt_displacement_x = 30

local special_timer = 0 
local special_duration = 420 -- 10 seconds
local special_range_x = 150
local special_range_y = 100
local special_display_1 = nil
local special_display_2 = nil

-- ========== Vars ==========   

local old_variables = {}
local old_balls = {}
local custom_id = 0
local ingame = false
local client_player = nil


-- ========== Sprite ==========  

-- Using a modified version of https://elthen.itch.io/2d-pixel-art-portal-sprites as a placeholder
local sprite_test = _ENV["!plugins_mod_folder_path"].."/PurplePortalSpriteSheet192x96.png"
local sprite_test2 = gm.sprite_add(sprite_test, 8, false, false, 48, 105)

-- States : bunted_up, bunted_top, bunted_down, grounded, hit, (special)

-- ========== Ball Handling ==========  

-- Like the phoenix, the ball rises from the ashes upon hitting an ennemy
function recreate_old_ball(old_var)
    ball = gm.instance_create_depth(old_var.x - (old_var.old_hspeed * 5), old_var.y, 1, 681)
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
    --ball.sprite_index = gm.constants.sEngiGrenadeP
    return ball
end

-- The variable[] array in instances which contains all custom vars as well as some others gets deleted upon instance destruction
-- So we back it up
function get_ball_vars(ball)
    return {
        par = ball.parent,
        x = ball.x,
        y = ball.y,
        old_hspeed = ball.old_hspeed, 
        old_vspeed = ball.old_vspeed,
        bounces = ball.bounces,
        status = ball.status,
        is_ball = ball.is_ball,
        custom_id = ball.custom_id,
    }
end

-- returns the single closest ball
function find_closest_ball(parent)
    
    if not next(old_balls) then return nil end -- return if balls are empty
    local closest_ball = nil
    local distance = 0
    local closest_distance = 10000000000000
    for c_id, ball in pairs(old_balls) do
        distance = (ball.x - parent.x)*(ball.x - parent.x) + (ball.y - parent.y)*(ball.y - parent.y) -- clean this later
        if distance < closest_distance then 
            closest_distance = distance
            closest_ball = ball
        end
    end
    return closest_ball, math.sqrt(closest_distance)
end

-- returns all the balls under a certain distance
function find_balls_under_distance(x, y, dist)
    if not next(old_balls) then return nil end -- return if balls are empty
    local close_balls = {}
    local max_distance = dist*dist
    local distance = 0 
    for c_id, ball in pairs(old_balls) do
        distance = (ball.x - x)*(ball.x - x) + (ball.y - y)*(ball.y - y) -- clean this later (can make it way faster)
        if distance < max_distance then 
            table.insert(close_balls, #close_balls + 1 ,ball)
        end
    end
    return close_balls
end

-- ========== Skills ==========

-- Throws the  ball up in 'bunted' state 
function create_new_ball(parent)
    -- Grenade is recreated
    local x_pos = parent.x + throw_displacement_x
    if gm.actor_get_facing_direction(parent) == 180 then
        x_pos = x_pos - 2* throw_displacement_x
    end

    local ball = gm.instance_create_depth(x_pos, parent.y, 1, 681)
    ball.parent = parent
    ball.custom_id = custom_id
    custom_id = custom_id + 1
    --transform
    ball.gravity = throw_gravity
    ball.vspeed, ball.hspeed =  throw_speed, 0.0
    ball.old_vspeed, ball.old_hspeed= throw_speed, base_speed
    --properties
    ball.bounces = - max_ball_bounces + 3
    ball.is_ball, ball.status = true, "bunted_up"
    ball.damage_coeff = damage_coeff
    --ball.sprite_index = gm.constants.sEngiGrenadeP

    old_variables[ball.custom_id] = get_ball_vars(ball)
    old_balls[ball.custom_id] = ball
    return ball
end

-- Hits the ball, giving it some speed and changing it's state to 'hit'
-- Hitting the ball at it's apex makes it go twice as fast
function hit_ball(ball, parent)
    local speed = ball.old_hspeed
    if ball.status =="hit" then 
        if gm.actor_get_facing_direction(parent) == 180 then -- facing left
            ball.hspeed = - math.min(max_speed, math.abs(ball.old_hspeed) * speed_up)
        else -- facing right
            ball.hspeed = math.min(max_speed, math.abs(ball.old_hspeed) * speed_up)
        end
        
    else 
        if ball.status == "bunted_top" then speed = ball.old_hspeed * 2 end

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

-- Bunts the ball, stoping its momentum but storing its speed for when it's hit again
-- Resets the ball's bounces
function bunt_ball(ball, parent)
    ball.parent = parent
    --transform
    ball.gravity = throw_gravity
    ball.vspeed, ball.hspeed =  throw_speed, 0.0
    -- ball.old_vspeed, ball.old_hspeed= throw_speed, 0.0
    --properties
    ball.bounces = - max_ball_bounces + 3
    ball.is_ball, ball.status = true, "bunted_up"
    ball.damage_coeff = damage_coeff
    print(ball.old_hspeed)
    return ball
end


function special_skill(parent, time)
    if special_timer > 0 then 
        special_timer = special_duration
        return 
    end
    special_display_1 = gm.instance_create_depth(parent.x + special_range_x, parent.y, 1, gm.constants.oBossRain)
    special_display_2 = gm.instance_create_depth(parent.x - special_range_x, parent.y, 1, gm.constants.oBossRain)
    special_display_1.parent, special_display_2.parent = parent, parent
    special_display_1.sprite_index, special_display_2.sprite_index = sprite_test2, sprite_test2

    special_display_1.image_speed, special_display_2.image_speed = 0.2, 0.2
    special_timer = special_duration
end

--oChefPot decent
--oHUDTabMenu could work with deactivating the menu itself, should cause issues with normal tab menu

-- ========== Main ==========

function update_balls() 
    special_timer = special_timer - 1
    if special_timer>0 then 
        special_display_1.x, special_display_2.x =  client_player.x + special_range_x, client_player.x - special_range_x
        special_display_1.y, special_display_2.y =  client_player.y, client_player.y
    elseif special_timer == 0 then
        gm.instance_destroy(special_display_1)
        gm.instance_destroy(special_display_2)
    end
    if not next(old_balls) and not next(old_variables) then return nil end -- if no old or new balls exist

    new_variables = {}

    for c_id, ball in pairs(old_balls) do -- for all the new balls
        if not ball.custom_id then -- if a ball is missing
            if old_variables[c_id].bounces < 3 -- grenades explode on 3rd bounce
            and old_variables[c_id].status == "hit" then -- bunted balls don't revive
                local reborn_ball = recreate_old_ball(old_variables[c_id])
                old_balls[c_id] = reborn_ball --Add ball back to array
                new_variables[c_id] = get_ball_vars(reborn_ball) --Save ball
            else
                old_balls[c_id] = nil -- remove old balls
            end
        else 
            -- If ball is alive, manage it's speed and status
            if ball.status == "hit" then
                if math.abs(ball.hspeed) < 2 then
                    ball.x = ball.x - 2 * ball.old_hspeed
                    ball.hspeed = - ball.old_hspeed
                    ball.vspeed = ball.old_vspeed 
                    ball.damage_coeff = damage_coeff * math.abs(ball.hspeed)
                else
                    ball.old_hspeed = ball.hspeed
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
            if special_timer > 0 then
                if math.abs(ball.y - client_player.y) < special_range_y then
                    if ball.x > (client_player.x + special_range_x) then 
                        ball.x = client_player.x - special_range_x
                    elseif ball.x < (client_player.x - special_range_x) then 
                        ball.x = client_player.x + special_range_x
                    end
                end
            end
            new_variables[c_id] = get_ball_vars(ball) --Save ball vars
        end
    end

    old_variables = new_variables
end

-- ========== Hooks ==========

gm.post_script_hook(gm.constants.skill_activate, function(self, other, result, args)
    client_player = Helper.get_client_player() -- get the client
    if self ~= client_player then return end -- is the client using the skill
    if args[1].value == 0 then -- ball throw
        create_new_ball(client_player)
    end 
    -- if args[1].value == 1 then -- hitting one ball
    --     local ball, distance = find_closest_ball(client_player)
    --     if ball ~= nil then hit_ball(ball, client_player, distance) end
    -- end
    if args[1].value == 1 then --hit
        local close_balls = find_balls_under_distance(client_player.x, client_player.y, hit_distance)
        if not close_balls then return end
        for _, ball in pairs(close_balls) do
            hit_ball(ball, client_player, 0)
        end
    end
    if args[1].value == 2 then --bunt
        local displacement_x = bunt_displacement_x
        if gm.actor_get_facing_direction(client_player) == 180 then displacement_x = - bunt_displacement_x end -- facing left
        local close_balls = find_balls_under_distance(client_player.x + displacement_x, client_player.y, bunt_distance)
        if not close_balls then return end
        for _, ball in pairs(close_balls) do
            bunt_ball(ball, client_player, 0)
        end
    end
    if args[1].value == 3 then --special
        special_skill(client_player, 0)
    end

end)

gm.post_script_hook(gm.constants.__input_system_tick, function() 
    update_balls()
end)

-- Reset Arrays
gm.pre_script_hook(gm.constants.run_create, function(self, other, result, args)
    --ingame = true
    local custom_id = 0
    old_variables = {}
    old_balls = {}
end)

gm.post_script_hook(gm.constants.actor_phy_on_landed, function(self, other, result, args)
    ingame = true
end)

gm.pre_script_hook(gm.constants.run_destroy, function(self, other, result, args)
    ingame = false
end)

ingame = false
-- local rec_w = 150
-- local rec_h = 75
-- local win_h = nil
-- local win_w = nil
-- local surf = -1
-- gm.pre_code_execute(function(self, other, code, result, flags)
    
--     if code.name:match("oInit_Draw_7") then
        
--         client_player = Helper.get_client_player()
--         local cam = gm.view_get_camera(0)
--         if not win_h or not win_w then win_h, win_w = gm.camera_get_view_height(cam)/2, gm.camera_get_view_width(cam)/2 end
        
--         if gm.surface_exists(surf) == 0.0 then surf = gm.surface_create(gm.camera_get_view_width(cam), gm.camera_get_view_height(cam)) end
--         gm.surface_set_target(surf)
--         gm.draw_clear_alpha(16777215,0)
--         gm.draw_sprite(sprite_test2,(timer/10)%8, win_w-70, win_h+80)
--         gm.draw_sprite(sprite_test2,(timer/10)%8, win_w+250, win_h+80)
--         gm.surface_reset_target()
        
--         gm.draw_surface(surf, gm.camera_get_view_x(cam), gm.camera_get_view_y(cam))
--     end
-- end)


function get_variables(inst)
    if inst then
        local vars = {}
        local var_names = gm.variable_instance_get_names(inst.id)
        for i = 1, #var_names do
            local var_name = var_names[i]
            if var_name~=nil then
                local data = tostring(var_name)
                if gm.variable_instance_exists(inst.id, var_name) then
                    local variable = gm.variable_instance_get(inst.id, var_name)
                    data = data.."  =  "..tostring(variable)
                end
                table.insert(vars, data)
            end
        end
        
        table.sort(vars)
        
        for i = 1, #vars do print(vars[i]) end
    end
end

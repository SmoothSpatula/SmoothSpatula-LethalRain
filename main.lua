log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- Testing grenades

local grenade_table = {}
local count = 0
local client_player = nil

-- Parameters

local damage_coeff = 5
local throw_gravity = 0.25
local throw_speed = -5

function create_ball(old, parent)
    -- Grenade is recreated
    if old ~= nil then
        if old.hspeed >0 then
            inst = gm.instance_create_depth(old.x - old.hspeed*5, old.y, 1, 681)
        else
            inst = gm.instance_create_depth(old.x - old.hspeed*5, old.y, 1, 681)
        end
        inst.hspeed = -old.hspeed
        inst.parent = parent
        inst.is_ball = true
        print(inst)
        return inst
    else -- Grenade is new and thrown up
        inst = gm.instance_create_depth(parent.x, parent.y, 1, 681)
        inst.parent = parent
        inst.gravity = throw_gravity
        inst.vspeed =  throw_speed
        inst.bounces = -100
        inst.is_ball = true
        inst.damage_coeff = damage_coeff
        print(inst.id)
        --inst.team = 1000
        -- update table info 
        return inst
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
            distance = (balls[i].x - parent.x)*(balls[i].x - parent.x) + (balls[i].y - parent.y)*(balls[i].y - parent.y)
            if distance < closest_distance then 
                closest_distance = distance
                closest_ball = balls[i]
            end
        end
    end
    return closest_ball, math.sqrt(closest_distance)
end

function hit_ball(ball, parent, distance)
    if distance > 30 then return end
    if gm.actor_get_facing_direction(parent) == 180 then -- facing left
        ball.hspeed = -8
    else -- facing right
        ball.hspeed = 8
    end
    ball.vspeed = 0
    ball.gravity = 0
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

gm.post_script_hook(gm.constants.skill_activate, function(self, other, result, args)
    if not client_player then client_player = Helper.get_client_player() end --get the client
    if self ~= client_player then return end -- is the client using the skill
    if args[1].value == 0 then -- ball throw
        create_ball (nil, client_player)
    end 
    if args[1].value == 1 then -- ball hit
        local ball, distance = find_closest_ball(client_player)
        if ball ~= nil then hit_ball(ball, client_player, distance) end
    end
end)

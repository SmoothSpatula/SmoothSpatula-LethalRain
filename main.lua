log.info("Successfully loaded ".._ENV["!guid"]..".")
survivor_setup = require("./survivor_setup")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- Testing grenades

local grenade_table = {}
local count = 0
local client_player = nil

-- Character parameters

local portrait_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanPortrait.png")
local portraitsmall_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanPortraitSmall.png")

local loadout_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanLoadout.png")
local idle_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanIdle.png")
local walk_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanWalk.png")
local shoot1_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanShoot1.png")
local shoot1_air_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanShoot1Air.png")
local shoot2_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanShoot2.png")
local death_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanDeath.png")
local jump_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanjump.png")
local jumpfall_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanjumpfall.png")
local hit_path = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites", "sCandymanhit.png")

local portrait_sprite = gm.sprite_add(portrait_path, 1, false, false, 0, 0)
local portraitsmall_sprite = gm.sprite_add(portraitsmall_path, 1, false, false, 0, 0)

local loadout_sprite = gm.sprite_add(loadout_path, 7, false, false, 100, 5)
local idle_sprite = gm.sprite_add(idle_path, 3, false, false, 40, 53)
local walk_sprite = gm.sprite_add(walk_path, 2, false, false, 40, 52)
local shoot1_sprite = gm.sprite_add(shoot1_path, 7, false, false, 40, 42)
local shoot1_air_sprite = gm.sprite_add(shoot1_air_path, 7, false, false, 40, 58)
local shoot2_sprite = gm.sprite_add(shoot2_path, 4, false, false, 40, 50)
local death_sprite = gm.sprite_add(death_path, 4, false, false, 40, 39)
local jump_sprite = gm.sprite_add(jump_path, 1, false, false, 10, 54)
local jumpfall_sprite = gm.sprite_add(jumpfall_path, 1, false, false, 17, 36)
local hit_sprite = gm.sprite_add(hit_path, 1, false, false, 20, 46)

-- if new_sprite == -1 then
--     log.warning("Failed loading sprite", file_name, file_path)
--     return gm.constants.sCommandoWalk
-- end

--[==[ Section Ball Handling ]==]--

-- ========== Parameters ==========  

local base_speed = 4
local speed_up = 1.4
local damage_coeff = 0.5 -- Ball damage = damage_coeff * ball speed
local throw_gravity = 0.25
local throw_speed = -4.5
local bunt_speed = -7
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
local sprite_test = path.combine(_ENV["!plugins_mod_folder_path"], "Sprites","PurplePortalSpriteSheet192x96.png")
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
    ball.vspeed, ball.hspeed =  bunt_speed , 0.0
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
                if math.abs(ball.y - client_player.y) < special_range_y and math.abs(ball.x - client_player.x) < special_range_x + 40 then
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


-- Survivor Setup

local candyman_id = -1
local candyman = nil


local function create_survivor()
    candyman_id = gm.survivor_create("SmoothSpatula", "Candyman")
    candyman = survivor_setup.Survivor(candyman_id)
    local commando_survivor_id = 0
    local vanilla_survivor = survivor_setup.Survivor(commando_survivor_id)

    -- configure properties
    candyman.token_name = "Candyman"
    candyman.token_name_upper = "CANDYMAN"
    candyman.token_description = "He's here to smash and bunt!"
    candyman.token_end_quote = "It was a fun ride"

    candyman.sprite_loadout = loadout_sprite
    candyman.sprite_title = walk_sprite
    candyman.sprite_idle = idle_sprite
    candyman.sprite_portrait = portrait_sprite
    candyman.sprite_portrait_small = portraitsmall_sprite
    candyman.sprite_credits = walk_sprite
    -- candyman.primary_color = vanilla_survivor.primary_color
    -- candyman.primary_color = 0x70D19D -- gamemaker uses BBGGRR colour

    -- configure skills

    -- Primary
    local skill_primary = candyman.skill_family_z[0]

    skill_primary.token_name = "Smash"
    skill_primary.token_description = "Smash ennemies for 150%.\n Smash the ball."

    skill_primary.sprite = vanilla_survivor.skill_family_z[0].sprite
    skill_primary.subimage = vanilla_survivor.skill_family_z[0].subimage

    skill_primary.cooldown = 0
    skill_primary.damage = 1.5
    skill_primary.required_stock = 0
    skill_primary.require_key_press = true
    skill_primary.use_delay = 0
    skill_primary.is_primary = true

    skill_primary.does_change_activity_state = true

    skill_primary.on_can_activate = vanilla_survivor.skill_family_z[0].on_can_activate
    skill_primary.on_activate = vanilla_survivor.skill_family_z[0].on_activate
    skill_primary.on_step = vanilla_survivor.skill_family_z[0].on_step
    
    -- Secondary
    local skill_secondary = candyman.skill_family_x[0]
    skill_secondary.token_name = "Bunt"
    skill_secondary.token_description = "Damage enemies for 75% and stun them.\nBunt the ball."

    skill_secondary.sprite = vanilla_survivor.skill_family_z[0].sprite
    skill_secondary.subimage = vanilla_survivor.skill_family_z[0].subimage

    skill_secondary.cooldown = 60
    skill_secondary.damage = 0.75
    skill_secondary.required_stock = 0
    skill_secondary.require_key_press = true
    skill_secondary.use_delay = 0

    skill_secondary.does_change_activity_state = true
    
    skill_secondary.on_can_activate = vanilla_survivor.skill_family_x[0].on_can_activate
    skill_secondary.on_activate = vanilla_survivor.skill_family_x[0].on_activate
    
    -- Utility
    local skill_utility = candyman.skill_family_c[0]
    -- skill_utility.sprite = gm.constants.sMobSkills
    -- skill_utility.animation = shoot1_sprite
    -- skill_primary.is_utility = true
    
    -- skill_utility.on_can_activate = vanilla_survivor.skill_family_c[0].on_can_activate
    -- skill_utility.on_activate = vanilla_survivor.skill_family_c[0].on_activate
    
    -- Special
    local skill_special = candyman.skill_family_v[0]
    -- skill_special.sprite = gm.constants.sMobSkills
    -- skill_special.animation = shoot1_sprite
    
    -- skill_special.on_can_activate = vanilla_survivor.skill_family_v[0].on_can_activate
    -- skill_special.on_activate = vanilla_survivor.skill_family_v[0].on_activate

    candyman.on_init = vanilla_survivor.on_init
    candyman.on_step = vanilla_survivor.on_step
    candyman.on_remove = vanilla_survivor.on_remove
    
end

local function setup_sprites(self)
    local survivors = gm.variable_global_get("class_survivor")

    if not survivors or self.class ~= candyman_id then return end

    self.sprite_idle        = idle_sprite
    self.sprite_walk        = walk_sprite
    self.sprite_jump        = jump_sprite
    self.sprite_jump_peak   = jump_sprite
    self.sprite_fall        = jumpfall_sprite
    self.sprite_climb       = hit_sprite    -- change
    self.sprite_death       = death_sprite
    self.sprite_decoy       = hit_sprite    -- change
end

-- Skill Setup

local function skill_primary_on_step(self, actor_skill, skill_index)
    print("HELLO")
    print(self.image_index)
end

local function skill_primary_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end

    -- print(actor_skill.value.name)
    -- print(skill_index.value.token_name)

    gm._mod_actor_setActivity(self, 92, 1, true, nil)
    self.image_speed = 0.2

    gm._mod_sprite_set_speed(shoot1_sprite, 1)
    gm._mod_instance_set_sprite(self, shoot1_sprite)

    local ball, distance = find_closest_ball(self)
    if ball ~= nil then hit_ball(ball, self, distance) end

    local direction = gm.actor_get_facing_direction(self)

    local orig_x = self.x + math.cos(direction)*2
    local orig_y = self.y - 14
    gm._mod_attack_fire_explosion(
        self,
        orig_x,--+math.cos(direction)*55,
        orig_y,
        60,
        32,
        self.skills[1].active_skill.damage,
        0,
        gm.constants.sSparks1,
        true
    )

end

local function skill_secondary_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end
    --if not self.local_client_is_authority then return end -- don't call if this isn't our player

    gm._mod_actor_setActivity(self, 92, 1, true, nil)    
    print(self.image_speed)
    -- self.image_speed = 0.2

    if self.pVspeed == 0.0 then self.pHspeed = 0 end

    gm._mod_sprite_set_speed(shoot2_sprite, 1)
    gm._mod_instance_set_sprite(self, shoot2_sprite)

    local displacement_x = bunt_displacement_x
    if gm.actor_get_facing_direction(self) == 180 then displacement_x = - bunt_displacement_x end -- facing left
    local close_balls = find_balls_under_distance(self.x + displacement_x, self.y, bunt_distance)
    if not close_balls then return end
    for _, ball in pairs(close_balls) do
        bunt_ball(ball, self, 0)
    end
    
end

local function skill_utility_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end
    --if not self.local_client_is_authority then return end -- don't call if this isn't our player

    create_new_ball(self)

end

local function skill_special_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end
    --if not self.local_client_is_authority then return end -- don't call if this isn't our player
    client_player = self
    special_skill(self, 0)
end

-- Callbacks

local callback_names = gm.variable_global_get("callback_names")
local on_player_init_callback_id = 0
local on_player_step_callback_id = 0
for i = 1, #callback_names do
    local callback_name = callback_names[i]
    if callback_name:match("onPlayerInit") then
        on_player_init_callback_id = i - 1
    end

    if callback_name:match("onPlayerStep") then
        on_player_step_callback_id = i - 1
    end
end

local pre_hooks = {}
gm.pre_script_hook(gm.constants.callback_execute, function(self, other, result, args)
    if self.class ~= candyman_id then return end

    local callback_id = args[1].value
    if pre_hooks[callback_id] then
        return pre_hooks[callback_id](self, other, result, args)
    end

    return true
end)

local post_hooks = {}
gm.post_script_hook(gm.constants.callback_execute, function(self, other, result, args)
    if self.class ~= candyman_id then return end

    local callback_id = args[1].value
    if post_hooks[callback_id] then
        post_hooks[callback_id](self, other, result, args)
    end
end)

post_hooks[on_player_step_callback_id] = function(self_, other, result, args)
    if self_.class ~= candyman_id then return end

    local self = args[2].value
    -- rotating_balls_step_logic(self)
end

local function setup_skills_callbacks()
    local primary = candyman.skill_family_z[0]
    local secondary = candyman.skill_family_x[0]
    local utility = candyman.skill_family_c[0]
    local special = candyman.skill_family_v[0]

    if not pre_hooks[primary.on_step] then
        pre_hooks[primary.on_step] = function(self, other, result, args)
            skill_primary_on_step(self)
            return false
        end
    end

    if not pre_hooks[primary.on_activate] then
        pre_hooks[primary.on_activate] = function(self, other, result, args)
            skill_primary_on_activation(self, args[2], args[3])
            return false
        end
    end

    if not pre_hooks[secondary.on_activate] then
        pre_hooks[secondary.on_activate] = function(self, other, result, args)
            skill_secondary_on_activation(self)
            return false
        end
    end

    if not pre_hooks[utility.on_activate] then
        pre_hooks[utility.on_activate] = function(self, other, result, args)
            skill_utility_on_activation(self)
            return false
        end
    end

    if not pre_hooks[special.on_activate] then
        pre_hooks[special.on_activate] = function(self, other, result, args)
            skill_special_on_activation(self)
            return false
        end
    end
end


post_hooks[on_player_init_callback_id] = function(self, other, result, args)
    setup_sprites(self)

    setup_skills_callbacks()
end

local hooks = {}
hooks["gml_Object_oStartMenu_Step_2"] = function() -- mod init
    hooks["gml_Object_oStartMenu_Step_2"] = nil

    create_survivor()
end

gm.pre_code_execute(function(self, other, code, result, flags)
    if hooks[code.name] then
        hooks[code.name](self)
    end
end)

-- gm.post_script_hook(gm.constants.actor_activity_set, function(self, other, result, args)
--     if args[1].value.team ~= 1 then return end
    
--     print(args[2].value)
--     print(args[3].value)
--     print(args[4].value)
--     print(args[5].value.script_name)
--     print(args[6].value)
-- end)



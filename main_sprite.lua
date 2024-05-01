log.info("Successfully loaded ".._ENV["!guid"]..".")
survivor_setup = require("./survivor_setup")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- Testing grenades

local grenade_table = {}
local count = 0
local client_player = nil

-- Character parameters

local portrait_path = _ENV["!plugins_mod_folder_path"].."/sCandymanPortrait.png"
local portraitsmall_path = _ENV["!plugins_mod_folder_path"].."/sCandymanPortraitSmall.png"

local loadout_path = _ENV["!plugins_mod_folder_path"].."/sCandymanLoadout.png"
local idle_path = _ENV["!plugins_mod_folder_path"].."/sCandymanIdle.png"
local walk_path = _ENV["!plugins_mod_folder_path"].."/sCandymanWalk.png"
local shoot1_path = _ENV["!plugins_mod_folder_path"].."/sCandymanShoot1.png"
local shoot1_air_path = _ENV["!plugins_mod_folder_path"].."/sCandymanShoot1Air.png"
local shoot2_path = _ENV["!plugins_mod_folder_path"].."/sCandymanShoot2.png"
local death_path = _ENV["!plugins_mod_folder_path"].."/sCandymanDeath.png"
local jump_path = _ENV["!plugins_mod_folder_path"].."/sCandymanjump.png"
local jumpfall_path = _ENV["!plugins_mod_folder_path"].."/sCandymanjumpfall.png"
local hit_path = _ENV["!plugins_mod_folder_path"].."/sCandymanhit.png"

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

-- Parameters

local base_speed = 4
local speed_up = 1.2
local damage_coeff = 5
local throw_gravity = 0.25
local throw_speed = -5
local hit_distance = 100

-- Utils

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
        if balls[i].status == "hit" then
            if math.abs(balls[i].hspeed) < 2 then --
                balls[i].x = balls[i].x + 5 * balls[i].hspeed
                balls[i].hspeed = - balls[i].old_hspeed
                balls[i].vspeed = balls[i].old_vspeed 
            end
        else if balls[i].status == "bunted" then
            if math.abs(balls[i].vspeed) < 2 then
                balls[i].y = balls[i].y + 5 * balls[i].vspeed
                balls[i].vspeed = - balls[i].old_vspeed
                balls[i].hspeed = balls[i].old_hspeed 
            end
        end end
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

    gm._mod_actor_setActivity(self, 92, 1, true, nil)
    self.image_speed = 0.2

    if self.pVspeed ~= 0.0 then
        gm._mod_sprite_set_speed(shoot1_air_sprite, 1)
        gm._mod_instance_set_sprite(self, shoot1_air_sprite)
    else
        self.pHspeed = 0
        gm._mod_sprite_set_speed(shoot1_sprite, 1)
        gm._mod_instance_set_sprite(self, shoot1_sprite)
    end

    local ball, distance = find_closest_ball(self)
    if ball ~= nil then hit_ball(ball, self, distance) end

    local direction = gm.actor_get_facing_direction(self)

    local orig_x = self.x - 10
    local orig_y = self.y - 30
    gm._mod_attack_fire_explosion(
        self,
        orig_x,
        orig_y,
        95,
        50,
        self.skills[1].active_skill.damage,
        0,
        gm.constants.sSparks1,
        true
    )
end

local function skill_secondary_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end

    gm._mod_actor_setActivity(self, 92, 1, true, nil)    
    print(self.image_speed)
    -- self.image_speed = 0.2

    if self.pVspeed == 0.0 then self.pHspeed = 0 end

    gm._mod_sprite_set_speed(shoot2_sprite, 1)
    gm._mod_instance_set_sprite(self, shoot2_sprite)

    local ball, distance = find_closest_ball(self)
    if ball ~= nil then hit_ball(ball, self, distance) end
end

local function skill_utility_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end

    create_ball (nil, self)
end

local function skill_special_on_activation(self, actor_skill, skill_index)
    if self.class ~= candyman_id then return end
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

gm.post_script_hook(gm.constants.__input_system_tick, function() 
    update_balls()
end)

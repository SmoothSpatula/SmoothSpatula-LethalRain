log.info("Successfully loaded ".._ENV["!guid"]..".")
mods.on_all_mods_loaded(function() for k, v in pairs(mods) do if type(v) == "table" and v.hfuncs then Helper = v end end end)

-- gm.pre_script_hook(gm.constants._ui_draw_button, function(self, other, result, args)

--     --
--     local osm  = Helper.find_active_instance(gm.constants.oSteamMultiplayer)
--     if osm then 
--         osm.host_opt[2][1] = osm.host_opt[3][1]
--         --osm.host_opt[2][1] = osm.host_opt[3][1]
--         osm.host_opt[2][1] = osm.host_opt[3][3]
--         osm.host_opt[2][1] = osm.host_opt[3][4]
--         osm.host_opt[2][1] = "dont hover me bro"
--         --print(osm.host_opt[2][2])
--     end
-- end)

-- Testing grenades

local grenade_table = {}
local count = 0
local client_player = nil

function create_grenade( old, parent)
    if old.hspeed >0 then
        inst = gm.instance_create_depth(old.x - old.hspeed*5, old.y, 1, 681)
    else
        inst = gm.instance_create_depth(old.x - old.hspeed*5, old.y, 1, 681)
    end
    inst.hspeed = -old.hspeed
    inst.parent = parent
    print(inst)
    return inst
end

function check_grenades()
    for index, grenade in pairs(grenade_table) do
        --print(grenade.c.." - "..count)
        if grenade.c < count and grenade.c >0 then
            grenade.c = -1
            -- x,y, ?, object index
            local inst = nil
            inst = create_grenade(grenade.obj, client_player)
            grenade_table[inst.id] = {
                obj = inst,
                c = count
            }
            --table.remove(grenade_table, index) 
            print(#grenade_table)
        end
    end
end

gm.post_script_hook(gm.constants.__input_system_tick, function() 
    if not client_player then client_player = Helper.get_client_player() end
    local grenades, grenades_exist = Helper.find_active_instance_all(gm.constants.oEngiGrenade)
    count = count + 1
    if not grenades_exist then return end
    for i=1, #grenades do
        grenades[i].gravity = 0


        --print(grenades[i].vspeed)
        if math.abs(grenades[i].hspeed) > 5 then
            gm.instance_destroy(grenades[i])
        else
            grenades[i].vspeed = 0
            if grenades[i].hspeed > 0 then
                grenades[i].hspeed = 4.5
            else
                grenades [i].hspeed = -4.5
            end
            grenades[i].bounces = 2
            
            -- update table info
            grenade_table[grenades[i].id] = {
                obj = grenades[i],
                c = count
            }
        end
    end
    check_grenades()
end)
-- anti_lava_area
-- Original (anti_lava_area)  : Copyright 2016 James Stevenson (everamzah)
-- Additional (anti_lava_area): Copyright Tai Kedzierski (DuCake)
-- Edit (anit_lava_area) : Copyright 2020 Cato Yiu (Emoji)
-- LGPL v2.1+

local worlddir = minetest.get_worldpath()
local modname = minetest.get_current_modname()

local hasareasmod = minetest.get_modpath("areas")


local function check_protection(pos, name, text)
	if minetest.is_protected(pos, name) then
		minetest.log("action", (name ~= "" and name or "A mod")
			.. " tried to " .. text
			.. " at protected position "
			.. minetest.pos_to_string(pos)
			.. " with a bucket")
		minetest.record_protection_violation(pos, name)
		return true
	end
	return false
end

-- The settings object
local settings = {}
if minetest.settings then
	settings = minetest.settings
else
	--- Function to retrieve a setting value.
	--
	-- @function settings:get
	-- @param setting **string** setting name
	-- @return String value of setting
	function settings:get(setting)
		return minetest.setting_get(setting)
	end

	--- Function to retrieve a boolean setting value.
	--
	-- @function settings:get_bool
	-- @param setting **string** setting name
	-- @return **bool**: True if setting is enabled
	function settings:get_bool(setting)
		return minetest.setting_getbool(setting)
	end
end

local area_label = settings:get("anti_lava_are.label") or "Anit-lava defined area."

local anti_lava_area_store = AreaStore()
anti_lava_area_store:from_file(worlddir .. "/anti_lava_area_store.dat")

local anti_lava_area_default = minetest.is_yes(settings:get_bool("anti_lava_are.enable_lava"))
minetest.log("action", "[" .. modname .. "] PvP by Default: " .. tostring(anti_lava_area_default))

local anti_lava_area_players = {}
local anti_lava_area = {}

local function update_anti_lava_area()
	local counter = 0
	anti_lava_area = {}
	while anti_lava_area_store:get_area(counter) do
		table.insert(anti_lava_area, anti_lava_area_store:get_area(counter))
		counter = counter + 1
	end
end
update_anti_lava_area()

local function save_anti_lava_area()
	anti_lava_area_store:to_file(worlddir .. "/anti_lava_area_store.dat")
end

local function areas_entity(pos,num)
	if hasareasmod then
		local obj = minetest.add_entity(pos, "areas:pos"..tostring(num))
		local ent = obj:get_luaentity()
		ent.active = true
	end
end

-- Register privilege and chat command.
minetest.register_privilege("anti_lava_area_admin", "Can set and remove anti lava areas.")
minetest.register_privilege("anti_lava_area_ignore", {
	description = "Can ignore anti lava areas.",
	give_to_singleplayer= false,
})

minetest.register_chatcommand("anti_lava_area", {
	description = "Mark and set areas for PvP.",
	params = "<pos1> <pos2> <set> <remove>",
	privs = "anti_lava_area_admin",
	func = function(name, param)
		local pos = vector.round(minetest.get_player_by_name(name):getpos())
		if param == "pos1" then
			if not anti_lava_area_players[name] then
				anti_lava_area_players[name] = {pos1 = pos}
			else
				anti_lava_area_players[name].pos1 = pos
			end
			minetest.chat_send_player(name, "Position 1: " .. minetest.pos_to_string(pos))
		elseif param == "pos2" then
			if not anti_lava_area_players[name] then
				anti_lava_area_players[name] = {pos2 = pos}
			else
				anti_lava_area_players[name].pos2 = pos
			end
			minetest.chat_send_player(name, "Position 2: " .. minetest.pos_to_string(pos))
		elseif param == "set" then
			if not anti_lava_area_players[name] or not anti_lava_area_players[name].pos1 then
				minetest.chat_send_player(name, "Position 1 missing, use \"/anti_lava_area pos1\" to set.")
			elseif not anti_lava_area_players[name].pos2 then
				minetest.chat_send_player(name, "Position 2 missing, use \"/anti_lava_area pos2\" to set.")
			else
				anti_lava_area_store:insert_area(anti_lava_area_players[name].pos1, anti_lava_area_players[name].pos2, "anti_lava_area", #anti_lava_area)
				table.insert(anti_lava_area, anti_lava_area_store:get_area(#anti_lava_area))
				update_anti_lava_area()
				save_anti_lava_area()
				anti_lava_area_players[name] = nil
				minetest.chat_send_player(name, "Area set.")
			end
		elseif param:sub(1, 6) == "remove" then
			local n = tonumber(param:sub(8, -1))
			if n and anti_lava_area_store:get_area(n) then
				anti_lava_area_store:remove_area(n)
				if anti_lava_area_store:get_area(n + 1) then
					-- Insert last entry in new empty (removed) slot.
					local a = anti_lava_area_store:get_area(#anti_lava_area - 1)
					anti_lava_area_store:remove_area(#anti_lava_area - 1)
					anti_lava_area_store:insert_area(a.min, a.max, "anti_lava_area", n)
				end
				update_anti_lava_area()
				save_anti_lava_area()
				minetest.chat_send_player(name, "Removed " .. tostring(n))
			else
				minetest.chat_send_player(name, "Invalid argument.  You must enter a valid area identifier.")
			end
		elseif param ~= "" then
			minetest.chat_send_player(name, "Invalid usage.  Type \"/help anti_lava_area\" for more information.")
		else
			for k, v in pairs(anti_lava_area) do
				minetest.chat_send_player(name, k - 1 .. ": " ..
						minetest.pos_to_string(v.min) .. " " ..
						minetest.pos_to_string(v.max))
			end
		end
	end
})

-- Register place lava callback.
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
	if newnode.name == "default:lava_source" then
		local name = placer:get_player_name()
		if name then
			local can_ignore, missing_privs = minetest.check_player_privs(name, {anti_lava_area_ignore=true})
			if not(can_ignore) then
				for k, v in pairs(anti_lava_area_store:get_areas_for_pos(pos)) do
					if k then
						minetest.chat_send_player(name, "You can't place lava here!")
						minetest.set_node(pos, {name=oldnode.name})
						return
					end
				end
			end
			-- minetest.chat_send_player(name, "[DEBUG] Place lava sucess!")
		end
	end
end)
-- bucket:bucket_lava
minetest.override_item("bucket:bucket_lava", {
    	on_place = function(itemstack, user, pointed_thing)
		-- Must be pointing to node
		if pointed_thing.type ~= "node" then
			return
		end
	
		local node = minetest.get_node_or_nil(pointed_thing.under)
		local ndef = node and minetest.registered_nodes[node.name]
	
		-- Call on_rightclick if the pointed node defines it
		if ndef and ndef.on_rightclick and
				not (user and user:is_player() and
				user:get_player_control().sneak) then
			return ndef.on_rightclick(
				pointed_thing.under,
				node, user,
				itemstack)
		end
	
		local lpos
	
		-- Check if pointing to a buildable node
		if ndef and ndef.buildable_to then
			-- buildable; replace the node
			lpos = pointed_thing.under
		else
			-- not buildable to; place the liquid above
			-- check if the node above can be replaced
	
			lpos = pointed_thing.above
			node = minetest.get_node_or_nil(lpos)
			local above_ndef = node and minetest.registered_nodes[node.name]
	
			if not above_ndef or not above_ndef.buildable_to then
				-- do not remove the bucket with the liquid
				return itemstack
			end
		end
	
		if check_protection(lpos, user
				and user:get_player_name()
				or "", "place ".."default:lava_source") then
			return
		end
		
		local name = user:get_player_name()
		if name then
			local can_ignore, missing_privs = minetest.check_player_privs(name, {anti_lava_area_ignore=true})
			if not(can_ignore) then
				for k, v in pairs(anti_lava_area_store:get_areas_for_pos(lpos)) do
					if k then
						minetest.chat_send_player(name, "You can't place lava here!")
						return
					end
				end
			end
			-- minetest.chat_send_player(name, "[DEBUG] Place lava sucess!")
		end
		minetest.set_node(lpos, {name = "default:lava_source"})
		return ItemStack("bucket:bucket_empty")
	end
})


if hasareasmod then
	if areas.registerHudHandler then

		local function advertise_nokillzone(pos, list)
			for k, v in pairs(anti_lava_area_store:get_areas_for_pos(pos)) do
				if k then
					table.insert(list, {
						id = "Anit-lava Area "..tostring(k),
						name = area_label,
					} )
					return
				end
			end
		end

		areas:registerHudHandler(advertise_nokillzone)
	else
		minetest.log("info","Your version of `areas` does not support registering hud handlers.")
	end
end

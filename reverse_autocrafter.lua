local reverseAutocrafterCache = {}  -- caches some task data to avoid to call the slow function minetest.get_craft_result() every second

local function make_inventory_cache(invlist)
	local l = {}
	for _, stack in ipairs(invlist) do
		l[stack:get_name()] = (l[stack:get_name()] or 0) + stack:get_count()
	end
	return l
end

local function get_recipe_list(taskname)
	print("getting recipe list")
	if taskname == nil or taskname == "" then
		return {}
	end

	print("taskname: "..dump(taskname))

	local recipe_list = minetest.get_all_craft_recipes(taskname)
	if recipe_list == nil then
	else
		local i
		local recipe

		for i, recipe in ipairs(recipe_list)
		do
			-- extract count
			local pos = string.find(recipe.output," %d+")
			if pos == nil then
				recipe_list[i].count = 1
			else
				recipe_list[i].count = string.sub(recipe.output, string.find(recipe.output," %d+")) + 0
			end
			print(i.." - "..dump(recipe))
		end
	end
	return recipe_list
end

local function autocraft(inventory, pos)
	local task = inventory:get_list("task")
	local task_last

	if reverseAutocrafterCache[minetest.hash_node_position(pos)] == nil then
		task_last = {}
		for i = 1, 1 do
			task_last[i] = task[i]
			task[i] = ItemStack({name = task[i]:get_name(), count = 1})
		end

		recipe_list = get_recipe_list(task[1]:get_name())
		reverseAutocrafterCache[minetest.hash_node_position(pos)] = {["task"] = task, ["recipe_list"] = recipe_list}
	else
		local reverseAutocrafterCacheEntry = reverseAutocrafterCache[minetest.hash_node_position(pos)]
		task_last = reverseAutocrafterCacheEntry["task"]
		recipe_list = reverseAutocrafterCacheEntry["recipe_list"]
		local taskUnchanged = true
		for i = 1, 1 do
			if task[i]:get_name() ~= task_last[i]:get_name() then
				taskUnchanged = false
				break
			end
			if task[i]:get_count() ~= task_last[i]:get_count() then
				taskUnchanged = false
				break
			end
		end
		if taskUnchanged then
		else
			for i = 1, 1 do
					task_last[i] = task[i]
					task[i] = ItemStack({name = task[i]:get_name(), count = 1})
			end

	                recipe_list = get_recipe_list(task[1]:get_name())
			reverseAutocrafterCache[minetest.hash_node_position(pos)] = {["task"] = task, ["recipe_list"] = recipe_list}
		end
	end

-- crafting part -------------------------

	local recipe

	if recipe_list == nil then
		return
	end

	for _, recipe in ipairs(recipe_list)
	do

		if recipe.type == 'normal' then

			local invcache = make_inventory_cache(inventory:get_list("src"))
			local result = task[1]:get_name() .. " " .. recipe.count

			print("invcache"..dump(invcache))

			if not inventory:room_for_item("dst", result) then return end
			local to_use = {}
			for _, item in ipairs(recipe.items) do
				if item == nil then
				elseif string.find(item, "group:") == 1 then
					print("group")
					local group_match = false
					local groupname = string.sub(item, 7)

					for i, _ in pairs(invcache) do
						if i ~= nil and i ~= "" then
							print ("... "..i)
							local groupval = minetest.get_item_group(i, groupname)
							if groupval ~= nil and groupval > 0 then
								print(i.." is a "..groupname)

								if to_use[i] == nil then
									to_use[i] = 1
								else
									to_use[i] = to_use[i]+1
								end
								group_match = true
								break
							else
								print(i.." is no "..groupname)
							end
						end
					end

					if group_match == false then
						if to_use[item] == nil then
							to_use[item] = 1
						else
							to_use[item] = to_use[item]+1
						end
					end
				else
					if to_use[item] == nil then
						to_use[item] = 1
					else
						to_use[item] = to_use[item]+1
					end
				end
			end

			print("to_use: "..dump(to_use))

			local can_build = true
			for itemname, number in pairs(to_use) do
				print("checking item "..dump(itemname).."... ")
				if (not invcache[itemname]) or invcache[itemname] < number then
					can_build = false
					break
				end
			end

			print()

			if can_build then

				for itemname, number in pairs(to_use) do
					for i = 1, number do -- We have to do that since remove_item does not work if count > stack_max
						inventory:remove_item("src", ItemStack(itemname))
						print("removing "..itemname.." from  stack")
					end
				end
				inventory:add_item("dst", result)
				--for i = 1, 9 do
				--	inventory:add_item("dst", new.items[i])
				--end

				return
			end
		end
	end

-- /crafting part ----------------------

end

minetest.register_node("pipeworks_plus:reverse_autocrafter", {
	description = "Reverse Autocrafter", 
	drawtype = "normal", 
	tiles = {"pipeworks_plus_reverse_autocrafter.png"}, 
	groups = {snappy = 3, tubedevice = 1, tubedevice_receiver = 1}, 
	tube = {insert_object = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:add_item("src", stack)
		end, 
		can_insert = function(pos, node, stack, direction)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			return inv:room_for_item("src", stack)
		end, 
		input_inventory = "dst", 
		connect_sides = {left = 1, right = 1, front = 1, back = 1, top = 1, bottom = 1}}, 
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("formspec",
				"size[8,11]"..
				"list[current_name;task;0,0;1,1;]"..
				"list[current_name;src;0,3.5;8,3;]"..
				"list[current_name;dst;4,0;4,3;]"..
				"list[current_player;main;0,7;8,4;]")
		meta:set_string("infotext", "Reverse Autocrafter")
		local inv = meta:get_inventory()
		inv:set_size("src", 3*8)
		inv:set_size("task", 1*1)
		inv:set_size("dst", 4*3)
	end, 
	can_dig = function(pos, player)
		local meta = minetest.get_meta(pos); 
		local inv = meta:get_inventory()
		return (inv:is_empty("src") and inv:is_empty("task") and inv:is_empty("dst"))
	end, 
	after_place_node = function(pos)
		pipeworks.scan_for_tube_objects(pos)
	end,
	after_dig_node = function(pos)
		pipeworks.scan_for_tube_objects(pos)
		reverseAutocrafterCache[minetest.hash_node_position(pos)] = nil
	end
})

minetest.register_abm({nodenames = {"pipeworks_plus:reverse_autocrafter"}, interval = 1, chance = 1, 
			action = function(pos, node)
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				autocraft(inv, pos)
			end
})


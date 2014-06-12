local replicatorCache = {}  -- caches some task data to avoid to call the slow function minetest.get_craft_result() every second

local function make_inventory_cache(invlist)
	local l = {}
	for _, stack in ipairs(invlist) do
		l[stack:get_name()] = (l[stack:get_name()] or 0) + stack:get_count()
	end
	return l
end

Replicator = {}
Replicator.__index = Replicator

function Replicator.create(inventory, pos)
	local r = {}             -- our new object
	setmetatable(r,Replicator)  -- make Account handle lookup

	r.inventory = inventory
	r.pos = pos
	r.task = nil
	r.task_last = nil
	r.recipe_list = nil
	r.task = inventory:get_list("task")
	r.task_last = nil
	r.invcache = make_inventory_cache(inventory:get_list("src"))

	return r
end

function Replicator:replicate()

	self:init_cache()
	print("recipes: "..dump(self.recipe_list))
	for i = 1, 6 do
		if self:craft(i) then
			return
		end
	end
end

function Replicator:get_recipe_list(taskname)
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

function Replicator:get_all_recipe_lists()
	local r = {}
	for i = 1, 6 do
		local taskname = self.task[i]:get_name()
		r[i] = self:get_recipe_list(taskname)
	end
	return r
end

function Replicator:init_cache()
	if replicatorCache[minetest.hash_node_position(self.pos)] == nil then
		self.task_last = {}
		for i = 1, 6 do
			self.task_last[i] = self.task[i]
			self.task[i] = ItemStack({name = self.task[i]:get_name(), count = 1})
		end

		self.recipe_list = self:get_all_recipe_lists()
		replicatorCache[minetest.hash_node_position(self.pos)] = {["task"] = self.task, ["recipe_list"] = self.recipe_list}
	else
		local replicatorCacheEntry = replicatorCache[minetest.hash_node_position(self.pos)]
		self.task_last = replicatorCacheEntry["task"]
		self.recipe_list = replicatorCacheEntry["recipe_list"]
		local taskUnchanged = true
		for i = 1, 6 do
			if self.task[i]:get_name() ~= self.task_last[i]:get_name() then
				taskUnchanged = false
				break
			end
			if self.task[i]:get_count() ~= self.task_last[i]:get_count() then
				taskUnchanged = false
				break
			end
		end
		if taskUnchanged then
		else
			for i = 1, 6 do
					self.task_last[i] = self.task[i]
					self.task[i] = ItemStack({name = self.task[i]:get_name(), count = 1})
			end

	                self.recipe_list = self:get_all_recipe_lists()
			replicatorCache[minetest.hash_node_position(self.pos)] = {["task"] = self.task, ["recipe_list"] = self.recipe_list}
		end
	end
end

function Replicator:craft(num)
	local recipe

	if self.recipe_list[num] == nil then
		return false
	end

	-- try all recipes
	for _, recipe in ipairs(self.recipe_list[num])
	do

		-- only execute normal recipes
		if recipe.type == 'normal' then

			local result = self.task[num]:get_name() .. " " .. recipe.count

			-- check for free room
			if not self.inventory:room_for_item("dst", result) then return end

			-- find out which items to use
			local to_use = self:build_to_use_list(recipe)
			print("to_use: "..dump(to_use))

			-- check if we're able to replicate using this recipe
			local can_build = true
			for itemname, number in pairs(to_use) do
				print("checking item "..dump(itemname).."... ")
				if (not self.invcache[itemname]) or self.invcache[itemname] < number then
					can_build = false
					break
				end
			end

			print()

			-- actually replicate and return
			if can_build then

				for itemname, number in pairs(to_use) do
					for i = 1, number do -- We have to do that since remove_item does not work if count > stack_max
						self.inventory:remove_item("src", ItemStack(itemname))
						print("removing "..itemname.." from  stack")
					end
				end
				self.inventory:add_item("dst", result)

				return true
			end
		end
	end
	return false
end

function Replicator:add_to_use(to_use, item)
	if to_use[item] == nil then
		to_use[item] = 1
	else
		to_use[item] = to_use[item]+1
	end
end

function Replicator:build_to_use_list(recipe)

	local to_use = {}
	for _, item in ipairs(recipe.items) do
		if item == nil then
			-- ignore nil values
		elseif string.find(item, "group:") == 1 then
			-- special handling for groups:
			-- check if there are any elements matching the
			-- group in inv, substitute the group by a matching
			-- element if possible

			print("group")
			local group_match = false
			local groupname = string.sub(item, 7)

			-- check all elements in inv for a match
			for i, _ in pairs(self.invcache) do
				if i ~= nil and i ~= "" then
					print ("... "..i)
					local groupval = minetest.get_item_group(i, groupname)
					if groupval ~= nil and groupval > 0 then
						-- yey, element matched
						print(i.." is a "..groupname)

						self:add_to_use(to_use, i)
						group_match = true
						break
					else
						print(i.." is no "..groupname)
					end
				end
			end

			if group_match == false then
				-- add the group to make the recipe fail
				self:add_to_use(to_use, item)
			end
		else
			-- not a group, simply add the item
			self:add_to_use(to_use, item)
		end
	end

	return to_use

end

minetest.register_node("pipeworks_plus:replicator", {
	description = "Replicator", 
	drawtype = "normal", 
	tiles = {"pipeworks_plus_replicator.png"}, 
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
				"list[current_name;task;0,0;2,3;]"..
				"list[current_name;src;0,3.5;8,3;]"..
				"list[current_name;dst;4,0;4,3;]"..
				"list[current_player;main;0,7;8,4;]")
		meta:set_string("infotext", "Replicator")
		local inv = meta:get_inventory()
		inv:set_size("src", 3*8)
		inv:set_size("task", 2*3)
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
		replicatorCache[minetest.hash_node_position(pos)] = nil
	end
})

minetest.register_abm({nodenames = {"pipeworks_plus:replicator"}, interval = 1, chance = 1, 
			action = function(pos, node)
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				replicator = Replicator.create(inv, pos)
				replicator:replicate()
			end
})


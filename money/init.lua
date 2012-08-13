--Mod by kotolegokot
dofile(minetest.get_modpath("money") .. "/settings.txt")

local function set_money(name, value)
	local output = io.open(minetest.get_worldpath() .. "/money_" .. name .. ".txt", "w")
	output:write(value)
	io.close(output)
end

local function get_money(name)
	local input = io.open(minetest.get_worldpath() .. "/money_" .. name .. ".txt", "r")
	if not input then 
		return nil
	end
	money = input:read("*n")
	io.close(input)
	return money
end

minetest.register_on_joinplayer(function(player)
	name = player:get_player_name()
	if not get_money(name) then
		set_money(name, tostring(INITIAL_MONEY))
	end
end)

minetest.register_privilege("money", "Can use /money [pay <player> <amount>] command")
minetest.register_privilege("money_admin", {
	description = "Can use /money [<player> | pay/set/add/dec <player> <amount>] command",
	give_to_singleplayer = false,
})

minetest.register_chatcommand("money", {
	privs = {money=true},
	params = "[<player> | pay/set/add/dec <player> <amount>]",
	description = "Operations with money",
	func = function(name,  param)
		if param == "" then
			minetest.chat_send_player(name, get_money(name) .. MONEY_NAME)
		else
			local param1, reciever, amount = string.match(param, "([^ ]+) ([^ ]+) (.+)")
			if not reciever and not amount then
				if minetest.get_player_privs(name)["money_admin"] then
					if not get_money(param) then
						minetest.chat_send_player(name, "Player named \"" .. param .. "\" do not exist or not have an account.")
						return true
					end
					minetest.chat_send_player(name, get_money(param) .. MONEY_NAME)
					return true
				else
					minetest.chat_send_player(name, "You don't have permission to run this command (missing privileges: money_admin)")
				end
			end
			if (param1 ~= "pay") and (param1 ~= "set") and (param1 ~= "add") and (param1 ~= "dec") or not reciever or not amount then
				minetest.chat_send_player(name, "Invalid parameters (see /help money)")
				return true
			elseif not get_money(reciever) then
				minetest.chat_send_player(name, "Player named \"" .. reciever .. "\" does not exist or not have account.")
				return true
			elseif not tonumber(amount) then
				minetest.chat_send_player(name, amount .. " is not a number.")
				return true
			elseif tonumber(amount) < 0 then
				minetest.chat_send_player(name, "The amount must be greater than 0.")
				return true
			end
			amount = tonumber(amount)
			if param1 == "pay" then
				if get_money(name) < amount then
					minetest.chat_send_player(name, "You do not have enough " .. amount - get_money(name) .. MONEY_NAME .. ".")
					return true
				end
				set_money(name, get_money(name) - amount)
				set_money(reciever, get_money(reciever) + amount)
				minetest.chat_send_player(name, reciever .. " took your " .. amount .. MONEY_NAME)
				minetest.chat_send_player(reciever, name .. " sent you " .. amount .. MONEY_NAME)
			elseif minetest.get_player_privs(name)["money_admin"] then
				if param1 == "add" then
					newmoney = get_money(reciever) + amount
					set_money(reciever, newmoney)
				elseif param1 == "dec" then
					if amount <= get_money(reciever) then
						newmoney = get_money(reciever) - amount
						set_money(reciever, newmoney)
					else
						minetest.chat_send_player(name, reciever .. " has too little money.")
					end
				elseif param1 == "set" then
					newmoney = amount
					set_money(reciever, amount)
				end
				minetest.chat_send_player(name, reciever .. " " .. newmoney .. MONEY_NAME)
			else
				minetest.chat_send_player(name, "You don't have permission to run this command (missing privileges: money_admin)")
			end
		end
	end,
})
	
minetest.register_on_punchnode(function(pos, node, puncher)
	bottom_pos = {x=pos.x, y=pos.y - 1, z=pos.z}
	bottom_node = minetest.env:get_node(bottom_pos)
	if (node.name == "locked_sign:sign_wall_locked") and (bottom_node.name == "default:chest_locked") and
		minetest.env:get_meta(pos):get_string("owner") == minetest.env:get_meta(bottom_pos):get_string("owner") then
		local sign_text = minetest.env:get_meta(pos):get_string("text")
		local shop_name, shop_type, nodename, amount, cost = string.match(sign_text, "([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)")
		local owner_name = minetest.env:get_meta(pos):get_string("owner")
		local puncher_name = puncher:get_player_name()
		if (shop_type ~= "B") and (shop_type ~= "S") or (not minetest.registered_items[nodename]) or (not tonumber(amount)) or
		(not tonumber(cost)) then
			return true
		end
		local chest_inv = minetest.env:get_meta({x=pos.x, y=pos.y - 1, z = pos.z}):get_inventory()
		local puncher_inv = puncher:get_inventory()
		--BUY
		if shop_type == "B" then
			if not chest_inv:contains_item("main", nodename .. " " .. amount) then
				minetest.chat_send_player(puncher_name, "In the chest is not enough goods.")
				return true
			elseif not puncher_inv:room_for_item("main", nodename .. " " .. amount) then
				minetest.chat_send_player(puncher_name, "In your inventory is not enough space.")
				return true
			elseif get_money(puncher_name) - cost < 0 then
				minetest.chat_send_player(puncher_name, "You do not have enough money.")
				return true
			end
			set_money(puncher_name, get_money(puncher_name) - cost)
			set_money(owner_name, get_money(owner_name) + cost)
			puncher_inv:add_item("main", nodename .. " " .. amount)
			chest_inv:remove_item("main", nodename .. " " .. amount)
			minetest.chat_send_player(puncher_name, "You bought " .. amount .. " " .. nodename .. " at a price of " .. cost .. MONEY_NAME .. ".")
		--SELL
		elseif shop_type == "S" then
			if not puncher_inv:contains_item("main", nodename .. " " .. amount) then
				minetest.chat_send_player(puncher_name, "You do not have enough product.")
				return true
			elseif not chest_inv:room_for_item("main", nodename .. " " .. amount) then
				minetest.chat_send_player(puncher_name, "In the chest is not enough space.")
				return true
			elseif get_money(owner_name) - cost < 0 then
				minetest.chat_send_player(puncher_name, "The buyer is not enough money.")
				return true
			end
			set_money(puncher:get_player_name(), get_money(puncher:get_player_name()) + cost)
			set_money(owner_name, get_money(owner_name) - cost)
			puncher_inv:remove_item("main", nodename .. " " .. amount)
			chest_inv:add_item("main", nodename .. " " .. amount)
			minetest.chat_send_player(puncher_name, "You sold " .. amount .. " " .. nodename .. " at a price of " .. cost .. MONEY_NAME .. ".")
		end
	end
end)
--Gui elements
Event.register(defines.events.on_gui_click, function(event)
	local s = global.surface
	local gui = event.element
	local player = game.players[event.player_index]
	local index = event.player_index
	
	if not event.element.valid then return end
	-- Turns on/off Flashlight
	if (event.element.name == "flashlight_button") then
		if player.character == nil then return end
		global.player_flashlight_state = global.player_flashlight_state or {}
		if global.player_flashlight_state == true then
			player.character.enable_flashlight()
			global.player_flashlight_state = false
		else
			player.character.disable_flashlight()
			global.player_flashlight_state = true
		end
		return
	end
	
	if (event.element.name == "crouch_button") then
		if player.character == nil then return end
		global.player_crouch_state = global.player_crouch_state or {}
		global.player_crouch_color = global.player_crouch_color or {}
		if global.player_crouch_state == true then
			global.player_crouch_state = false
			player.character_running_speed_modifier = 0
			player.color = global.player_crouch_color
		else 
			global.player_crouch_state = true
			player.character_running_speed_modifier = -0.6
			global.player_crouch_color = player.color
			player.color = black				
		end
	end
	
	if (event.element.name == "score_button") then
		if player.gui.left.score_board then
			player.gui.left.score_board.destroy()
		else
			local frame = player.gui.left.add{name = "score_board", type = "frame", direction = "vertical", caption = "Player Count"}
			local score_board_table = frame.add{type = "table", name = "score_board_table", colspan = 4}
			score_board_table.add{type = "label", name = "score_board_table_force_name", caption = {"team-name"}}
			score_board_table.add{type = "label", name = "score_board_table_player_count", caption = "Players Joined"}
			score_board_table.add{type = "label", name = "score_board_table_players_online", caption = "Players Online"}
			score_board_table.add{type = "label", name = "score_board_kill_counter", caption = "Kill Count"}
			for k = 1, global.config.number_of_teams do
				local team = global.force_list[k]
				local force = game.forces[team.name]
				if force ~= nil then
					local c = team.color
					local color = {r = 1 - (1 - c[1]) * 0.5, g = 1 - (1 - c[2]) * 0.5, b = 1 - (1 - c[3]) * 0.5, a = 1}
					local name = score_board_table.add{type = "label", name = force.name.."_label", caption = force.name}
					name.style.font_color = color
					score_board_table.add{type = "label", name = force.name.."_count", caption = #force.players}
					score_board_table.add{type = "label", name = force.name.."_online", caption = #force.connected_players}
					score_board_table.add{type = "label", name = force.name.."_kill_count", caption = global.kill_counts[force.name] or 0}
				end
			end
		end
	end	
	
	--Brings up vote-to-surrender dialog
	if (event.element.name == "surrender_button") then
		if player.gui.left.surrender_dialog then
			player.gui.left.surrender_dialog.destroy()
		else
			local frame = player.gui.left.add{name = "surrender_dialog", type = "frame", direction = "vertical", caption = "Vote: Do you wish to surrender?"}
			--the following line was the only way I could figure out how to cause elements to appear vertically instead of horizontally, there has got to be a better way
			local surrender_table = frame.add{type = "table", name = "surrender_table", colspan = 1}
			local button_table = surrender_table.add{type = "table", name = "button_table", colspan = 2}
			button_table.add{type = "button", name = "surrender_vote_yes", caption = "Yes"}
			button_table.add{type = "button", name = "surrender_vote_no", caption = "No"}
			
			if not global.surrender_votes then global.surrender_votes = {} end  --this contains the surrender votes for all teams
			if not global.surrender_votes[player.force.name] then 
				global.surrender_votes[player.force.name] = {}
				global.surrender_votes[player.force.name].in_progress = false
			end
			if global.surrender_votes[player.force.name].in_progress then add_surrender_vote_tally_table(player) end
			local surrender_info_label = surrender_table.add{type = "label", name = "70% Yes vote required for surrender."}
			
			local too_early = is_too_early_in_match_to_surrender()
			local too_soon = is_too_soon_since_last_surrender_vote(player.force)
			if too_early then
				local surrender_error_message = "You can not surrender during the first " .. time_before_first_surrender_available .. " minutes of a match."
			end
			if too_soon then
				local surrender_error_message = "You can not surrender until " .. minimum_time_between_surrender_votes .. " minutes have passed since the last vote."
			end

			if too_early or too_soon then
				surrender_vote_yes.style.font_color = colors.grey
				surrender_vote_no.style.font_color = colors.grey
				local surrender_error_label = surrender_table.add{type = "label", name = surrender_error_message, style.font_color = colors.red}
			end
		end
	end
	
	if (event.element.name == "surrender_vote_yes") then
		if is_too_early_in_match_to_surrender() or is_too_soon_since_last_surrender_vote(player.force) then return end

		local votes = global.surrender_votes[player.force.name]
		if not votes.in_progress then
			votes.yes_votes_count = 0
			votes.no_votes_count = 0
			votes.not_yet_voted_count = #player.force.connected_players
			votes.in_progress = true
		end		
	end
	
	if gui.name == "balance_options_confirm" then
		set_balance_settings(gui.parent.balance_options_scrollpane)
		gui.parent.destroy()
		return
	end
	
	if gui.name == "balance_options_cancel" then
		gui.parent.destroy()
		return
	end
	
	if gui.name == "balance_options" then
		create_balance_option(player.gui.left)
		return
	end
	
	if gui.name == "config_confirm" then
		config_confirm(gui)
		return
	end
	
	if gui.name == "close_config" then
		destroy_config_for_all(gui.parent.name)
		return
	end
	
	if gui.name == "random_join_button" then
		gui.parent.destroy()
		random_join(player)
		return
	end	 
	
	if gui.name == "auto_assign_button" then
		gui.parent.destroy()
		auto_assign(player)
		return
	end 
	
	if gui.name == "player_pick_confirm" then
		for k = 1, global.config.number_of_teams do
			local team = global.force_list[k]
			local force = game.forces[team.name]
			if force then
				local check = gui.parent.pick_join_table[force.name]
				if check.state then 
					local c = team.color
					local color = {r = fpn(c[1]), g = fpn(c[2]), b = fpn(c[3]), a = fpn(c[4])}
					gui.parent.destroy()
					set_player(player,force,color)
					for k, player in pairs (game.forces.player.players) do
						update_players_on_team_count(player)
					end
					break
				end
			end
		end
	end
	
end)

function is_too_early_in_match_to_surrender()
	return game.tick < global.match_start_time + time_before_first_surrender_available * 3600
end

function add_surrender_vote_tally_table(player)
	local votes = global.surrender_votes[player.force.name]
	local surrender_tally_table = surrender_table.add{type = "table", name = "surrender_tally_table", colspan = 3}
	surrender_tally_table.add{type = "label", name = "surrender_tally_table_yes_votes", caption = "Yes votes"}
	surrender_tally_table.add{type = "label", caption = "      "}  --adds whitespace between the two actual columns... there has got to be a better way to do this...
	surrender_tally_table.add{type = "label", name = "surrender_tally_table_yes_votes_count", caption = votes.yes_votes_count}
	surrender_tally_table.add{type = "label", name = "surrender_tally_table_no_votes", caption = "No votes"}
	surrender_tally_table.add{type = "label", caption = "      "}
	surrender_tally_table.add{type = "label", name = "surrender_tally_table_no_votes_count", caption = votes.no_votes_count}
	surrender_tally_table.add{type = "label", name = "surrender_tally_table_not_yet_voted", caption = "Not yet voted"}
	surrender_tally_table.add{type = "label", caption = "      "}
	surrender_tally_table.add{type = "label", name = "surrender_tally_table_not_yet_voted_count", caption = votes.not_yet_voted_count}
end

--using this to order the gui'
function create_buttons(event)
	local player = game.players[event.player_index]
	if (not player.gui.top["flashlight_button"]) then
		player.gui.top.add{type="button", name="flashlight_button", caption="Flashlight"}
	end

	if (not player.gui.top["crouch_button"]) then
		local frame = player.gui.top.add{name = "crouch_button", type = "button", direction = "horizontal", caption = "Crouch"}
	end
	
	if (not player.gui.top["score_button"]) then
		player.gui.top.add{type="button", name="score_button", caption="Score"}
	end
	if (not player.gui.top["surrender_button"]) then
		player.gui.top.add{type="button", name="surrender_button", caption="Surrender Menu"}
	end
end	

function choose_joining_gui(player)

	if global.team_joining == "random" then
		create_random_join_gui(player.gui.center)
		return
	end

	if global.team_joining == "player_pick" then
		create_pick_join_gui(player.gui.center)
		return
	end
	
	if global.team_joining == "auto_assign" then
		create_auto_assign_gui(player.gui.center)
		return
	end
	
end

function destroy_joining_guis(gui)
	if gui.random_join_frame then
		gui.random_join_frame.destroy()
	end
	if gui.pick_join_frame then
		gui.pick_join_frame.destroy()
	end
	if gui.auto_assign_frame then
		gui.auto_assign_frame.destroy()
	end
end

function create_random_join_gui(gui)
	if gui.random_join_frame then
		gui.random_join_frame.destroy()
	end
	local frame = gui.add{type = "frame", name = "random_join_frame", caption = {"",{"random-join"},""}}
	local button = frame.add{type = "button", name = "random_join_button", caption = {"",{"random-join-button"},""}}
end

function create_auto_assign_gui(gui)
	local name = "auto_assign"
	if gui[name.."_frame"] then
		gui[name.."_frame"].destroy()
	end
	local frame = gui.add{type = "frame", name = name.."_frame", caption = {name.."_frame"}}
	local button = frame.add{type = "button", name = name.."_button", caption = {name.."_button"}}
end

function create_pick_join_gui(gui)
	if gui.pick_join_frame then
		gui.pick_join_frame.destroy()
	end
	local frame = gui.add{type = "frame", name = "pick_join_frame", caption = {"",{"pick-join"},""}, direction = "vertical"}
	local pick_join_table = frame.add{type = "table", name = "pick_join_table", colspan = 3}
	pick_join_table.add{type = "label", name = "pick_join_table_force_name", caption = {"team-name"}}
	pick_join_table.add{type = "label", name = "pick_join_table_player_count", caption = {"players-on-team"}}
	pick_join_table.add{type = "label", name = "pick_join_table_pad", caption = {"join"}}
	for k = 1, global.config.number_of_teams do
		local team = global.force_list[k]
		local force = game.forces[team.name]
		if force ~= nil then
			local c = team.color
			local color = {r = 1 - (1 - c[1]) * 0.5, g = 1 - (1 - c[2]) * 0.5, b = 1 - (1 - c[3]) * 0.5, a = 1}
			local name = pick_join_table.add{type = "label", name = force.name.."_label", caption = force.name}
			name.style.font_color = color
			pick_join_table.add{type = "label", name = force.name.."_count", caption = #force.connected_players}
			pick_join_table.add{type = "checkbox", name = force.name,state = false}
		end
	end
	local button = frame.add{type = "button", name = "player_pick_confirm", caption = {"confirm"}}
	button.style.font = "default"
end

function create_config_gui(player)
	local gui = player.gui.left
	if gui.config_gui then
		gui.config_gui.destroy()
	end
	local frame = gui.add{type = "frame", name = "config_gui", caption = {"config-gui"}, direction = "vertical"}
	local config_table = frame.add{type = "table", name = "config_table", colspan = 2}
	for k, name in pairs (global.config) do
		if tonumber(name) then
			config_table.add{type = "label", name = k, caption = {k}}
			local input = config_table.add{type = "textfield", name = k.."box"}
			input.text = name
		elseif tostring(type(name)) == "boolean" then
			config_table.add{type = "label", name = k, caption = {k}}
			config_table.add{type = "checkbox", name = k.."_"..tostring(type(name)), caption= {"",{tostring(type(name))},""}, state = name}
		else
			config_table.add{type = "label", name = k, caption = {k}}
			local option_table = config_table.add{type = "table", name = k.."_option_table", colspan = #name}
			for j, option in pairs (name) do
				local check = option_table.add{type = "checkbox", name = option, caption= {"",{option},""}, state = false}
				if global[k] == option then check.state = true end
				if global.research_ingredient_list[check.name] then check.state = global.research_ingredient_list[check.name] end
			end
		end
	end
	frame.add{type = "button", name = "config_confirm", caption = {"config-confirm"}}.style.font = "default"
	frame.add{type = "button", name = "balance_options", caption = {"balance-options"}}.style.font = "default"
	frame.add{type = "button", name = "close_config", caption = "Close"}.style.font = "default"
end


function create_balance_option(gui)

	if gui.balance_options_frame then
		gui.balance_options_frame.destroy()
	end
	local frame = gui.add{name = "balance_options_frame", type = "frame", direction = "vertical", caption = {"balance-options"}}
	local scrollpane = frame.add{name = "balance_options_scrollpane", type = "scroll-pane"}
	scrollpane.style.maximal_height = 500
	for modifier_name, array in pairs (global.modifier_list) do
		scrollpane.add{name = modifier_name.."label", type = "label", caption = {modifier_name} }
		local table = scrollpane.add{name = modifier_name.."table", type = "table", colspan = 2}
		for name, modifier in pairs (array) do
			if modifier_name == "ammo_damage_modifier" then
				local string = "ammo-category-name."..name
				table.add{name = name.."label", type = "label", caption = {string}}
			elseif modifier_name == "gun_speed_modifier" then
				local string = "ammo-category-name."..name
				table.add{name = name.."label", type = "label", caption = {string}}
			elseif modifier_name == "turret_attack_modifier" then
				local string = "entity-name."..name
				table.add{name = name.."label", type = "label", caption = {string}}
			else
				table.add{name = name.."label", type = "label", caption = {name}}
			end
			

			local input = table.add{name = name.."text", type = "textfield"}
			input.text = modifier
		end
	end
	frame.add{type = "button", name = "balance_options_confirm", caption = {"config-confirm"}}.style.font = "default"
	frame.add{type = "button", name = "balance_options_cancel", caption = {"cancel"}}.style.font = "default"
	
end

function set_balance_settings(gui)
	for modifier_name, array in pairs (global.modifier_list) do
		local modifier_table = gui[modifier_name.."table"]
		if modifier_table then
			for name, modifier in pairs (array) do
				local text = modifier_table[name.."text"].text
				if text then
					local n = tonumber(text)
					if n == nil then 
						game.players[gui.player_index].print({"must-be-number",name})
						return
					end
					global.modifier_list[modifier_name][name] = n
				end
			end
		end
	end
end

function config_confirm(gui)

	local parent = gui.parent
	local config = parent.config_table
	for name, value in pairs (global.config) do
		if config[name.."box"] then
			local text = config[name.."box"].text
			local n = tonumber(text)
			if n ~= nil then
				global.config[name] = n
			else
				game.players[gui.player_index].print({"must-be-number",name})
				return
			end
		end
		if type(value) == "boolean" then
			if config[name] then
				global.config[name] = config[name.."_boolean"].state
			end
		end
	end
	if global.config.number_of_teams <= 1 then
		player.print({"more-than-1-team"})
		return
	end
	if global.config.number_of_teams > 12 then 
		player.print({"less-than-12-teams"})
		return
	end
	destroy_config_for_all(gui.parent.name)
	prepare_next_round()

end

function destroy_config_for_all(name)
	for k, player in pairs (game.players) do
		if player.gui.left[name] then
			player.gui.left[name].destroy()
		end
	end
end

--Kill Counts
Event.register(-1, function()
	global.kill_counts = {}
end)

Event.register(defines.events.on_entity_died, function(event)
	local entity = event.entity
	local force = event.force
	if entity and entity.valid and entity.type == "player" and force and force.name ~= entity.force.name and force.name ~= "enemy" then
		if not global.kill_counts[force.name] then global.kill_counts[force.name] = 1
		else global.kill_counts[force.name] = global.kill_counts[force.name] + 1 end
		update_kill_counts(force)
	end
end)

function update_kill_counts(force)
	for _,player in pairs(game.players) do
		if player.gui.left.score_board then
			local force_kill_counter = force.name .. "_kill_count"
			if not player.gui.left.score_board.score_board_table[force_kill_counter] then return end
			player.gui.left.score_board.score_board_table[force_kill_counter].caption = global.kill_counts[force.name]
		end
	end
end

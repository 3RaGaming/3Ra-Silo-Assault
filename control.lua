--Team PVP [Based on Roboport_PvP_Slow by Klonan]
--A 3Ra Gaming revision
if not scenario then scenario = {} end
if not scenario.config then scenario.config = {} end

normal_attack_sent_event = script.generate_event_name()
landing_attack_sent_event = script.generate_event_name()
team_eliminated = script.generate_event_name()

require "config"
require "locale/utils/event"
require "locale/utils/admin"
require "locale/utils/undecorator"
require "locale/utils/utils"
require "balance"
require "technologies"
require "locale/utils/gravestone"
require "gui"
require "tag"
require "locale/utils/bot"

-- controls how much slower you run as you lose health
global.crippling_factor = 1

global.given_starting_items = {}
global.silo_progress_warning_level = {}
global.endgame = false

black = {r = 0, g = 0, b = 0}

Event.register(-1, function ()
	load_config()
	global.copy_surface = game.surfaces[1]
	global.round_number = 0
	global.next_round_start_tick = 60*60
	game.disable_replay()
	local surface = game.create_surface("Lobby",{width = 1, height = 1})
	surface.set_tiles({{name = "out-of-map",position = {1,1}}})
	game.create_force("Admins")
end)

local function log_scenario(msg)
	if global.pvp_log_enabled then
		game.write_file("pvp_scenario_log.txt", msg .. "\n", true, 0)
	end
end

-- admin restriction controls
global.restrict_admin_character = true
remote.add_interface("admin_control",
{
	restrict_admins = function()
		if global.restrict_admin_character then
			game.player.print("Admins are already restricted")
		else
			global.restrict_admin_character = true
			for k,p in pairs(game.players) do
				if p.admin then
					if p.gui.left.admin_pane.character ~= nil then
						p.gui.left.admin_pane.character.destroy()
					elseif p.gui.left.admin_pane.character_panel ~= nil then
						p.gui.left.admin_pane.character_panel.destroy()
					end
					if p.character then
						global.player_character_stats[p.index] = {
							item_loot_pickup = false,
							build_itemdrop_reach_resourcereach_distance = false,
							crafting_speed = false,
							mining_speed = false,
							running_speed = 0
						}
						update_character(p.index)
					end
					p.print("Admins are now restricted from adjusting their characters. Your character is now reset to its default state.")
				end
			end
		end
	end,
	unrestrict_admins = function()
		if not global.restrict_admin_character then
			game.player.print("Admins are already unrestricted")
		else
			global.restrict_admin_character = false
			for k,p in pairs(game.players) do
				if p.admin then
					if p.gui.left.admin_pane.character == nil then
						p.gui.left.admin_pane.add{name = "character", type = "button", caption = "Character"}
					end
					p.print("Admins have been unrestricted from adjusting their characters. Please do not abuse this if you are on a team, keep PvP fair.")
				end
			end
		end
	end
})

function create_next_surface()
	log_scenario("Begin create_next_surface")
	global.round_number = global.round_number + 1
	local settings = global.copy_surface.map_gen_settings
	settings.starting_area = "very-low"
	settings.peaceful_mode = global.config.peaceful_mode
	settings.seed = math.random(1, 2000000)
	if global.alien_artifacts_source ~= "biters_enabled" then
		settings.autoplace_controls["enemy-base"].size = "none"
	end
	settings.height = global.config.map_height
	settings.width = global.config.map_width
	if game.surfaces["Battle_surface"] then
		game.print("Error on new round - Previous surface not deleted properly")
		end_round()
	end
	global.surface = game.create_surface("Battle_surface", settings)
	--global.surface.daytime = 0
	log_scenario("End create_next_surface")
end

Event.register(defines.events.on_rocket_launched, function (event)
	local force = event.rocket.force
	if event.rocket.get_item_count("satellite") == 0 then
		force.print({"rocket-launched-without-satellite"})
		global.silo_progress_warning_level[force.name] = 1
		return
	end
	game.print({"team-launched-rocket",force.name})
	print("PVPROUND$end," .. global.round_number .. "," .. force.name..","..match_elapsed_time())

	if global.config.continuous_play then
		end_round()
	else
		game.set_game_state{game_finished=true, player_won=true, can_continue=true}
	end
end)

function end_round()
	log_scenario("Begin end_round()")

	local player_count = 0
	for k, player in pairs (game.players) do
		player.force = game.forces.player
		destroy_joining_guis(player.gui.center)
		if player.connected then
			local character = player.character
			player.character = nil
			if character then
				player_count = player_count + 1
				character.destroy()
			end
			player.teleport({0,1000}, game.surfaces.Lobby)
			welcome_window(player)
			if player.admin then
				create_config_gui(player)
			end
		else
			if not player.admin then
				game.remove_offline_players({player})
			end
		end
	end

	log_scenario("Characters destroyed: " .. player_count)
	log_scenario("Characters still on map: " .. #game.surfaces["Battle_surface"].find_entities_filtered{type="player"})

	if game.surfaces["Battle_surface"] then
		log_scenario("Delete Battle_surface")
		game.delete_surface(game.surfaces["Battle_surface"])
	end
	global.kill_counts = {}
	if global.config.team_prepare_period > 0 then
		game.print{"next-round-start", global.config.time_between_rounds, global.config.team_prepare_period}
	else
		game.print{"next-round-start-no-prep", global.config.time_between_rounds}
	end
	global.next_round_start_tick = game.tick + global.config.time_between_rounds * 60
	global.teams_currently_preparing = false
	global.setup_finished = false
	global.given_starting_items = {}
	global.silo_progress_warning_level = {}

	game.evolution_factor = 0
	log_scenario("End end_round()")
end

function prepare_next_round()
	log_scenario("Begin prepare_next_round()")
	--if global.silos then
	--	for forcename,silo in pairs(global.silos) do
	--		game.merge_forces(forcename, "neutral")
	--	end
	--end
	update_players_list()
	update_scoreboard()
	destroy_config_for_all()
	global.next_round_start_tick = nil
	global.setup_finished = false
	global.surrender_votes = {}
	for i,p in pairs(game.players) do
		if p.gui.left.surrender_dialog then p.gui.left.surrender_dialog.destroy() end
		p.gui.top.surrender_button.style.font_color = colors.white
	end

	prepare_map()
	log_scenario("End prepare_next_round()")
end

--global variables for the message desplay
global.timer_value = 0
global.timer_wait = 600
global.timer_display = 1

Event.register(defines.events.on_tick, function(event)
	--runs every tick
	end_game()
	--runs every 500ms
	if(game.tick % 30 == 0) then
		update_silo_progress_bars()
		show_health()
		if global.teams_currently_preparing then
			team_prepare()
		end
		if global.silos then 
			for force_name, silo in pairs(global.silos) do
				if silo and silo.valid then
					local silo_inventory = silo.get_inventory(defines.inventory.rocket_silo_rocket)
					if silo_inventory and silo_inventory.find_item_stack("satellite") then
						if not silo.launch_rocket() then game.print("Error: Was not able to launch rocket.") end
					end
				end
			end
		end
	end

	--runs every second
	if(game.tick % 60 == 0) then
		for force_name, warning_level in pairs(global.silo_progress_warning_level) do
			local silo = global.silos[force_name]
			if silo and silo.rocket_parts >= warning_level then
				if warning_level == 1 then
					game.print({"rocket-assembly-begun", force_name})
					global.silo_progress_warning_level[force_name] = 10
				else
					game.print({"rocket-assembly-progress", force_name, warning_level})
					global.silo_progress_warning_level[force_name] = warning_level + 10
				end
			end
		end
		for _,player in pairs(game.players) do
			if player.gui.left.score_board then open_score_board_window(player) end
		end
	end

	-- Runs every 5 seconds
	if game.tick % 300 == 0 then
		check_player_color(true)
		if global.surrender_votes then
			for force_name, votes in pairs(global.surrender_votes) do
				if votes.in_progress and game.tick >= votes.vote_start_time + global.surrender_voting_period * 3600 then
					local force = game.forces[force_name]
					if force and force.valid then
						force.print({"voting-period-timed-out"})
						votes.in_progress = false
						for i,p in pairs(force.players) do
							p.gui.top.surrender_button.style.font_color = colors.red
							if p.gui.left.surrender_dialog then open_surrender_window(p) end
						end
					end	
				end
			end
		end
	end

	-- Runs every 30 seconds
	if(game.tick % 1800 == 0) then
		if not game.forces["Spectators"] then game.create_force("Spectators") end
		game.forces.Spectators.chart_all()
		if global.alien_artifacts_source == "gradual_distribution" then
			gradual_plus_remainder = global.config.num_alien_artifacts_gradual + global.alien_artifacts_gradual_remainder
			local give_amount = math.floor(gradual_plus_remainder / 120)
			global.alien_artifacts_gradual_remainder = gradual_plus_remainder % 120
			if give_amount > 0 then for i,v in pairs(game.connected_players) do v.insert{name="alien-artifact", count=give_amount} end end
		end
	end
	local current_time = game.tick / 60 - global.timer_value
	local message_display = "test"
	if current_time >= global.timer_wait then
		if global.timer_display == 1 then
			message_display = {"msg-announce1"}
			global.timer_display = 2
		else
			message_display = {"msg-announce2"}
			global.timer_display = 1
		end
		for k, player in pairs(game.players) do
			player.print(message_display)
		end
		global.timer_value = game.tick / 60
	end
	if global.setup_finished then return end
	check_round_start()
	copy_paste_starting_area_tiles()
	copy_paste_starting_area_entities()
	check_starting_area_chunks_are_generated()
	clear_starting_area_enemies()
	finish_setup()
end)

Event.register(defines.events.on_player_joined_game, function(event)
	if game.tick < 10 then
		global.next_round_start_tick = nil
		return
	end
	local player = game.players[event.player_index]
	unfreeze_player(player)
	update_surrender_tally(player.force, false)
	update_players_list()
	
	if player.force.name ~= "player" then
		for k, p in pairs (game.players) do
			update_players_on_team_count(p)
		end
		return
	end
	update_scoreboard()

	local character = player.character
	player.character = nil
	if character then character.destroy() end
	player.teleport({0,1000}, game.surfaces.Lobby)
	if global.setup_finished then
		choose_joining_gui(player)
	else
		welcome_window(player)
		if player.admin then
			create_config_gui(player)
		end
	end
	if player.admin then player.tag = "[Admin]" end
	player.set_controller{type = defines.controllers.ghost}
	local p = game.players[event.player_index]
	create_buttons(player)
 end)

Event.register(defines.events.on_player_created, function(event)
	local player = game.players[event.player_index]
	create_buttons(player)
	if event.player_index ~= 1 then return end

	local character = player.character
	player.character = nil
	if character then character.destroy() end
	local size = global.copy_surface.map_gen_settings.starting_area
	local radius = math.ceil(starting_area_constant[size]/2) --radius in tiles
	game.forces.player.chart(player.surface, {{-radius,-radius},{radius, radius}})
	welcome_window(player)
	create_config_gui(player)

	player.print({"msg-intro1"})
	player.print({"msg-intro2"})
end)

Event.register(defines.events.on_player_respawned, function(event)
	spread_spawn(game.players[event.player_index])
end)

Event.register(defines.events.on_player_left_game, function(event)
	local player = game.players[event.player_index]
	if player.force.name ~= "player" then
		for k, p in pairs (game.players) do
			update_players_on_team_count(p)
		end
	end
	update_surrender_tally(player.force, false)
	update_players_list()
	update_scoreboard()
end)

Event.register(defines.events.on_player_respawned, function(event)
	give_respawn_equipment(game.players[event.player_index])
end)

-- for backwards compatibility
Event.register(-3, function(data)
	if global.attack_data == nil then
		init_attack_data()
		if global.attack_count ~= nil then
			global.attack_data.attack_count = global.attack_count
		end
		if global.until_next_attacknormal ~= nil then
			global.attack_data.until_next_attack = global.until_next_attacknormal
		end
	end
	if global.attack_data.distraction == nil then
		global.attack_data.distraction = defines.distraction.byenemy
	end
end)

Event.register(defines.events.on_entity_died, function(event)
	local killing_force = event.force
	local silo = event.entity
	local surface = global.surface
	if not silo or not silo.valid then return end
	if silo.name ~= "rocket-silo" then return end
	log_scenario("rocket silo died")
	local force = silo.force
	global.silos[force.name] = nil
	if not killing_force then
		killing_force = {}
		killing_force.name = "neutral"
	end
	game.print({"silo-destroyed",force.name, killing_force.name})
	local index = 0
	local winner_name = "none"
	for k, listed_silo in pairs (global.silos) do
		if listed_silo ~= nil then
			index = index + 1
			winner_name = k
		end
	end
	for k, player in pairs (force.players) do
		player.force = game.forces.Lobby
		if player.connected then
			print("PLAYER$force," .. player.index .. "," .. player.name .. ",Lobby")
			local character = player.character
			player.character = nil
			if character then character.destroy() end
			player.teleport({0,1000}, game.surfaces.Lobby)
			if index > 1 then
				player.print{"join-new-team"}
			end
		end
	end
	for i = 1, global.config.number_of_teams do
		if global.force_list[i].name == force.name then
			global.force_list[i].status = "dead"
			break
		end
	end
	if force.name == killing_force.name then
		log_scenario("merge force to neutral")
		print("PVPROUND$eliminated," .. force.name .. ",suicide")
		game.merge_forces(force.name, "neutral")
	else
		log_scenario("merge force")
		print("PVPROUND$eliminated," .. force.name .. "," .. killing_force.name)
		game.merge_forces(force.name, killing_force.name)
	end
	update_players_list()
	update_scoreboard()
	if index > 1 then
		for _,player in pairs(game.forces.Lobby.connected_players) do choose_joining_gui(player) end
	else
		global.ending_tick = game.tick + 300
		global.ending_tick_2 = game.tick + 480
		global.silo_position = silo.position
		global.dummie_silo = surface.create_entity{name = "rocket-silo", position = global.silo_position, force = "neutral"}
		global.endgame = true
		for k, player in pairs (game.connected_players) do
			local character = player.character
			player.character = nil
			player.teleport(silo.position, surface)
			global.zoom_count = 1
			player.zoom = global.zoom_count
		end
		global.zoom_count = global.zoom_count + (1/300)
		local time = match_elapsed_time()
		game.print({"team-won",winner_name})
		game.print("Match lasted " .. time:gsub(";", ",") .. ".")
		print("PVPROUND$end," .. global.round_number .. "," .. winner_name .. "," .. time)
	end
end)

function end_game()
	--called in on_tick
	if global.endgame ~= true then return end
	local surface = global.surface
	local x = global.silo_position.x
	local y = global.silo_position.y
	for k, player in pairs (game.connected_players) do
		local surface = global.surface
		local character = player.character
			player.character = nil
			player.teleport(global.silo_position, surface)
			player.zoom = global.zoom_count
	end
	global.zoom_count = global.zoom_count - (1/3000)
	if game.tick < global.ending_tick and game.tick % 20 == 0 then
    surface.create_entity{position = {x + math.random(-4,4),y + math.random(-4,4)}, name = "medium-explosion"}
	end
	if game.tick == global.ending_tick then
	if global.dummie_silo then global.dummie_silo.destroy() end
	surface.create_entity{position = global.silo_position, name = "big-explosion"}
	end
	if game.tick == global.ending_tick_2 then

		if global.config.continuous_play then
			end_round()
			global.endgame = false
		end
	end

end

function freeze_player(player)
	if player.character then
		player.zoom = 0.085
		player.character_crafting_speed_modifier = -1
		player.character_mining_speed_modifier = -1
		player.character_running_speed_modifier = -1
	end
end

function unfreeze_player(player)
	if player.character then
		player.zoom = 1
		player.character_crafting_speed_modifier = 0
		player.character_mining_speed_modifier = 0
		player.character_running_speed_modifier = 0
	end
end

-- Give everyone some time with their team to discuss strategy before anyone is allowed to do anything.
function team_prepare()
	if game.tick < global.config.team_prepare_period * 60 + global.match_start_time then
		-- The following essentially freezes all players.
		for k, player in pairs (game.connected_players) do
			if player.force.name ~= "Admins" then freeze_player(player) end
		end
	else
		-- Unfreezes players.
		for k, player in pairs (game.connected_players) do
			if player.character and player.force.name ~= "Admins" then
				pcall(unfreeze_player, player)
				if not global.given_starting_items[player.index] then
					give_equipment(player)
					give_inventory(player)
					global.given_starting_items[player.index] = true
				end
			end
		end
		global.teams_currently_preparing = false
		global.surface.daytime = 0
		game.print({"start-match"})
	end
end

function match_elapsed_time()
	local returnstring = ""
	local ticks = game.tick - global.match_start_time - global.config.team_prepare_period * 60
	if ticks < 0 then
		ticks = ticks * -1
		returnstring = "-"
	end
	local hours = math.floor(ticks / 60^3)
	local minutes = math.floor((ticks % 60^3) / 60^2)
	local seconds = math.floor((ticks % 60^2) / 60)
	if hours > 0 then returnstring = returnstring .. hours .. (hours > 1 and " hours; " or " hour; ") end
	if minutes > 0 then returnstring = returnstring .. minutes .. (minutes > 1 and " minutes" or " minute").. " and " end
	returnstring = returnstring .. seconds .. (seconds ~= 1 and " seconds" or " second")
	return returnstring
end

-- shows player health as a text float.
function show_health()
		for k, player in pairs(game.players) do
		if player.connected then
			if player.character then
				if player.character.health == nil  then return end
				local index = player.index
				local health = math.ceil(player.character.health)
				if global.player_health == nil then global.player_health = {} end
				if global.player_health[index] == nil then global.player_health[index] = health end
				if global.player_health[index] ~= health then
					global.player_health[index] = health
					-- slows the player just slightly if not at full health
						player.character_running_speed_modifier = -.1*(100-health)*global.crippling_factor/100
					-- prints player health when < 80%
					if health < 80 then
						if health > 50 then
							player.surface.create_entity{name="flying-text", color={b = 0.2, r= 0.1, g = 1, a = 0.8}, text=(health), position= {player.position.x, player.position.y-2}}
						elseif health > 29 then
							player.surface.create_entity{name="flying-text", color={r = 1, g = 1, b = 0}, text=(health), position= {player.position.x, player.position.y-2}}
						else
							player.surface.create_entity{name="flying-text", color={b = 0.1, r= 1, g = 0, a = 0.8}, text=(health), position= {player.position.x, player.position.y-2}}
						end
					end
				end
			end
				end
		end
end


Event.register(defines.events.on_gui_checked_state_changed, function (event)
	local player = game.players[event.player_index]
	local gui = event.element
	if gui.parent.name == "research_level_option_table" then
		--TODO fix this for 0.15 non-linear research system
		local check_index = 1
		for k, checkbox in pairs (gui.parent.children_names) do
			if checkbox == gui.name then
				check_index = k
			end
		end
		for k, checkbox in pairs (gui.parent.children_names) do
			local check = gui.parent[checkbox]
			if k < check_index and gui.state then
				check.state = true
				if global.research_ingredient_list[check.name] ~= nil then
					global.research_ingredient_list[check.name] = check.state
				end
			end
			if (k > check_index) and not gui.state then
				check.state = false
				if global.research_ingredient_list[check.name] ~= nil then
					global.research_ingredient_list[check.name] = check.state
				end
			end
		end
		if global.research_ingredient_list[gui.name] ~= nil then
			global.research_ingredient_list[gui.name] = gui.state
		end
		return
	end
	if gui.parent.name == "starting_inventory_option_table" then
		for k, checkbox in pairs (gui.parent.children_names) do
			local check = gui.parent[checkbox]
			if check ~= gui then
				check.state = false
			end
		end
		global.starting_inventory = gui.name
		return
	end
	if gui.parent.name == "starting_equipment_option_table" then
		for k, checkbox in pairs (gui.parent.children_names) do
			local check = gui.parent[checkbox]
			if check ~= gui then
				check.state = false
			end
		end
		global.starting_equipment = gui.name
		return
	end
	if gui.parent.name == "team_joining_option_table" then
		for k, checkbox in pairs (gui.parent.children_names) do
			local check = gui.parent[checkbox]
			if check ~= gui then
				check.state = false
			end
		end
		global.team_joining = gui.name
		return
	end
	if gui.parent.name == "pick_join_table" then
		for k = 1, global.config.number_of_teams do
			local team = global.force_list[k]
			local force = game.forces[team.name]
			if force then
				local check = gui.parent[team.name]
				if check and (check.name ~= gui.name) then
					check.state = false
				end
			else
				if gui.parent[team.name] then
					create_pick_join_gui(player.gui.center)
					return
				end
			end
		end
	end
	if gui.parent.name == "alien_artifacts_source_option_table" then
		for k, checkbox in pairs (gui.parent.children_names) do
			local check = gui.parent[checkbox]
			if check ~= gui then
				check.state = false
			end
		end
		global.alien_artifacts_source = gui.name
	end
end)


function auto_assign(player)
	local force
	local team
	repeat
		local index = math.random(global.config.number_of_teams)
		team = global.force_list[index]
		force = game.forces[team.name]
	until force ~= nil
	local count = #force.connected_players
	local total = #force.players
	for k = 1, global.config.number_of_teams do
		this_team = global.force_list[k]
		local other_force = game.forces[this_team.name]
		if other_force ~= nil then
			if #other_force.connected_players < count then
				count = #other_force.connected_players
				total = #other_force.players
				force = other_force
				team = this_team
			elseif #other_force.connected_players == count and #other_force.players < total then
				count = #other_force.connected_players
				total = #other_force.players
				force = other_force
				team = this_team
			end
		end
	end
	local c = team.color
	local color = {r = fpn(c[1]), g = fpn(c[2]), b = fpn(c[3]), a = fpn(c[4])}
	set_player(player,force,color)
end


function admin_spectate_join(player)
	local force = game.forces["Admins"]
	local c = {1, 0.012, 0.012, 1}
	local color = {r = fpn(c[1]), g = fpn(c[2]), b = fpn(c[3]), a = fpn(c[4])}
	set_player(player,force,color)
end


function prepare_map()
	create_next_surface()
	global.next_round_start_tick = nil
	game.print({"preparing-map"})
	setup_teams()
	if global.config.copy_starting_area then
		setup_start_area_copy()
	else
		chart_starting_area_for_force_spawns()
	end
	set_evolution_factor()
end

function set_evolution_factor()
	local n = global.config.evolution_factor
	if n >= 1 then
		n = 1
	end
	if n <= 0 then
		n = 0
	end
	game.evolution_factor = n
	global.config.evolution_factor = n
end

function update_players_on_team_count(player)

	local gui = player.gui.center
	if not gui.pick_join_frame then return end
	if not gui.pick_join_frame.pick_join_table then return end
	for k = 1, global.config.number_of_teams do
		local team = global.force_list[k]
		local force = game.forces[team.name]
		if force then
			if gui.pick_join_frame.pick_join_table[force.name.."_count"] then
				--Should the following be #force.connected_players instead of #force.players ?
				gui.pick_join_frame.pick_join_table[force.name.."_count"].caption = #force.connected_players
			end
		end
	end

end

function random_join(player)
	local force
	local team
	repeat
		local index = math.random(global.config.number_of_teams)
		team = global.force_list[index]
		force = game.forces[team.name]
	until force ~= nil
	local c = team.color
	local color = {r = fpn(c[1]), g = fpn(c[2]), b = fpn(c[3]), a = fpn(c[4])}
	set_player(player,force,color)
end

function spread_spawn(player)
	local surface = global.surface
	if not surface.valid then error("global.surface is false!") return end
	force_spawn = player.force.get_spawn_position(surface)
	local spread = 38 --how far away from the actual force spawn position to teleport the player
	local spread_spawn_x = math.random(-1*spread, spread) + force_spawn.x
	local spread_spawn_y = math.random(-1*spread, spread) + force_spawn.y
	local spread_spawn_position = surface.find_non_colliding_position("player", {spread_spawn_x, spread_spawn_y},64,1)
	player.teleport(spread_spawn_position, surface)
	return spread_spawn_position
end

function set_player(player,force,color)
	if player.gui.left.surrender_dialog then player.gui.left.surrender_dialog.destroy() end
	player.force = force
	player.color = color
	local position = spread_spawn(player)
	if player.character then player.character.destroy() end
	player.character = global.surface.create_entity{name = "player", position = position, force = force}
	--force.chart(player.surface, {{-radius,-radius},{radius, radius}})
	if force.name ~= "Admins" then
		if not global.teams_currently_preparing then
			give_inventory(player)
			give_equipment(player)
			global.given_starting_items[player.index] = true
		end
		update_players_list()
		update_scoreboard()
		create_silo_progress_bars(player)
		game.print({"joined", player.name, player.force.name})
		player.print({"objective"})
		player.print({"objective-warning"})
		player.print({"wall-warning"})
		if     global.alien_artifacts_source == "biters_enabled"       then player.print({"biters_enabled_message"})
		elseif global.alien_artifacts_source == "alien_tech_research"  then player.print({"alien_tech_research_message",global.config.num_alien_artifacts_on_tech})
		elseif global.alien_artifacts_source == "gradual_distribution" then player.print({"gradual_distribution_message",global.config.num_alien_artifacts_gradual})
		else game.print("error in set_player()!") end
	else
		player.print("You are now an admin. You are not on any team, and cannot join another team without a console command.")
	end
	print("PLAYER$force," .. player.index .. "," .. player.name .. "," .. player.force.name)
end

function give_inventory(player)
	if not global.inventory_list then return end
	if not global.inventory_list[global.starting_inventory] then return end
	local list = global.inventory_list[global.starting_inventory]
	for name, count in pairs (list) do
		if game.item_prototypes[name] then
			player.insert{name = name, count = count}
		else
			game.print(name.." is not a valid item")
		end
	end
end

function setup_teams()
	if not game.forces["Lobby"] then
		game.create_force("Lobby")
	end
	if not global.force_list then error("No force list defined") return end
	local list = global.force_list
	local n = global.config.number_of_teams
	if n <= 0 then error ("Number of team to setup must be greater than 0")return end
	if n > #list then error("Not enough forces defined for number of teams. Max teams is "..#list) return end
	for i,player in pairs(game.players) do
		global.surrender_votes = nil
		if player.gui.left.surrender_dialog then player.gui.left.surrender_dialog.destroy() end
		player.gui.top.surrender_button.style.font_color = colors.white
	end
	for k = 1, n do
		if not list[k] then	break end
		local name = list[k].name
		if name then
			local new_force
			if not game.forces[name] then
				new_force = game.create_force(name)
			else
				new_force = game.forces[name]
			end
			set_spawn_position(k, n, new_force, global.surface)
			global.force_list[k].status = "alive"
			new_force.set_cease_fire("Admins", true)
			game.forces["Admins"].set_cease_fire(new_force.name, true)
		end
	end
	for k, force in pairs (game.forces) do
		force.reset()
		apply_balance(force)
		setup_research(force)
		disable_combat_technologies(force)
		set_all_ceasefire(force)
	end
end

function set_all_ceasefire(force)
	for k, other in pairs (game.forces) do
		if other.name ~= force.name then
			force.set_cease_fire(other, global.config.ceasefire)
		end
	end
end

function set_spawn_position(k, n, force,surface)
	local copy_settings = global.copy_surface.map_gen_settings
	local settings = global.surface.map_gen_settings
	local rotation = (k*2*math.pi)/n
	local config = global.config
	local displacement = config.average_team_displacement
	local height_scale = settings.height/settings.width
	local max_distance = starting_area_constant[copy_settings.starting_area] + (config.team_max_variance*displacement)
	local elevator_set = false

	if height_scale == 1 then
		if max_distance > surface.map_gen_settings.width then
			displacement = surface.map_gen_settings.width*global.shrink_from_edge_constant
		end
	end

	if height_scale < 1 then
		if config.number_of_teams == 2 then
			if max_distance > surface.map_gen_settings.width then
				displacement = surface.map_gen_settings.width*global.shrink_from_edge_constant
			end
			max_distance = 0
		end
		if max_distance > surface.map_gen_settings.height then
			displacement = surface.map_gen_settings.height*global.shrink_from_edge_constant
		end
	end

	if height_scale > 1 then
		if config.number_of_teams == 2 then
			if max_distance > surface.map_gen_settings.height then
				displacement = surface.map_gen_settings.height*global.shrink_from_edge_constant
			end
			elevator_set = true
			max_distance = 0
		end
		if max_distance > surface.map_gen_settings.width then
			displacement = surface.map_gen_settings.width*global.shrink_from_edge_constant
		end
	end

	local team_displacement_variance = math.random(global.config.team_min_variance*100,global.config.team_max_variance*100)/100
	local distance = 0.5*displacement*team_displacement_variance
	local X = 32*(math.floor((math.cos(rotation)*distance+0.5)/32))
	local Y = 32*(math.floor((math.sin(rotation)*distance+0.5)/32))

	if elevator_set then
		--Swap X and Y for elevators
		Y = 32*(math.floor((math.cos(rotation)*distance+0.5)/32))
		X = 32*(math.floor((math.sin(rotation)*distance+0.5)/32))
	end

	force.set_spawn_position({X,Y}, surface)
	-- surface.create_entity{name = "construction-robot", position = {X,Y}, force = game.forces.player }
	-- game.print(height_scale.." - "..force.name.."	"..X.."-"..Y.." "..(X/32).."-"..(Y/32).." "..height_scale.." "..max_distance)
end

function chart_starting_area_for_force_spawns()
	local surface = global.surface
	local size = global.copy_surface.map_gen_settings.starting_area
	local radius = math.ceil((starting_area_constant[size] + 240) / 64)
	for k = 1, global.config.number_of_teams do
		local name = global.force_list[k].name
		local force = game.forces[name]
		if force ~= nil then
			local origin = force.get_spawn_position(surface)
			local area = {{origin.x-416, origin.y-256},{origin.x+416,origin.y+256}}
			--force.chart(surface, area)
			surface.request_to_generate_chunks({origin.x, origin.y}, radius)
			force.chart(surface, area)
		end
	end
	game.speed = 10
	global.check_starting_area_generation = true
end

function check_starting_area_chunks_are_generated()
	if not global.check_starting_area_generation then return end
	local surface = global.surface
	local size = global.copy_surface.map_gen_settings.starting_area
	--local check_radius = math.ceil(starting_area_constant[size]/64)
	local check_radius = math.ceil((starting_area_constant[size] + 240) / 64)
	local total = 0
	local generated = 0
	for k = 1, global.config.number_of_teams do
		local name = global.force_list[k].name
		local force = game.forces[name]
		if force ~= nil then
			local origin = force.get_spawn_position(surface)
			local origin_X = math.floor(origin.x/32)
			local origin_Y = math.floor(origin.y/32)
			for X = -check_radius, check_radius -1 do
				for Y = -check_radius, check_radius -1 do
					total = total + 1
					if (surface.is_chunk_generated({X+origin_X,Y+origin_Y})) then
						generated = generated + 1
					end
				end
			end
		end
	end
	if total == generated then
		game.speed = 1
		global.check_starting_area_generation = false
		global.clear_starting_area_enemies = game.tick+global.config.number_of_teams
	end
end



function check_player_color(printchange)
	for k, player in pairs (game.connected_players) do
		for i, force in pairs (global.force_list) do
			if force.name == player.force.name then
				if (fpn(player.color.r) ~= fpn(force.color[1])) or (fpn(player.color.g) ~= fpn(force.color[2])) or (fpn(player.color.b) ~= fpn(force.color[3])) then
					player.color = {r = fpn(force.color[1]), g = fpn(force.color[2]), b = fpn(force.color[3]), a = fpn(force.color[4])}
					if printchange then
						--game.print({"player-changed-color", player.name, force.name})
						game.print({"player-changed-forces", player.name, force.name})
					end
				end
				break
			end
		end
	end
end

function check_round_start()
	if not global.next_round_start_tick then return end
	if game.tick ~= global.next_round_start_tick then return end
	prepare_next_round()
end

function clear_starting_area_enemies()
	if not global.clear_starting_area_enemies then return end
	local index = global.clear_starting_area_enemies - game.tick
	local surface = global.surface
	if index == 0 then
		global.clear_starting_area_enemies = nil
		global.finish_setup = game.tick + global.config.number_of_teams
		return
	end
	local name = global.force_list[index].name
	local force = game.forces[name]
	local size = global.copy_surface.map_gen_settings.starting_area
	local radius = math.ceil(starting_area_constant[size]/2)
	local origin = force.get_spawn_position(surface)
	local area = {{origin.x-radius, origin.y-radius},{origin.x+radius, origin.y+radius}}
	for k, entity in pairs (surface.find_entities_filtered{area = area, force = "enemy"}) do
		entity.destroy()
	end
end

function finish_setup()
	if not global.finish_setup then return end
	local index = global.finish_setup - game.tick
	--log("index = " .. index)
	local surface = global.surface
	if index == 0 and not global.check_starting_area_generation then
		global.finish_setup = nil
		game.print({"map-ready"})
		global.setup_finished = true
		global.surface.daytime = 0
		global.match_start_time = game.tick
		for k, player in pairs (game.connected_players) do
			choose_joining_gui(player)
			create_silo_progress_bars(player)
		end
		global.teams_currently_preparing = true
		if global.config.team_prepare_period > 0 then
			game.print({"team-preparing-period-start",global.config.team_prepare_period})
		end
		
		local tempstring = "PVPROUND$begin," .. global.round_number .. ","
		for i = 1, global.config.number_of_teams, 1 do
			local force_name = global.force_list[i].name
			tempstring = tempstring .. force_name .. ","
		end
		print(tempstring:sub(1,#tempstring-1))
		
	elseif index > 0 then
		local name = global.force_list[index].name
		local force = game.forces[name]
		create_silo_for_force(force)
		--chart_area_for_force(surface, global.silos[force.name].position, 350, force)
		if global.config.reveal_team_positions then
			for k, other_force in pairs (game.forces) do
				chart_area_for_force(surface, global.silos[force.name].position, 16, other_force)
			end
		end
		create_wall_for_force(force)
	end
end

function chart_area_for_force(surface, origin, radius, force)
	if not force.valid then return end
	if (not origin.x) or (not origin.y) then
		game.print ("No valid value in position array")
		return
	end

	local area = {{origin.x-radius, origin.y-radius},{origin.x+radius, origin.y+radius}}
	force.chart(surface, area)

end

function setup_start_area_copy()
	local size = global.copy_surface.map_gen_settings.starting_area
	if size == "none" then
		global.finish_setup = game.tick + global.config.number_of_teams
		return
	end
	local radius = math.ceil(starting_area_constant[size]/64) --radius in chunks
	global.chunk_offsets = {}
	for X = -radius, radius-1 do
		for Y = -radius, radius - 1 do
			table.insert(global.chunk_offsets,{X,Y})
		end
	end
	global.copy_paste_starting_area_tiles_end = game.tick + (#global.chunk_offsets * global.config.number_of_teams)
end

function copy_paste_starting_area_tiles()
	if not global.copy_paste_starting_area_tiles_end then return end
	local surface = global.copy_surface
	local index = global.copy_paste_starting_area_tiles_end - game.tick
	local force_index = math.ceil((index)/(#global.chunk_offsets))
	local offset_index = (index - ((#global.chunk_offsets)*(force_index-1)))
	if index == 0 then
		global.copy_paste_starting_area_entities_end = game.tick + (#global.chunk_offsets * global.config.number_of_teams)
		global.copy_paste_starting_area_tiles_end = nil
		return
	end
	local offset = global.chunk_offsets[offset_index]
	if not offset then return end
	if not surface.is_chunk_generated({offset[1],offset[2]}) then
		global.copy_paste_starting_area_tiles_end = global.copy_paste_starting_area_tiles_end + 1
		return
	end
		local this_force = global.force_list[force_index]
	if not this_force then game.print("No force defined at selected force index") return end
	local force = game.forces[this_force.name]
	local origin = force.get_spawn_position(global.surface)
	local tiles = {}
	for X = offset[1]*32, (offset[1]+1)*32 do
		for Y = offset[2]*32, (offset[2]+1)*32 do
			local tile = surface.get_tile(X,Y)
			local position = tile.position
			table.insert(tiles, {name = tile.name, position = {position.x + origin.x, tile.position.y + origin.y}})
		end
	end
	global.surface.set_tiles(tiles)
	local chunk_position_x = offset[1]+((origin.x)/32)
	if not (chunk_position_x == math.floor(chunk_position_x)) then game.print("Chunk position calculated from force spawn was not an integer") return end
	local chunk_position_y = offset[2]+((origin.y)/32)
	if not (chunk_position_y == math.floor(chunk_position_y)) then game.print("Chunk position calculated from force spawn was not an integer") return end
	global.surface.set_chunk_generated_status({chunk_position_x,chunk_position_y}, defines.chunk_generated_status.entities)
end

function copy_paste_starting_area_entities()
	if not global.copy_paste_starting_area_entities_end then return end
		local surface = global.copy_surface
	local index = global.copy_paste_starting_area_entities_end - game.tick
	local force_index = math.ceil((index)/(#global.chunk_offsets))
	local offset_index = (index - ((#global.chunk_offsets)*(force_index-1)))
	if index == 0 then
		global.copy_paste_starting_area_entities_end = nil
		global.finish_setup = game.tick + global.config.number_of_teams
		return
	end
	local offset = global.chunk_offsets[offset_index]
	if not offset then return end
	if not surface.is_chunk_generated({offset[1],offset[2]}) then
		global.copy_paste_starting_area_entities_end = global.copy_paste_starting_area_entities_end + 1
		return
	end
		local this_force = global.force_list[force_index]
	if not this_force then game.print("No force defined at selected force index") return end
	local force = game.forces[this_force.name]
	local origin = force.get_spawn_position(global.surface)
	local area = {{offset[1]*32, offset[2]*32},{(offset[1]+1)*32, (offset[2]+1)*32}}
	for k, entity in pairs (surface.find_entities(area)) do
		local position = entity.position
		if not (position.x < offset[1]*32 or
		position.x >= (offset[1]+1)*32 or
		position.y < offset[2]*32 or
		position.y >= (offset[2]+1)*32) then
			local new_position = {position.x + origin.x, position.y + origin.y}
			if entity.type == "resource" then
				global.surface.create_entity{name = entity.name, position = new_position, amount = entity.amount}
			else
				global.surface.create_entity{name = entity.name, position = new_position}
			end
		end
	end
	chart_starting_area_for_force_spawns()
end


function create_silo_for_force(force)
	if not global.silos then global.silos = {} end
	if not force then return end
	if not force.valid or (global.silos[force.name] and global.silos[force.name].valid) then return end
	local surface = global.surface
	local origin = force.get_spawn_position(surface)
	local offset_x = 0
	local offset_y = 0 --1 chunk above the spawn position
	local silo_position = {origin.x+offset_x, origin.y+offset_y}
	local area = {{silo_position[1]-5,silo_position[2]-6},{silo_position[1]+6, silo_position[2]+6}}
	for i, entity in pairs(surface.find_entities_filtered({area = area, force = "neutral"})) do
		entity.destroy()
	end
	global.silos[force.name] = surface.create_entity{name = "rocket-silo", position = silo_position, force = force}
	global.silos[force.name].minable = false
	global.silos[force.name].backer_name = tostring(force.name)
	global.silo_progress_warning_level[force.name] = 1
	local tiles_1 = {}
	local tiles_2 = {}
	for X = -5, 5 do
		for Y = -6, 5 do
			table.insert(tiles_1, {name = "grass", position = {silo_position[1]+X, silo_position[2]+Y}})
			table.insert(tiles_2, {name = "hazard-concrete-left", position = {silo_position[1]+X, silo_position[2]+Y}})
		end
	end
	surface.set_tiles(tiles_1)
	surface.set_tiles(tiles_2)
end

function setup_research(force)
	if not force then return end
	if not force.valid then return end
	--Unlocks all research, and then unenables them based on a blacklist
	global.disable_tech_event = true
	force.research_all_technologies()
	for k, technology in pairs (force.technologies) do
		for j, ingredient in pairs (technology.research_unit_ingredients) do
			if not global.research_ingredient_list[ingredient.name] then
				technology.researched = false
				break
			end
		end
	end
	global.disable_tech_event = false
end

function create_wall_for_force(force)
	if not global.config.team_walls then return end
	if not force.valid then return end
	local surface = global.surface
	local origin = force.get_spawn_position(surface)
	local size = global.copy_surface.map_gen_settings.starting_area
	local radius = math.ceil(starting_area_constant[size]/2) - 20 --radius in tiles
	local perimeter_v = {}
	local perimeter_h = {}
	local tiles_grass = {}
	local tiles = {}
	for X = -radius, radius -1 do
		for Y = -radius, radius-1 do
			if (X == -radius) or (X == radius -1) then
				table.insert(perimeter_v, {origin.x+X,origin.y+Y})
			end
			if (Y == -radius) or (Y == radius -1) then
				table.insert(perimeter_h, {origin.x+X,origin.y+Y})
			end
		end
	end
	for k, position in pairs (perimeter_v) do
		table.insert(tiles_grass, {name = "grass", position = {position[1]-1,position[2]}})
		table.insert(tiles_grass, {name = "grass", position = {position[1],position[2]}})
		table.insert(tiles_grass, {name = "grass", position = {position[1]+1,position[2]}})
		table.insert(tiles, {name = "stone-path", position = {position[1]-1,position[2]}})
		table.insert(tiles, {name = "stone-path", position = {position[1],position[2]}})
		table.insert(tiles, {name = "stone-path", position = {position[1]+1,position[2]}})
		for i, entity in pairs(surface.find_entities_filtered({area = {{position[1]-2,position[2]-2},{position[1]+2, position[2]+2}}, force = "neutral"})) do
			entity.destroy()
		end
		if (position[2] % 32 == 14) or (position[2] % 32 == 15) or (position[2] % 32 == 16) or (position[2] % 32 == 17) then
			surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 0, force = force}
		else
			surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
		end
	end
	for k, position in pairs (perimeter_h) do
		table.insert(tiles_grass, {name = "grass", position = {position[1],position[2]-1}})
		table.insert(tiles_grass, {name = "grass", position = {position[1],position[2]}})
		table.insert(tiles_grass, {name = "grass", position = {position[1],position[2]+1}})
		table.insert(tiles, {name = "stone-path", position = {position[1],position[2]-1}})
		table.insert(tiles, {name = "stone-path", position = {position[1],position[2]}})
		table.insert(tiles, {name = "stone-path", position = {position[1],position[2]+1}})
		for i, entity in pairs(surface.find_entities_filtered({area = {{position[1]-2,position[2]-2},{position[1]+2, position[2]+2}}, force = "neutral"})) do
			entity.destroy()
		end
		if (position[1] % 32 == 14) or (position[1] % 32 == 15) or (position[1] % 32 == 16) or (position[1] % 32 == 17) then
			surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 2, force = force}
		else
			surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
		end

	end
	surface.set_tiles(tiles_grass)
	surface.set_tiles(tiles)
end

Event.register(defines.events.on_built_entity, function(event)
	if event.created_entity.type == "container" and global.config.chests_neutral then
		event.created_entity.force = "neutral"
	end
end)

Event.register(defines.events.on_player_driving_changed_state, function(event)
	local player = game.players[event.player_index]
	local search_area = {{player.position.x - 5, player.position.y - 5}, {player.position.x + 5, player.position.y + 5}}
	local entities = game.surfaces["Battle_surface"].find_entities_filtered{area = search_area, name = "stone-wall"}
	for _,entity in pairs(entities) do
		if entity.last_user == nil and entity.force ~= player.force then
			if player.driving then player.vehicle.passenger = nil end
			if not player.character then return end
			player.character.damage(10000, entity.force)
			game.print(player.name.." got electrocuted because they entered or exited a vehicle within 5 tiles of an enemy starting wall.")
		end
	end
end)

function switch_teams(playername, forcename)
	set_player(game.players[playername], game.forces[forcename], {0,0,0,0})
end

function kill_force(force)
	global.silos[force.name].damage(10000, force)
end

function get_seed()
	game.print(game.surfaces["nauvis"].map_gen_settings.seed)
end

function remove_buttons(player)
	for _,child in pairs(player.gui.top.children_names) do player.gui.top[child].destroy() end
end

function remove_biters()
	for c in game.surfaces["Battle_surface"].get_chunks() do
		for key, entity in pairs(game.surfaces["Battle_surface"].find_entities_filtered({area={{c.x * 32, c.y * 32}, {c.x * 32 + 32, c.y * 32 + 32}}, force= "enemy"})) do
			entity.destroy()
		end
	end
end

function fpn(n)
	return (math.floor(n*32)/32)
end

function ongoingRound()
	if not global.setup_finished then return end
	local tempstring = "PVPROUND$ongoing," .. global.round_number .. ","
	for i = 1, global.config.number_of_teams, 1 do
		local force_name = global.force_list[i].name
		if global.force_list[i].status == "alive" then tempstring = tempstring .. force_name .. "," end
	end
	print(tempstring:sub(1,#tempstring-1))
end
	
Event.register(-2, ongoingRound)

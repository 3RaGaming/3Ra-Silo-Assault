
function load_config()
	global.shrink_from_edge_constant = 0.75
	global.starting_inventory = "medium"
	global.starting_equipment = "small"
	global.team_joining = "player_pick"
	global.alien_artifacts_source = "gradual_distribution"
	global.alien_artifacts_gradual_remainder = 0
	global.setup_finished = false
	global.teams_currently_preparing = false
	global.config =
		{
			["number_of_teams"] = 2,
			["average_team_displacement"] = 75*32,
			["team_max_variance"] = 1,
			["team_min_variance"] = 1,
			["map_height"] = 100*32,
			["map_width"] = 100*32,
			["copy_starting_area"] = true,
			["reveal_team_positions"] = false,
			["team_walls"] = true,
			["continuous_play"] = true,
			["time_between_rounds"] = 30, -- seconds
			["team_prepare_period"] = 30, -- seconds
			["research_level"] = {"science-pack-1", "science-pack-2", "science-pack-3", "alien-science-pack"}, --TODO fix for 0.15 packs when needed
			["unlock_combat_research"] = false,
			["starting_inventory"] = {"none", "small", "medium", "large"},
			["starting_equipment"] = {"none", "small", "medium", "large"},
			["team_joining"] = {"player_pick", "random", "auto_assign"},
			["alien_artifacts_source"] = {"biters_enabled", "alien_tech_research", "gradual_distribution"},
			["num_alien_artifacts_on_tech"] = 200, -- give this amount to each player on a force when they research alien technology
			["num_alien_artifacts_gradual"] = 50, -- per hour
			["peaceful_mode"] = false,
			["ceasefire"] = false,
			["evolution_factor"] = 0
		}

	global.research_ingredient_list =
		{
			--false means disabled.
			["science-pack-1"] = false,
			["science-pack-2"] = false,
			["science-pack-3"] = false,
			["alien-science-pack"] = false
		}
	global.force_list =
		{
			{name = "Blue", color = {0.2, 0.2, 0.8, 0.7}},
			{name = "Green", color = {0.1, 0.8, 0.1, 0.8}},
			{name = "Orange", color = {0.8, 0.4, 0.0, 0.8}},
			{name = "Yellow", color = {0.8, 0.8, 0.0, 0.6}},
			{name = "Pink", color = {0.8, 0.2, 0.8, 0.2}},
			{name = "Cyan", color = {0.1, 0.9, 0.9, 0.8}},
			{name = "Purple", color = {0.8, 0.2, 0.8, 0.9}},
			{name = "Brown", color = {0.5, 0.3, 0.1, 0.8}},
			{name = "White", color = {0.8, 0.8, 0.8, 0.5}},
			{name = "Lobby", color = {0.6, 0.6, 0.6, 0.8}},
			{name = "Black", color = {0.1, 0.1, 0.1, 0.8}},
			{name = "Red", color = {0.9, 0.1, 0.1, 0.8}}
		}

	global.inventory_list =
	{
		["none"] =
		{
			["iron-plate"] = 8,
			["burner-mining-drill"] = 2,
			["stone-furnace"] = 2
		},
		["small"] =
		{
			["iron-plate"] = 50,
			["pipe"] = 100,
			["pipe-to-ground"] = 20,
			["copper-plate"] = 10,
			["transport-belt"] = 200,
			["repair-pack"] = 20,
			["inserter"] = 20,
			["fast-inserter"] = 20,
			["small-electric-pole"] = 40,
			["burner-mining-drill"] = 16,
			["stone-furnace"] = 12,
			["burner-inserter"] = 30,
			["assembling-machine-1"] = 8,
			["electric-mining-drill"] = 2,
			["boiler"] = 7,
			["steam-engine"] = 5
		},
		["medium"] =
		{
			["iron-plate"] = 200,
			["pipe"] = 100,
			["pipe-to-ground"] = 20,
			["iron-gear-wheel"] = 100,
			["copper-plate"] = 100,
			["steel-plate"] = 50,
			["electronic-circuit"] = 100,
			["transport-belt"] = 300,
			["underground-belt"] = 20,
			["splitter"] = 20,
			["repair-pack"] = 20,
			["inserter"] = 20,
			["fast-inserter"] = 70,
			["burner-inserter"] = 14,
			["small-electric-pole"] = 40,
			["burner-mining-drill"] = 10,
			["electric-mining-drill"] = 20,
			["stone-furnace"] = 50,
			["steel-furnace"] = 20,
			["assembling-machine-1"] = 20,
			["assembling-machine-2"] = 8,
			["boiler"] = 14,
			["steam-engine"] = 10,
			["chemical-plant"] = 5,
			["oil-refinery"] = 2,
			["pumpjack"] = 8
		},
		["large"] =
		{
			["iron-plate"] = 200,
			["pipe"] = 100,
			["pipe-to-ground"] = 20,
			["copper-plate"] = 200,
			["steel-plate"] = 200,
			["iron-gear-wheel"] = 250,
			["transport-belt"] = 400,
			["underground-belt"] = 40,
			["splitter"] = 40,
			["repair-pack"] = 20,
			["inserter"] = 100,
			["burner-inserter"] = 50,
			["small-electric-pole"] = 50,
			["burner-mining-drill"] = 50,
			["electric-mining-drill"] = 50,
			["stone-furnace"] = 35,
			["steel-furnace"] = 20,
			["electric-furnace"] = 8,
			["assembling-machine-1"] = 50,
			["assembling-machine-2"] = 20,
			["assembling-machine-3"] = 8,
			["electronic-circuit"] = 200,
			["fast-inserter"] = 100,
			["medium-electric-pole"] = 50,
			["substation"] = 10,
			["boiler"] = 30,
			["steam-engine"] = 20,
			["chemical-plant"] = 10,
			["oil-refinery"] = 5,
			["pumpjack"] = 10
		}
	}
	global.scenario = {custom_functions={}}
end

function give_equipment(player)

	if global.starting_equipment == "none" then
		player.insert{name = "submachine-gun", count = 1}
		player.insert{name = "firearm-magazine", count = 30}
		player.insert{name = "iron-axe", count = 1}
		return
	end

	if global.starting_equipment == "small" then
		player.insert{name = "light-armor", count = 1}
		player.insert{name = "steel-axe", count = 1}
		player.insert{name = "submachine-gun", count = 1}
		player.insert{name = "firearm-magazine", count = 40}
		return
	end

	if global.starting_equipment == "medium" then
		player.insert{name = "heavy-armor", count = 1}
		player.insert{name = "steel-axe", count = 3}
		player.insert{name = "submachine-gun", count = 1}
		player.insert{name = "piercing-rounds-magazine", count = 40}
		return
	end

	if global.starting_equipment == "large" then
		player.insert{name = "steel-axe", count = 3}
		player.insert{name = "submachine-gun", count = 1}
		player.insert{name = "piercing-rounds-magazine", count = 40}
		player.insert{name = "combat-shotgun", count = 1}
		player.insert{name = "piercing-shotgun-shell", count = 20}
		player.insert{name = "rocket-launcher", count = 1}
		player.insert{name = "rocket", count = 80}
		player.insert{name = "power-armor", count = 1}
		local p_armor = player.get_inventory(5)[1].grid
		p_armor.put({name = "fusion-reactor-equipment"})
		p_armor.put({name = "exoskeleton-equipment"})
		p_armor.put({name = "energy-shield-mk2-equipment"})
		p_armor.put({name = "energy-shield-mk2-equipment"})
		p_armor.put({name = "personal-roboport-equipment"})
		player.force.worker_robots_speed_modifier = 2.5
		player.insert{name = "construction-robot", count = 10}
		player.insert{name = "blueprint", count = 3}
		player.insert{name = "deconstruction-planner", count = 1}
		player.insert{name = "car", count = 1}
		return
	end

end

function give_respawn_equipment(player)

	player.insert{name = "submachine-gun", count = 1}
	player.insert{name = "firearm-magazine", count = 30}
	player.insert{name = "iron-axe", count = 1}
	return
end

starting_area_constant =
	{
		["none"] = 0,
		["very-low"] = 120,
		["low"] = 2*120,
		["normal"] = 3*120,
		["high"] = 4*120,
		["very-high"] = 5*120
	}

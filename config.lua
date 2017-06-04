function load_config()

  global.setup_finished = false
  global.time_between_rounds = 60*3
  
  global.map_config = 
  {
    ["average_team_displacement"] = 2000,
    ["map_height"] = 2,
    ["map_width"] = 2,
    ["map_seed"] = 0,
    ["starting_area_size"] = 
    {
      options = {"none", "very-low", "low", "normal", "high", "very-high"},
      selected = "normal"
    },
    ["copy_starting_area"] = true,
    ["always_day"] = false,
    ["biters_disabled"] = true, 
    ["peaceful_mode"] = false,
    ["evolution_factor"] = 0,
  }
  
  global.team_config = 
  {
    ["friendly_fire"] = false,
    ["locked_teams"] = true,
    ["who_decides_diplomacy"] =
    {
      options = {"all_players", "team_leader"},
      selected = "team_leader"
    },
    ["team_joining"] =
    {
      options = {"player_pick", "random", "auto_assign"},
      selected = "auto_assign"
    },
    ["spawn_position"] = 
    {
      options = {"random", "fixed", "team_together"},
      selected = "team_together"
    },
    ["no_rush_time"] = 10,
    ["reveal_team_positions"] = true,
    ["team_walls"] = true,
    ["victory_condition"] =
    {
      options = {"standard", "space_race", "last_silo_standing", "freeplay"},
      selected = "last_silo_standing",
      tooltip = {"victory_condition_tooltip", {"standard_description"}, {"space_race_description"}, {"last_silo_standing_description"}, {"freeplay_description"}}
    },
    ["research_level"] = 
    {
      options = {"none","science-pack-1", "science-pack-2", "science-pack-3", "military-science-pack", "production-science-pack", "high-tech-science-pack", "space-science-pack"},
      selected = "none"
    },
    ["unlock_combat_research"] = false,
    ["starting_inventory"] = 
    {
      options = {"none", "small", "medium", "large"},
      selected = "none"
    },
    ["starting_equipment"] =
    {
      options = {"none", "small", "medium", "large", "none_with_bots", "small_with_bots", "medium_with_bots"},
      selected = "none"
    },
  }
    
  global.research_ingredient_list = {}
  for k, research in pairs (global.team_config.research_level.options) do
    global.research_ingredient_list[research] = false
  end
  
  global.colors =
  {
    {name = "Blue", color = {0.2, 0.2, 0.8, 0.7}},
    {name = "Green", color = {0.1, 0.8, 0.1, 0.8}},
    {name = "Purple", color = {0.8, 0.2, 0.8, 0.9}},
    {name = "Yellow", color = {0.8, 0.8, 0.0, 0.6}},
    {name = "Cyan", color = {0.1, 0.9, 0.9, 0.8}},
    {name = "Orange", color = {0.8, 0.4, 0.0, 0.8}},
    {name = "Pink", color = {0.8, 0.2, 0.8, 0.2}},
    {name = "White", color = {0.8, 0.8, 0.8, 0.5}},
    {name = "Black", color = {0.1, 0.1, 0.1, 0.8}},
    {name = "Gray", color = {0.6, 0.6, 0.6, 0.8}}
  }
  
  global.color_map = {}
  for k, color in pairs (global.colors) do
    global.color_map[color.name] = k
  end
    
  global.teams = 
  {
    {name = "Green 1", color = "Green", team = "-"},
    {name = "Purple 2", color = "Purple", team = "-"}
  }
    
  global.inventory_list = 
  {
    ["none"] = 
    {
      ["iron-plate"] = 8,
      ["burner-mining-drill"] = 1,
      ["stone-furnace"] = 1
    },
    ["small"] =
    {
      ["iron-plate"] = 20,
      ["pipe"] = 100,
      ["pipe-to-ground"] = 20,
      ["copper-plate"] = 10,
      ["transport-belt"] = 200,
      ["repair-pack"] = 20,
      ["inserter"] = 50,
      ["small-electric-pole"] = 40,
      ["burner-mining-drill"] = 16,
      ["stone-furnace"] = 12,
      ["burner-inserter"] = 30,
      ["assembling-machine-1"] = 8,
      ["electric-mining-drill"] = 2,
      ["boiler"] = 2,
      ["steam-engine"] = 4
    },
    ["medium"] =
    {
      ["iron-plate"] = 200,
      ["pipe"] = 100,
      ["pipe-to-ground"] = 20,
      ["iron-gear-wheel"] = 100,
      ["copper-plate"] = 100,
      ["steel-plate"] = 100,
      ["electronic-circuit"] = 100,
      ["transport-belt"] = 300,
      ["underground-belt"] = 20,
      ["splitter"] = 20,
      ["repair-pack"] = 20,
      ["inserter"] = 100,
      ["small-electric-pole"] = 40,
      ["fast-inserter"] = 50,
      ["burner-inserter"] = 50,
      ["burner-mining-drill"] = 20,
      ["electric-mining-drill"] = 20,
      ["stone-furnace"] = 50,
      ["steel-furnace"] = 20,
      ["assembling-machine-1"] = 20,
      ["assembling-machine-2"] = 8,
      ["boiler"] = 5,
      ["steam-engine"] = 10,
      ["chemical-plant"] = 20,
      ["oil-refinery"] = 5,
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
      ["long-handed-inserter"] = 100,
      ["medium-electric-pole"] = 50,
      ["substation"] = 10,
      ["boiler"] = 10,
      ["steam-engine"] = 20,
      ["chemical-plant"] = 20,
      ["oil-refinery"] = 5,
      ["pumpjack"] = 10
    }
  }
end

function give_equipment(player)

  local setting = global.team_config.starting_equipment.selected
  
  if setting == "none" then
    player.insert{name = "submachine-gun", count = 1}
	player.insert{name = "firearm-magazine", count = 30}
	player.insert{name = "iron-axe", count = 1}
	return
  end
  
  if setting == "small" then
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 30}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "iron-axe", count = 1}
    player.insert{name = "heavy-armor", count = 1}
    return
  end
  
  if setting == "medium" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "car", count = 1}
    player.insert{name = "modular-armor", count = 1}
    return
  end
  
  if setting == "large" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "combat-shotgun", count = 1}
    player.insert{name = "piercing-shotgun-shell", count = 20}
    player.insert{name = "rocket-launcher", count = 1}
    player.insert{name = "rocket", count = 80}
    player.insert{name = "power-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "fusion-reactor-equipment"})
    armor.put({name = "exoskeleton-equipment"})
    armor.put({name = "energy-shield-equipment"})
    armor.put({name = "energy-shield-equipment"})
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
    player.insert{name = "car", count = 1}
    return
  end  

  if setting == "none_with_bots" then
    player.insert{name = "submachine-gun", count = 1}
	player.insert{name = "firearm-magazine", count = 30}
	player.insert{name = "iron-axe", count = 1}
    player.insert{name = "modular-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
	return
  end
  
  if setting == "small_with_bots" then
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 30}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "iron-axe", count = 1}
    player.insert{name = "modular-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
    return
  end
  
  if setting == "medium_with_bots" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "car", count = 1}
    player.insert{name = "modular-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
    return
  end
  
end

function give_respawn_equipment(player)

  local setting = global.team_config.starting_equipment.selected
  
  if setting == "none" then
    player.insert{name = "submachine-gun", count = 1}
	player.insert{name = "firearm-magazine", count = 30}
	player.insert{name = "iron-axe", count = 1}
	return
  end
  
  if setting == "small" then
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 30}
    player.insert{name = "iron-axe", count = 1}
    player.insert{name = "heavy-armor", count = 1}
    return
  end
  
  if setting == "medium" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "modular-armor", count = 1}
    return
  end
  
  if setting == "none_with_bots" then
    player.insert{name = "submachine-gun", count = 1}
	player.insert{name = "firearm-magazine", count = 30}
	player.insert{name = "iron-axe", count = 1}
    player.insert{name = "modular-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
	return
  end
  
  if setting == "small_with_bots" then
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 30}
    player.insert{name = "iron-axe", count = 1}
    player.insert{name = "modular-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
    return
  end
  
  if setting == "medium_with_bots" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "modular-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
    return
  end
  
  if setting == "large" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "power-armor", count = 1}
    local armor = player.get_inventory(5)[1].grid
    armor.put({name = "fusion-reactor-equipment"})
    armor.put({name = "exoskeleton-equipment"})
    armor.put({name = "energy-shield-equipment"})
    armor.put({name = "energy-shield-equipment"})
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 1}
    player.insert{name = "deconstruction-planner", count = 1}
    return
  end  
  
end

starting_area_constant =
  {
    ["none"] = 128,
    ["very-low"] = 128,
    ["low"] = 2*128,
    ["normal"] = 3*128,
    ["high"] = 4*128,
    ["very-high"] = 5*128
  }
  
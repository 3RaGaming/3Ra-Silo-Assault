function load_config(dummy_load)
  local config = global
  if dummy_load then
    config = {}
  end

  config.setup_finished = false
  config.admin_config = 
  {
  }

  config.map_config =
  {
    average_team_displacement = 2048,
    map_height = 0,
    map_width = 0,
    map_seed = 0,
    starting_area_size =
    {
      options = {"none", "very-low", "low", "normal", "high", "very-high"},
      selected = "normal"
    },
    always_day = true,
    biters_disabled = true,
    peaceful_mode = false,
    evolution_factor = 0,
    duplicate_starting_area_entities = true
  }

  config.game_config = 
  {
    game_mode =
    {
      options = {"conquest", "space_race", "last_silo_standing", "freeplay", "production_score", "oil_harvest"},
      selected = "last_silo_standing",
      tooltip = 
      {
        "", {"game_mode_tooltip"},
        "\n",{"conquest_description"},
        "\n", {"space_race_description"},
        "\n", {"last_silo_standing_description"},
        "\n", {"freeplay_description"},
        "\n", {"production_score_description"},
        "\n", {"oil_harvest_description"}
      }
    },
    disband_on_loss = true,
    time_limit = 0,
    required_production_score = 50000000,
    required_oil_barrels = 1000,
    oil_only_in_center = true,
    allow_spectators = false,
    spectator_fog_of_war = true,
    no_rush_time = 0,
    base_exclusion_time = 0,
    reveal_team_positions = true,
    reveal_map_center = false,
    team_walls = true,
    team_turrets = true,
    team_artillery = true,
    give_artillery_remote = false,
    auto_new_round_time = 1
  }

  config.team_config =
  {
    friendly_fire = true,
    locked_teams = false,
    share_chart = true,
    who_decides_diplomacy =
    {
      options = {"all_players", "team_leader"},
      selected = "team_leader"
    },
    team_joining =
    {
      options = {"player_pick", "random", "auto_assign"},
      selected = "player_pick"
    },
    spawn_position =
    {
      options = {"random", "fixed", "team_together"},
      selected = "team_together"
    },
    research_level =
    {
      options = {"none","science-pack-1", "science-pack-2", "science-pack-3", "military-science-pack", "production-science-pack", "high-tech-science-pack", "space-science-pack"},
      selected = "military-science-pack"
    },
    unlock_combat_research = false,
    starting_equipment =
    {
      options = {"none", "small", "medium", "large"},
      selected = "large"
    },
    starting_inventory =
    {
      options = {"none", "small", "medium", "large"},
      selected = "none"
    },
    starting_chest =
    {
      options = {"none", "small", "medium", "large"},
      selected = "large"
    },
    starting_chest_multiplier = 5
  }

  config.research_ingredient_list = {}
  for k, research in pairs (config.team_config.research_level.options) do
    config.research_ingredient_list[research] = false
  end

  config.colors =
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

  config.color_map = {}
  for k, color in pairs (config.colors) do
    config.color_map[color.name] = k
  end

  config.teams =
  {
    {name = "Green 1", color = "Green", team = "-"},
    {name = "Purple 2", color = "Purple", team = "-"}
  }

  config.inventory_list =
  {
    none =
    {
      ["iron-plate"] = 8,
      ["burner-mining-drill"] = 1,
      ["stone-furnace"] = 1
    },
    small =
    {
      ["iron-plate"] = 200,
      ["pipe"] = 100,
      ["pipe-to-ground"] = 20,
      ["copper-plate"] = 200,
      ["iron-gear-wheel"] = 200,
      ["electronic-circuit"] = 200,
      ["transport-belt"] = 400,
      ["repair-pack"] = 20,
      ["inserter"] = 100,
      ["small-electric-pole"] = 50,
      ["burner-mining-drill"] = 50,
      ["stone-furnace"] = 50,
      ["burner-inserter"] = 100,
      ["assembling-machine-1"] = 20,
      ["electric-mining-drill"] = 20,
      ["boiler"] = 5,
      ["steam-engine"] = 10,
      ["offshore-pump"] = 2,
      ["raw-wood"] = 50
    },
    medium =
    {
      ["iron-plate"] = 200,
      ["pipe"] = 100,
      ["pipe-to-ground"] = 20,
      ["iron-gear-wheel"] = 100,
      ["copper-plate"] = 100,
      ["steel-plate"] = 100,
      ["electronic-circuit"] = 400,
      ["transport-belt"] = 400,
      ["underground-belt"] = 20,
      ["splitter"] = 20,
      ["repair-pack"] = 20,
      ["inserter"] = 150,
      ["small-electric-pole"] = 100,
      ["fast-inserter"] = 50,
      ["long-handed-inserter"] = 50,
      ["burner-inserter"] = 100,
      ["burner-mining-drill"] = 50,
      ["electric-mining-drill"] = 40,
      ["stone-furnace"] = 100,
      ["steel-furnace"] = 30,
      ["assembling-machine-1"] = 40,
      ["assembling-machine-2"] = 20,
      ["boiler"] = 10,
      ["steam-engine"] = 20,
      ["chemical-plant"] = 20,
      ["oil-refinery"] = 5,
      ["pumpjack"] = 8,
      ["offshore-pump"] = 2,
      ["raw-wood"] = 50
    },
    large =
    {
      ["iron-plate"] = 200,
      ["pipe"] = 100,
      ["pipe-to-ground"] = 20,
      ["copper-plate"] = 200,
      ["steel-plate"] = 200,
      ["electronic-circuit"] = 400,
      ["iron-gear-wheel"] = 250,
      ["transport-belt"] = 400,
      ["underground-belt"] = 40,
      ["splitter"] = 40,
      ["repair-pack"] = 20,
      ["inserter"] = 200,
      ["burner-inserter"] = 50,
      ["small-electric-pole"] = 50,
      ["burner-mining-drill"] = 50,
      ["electric-mining-drill"] = 50,
      ["stone-furnace"] = 100,
      ["steel-furnace"] = 50,
      ["electric-furnace"] = 20,
      ["assembling-machine-1"] = 50,
      ["assembling-machine-2"] = 40,
      ["assembling-machine-3"] = 20,
      ["electronic-circuit"] = 200,
      ["fast-inserter"] = 100,
      ["long-handed-inserter"] = 100,
      ["medium-electric-pole"] = 50,
      ["substation"] = 10,
      ["big-electric-pole"] = 10,
      ["boiler"] = 10,
      ["steam-engine"] = 20,
      ["chemical-plant"] = 20,
      ["oil-refinery"] = 5,
      ["pumpjack"] = 10,
      ["offshore-pump"] = 2,
      ["raw-wood"] = 50
    }
  }
  if dummy_load then
    return config
  end
end

function give_equipment(player)

  local setting = global.team_config.starting_equipment.selected

  if setting == "none" then
    player.insert{name = "pistol", count = 1}
    player.insert{name = "firearm-magazine", count = 10}
    return
  end

  if setting == "small" then
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "firearm-magazine", count = 30}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "iron-axe", count = 1}
    player.insert{name = "heavy-armor", count = 1}
    return
  end

  if setting == "medium" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "firearm-magazine", count = 40}
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
    local armor = player.get_inventory(defines.inventory.player_armor)[1].grid
    armor.put({name = "fusion-reactor-equipment"})
    armor.put({name = "exoskeleton-equipment"})
    armor.put({name = "energy-shield-equipment"})
    armor.put({name = "energy-shield-equipment"})
    armor.put({name = "personal-roboport-equipment"})
    player.force.worker_robots_speed_modifier = 2.5
    player.insert{name = "construction-robot", count = 10}
    player.insert{name = "blueprint", count = 3}
    player.insert{name = "deconstruction-planner", count = 1}
    player.insert{name = "car", count = 1}
    return
  end

end
function get_starting_area_radius(as_tiles)
  if not global.map_config.starting_area_size then return 0 end
  local starting_area_chunk_radius =
  {
    ["none"] = 3,
    ["very-low"] = 3,
    ["low"] = 4,
    ["normal"] = 5,
    ["high"] = 6,
    ["very-high"] = 7
  }
  return as_tiles and starting_area_chunk_radius[global.map_config.starting_area_size.selected] * 32 or starting_area_chunk_radius[global.map_config.starting_area_size.selected]
end

function parse_config_from_gui(gui, config)
  local config_table = gui.config_table
  if not config_table then
    error("Trying to parse config from gui with no config table present")
  end
  for name, value in pairs (config) do
    if config_table[name.."_box"] then
      local text = config_table[name.."_box"].text
      local n = tonumber(text)
      if text == "" then n = 0 end
      if n ~= nil then
        if n <= 4294967295 then
          config[name] = n
        else
          game.players[config_table.player_index].print({"value-too-big", {name}})
          return
        end
      else
        game.players[config_table.player_index].print({"must-be-number", {name}})
        return
      end
    end
    if type(value) == "boolean" then
      if config_table[name] then
        config[name] = config_table[name.."_boolean"].state
      end
    end
    if type(value) == "table" then
      local menu = config_table[name.."_dropdown"]
      if not menu then game.print("Error trying to read drop down menu of gui element "..name)return end
      config[name].selected = config[name].options[menu.selected_index]
    end
  end
  return true
end

function make_config_table(gui, config)
  local config_table = gui.config_table
  if config_table then
    config_table.clear()
  else
    config_table = gui.add{type = "table", name = "config_table", column_count = 2}
    config_table.style.column_alignments[2] = "right"
  end
  local items = game.item_prototypes
  for k, name in pairs (config) do
    local label
    if tonumber(name) then
      label = config_table.add{type = "label", name = k, tooltip = {k.."_tooltip"}}
      local input = config_table.add{type = "textfield", name = k.."_box"}
      input.text = name
      input.style.maximal_width = 100
    elseif tostring(type(name)) == "boolean" then
      label = config_table.add{type = "label", name = k, tooltip = {k.."_tooltip"}}
      config_table.add{type = "checkbox", name = k.."_"..tostring(type(name)), state = name}
    else
      label = config_table.add{type = "label", name = k, tooltip = {k.."_tooltip"}}
      local menu = config_table.add{type = "drop-down", name = k.."_dropdown"}
      menu.style.maximal_width = 150
      local index
      for j, option in pairs (name.options) do
        if items[option] then
          menu.add_item(items[option].localised_name)
        else
          menu.add_item({option})
        end
        if option == name.selected then index = j end
      end
      menu.selected_index = index or 1
      if name.tooltip then
        label.tooltip = name.tooltip
      end
    end
    label.caption = {"", {k}, {"colon"}}
  end
end

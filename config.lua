function load_config(dummy_load)
  local config = global
  if dummy_load then
    config = {}
  end

  config.setup_finished = false
  config.match_started = false

  config.game_speed = 1

  config.disabled_items =
  {
    ["artillery-targeting-remote"] = 209,
    ["programmable-speaker"] = 264,
    ["raw-fish"] = 346
  }
  
  config.map_config =
  {
    average_team_displacement = 1024,
    map_height = 2048,
    map_width = 2048,
    map_seed = 0,
    starting_area_size =
    {
      options = {"none", "very-low", "low", "normal", "high", "very-high"},
      selected = "normal"
    },
    always_day = true,
    biters_disabled = true,
    peaceful_mode = true,
    evolution_factor = 0,
    duplicate_starting_area_entities = true
  }

  config.game_config = 
  {
    game_mode =
    {
      options = {"conquest", "space_race", "last_silo_standing", "freeplay", "production_score", "conquest_production", "oil_harvest"},
      selected = "conquest_production",
      tooltip = 
      {
        "", {"game_mode_tooltip"},
        "\n", {"conquest_description"},
        "\n", {"space_race_description"},
        "\n", {"last_silo_standing_description"},
        "\n", {"freeplay_description"},
        "\n", {"production_score_description"},
        "\n", {"conquest_production_description"},
        "\n", {"oil_harvest_description"}
      }
    },
    disband_on_loss = false,
    time_limit = 180,
    required_production_score = 10000000,
    required_oil_barrels = 1000,
    required_satellites_sent = 1,
    oil_only_in_center = true,
    allow_spectators = false,
    spectator_fog_of_war = false,
    no_rush_time = 20,
    base_exclusion_time = 0,
    fast_blueprinting_time = 20,
    character_speed_when_hurt = "90%",
    reveal_team_positions = true,
    reveal_map_center = true,
    team_walls = true,
    team_turrets = true,
    turret_ammunition =
    {
      options = {"piercing-rounds-magazine"},
      selected = "piercing-rounds-magazine"
    },
    team_artillery = false,
    give_artillery_remote = false,
    protect_empty_teams = false,
    enemy_building_restriction = false,
    neutral_chests = true,
    auto_new_round_time = 3,
    team_prep_time = 1,
    kill_cowards = true
  }

  local items = game.item_prototypes

  local bullet_entity_name = "gun-turret"
  local laser_entity_name = "laser-turret"
  local bullet_prototype = game.entity_prototypes[bullet_entity_name]
  local laser_prototype = game.entity_prototypes[laser_entity_name]
  if not bullet_prototype and not laser_prototype then
    config.game_config.team_turrets = nil
    config.game_config.turret_ammunition = nil
  else
    local ammos = {}
    if bullet_prototype then
      local category = bullet_prototype.attack_parameters.ammo_category
      if category then
        for name, item in pairs (items) do
          if item.type == "ammo" then
            local ammo = item.get_ammo_type()
            if ammo and ammo.category == category then
              table.insert(ammos, name)
            end
          end
        end
      end
    end
    if laser_prototype then
      table.insert(ammos, laser_entity_name)
    end
    config.game_config.turret_ammunition.options = ammos
    if not items["piercing-rounds-magazine"] then
      config.game_config.turret_ammunition.selected = ammos[1] or ""
    end
  end

  config.team_config =
  {
    max_players = 0,
    friendly_fire = true,
    share_chart = true,
    diplomacy_enabled = false,
    who_decides_diplomacy =
    {
      options = {"all_players", "team_leader"},
      selected = "all_players"
    },
    team_joining =
    {
      options = {"player_pick", "random", "auto_assign"},
      selected = "auto_assign"
    },
    spawn_position =
    {
      options = {"random", "fixed", "team_together"},
      selected = "team_together"
    },
    research_level =
    {
      options = {"none"},
      selected = "none"
    },
    unlock_combat_research = false,
    defcon_mode = true,
    defcon_random = false,
    defcon_timer = 0.6,
    starting_equipment =
    {
      options = {"none", "small", "medium", "large"},
      selected = "medium"
    },
    starting_chest =
    {
      options = {"none", "small", "medium", "large"},
      selected = "medium"
    },
    starting_chest_multiplier = 5
  }

  local packs = {}
  local sorted_packs = {}
  local techs = game.technology_prototypes
  for k, tech in pairs (techs) do
    for k, ingredient in pairs (tech.research_unit_ingredients) do
      if not packs[ingredient.name] then
        packs[ingredient.name] = true
        local order = tostring(items[ingredient.name].order) or "Z-Z"
        local added = false
        for k, t in pairs (sorted_packs) do
          if order < t.order then
            table.insert(sorted_packs, k, {name = ingredient.name, order = order})
            added = true
            break
          end
        end
        if not added then
          table.insert(sorted_packs, {name = ingredient.name, order = order})
        end
      end
    end
  end

  for k, t in pairs (sorted_packs) do
    table.insert(config.team_config.research_level.options, t.name)
  end
  local selected_tier = config.team_config.research_level.options[2]
  if selected_tier then config.team_config.research_level.selected = selected_tier end

  config.research_ingredient_list = {}
  for k, research in pairs (config.team_config.research_level.options) do
    config.research_ingredient_list[research] = false
  end

  config.colors =
  {
    { name = "orange" , color = { r = 0.869, g = 0.5  , b = 0.130, a = 0.5 }},
    { name = "purple" , color = { r = 0.485, g = 0.111, b = 0.659, a = 0.5 }},
    { name = "red"    , color = { r = 0.815, g = 0.024, b = 0.0  , a = 0.5 }},
    { name = "green"  , color = { r = 0.093, g = 0.768, b = 0.172, a = 0.5 }},
    { name = "blue"   , color = { r = 0.155, g = 0.540, b = 0.898, a = 0.5 }},
    { name = "yellow" , color = { r = 0.835, g = 0.666, b = 0.077, a = 0.5 }},
    { name = "pink"   , color = { r = 0.929, g = 0.386, b = 0.514, a = 0.5 }},
    { name = "white"  , color = { r = 0.8  , g = 0.8  , b = 0.8  , a = 0.5 }},
    { name = "black"  , color = { r = 0.1  , g = 0.1  , b = 0.1,   a = 0.5 }},
    { name = "gray"   , color = { r = 0.4  , g = 0.4  , b = 0.4,   a = 0.5 }},
    { name = "brown"  , color = { r = 0.300, g = 0.117, b = 0.0,   a = 0.5 }},
    { name = "cyan"   , color = { r = 0.275, g = 0.755, b = 0.712, a = 0.5 }},
    { name = "acid"   , color = { r = 0.559, g = 0.761, b = 0.157, a = 0.5 }},
  }
  
  config.color_map = {}
  for k, color in pairs (config.colors) do
    config.color_map[color.name] = k
  end

  config.teams =
  {
    {name = game.backer_names[math.random(#game.backer_names)], color = "orange", team = "-"},
    {name = game.backer_names[math.random(#game.backer_names)], color = "purple", team = "-"}
  }

  config.science_units_per_period = 100
  
  --values calculated based on solid raw materials being worth 1 and crude oil being worth 0.2
  --source is the second table on this page: https://wiki.factorio.com/Science_pack
  config.science_pack_costs =
  {
    ["science-pack-1"] = 3, -- 2 + 1
    ["science-pack-2"] = 7, -- 5.5 + 1.5
    ["science-pack-3"] = 48.94, -- 34 + 9.5 + 1 + 22.2 / 5
    ["military-science-pack"] = 39.5, -- 27 + 7.5 + 5
    ["production-science-pack"] = 74.18, -- 35.5 + 14 + 2.5 + 60.9 / 5 + 10
    ["high-tech-science-pack"] = 164.48, -- 44.4 + 84.3 + 5.5 + 151.4 / 5
    ["space-science-pack"] = 261.74, -- 101.5 + 85.3 + 10 + 324.7 / 5
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
      ["inserter"] = 100,
      ["small-electric-pole"] = 50,
      ["burner-mining-drill"] = 50,
      ["stone-furnace"] = 50,
      ["burner-inserter"] = 50,
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
      ["steel-chest"] = 15,
      ["electronic-circuit"] = 200,
      ["transport-belt"] = 400,
      ["underground-belt"] = 20,
      ["splitter"] = 20,
      ["inserter"] = 150,
      ["small-electric-pole"] = 100,
      ["medium-electric-pole"] = 50,
      ["fast-inserter"] = 50,
      ["long-handed-inserter"] = 50,
      ["burner-inserter"] = 20,
      ["burner-mining-drill"] = 20,
      ["electric-mining-drill"] = 40,
      ["stone-furnace"] = 50,
      ["steel-furnace"] = 30,
      ["assembling-machine-1"] = 10,
      ["assembling-machine-2"] = 20,
      ["boiler"] = 10,
      ["steam-engine"] = 20,
      ["chemical-plant"] = 15,
      ["oil-refinery"] = 3,
      ["pumpjack"] = 4,
      ["offshore-pump"] = 2,
      ["raw-wood"] = 50
    },
    large =
    {
      ["iron-plate"] = 200,
      ["pipe"] = 100,
      ["pipe-to-ground"] = 20,
      ["copper-plate"] = 100,
      ["steel-chest"] = 15,
      ["electronic-circuit"] = 200,
      ["iron-gear-wheel"] = 100,
      ["transport-belt"] = 400,
      ["underground-belt"] = 40,
      ["splitter"] = 40,
      ["repair-pack"] = 20,
      ["inserter"] = 200,
      ["burner-inserter"] = 20,
      ["small-electric-pole"] = 50,
      ["burner-mining-drill"] = 20,
      ["electric-mining-drill"] = 50,
      ["stone-furnace"] = 50,
      ["steel-furnace"] = 50,
      ["electric-furnace"] = 20,
      ["assembling-machine-1"] = 10,
      ["assembling-machine-2"] = 40,
      ["assembling-machine-3"] = 20,
      ["fast-inserter"] = 100,
      ["long-handed-inserter"] = 100,
      ["medium-electric-pole"] = 50,
      ["substation"] = 10,
      ["big-electric-pole"] = 10,
      ["boiler"] = 10,
      ["steam-engine"] = 20,
      ["chemical-plant"] = 20,
      ["oil-refinery"] = 5,
      ["pumpjack"] = 8,
      ["offshore-pump"] = 2,
      ["raw-wood"] = 50
    }
  }
  if dummy_load then
    return config
  end
end

function give_equipment(player, respawn)

  local setting = global.team_config.starting_equipment.selected

  if setting == "none" then
    player.insert{name = "pistol", count = 1}
    player.insert{name = "firearm-magazine", count = 10}
    return
  end

  if setting == "small" then
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 30}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "steel-axe", count = 1}
    player.insert{name = "heavy-armor", count = 1}
    return
  end

  if setting == "medium" then
    player.insert{name = "steel-axe", count = 3}
    player.insert{name = "submachine-gun", count = 1}
    player.insert{name = "piercing-rounds-magazine", count = 40}
    player.insert{name = "shotgun", count = 1}
    player.insert{name = "shotgun-shell", count = 20}
    player.insert{name = "deconstruction-planner", count = 1}
    -- @todo the following commented out code is the first attempt at removing bots and modular armor after fast blueprinting period ends.
    if not respawn then
      player.insert{name = "modular-armor", count = 1}
    --if global.end_fast_blueprinting > game.tick then
      local armor = player.get_inventory(defines.inventory.player_armor)[1]
      armor.grid.put({name = "personal-roboport-equipment"})
      --if not global.fast_blueprinting_items then
      --  global.fast_blueprinting_items = {}
      --end
      --table.insert(global.fast_blueprinting_items, armor)
      player.insert{name = "construction-robot", count = 10}
    else
      player.insert{name = "heavy-armor", count = 1}
    end
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
    armor.put({name = "personal-roboport-mk2-equipment"})
    player.insert{name = "construction-robot", count = 25}
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
      local n = tonumber(text:match("^([^%%]+)%%?$")) --remove trailing %
      if text == "" then n = 0 end
      if n ~= nil then
        if n > 4294967295 then
          game.players[config_table.player_index].print({"value-too-big", {name}})
          return
        end
        if n < 0 then
          game.players[config_table.player_index].print({"value-below-zero", {name}})
          return
        end
        config[name] = n
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
    --if tonumber(name) or ({tostring(name):gsub("^(%d+)%%", "%1")})[2] ~= 0 then
    if tonumber(name) or tostring(name):find("^%d+%%$") then
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

local config = {script_data = {}}

config.get_config = function()

  local data = {}

  data.setup_finished = false
  data.match_started = false

  data.game_speed = 1

  data.disabled_items =
  {
    ["artillery-targeting-remote"] = 209,
    ["programmable-speaker"] = 264,
    ["raw-fish"] = 346
  }
  
  data.map_config =
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
    duplicate_starting_area_entities = true,
    chunks_to_extend_duplication = 10,
    allow_spectators = false,
    spectator_fog_of_war = false,
    reveal_team_positions = true,
    reveal_map_center = true,
    team_walls = true,
    team_paved = true,
    team_turrets = true,
    turret_ammunition =
    {
      options = {"piercing-rounds-magazine"},
      selected = "piercing-rounds-magazine"
    },
    team_artillery = false,
    give_artillery_remote = false,
    protect_empty_teams = false,
    enemy_building_restriction = true
  }

  data.game_config =
  {
    game_mode = "dummy",
    time_limit = 180,
    last_silo_standing = true,
    disband_on_loss = false,
    production_score = true,
    required_production_score = 10000000,
    space_race = true,
    required_satellites_sent = 1,
    oil_harvest = false,
    required_oil = 10000000,
    oil_only_in_center = true,
    no_rush_time = 20,
    base_exclusion_time = 0,
    fast_blueprinting_time = 20,
    disable_starting_blueprints = false,
    character_speed_when_hurt = "80%",
    tank_speed = "100%",
    neutral_chests = true,
    neutral_vehicles = true,
    vehicle_wreckage = true,
    kill_cowards = true,
    nuclear_research_buff = true,
    tanks_research_nerf = true,
    auto_new_round_time = 3,
    team_prep_time = 1
  }

  local items = game.item_prototypes

  local bullet_entity_name = "gun-turret"
  local laser_entity_name = "laser-turret"
  local bullet_prototype = game.entity_prototypes[bullet_entity_name]
  local laser_prototype = game.entity_prototypes[laser_entity_name]
  if not bullet_prototype and not laser_prototype then
    data.map_config.team_turrets = nil
    data.map_config.turret_ammunition = nil
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
    data.map_config.turret_ammunition.options = ammos
    if not items["piercing-rounds-magazine"] then
      data.map_config.turret_ammunition.selected = ammos[1] or ""
    end
  end

  data.team_config =
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
    technology_price_multiplier = 1,
    defcon_mode = true,
    defcon_random = false,
    defcon_timer = 2,
    defcon_random_multiplier = 1,
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
    table.insert(data.team_config.research_level.options, t.name)
  end
  local selected_tier = config.team_config.research_level.options[2]
  if selected_tier then config.team_config.research_level.selected = selected_tier end

  data.research_ingredient_list = {}
  for k, research in pairs (data.team_config.research_level.options) do
    data.research_ingredient_list[research] = false
  end

  data.colors =
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

  data.color_map = {}
  for k, color in pairs (data.colors) do
    data.color_map[color.name] = k
  end

  data.teams =
  {
    {name = game.backer_names[math.random(#game.backer_names)], color = "orange", team = "-"},
    {name = game.backer_names[math.random(#game.backer_names)], color = "purple", team = "-"}
  }

  --values calculated based on solid raw materials being worth 1 and crude oil being worth 0.2
  --source is the second table on this page: https://wiki.factorio.com/Science_pack
  data.science_pack_costs =
  {
    ["automation-science-pack"] = 3,      -- 2 + 1
    ["logistic-science-pack"]   = 7,      -- 5.5 + 1.5
    ["chemical-science-pack"]   = 48.94,  -- 34 + 9.5 + 1 + 22.2 / 5
    ["military-science-pack"]   = 39.5,   -- 27 + 7.5 + 5
    ["production-science-pack"] = 74.18,  -- 35.5 + 14 + 2.5 + 60.9 / 5 + 10
    ["high-tech-science-pack"]  = 164.48, -- 44.4 + 84.3 + 5.5 + 151.4 / 5
    ["space-science-pack"]      = 261.74, -- 101.5 + 85.3 + 10 + 324.7 / 5
  }

  data.inventory_list =
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
      ["wood"] = 50
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
      ["underground-belt"] = 40,
      ["splitter"] = 10,
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
      ["chemical-plant"] = 10,
      ["oil-refinery"] = 2,
      ["pumpjack"] = 3,
      ["offshore-pump"] = 2,
      ["wood"] = 50
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
      ["underground-belt"] = 60,
      ["splitter"] = 20,
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
      ["chemical-plant"] = 15,
      ["oil-refinery"] = 4,
      ["pumpjack"] = 6,
      ["offshore-pump"] = 2,
      ["wood"] = 50
    }
  }

  data.equipment_list =
  {
    none =
    {
      items =
      {
        ["pistol"] = 1,
        ["firearm-magazine"] = 10,
      }
    },
    small =
    {
      items =
      {
        ["submachine-gun"] = 1,
        ["piercing-rounds-magazine"] = 30,
        ["shotgun"] = 1,
        ["shotgun-shell"] = 20,
        ["steel-axe"] = 1,
        ["heavy-armor"] = 1
      }
    },
    medium =
    {
      items =
      {
        ["steel-axe"] = 3,
        ["submachine-gun"] = 1,
        ["piercing-rounds-magazine"] = 40,
        ["shotgun"] = 1,
        ["shotgun-shell"] = 20,
        ["heavy-armor"] = 1
      },
      fast_blueprinting =
      {
        items = 
        {
          ["construction-robot"] = 10,
          ["deconstruction-planner"] = 1
        },
        armor = "modular-armor",
        equipment =
        {
          ["personal-roboport-equipment"] = 1
        }
      }
    },
    large =
    {
      items =
      {
        ["steel-axe"] = 3,
        ["submachine-gun"] = 1,
        ["piercing-rounds-magazine"] = 40,
        ["combat-shotgun"] = 1,
        ["piercing-shotgun-shell"] = 20,
        ["rocket-launcher"] = 1,
        ["rocket"] = 80,
        ["construction-robot"] = 25,
        ["car"] = 1,
      },
      armor = "power-armor",
      equipment =
      {
        ["fusion-reactor-equipment"] = 1,
        ["exoskeleton-equipment"] = 1,
        ["energy-shield-equipment"] = 2,
        ["personal-roboport-mk2-equipment"] = 1
      }
    }
  }

  data.prototypes =
  {
    chest = "steel-chest",
    wall = "stone-wall",
    gate = "gate",
    turret = "gun-turret",
    artillery = "artillery-turret",
    artillery_ammo = "artillery-shell",
    silo = "rocket-silo",
    tile_1 = "refined-concrete",
    tile_2 = "refined-hazard-concrete-left",
    artillery_remote = "artillery-targeting-remote",
    oil = "crude-oil",
    oil_resource = "crude-oil",
    satellite = "satellite"
  }

  data.silo_offset = {x = 0, y = 0}

  return data
end



config.give_equipment = function(player, respawn)
  if not config.script_data.equipment_list then return end
  local setting = config.script_data.team_config.starting_equipment.selected
  if not setting then return end
  local player_gear = config.script_data.equipment_list[setting]
  for equipment = player_gear, not respawn and player_gear.fast_blueprinting do
    if equipment then
      if equipment.items then
        util.insert_safe(player, equipment.items)
      end
      if equipment.armor then
        local stack = player.get_inventory(defines.inventory.player_armor)[1]
        local item = game.item_prototypes[equipment.armor]
        if item and item.type == "armor" then
          stack.set_stack{name = item.name}
        end
        if equipment.equipment then
          local grid = stack.grid
          if grid then
            local prototypes = game.equipment_prototypes
            for name, count in pairs (equipment.equipment) do
              if prototypes[name] then
                for k = 1, count do
                  grid.put{name = name}
                end
              end
            end
          end
        end
      end
    end
  end
end

config.get_starting_area_radius = function(as_tiles)
  if not config.script_data.map_config.starting_area_size then return 0 end
  local starting_area_chunk_radius =
  {
    ["none"] = 3,
    ["very-low"] = 3,
    ["low"] = 4,
    ["normal"] = 5,
    ["high"] = 6,
    ["very-high"] = 7
  }
  return as_tiles and starting_area_chunk_radius[config.script_data.map_config.starting_area_size.selected] * 32 or starting_area_chunk_radius[config.script_data.map_config.starting_area_size.selected]
end

config.parse_config_from_gui = function(gui, config)
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

local localised_names =
{
  peaceful_mode = {"gui-map-generator.peaceful-mode-checkbox"},
  map_height = {"gui-map-generator.map-width-simple"},
  map_width = {"gui-map-generator.map-height-simple"},
  map_seed = {"gui-map-generator.map-seed-simple"},
  starting_area_size = {"gui-map-generator.starting-area"},
  technology_price_multiplier = {"gui-map-generator.technology-price-multiplier"}
}

-- "" for no tooltip
local localised_tooltips =
{
  map_width = "",
  map_height = "",
  always_day = "",
  peaceful_mode = "",
  evolution_factor = "",
  starting_area_size = "",
  duplicate_starting_area_entities = "",
  friendly_fire = "",
  technology_price_multiplier = "",
  defcon_random_multiplier = ""
}

config.make_config_table = function(gui, config)
  local config_table = gui.config_table
  if config_table then
    config_table.clear()
  else
    config_table = gui.add{type = "table", name = "config_table", column_count = 2}
    config_table.style.column_alignments[2] = "right"
  end
  local items = game.item_prototypes
  for k, name in pairs (config) do
    local label = config_table.add{type = "label", name = k}
    if name == "dummy" then
      config_table.add{type = "label", name = k.."_dummy"}
    elseif tonumber(name) or tostring(name):find("^%d+%%$") then
      local input = config_table.add{type = "textfield", name = k.."_box"}
      input.text = name
      input.style.horizontally_stretchable = true
      --input.style.maximal_width = 100
    elseif tostring(type(name)) == "boolean" then
      config_table.add{type = "checkbox", name = k.."_boolean", state = name}
    else
      local menu = config_table.add{type = "drop-down", name = k.."_dropdown"}
      local index
      for j, option in pairs (name.options) do
        if items[option] then
          menu.add_item(items[option].localised_name)
        else
          menu.add_item(localised_names[option] or {option})
        end
        if option == name.selected then index = j end
      end
      menu.selected_index = index or 1
    end
    label.caption = {"", localised_names[k] or {k}, {"colon"}}
    label.tooltip = localised_tooltips[k] or {k.."_tooltip"}
  end
end

return config

local mod_gui = require("mod-gui")
local util = require("util")
local balance = require("balance")
local config = require("config")
local production_score = require("production-score")

local script_data = {}

local statistics_period = 150 -- Seconds
local game_message_color = {r = 1, g = 0.2, b = 0.8, a = 1} --hot pink

local events =
{
  on_round_end = script.generate_event_name(),
  on_round_start = script.generate_event_name(),
  on_team_lost = script.generate_event_name(),
  on_team_won = script.generate_event_name()
}

function create_spawn_positions()
  local map_config = script_data.map_config
  local width = map_config.map_width
  local height = map_config.map_height
  local displacement = math.max(map_config.average_team_displacement, 64)
  local horizontal_offset = (width/displacement) * 10
  local vertical_offset = (height/displacement) * 10
  script_data.spawn_offset = {x = math.floor(0.5 + math.random(-horizontal_offset, horizontal_offset) / 32) * 32, y = math.floor(0.5 + math.random(-vertical_offset, vertical_offset) / 32) * 32}
  local height_scale = height/width
  local radius = config.get_starting_area_radius()
  local count = #script_data.teams
  local max_distance = config.get_starting_area_radius(true) * 2 + displacement
  local min_distance = config.get_starting_area_radius(true) + (32 * (count - 1))
  local edge_addition = (radius + 2) * 32
  local elevator_set = false
  if height_scale == 1 then
    if max_distance > width then
      displacement = width - edge_addition
    end
  end
  if height_scale < 1 then
    if #script_data.teams == 2 then
      if max_distance > width then
        displacement = width - edge_addition
      end
      max_distance = 0
    end
    if max_distance > height then
      displacement = height - edge_addition
    end
  end
  if height_scale > 1 then
    if #script_data.teams == 2 then
      if max_distance > height then
        displacement = height - edge_addition
      end
      elevator_set = true
      max_distance = 0
    end
    if max_distance > width then
      displacement = width - edge_addition
    end
  end
  local distance = 0.5*displacement
  if distance < min_distance then
    game.print({"map-size-below-minimum"})
  end
  local positions = {}
  if count == 1 then
    positions[1] = {x = 0, y = 0}
  else
    for k = 1, count do
      local rotation = (k*2*math.pi)/count
      local X = 32*(math.floor((math.cos(rotation)*distance+0.5)/32))
      local Y = 32*(math.floor((math.sin(rotation)*distance+0.5)/32))
      if elevator_set then
        --[[Swap X and Y for elevators]]
        Y = 32*(math.floor((math.cos(rotation)*distance+0.5)/32))
        X = 32*(math.floor((math.sin(rotation)*distance+0.5)/32))
      end
      positions[k] = {x = X, y = Y}
    end
  end
  if #positions == 2 and height_scale == 1 then
    --If there are 2 teams in a square map, we adjust positions so they are in the corners of the map
    for k, position in pairs (positions) do
      if position.x == 0 then position.x = position.y end
      if position.y == 0 then position.y = -position.x end
    end
  end
  if #positions == 4 then
    --If there are 4 teams we adjust positions so they are in the corners of the map
    height_scale = math.min(height_scale, 2)
    height_scale = math.max(height_scale, 0.5)
    for k, position in pairs (positions) do
      if position.x == 0 then position.x = position.y end
      if position.y == 0 then position.y = -position.x end
      if height_scale > 1 then
        position.y = position.y * height_scale
      else
        position.x = position.x * (1/height_scale)
      end
    end
    if height_scale < 1 then
      --If the map is wider than tall, swap 1 and 3 so two allied teams will be together
      positions[1], positions[3] = positions[3], positions[1]
    end
  end
  for k, position in pairs (positions) do
    position.x = position.x + script_data.spawn_offset.x
    position.y = position.y + script_data.spawn_offset.y
  end
  script_data.spawn_positions = positions
  --error(serpent.block(positions))
  return positions
end

function create_next_surface()
  local name = "battle_surface_1"
  if game.surfaces[name] ~= nil then
    name = "battle_surface_2"
  end
  script_data.round_number = script_data.round_number + 1
  local settings = game.surfaces[1].map_gen_settings
  settings.starting_area = script_data.map_config.starting_area_size.selected
  if script_data.map_config.biters_disabled then
    settings.autoplace_controls["enemy-base"].size = "none"
  end
  if script_data.map_config.map_seed == 0 then
    settings.seed = math.random(4000000000)
  else
    settings.seed = script_data.map_config.map_seed
  end
  if script_data.map_config.map_height < 1 then
    script_data.map_config.map_height = 2000000
  end
  if script_data.map_config.map_width < 1 then
    script_data.map_config.map_width = 2000000
  end
  settings.height = script_data.map_config.map_height
  settings.width = script_data.map_config.map_width
  settings.starting_points = create_spawn_positions()
  script_data.surface = game.create_surface(name, settings)
  script_data.surface.daytime = 0
  script_data.surface.always_day = script_data.map_config.always_day
end

function destroy_player_gui(player)
  local button_flow = mod_gui.get_button_flow(player)
  for k, name in pairs (
    {
      "objective_button", "diplomacy_button", "admin_button",
      "silo_gui_sprite_button", "production_score_button", "oil_harvest_button",
      "space_race_button", "spectator_join_team_button", "list_teams_button"
    }) do
    if button_flow[name] then
      button_flow[name].destroy()
    end
  end
  local frame_flow = mod_gui.get_frame_flow(player)
  for k, name in pairs (
    {
      "objective_frame", "admin_button", "admin_frame",
      "silo_gui_frame", "production_score_frame", "oil_harvest_frame",
      "space_race_frame", "team_list"
    }) do
    if frame_flow[name] then
      frame_flow[name].destroy()
    end
  end
  local center_gui = player.gui.center
  for k, name in pairs ({"diplomacy_frame", "progress_bar", "start_match_frame"}) do
    if center_gui[name] then
      center_gui[name].destroy()
    end
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

function make_color_dropdown(k, gui)
  local team = script_data.teams[k]
  local menu = gui.add{type = "drop-down", name = k.."_color"}
  local count = 1
  for k, color in pairs (script_data.colors) do
    menu.add_item({"color."..color.name})
    if color.name == team.color then
      menu.selected_index = count
    end
    count = count + 1
  end
end

function add_team_to_team_table(gui, k)
  local team = script_data.teams[k]
  local textfield = gui.add{type = "textfield", name = k, text = team.name}
  textfield.style.minimal_width = 0
  textfield.style.horizontally_stretchable = true
  make_color_dropdown(k, gui)
  local caption
  if tonumber(team.team) then
    caption = team.team
  elseif team.team:find("?") then
    caption = "?"
  else
    caption = team.team
  end
  set_button_style(gui.add{type = "button", name = k.."_next_team_button", caption = caption, tooltip = {"team-button-tooltip"}})
  local bin = gui.add{name = k.."_trash_button", type = "sprite-button", sprite = "utility/trash_bin", tooltip = {"remove-team-tooltip"}}
  bin.style.top_padding = 0
  bin.style.bottom_padding = 0
  bin.style.right_padding = 0
  bin.style.left_padding = 0
  bin.style.minimal_height = 26
  bin.style.minimal_width = 26
end

function create_game_config_gui(gui)
  local name = "game_config_gui"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"game-config-gui"}, direction = "vertical", style = "inner_frame"}
  frame.clear()
  config.make_config_table(frame, script_data.game_config)
  create_disable_frame(frame)
end

function create_team_config_gui(gui)
  local name = "team_config_gui"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"team-config-gui"}, direction = "vertical", style = "inner_frame"}
  frame.clear()
  local scroll = frame.add{type = "scroll-pane", name = "team_config_gui_scroll"}
  scroll.style.minimal_width = 400
  scroll.style.minimal_height = 100
  scroll.style.maximal_height = 250
  local team_table = scroll.add{type = "table", column_count = 4, name = "team_table"}
  for k, name in pairs ({"team-name", "color", "team", "remove"}) do
    team_table.add{type = "label", caption = {name}}
  end
  for k, team in pairs (script_data.teams) do
    add_team_to_team_table(team_table, k)
  end
  set_button_style(frame.add{name = "add_team_button", type = "button", caption = {"add-team"}, tooltip = {"add-team-tooltip"}})
  config.make_config_table(frame, script_data.team_config)
end

function get_config_holder(player)
  local gui = player.gui.center
  local frame = gui.config_holding_frame
  if frame then return frame.scrollpane.horizontal_flow end
  frame = gui.add{name = "config_holding_frame", type = "frame", direction = "vertical"}
  frame.style.maximal_height = player.display_resolution.height * 0.95
  frame.style.maximal_width = player.display_resolution.width * 0.95
  local scroll = frame.add{name = "scrollpane", type = "scroll-pane"}
  local flow = scroll.add{name = "horizontal_flow", type = "table", column_count = 4}
  flow.draw_vertical_lines = true
  flow.style.horizontal_spacing = 32
  flow.style.horizontally_stretchable = true
  flow.style.horizontally_squashable = true
  return flow
end

function get_config_frame(player)
  local gui = player.gui.center
  local frame = gui.config_holding_frame
  if frame then return frame end
  get_config_holder(player)
  return gui.config_holding_frame
end

function check_config_frame_size(event)
  local player = game.players[event.player_index]
  if not player then return end
  local frame = player.gui.center.config_holding_frame
  if not frame then return end
  local visiblity = frame.visible
  frame.destroy()
  --In this case, it is better to destroy and re-create, instead of handling the sizing and scaling of all the elements in the gui
  create_config_gui(player)
  get_config_frame(player).visible = visiblity
end

function check_balance_frame_size(event)
  local player = game.players[event.player_index]
  if not player then return end
  local frame = player.gui.center.balance_options_frame
  if not frame then return end
  toggle_balance_options_gui(player)
  toggle_balance_options_gui(player)
end

function create_config_gui(player)
  local gui = get_config_holder(player)
  create_map_config_gui(gui)
  create_game_config_gui(gui)
  create_team_config_gui(gui)
  local frame = get_config_frame(player)
  if not frame.config_holder_button_flow then
    local button_flow = frame.add{type = "flow", direction = "horizontal", name = "config_holder_button_flow"}
    button_flow.style.horizontally_stretchable = true
    button_flow.style.horizontal_align = "right"
    button_flow.style.vertical_align = "bottom"
    button_flow.add{type = "button", name = "balance_options", caption = {"balance-options"}, style = "dialog_button"}
    button_flow.add{type = "sprite-button", name = "pvp_export_button", sprite = "utility/export_slot", tooltip = {"gui.export-to-string"}, style = "slot_button"}
    button_flow.add{type = "sprite-button", name = "pvp_import_button", sprite = "utility/import_slot", tooltip = {"gui-blueprint-library.import-string"}, style = "slot_button"}
    button_flow.add{type = "button", name = "config_confirm", caption = {"config-confirm"}, style = "confirm_button"}
  end
  set_mode_input(player)
end

function create_map_config_gui(gui)
  local name = "map_config_gui"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"map-config-gui"}, direction = "vertical", style = "inner_frame"}
  frame.clear()
  config.make_config_table(frame, script_data.map_config)
end

function create_waiting_gui(player)
  local gui = player.gui.center
  local frame = gui.waiting_frame or gui.add{type = "frame", name = "waiting_frame"}
  frame.clear()
  local label = frame.add{type = "label", caption = {"setup-in-progress"}}
end

function player_join_lobby(player)
  local character = player.character
  player.character = nil
  if character then character.destroy() end
  player.set_controller{type = defines.controllers.spectator}
  player.teleport({0, 1000}, game.surfaces.Lobby)
  player.color = script_data.colors[script_data.color_map["black"]].color
  player.chat_color = script_data.colors[script_data.color_map["yellow"]].color
end

function end_round(admin)
  for k, player in pairs (game.players) do
    player.force = game.forces.player
    player.tag = ""
    destroy_player_gui(player)
    destroy_joining_guis(player.gui.center)
    if player.connected then
      if player.ticks_to_respawn then
        player.ticks_to_respawn = nil
      end
      player_join_lobby(player)
      if player.admin then
        create_config_gui(player)
      else
        create_waiting_gui(player)
      end
    end
  end
  if script_data.surface ~= nil then
    game.delete_surface(script_data.surface)
  end
  if admin then
    game.print({"admin-ended-round", admin.name})
  end
  script_data.setup_finished = false
  script_data.check_starting_area_generation = false
  script_data.average_score = nil
  script_data.scores = nil
  script_data.exclusion_map = nil
  script_data.protected_teams = nil
  script_data.check_base_exclusion = nil
  script_data.oil_harvest_scores = nil
  script_data.production_scores = nil
  script_data.space_race_scores = nil
  script_data.last_defcon_tick = nil
  script_data.next_defcon_tech = nil
  script_data.research_time_wasted = nil
  script_data.previous_tech = nil
  script_data.silos = nil
  script_data.wrecks = nil
  script.raise_event(events.on_round_end, {})
end

function prepare_next_round()
  script_data.setup_finished = false
  script_data.team_won = false
  check_game_speed()
  game.speed = 3
  create_next_surface()
  setup_teams()
  chart_starting_area_for_force_spawns()
  set_evolution_factor()
  set_difficulty()
end

local visibility_map = {
  peaceful_mode = function(gui)
    local option = gui.biters_disabled_boolean
    if not option then return end
    return not option.state
  end,
  evolution_factor = function(gui)
    local option = gui.biters_disabled_boolean
    if not option then return end
    return not option.state
  end,
  chunks_to_extend_duplication = function(gui)
    local option = gui.duplicate_starting_area_entities_boolean
    if not option then return end
    return option.state
  end,
  required_production_score = function(gui)
    local option = gui.production_score_boolean
    if not option then return end
    return option.state
  end,
  required_oil = function(gui)
    local option = gui.oil_harvest_boolean
    if not option then return end
    return option.state
  end,
  oil_only_in_center = function(gui)
    local option = gui.oil_harvest_boolean
    if not option then return end
    return option.state
  end,
  time_limit = function(gui)
    local oil = gui.oil_harvest_boolean
    local production_score = gui.production_score_boolean
    if not production_score or not oil then return end
    return oil.state or production_score.state
  end,
  starting_chest_multiplier = function(gui)
    local dropdown = gui.starting_chest_dropdown
    local name = script_data.team_config.starting_chest.options[dropdown.selected_index]
    return name ~= "none"
  end,
  disband_on_loss = function(gui)
    local option = gui.last_silo_standing_boolean
    if not option then return end
    return option.state
  end,
  give_artillery_remote = function(gui)
    local option = gui.team_artillery_boolean
    if not option then return end
    return option.state
  end,
  turret_ammunition = function(gui)
    local option = gui.team_turrets_boolean
    if not option then return end
    return option.state
  end,
  required_satellites_sent = function(gui)
    local option = gui.space_race_boolean
    if not option then return end
    return option.state
  end,
  defcon_random = function(gui)
    local option = gui.defcon_mode_boolean
    if not option then return end
    return option.state
  end,
  defcon_timer = function(gui)
    local defcon_option = gui.defcon_mode_boolean
    local defcon_random = gui.defcon_random_boolean
    if not defcon_option or not defcon_random then return end
    return defcon_option.state and defcon_random.state
  end,
  defcon_random_multiplier = function(gui)
    local defcon_option = gui.defcon_mode_boolean
    local defcon_random = gui.defcon_random_boolean
    if not defcon_option or not defcon_random then return end
    return defcon_option.state and not defcon_random.state
  end,
  who_decides_diplomacy = function(gui)
    local option = gui.diplomacy_enabled_boolean
    if not option then return end
    return option.state
  end,
  space_race = function(gui)
    local item = game.item_prototypes[script_data.prototypes.satellite or ""]
    if item then return true end
    script_data.game_config.space_race = false
    local option = gui.space_race_boolean
    if option then option.state = false end
    return false
  end,
  last_silo_standing = function(gui)
    local item = game.entity_prototypes[script_data.prototypes.silo or ""]
    if item then return true end
    script_data.game_config.last_silo_standing = false
    local option = gui.last_silo_standing_boolean
    if option then option.state = false end
    return false
  end,
  oil_harvest = function(gui)
    local fluid = game.fluid_prototypes[script_data.prototypes.oil or ""]
    local entity = game.entity_prototypes[script_data.prototypes.oil_resource or ""]
    if fluid and entity then return true end
    script_data.game_config.oil_harvest = false
    local option = gui.oil_harvest_boolean
    if option then option.state = false end
    return false
  end
}

function set_mode_input(player)
  if not (player and player.valid and player.gui.center.config_holding_frame) then return end
  local gui = get_config_holder(player)
  for k, frame in pairs ({gui.map_config_gui, gui.game_config_gui, gui.team_config_gui}) do
    if frame and frame.valid then
      local config = frame.config_table
      if (config and config.valid) then
        local children = config.children
        if frame == gui.game_config_gui then
          local silo_option = config.last_silo_standing_boolean
          local score_option = config.production_score_boolean
          local space_option = config.space_race_boolean
          local oil_option = config.oil_harvest_boolean
          if silo_option and score_option and space_option and oil_option then
            local is_freeplay = not (silo_option.state or score_option.state or space_option.state or oil_option.state)
            if is_freeplay then
              config.game_mode_dummy.caption = {"", "(", {"freeplay"}, ")"}
              config.game_mode_dummy.tooltip = {"freeplay_tooltip"}
            else
              config.game_mode_dummy.caption = ""
              config.game_mode_dummy.tooltip = ""
            end
          end
        end          
        for k, child in pairs (children) do
          local name = child.name or ""
          local mapped = visibility_map[name]
          local localized_caption = children[k].caption
          local is_victory_option = {
            ["last_silo_standing"] = true,
            ["production_score"] = true,
            ["space_race"] = true,
            ["oil_harvest"] = true,
            ["last_silo_standing"] = true,
            ["production_score"] = true,
            ["required_production_score"] = true,
            ["space_race"] = true,
            ["required_satellites_sent"] = true,
            ["oil_harvest"] = true,
            ["required_oil_barrels"] = true,
            ["oil_only_in_center"] = true,
            ["time_limit"] = true,
            ["disband_on_loss"] = true
          }
          local indent = ""
          if is_victory_option[name] then
            indent = "    "
          end
          if mapped then
            local bool = mapped(config)
            children[k].visible = bool
            children[k+1].visible = bool
            indent = indent.."    "
          end
          if localized_caption[3] ~= indent and (mapped or is_victory_option[name]) then
            children[k].caption = {"", indent, localized_caption}
          end
        end
      end
    end
  end
end

game_mode_buttons = {
  ["production_score"] = {type = "button", caption = {"production_score"}, name = "production_score_button", style = mod_gui.button_style},
  ["oil_harvest"] = {type = "button", caption = {"oil_harvest"}, name = "oil_harvest_button", style = mod_gui.button_style},
  ["space_race"] = {type = "button", caption = {"space_race"}, name = "space_race_button", style = mod_gui.button_style}
}

function init_player_gui(player)
  destroy_player_gui(player)
  if not script_data.setup_finished then return end
  local button_flow = mod_gui.get_button_flow(player)
  button_flow.add{type = "button", caption = {"objective"}, name = "objective_button", style = mod_gui.button_style}
  button_flow.add{type = "button", caption = {"teams"}, name = "list_teams_button", style = mod_gui.button_style}
  if script_data.team_config.diplomacy_enabled then
    local button = button_flow.add{type = "button", caption = {"diplomacy"}, name = "diplomacy_button", style = mod_gui.button_style}
    button.visible = #script_data.teams > 1 and player.force.name ~= "spectator"
  end
  for name, button in pairs (game_mode_buttons) do
    if script_data.game_config[name] then
      button_flow.add(button)
    end
  end
  if player.admin then
    button_flow.add{type = "button", caption = {"admin"}, name = "admin_button", style = mod_gui.button_style}
  end
  if player.force.name == "spectator" and not script_data.team_won then
    button_flow.add{type = "button", caption = {"join-team"}, name = "spectator_join_team_button", style = mod_gui.button_style}
  end
  if not script_data.match_started then
    create_start_match_gui(player)
  end
end

function get_color(team, lighten)
  local c = script_data.colors[script_data.color_map[team.color]].color
  if lighten then
    return {r = 1 - (1 - c.r) * 0.5, g = 1 - (1 - c.g) * 0.5, b = 1 - (1 - c.b) * 0.5, a = 1}
  end
  return c
end

function add_player_list_gui(force, gui)
  if not (force and force.valid) then return end
  if #force.players == 0 then
    gui.add{type = "label", caption = {"none"}}
    return
  end
  local scroll = gui.add{type = "scroll-pane"}
  scroll.style.maximal_height = 120
  local name_table = scroll.add{type = "table", column_count = 1}
  name_table.style.vertical_spacing = 0
  local added = {}
  local first = true
  if #force.connected_players > 0 then
    local online_names = ""
    for k, player in pairs (force.connected_players) do
      if not first then
        online_names = online_names..", "
      end
      first = false
      online_names = online_names..player.name
      added[player.name] = true
    end
    local online_label = name_table.add{type = "label", caption = {"online", online_names}}
    online_label.style.single_line = false
    online_label.style.maximal_width = 180
  end
  first = true
  if #force.players > #force.connected_players then
    local offline_names = ""
    for k, player in pairs (force.players) do
      if not added[player.name] then
      if not first then
        offline_names = offline_names..", "
      end
      first = false
      offline_names = offline_names..player.name
      added[player.name] = true
      end
    end
    local offline_label = name_table.add{type = "label", caption = {"offline", offline_names}}
    offline_label.style.single_line = false
    offline_label.style.font_color = {r = 0.7, g = 0.7, b = 0.7}
    offline_label.style.maximal_width = 180
  end
end

function update_diplomacy_frame(player)
  local flow = player.gui.center.diplomacy_frame
  if not flow then return end
  gui = flow.diplomacy_inner_frame
  if not gui then return end
  local diplomacy_table = gui.diplomacy_table
  if not diplomacy_table then
    diplomacy_table = gui.add{type = "table", name = "diplomacy_table", column_count = 5}
    diplomacy_table.style.horizontal_spacing = 16
    diplomacy_table.style.vertical_spacing = 8
    diplomacy_table.draw_horizontal_lines = true
    diplomacy_table.draw_vertical_lines = true
  else
    diplomacy_table.clear()
  end
  for k, name in pairs ({"team-name", "stance", "enemy", "neutral", "ally"}) do
    local label = diplomacy_table.add{type = "label", name = name, caption = {name}}
    label.style.font = "default-bold"
  end
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force and force ~= player.force then
      local label = diplomacy_table.add{type = "label", name = team.name.."_name", caption = team.name}
      label.style.single_line = false
      label.style.maximal_width = 150
      label.style.font = "default-semibold"
      label.style.font_color = get_color(team, true)
      local stance = get_stance(player.force, force)
      local their_stance = get_stance(force, player.force)
      local stance_label = diplomacy_table.add{type = "label", name = team.name.."_stance", caption = {their_stance}}
      if their_stance == "ally" then
        stance_label.style.font_color = {r = 0.5, g = 1, b = 0.5}
      elseif their_stance == "enemy" then
        stance_label.style.font_color = {r = 1, g = 0.5, b = 0.5}
      end
      diplomacy_table.add{type = "checkbox", name = team.name.."_enemy", state = (stance == "enemy")}
      diplomacy_table.add{type = "checkbox", name = team.name.."_neutral", state = (stance == "neutral")}
      diplomacy_table.add{type = "checkbox", name = team.name.."_ally", state = (stance == "ally")}
    end
  end
  if not flow.diplomacy_confirm then
    flow.add{type = "button", name = "diplomacy_confirm", caption = {"confirm"}}
  end
end

function place_player_on_battle_surface(player)
  local force = player.force
  local surface = script_data.surface
  if not surface.valid then return end
  local force_spawn = force.get_spawn_position(surface)
  local offset_spawn = {force_spawn.x, force_spawn.y + 15}
  local position = surface.find_non_colliding_position("player", offset_spawn, 320, 1)
  if position then
    player.teleport(position, surface)
  else
    player.print({"cant-find-position"}, player.name)
    player.force = "player"
    player.tag = ""
    choose_joining_gui(player)
    return false
  end
  if player.character then
    player.character.destroy()
  end
  player.set_controller
  {
    type = defines.controllers.character,
    character = surface.create_entity{name = "player", position = position, force = force}
  }
  player.spectator = false
  local artillery_remote = script_data.prototypes.artillery_remote
  if script_data.map_config.team_artillery and script_data.map_config.give_artillery_remote and game.item_prototypes[artillery_remote] then
    player.insert(artillery_remote)
  end
  config.give_equipment(player)

  balance.apply_character_modifiers(player)
  check_force_protection(force)
  init_player_gui(player)
  return true
end

function set_player(player, team)
  local force = game.forces[team.name]
  player.force = force
  player.color = get_color(team)
  player.chat_color = get_color(team, true)
  player.tag = "["..force.name.."]"
  if script_data.match_started then
    if not place_player_on_battle_surface(player) then return end
  end
  for k, other_player in pairs (game.connected_players) do
    update_team_list_frame(player)
  end
  game.print({"joined", player.name, player.force.name})
end

function choose_joining_gui(player)
  if #script_data.teams == 1 then
    local team = script_data.teams[1]
    local force = game.forces[team.name]
    set_player(player, team)
    return
  end
  local setting = script_data.team_config.team_joining.selected
  if setting == "random" then
    create_random_join_gui(player.gui.center)
    return
  end
  if setting == "player_pick" then
    create_pick_join_gui(player.gui.center)
    return
  end
  if setting == "auto_assign" then
    create_auto_assign_gui(player.gui.center)
    return
  end
end

function add_join_spectator_button(gui)
  local player = game.players[gui.player_index]
  if (not script_data.map_config.allow_spectators) and (not player.admin) and (not script_data.team_won) then return end
  set_button_style(gui.add{type = "button", name = "join_spectator", caption = {"join-spectator"}})
end

function create_random_join_gui(gui)
  local name = "random_join_frame"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"random-join"}}
  frame.clear()
  if not script_data.team_won then
    set_button_style(frame.add{type = "button", name = "random_join_button", caption = {"random-join-button"}})
  end
  add_join_spectator_button(frame)
end


function create_auto_assign_gui(gui)
  local name = "auto_assign_frame"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"auto-assign"}}
  frame.clear()
  if not script_data.team_won then
    set_button_style(frame.add{type = "button", name = "auto_assign_button", caption = {"auto-assign-button"}})
  end
  add_join_spectator_button(frame)
end

function create_pick_join_gui(gui)
  local name = "pick_join_frame"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"pick-join"}, direction = "vertical"}
  frame.clear()
  if not script_data.team_won then
    local inner_frame = frame.add{type = "frame", style = "image_frame", name = "pick_join_inner_frame", direction = "vertical"}
    inner_frame.style.left_padding = 8
    inner_frame.style.top_padding = 8
    inner_frame.style.right_padding = 8
    inner_frame.style.bottom_padding = 8
    local pick_join_table = inner_frame.add{type = "table", name = "pick_join_table", column_count = 4}
    pick_join_table.style.horizontal_spacing = 16
    pick_join_table.style.vertical_spacing = 8
    pick_join_table.draw_horizontal_lines = true
    pick_join_table.draw_vertical_lines = true
    pick_join_table.style.column_alignments[3] = "right"
    pick_join_table.add{type = "label", name = "pick_join_table_force_name", caption = {"team-name"}}.style.font = "default-semibold"
    pick_join_table.add{type = "label", name = "pick_join_table_player_count", caption = {"players"}}.style.font = "default-semibold"
    pick_join_table.add{type = "label", name = "pick_join_table_team", caption = {"team-number"}}.style.font = "default-semibold"
    pick_join_table.add{type = "label", name = "pick_join_table_pad"}.style.font = "default-semibold"
    local teams = get_eligible_teams(game.players[gui.player_index])
    if not teams then return end
    for k, team in pairs (teams) do
      local force = game.forces[team.name]
      if force then
        local name = pick_join_table.add{type = "label", name = force.name.."_label", caption = force.name}
        name.style.font = "default-semibold"
        name.style.font_color = get_color(team, true)
        add_player_list_gui(force, pick_join_table)
        local caption
        if tonumber(team.team) then
          caption = team.team
        elseif team.team:find("?") then
          caption = team.team:gsub("?", "")
        else
          caption = team.team
        end
        pick_join_table.add{type = "label", name = force.name.."_team", caption = caption}
        set_button_style(pick_join_table.add{type = "button", name = force.name.."_pick_join", caption = {"join"}})
      end
    end
  end
  add_join_spectator_button(frame)
end

function on_pick_join_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (gui and gui.valid and player and player.valid) then return end
  local name = gui.name
  if not name then return end
  local suffix = "_pick_join"
  if not name:find(suffix) then return end
  team_name = name:gsub(suffix, "")
  local joined_team
  for k, team in pairs (script_data.teams) do
    if team_name == team.name then
      joined_team = team
      break
    end
  end
  if not joined_team then return end
  local force = game.forces[joined_team.name]
  if not force then return end
  set_player(player, joined_team)
  player.gui.center.pick_join_frame.destroy()

  for k, player in pairs (game.forces.player.players) do
    create_pick_join_gui(player.gui.center)
  end

  for k, player in pairs (game.connected_players) do
    update_team_list_frame(player)
  end

end

function create_start_match_gui(player)
  if not player.admin then return end
  local gui = player.gui.center
  local name = "start_match_frame"
  local frame = gui[name] or gui.add{type = "frame", name = name, caption = {"admin"}}
  frame.clear()
  set_button_style(frame.add{type = "button", name = "start_match_button", caption = {"start-match-button"}})
end

function add_team_button_press(event)
  local gui = event.element
  local index = #script_data.teams + 1
  for k = 1, index do
    if not script_data.teams[k] then
      index = k
      break
    end
  end
  if index > 24 then
    local player = game.players[event.player_index]
    if player then
      player.print({"too-many-teams", 24})
    end
    return
  end
  local color = script_data.colors[(1+index%(#script_data.colors))]
  local name = game.backer_names[math.random(#game.backer_names)]
  local team = {name = name, color = color.name, team = "-"}
  script_data.teams[index] = team
  for k, player in pairs (game.players) do
    local gui = get_config_holder(player).team_config_gui
    if gui then
      add_team_to_team_table(gui.team_config_gui_scroll.team_table, index)
    end
  end
end

function trash_team_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if not gui.name:find("_trash_button") then
    return
  end
  local team_index = gui.name:gsub("_trash_button", "")
  team_index = tonumber(team_index)
  local count = 0
  for k, team in pairs (script_data.teams) do
    count = count + 1
  end
  if count > 1 then
    script_data.teams[team_index] = nil
    remove_team_from_team_table(gui)
  else
    game.players[event.player_index].print({"cant-remove-only-team"})
  end
end

function remove_team_from_team_table(gui)
  local index = nil
  for k, child in pairs (gui.parent.children) do
    if child == gui then
      index = k
      break
    end
  end
  local delete_list = {}
  for k, player in pairs (game.players) do
    local gui = get_config_holder(player).team_config_gui
    if gui then
      local children = gui.team_config_gui_scroll.team_table.children
      for k = -3, 0 do
        children[index+k].destroy()
      end
    end
  end
end

function set_teams_from_gui(player)
  local gui = get_config_holder(player).team_config_gui
  if not gui then return end
  local teams = {}
  local team = {}
  local duplicates = {}
  local team_table = gui.team_config_gui_scroll.team_table
  local children = team_table.children
  for index = 1, 25 do
    local element = team_table[index]
    if element and element.valid then
      local text = element.text
      if is_ignored_force(text) then
        player.print({"disallowed-team-name", text})
        return
      end
      if text == "" then
        player.print({"empty-team-name"})
        return
      end
      if duplicates[text] then
        player.print({"duplicate-team-name", text})
        return
      end
      duplicates[text] = true
      local team = {}
      team.name = text
      team.color = script_data.colors[team_table[index.."_color"].selected_index].name
      local caption = team_table[index.."_next_team_button"].caption
      team.team = tonumber(caption) or caption
      table.insert(teams, team)
    end
  end
  if #teams > 24 then
    player.print({"too-many-teams", 24})
    return
  end
  script_data.teams = teams
  return true
end

function on_team_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if not gui.name:find("_next_team_button") then return end
  local left_click = (event.button == defines.mouse_button_type.left)
  local index = gui.caption
  if index == "-" then
    if left_click then
      index = 1
    else
      index = "?"
    end
  elseif index == "?" then
    if left_click then
      index = "-"
    else
      index = #script_data.teams
    end
  elseif index == tostring(#script_data.teams) then
    if left_click then
      index = "?"
    else
      index = index -1
    end
  else
    if left_click then
      index = tonumber(index) + 1
    elseif index == tostring(1) then
      index = "-"
    else
      index = index -1
    end
  end
  gui.caption = index
end

function toggle_balance_options_gui(player)
  if not (player and player.valid) then return end
  local gui = player.gui.center
  local frame = gui.balance_options_frame
  local config = gui.config_holding_frame
  if frame then
    frame.destroy()
    if config then
      config.visible = true
    end
    return
  end
  if config then
    config.visible = false
  end
  frame = gui.add{name = "balance_options_frame", type = "frame", direction = "vertical", caption = {"balance-options"}}
  frame.style.maximal_height = player.display_resolution.height * 0.95
  frame.style.maximal_width = player.display_resolution.width * 0.95
  local scrollpane = frame.add{name = "balance_options_scrollpane", type = "scroll-pane"}
  local big_table = scrollpane.add{type = "table", column_count = 4, name = "balance_options_big_table", direction = "horizontal"}
  big_table.style.horizontal_spacing = 32
  big_table.draw_vertical_lines = true
  local entities = game.entity_prototypes
  local ammos = game.ammo_category_prototypes
  for modifier_name, array in pairs (script_data.modifier_list) do
    local flow = big_table.add{type = "frame", name = modifier_name.."_flow", caption = {modifier_name}, style = "inner_frame"}
    local table = flow.add{name = modifier_name.."table", type = "table", column_count = 2}
    table.style.column_alignments[2] = "right"
    for name, modifier in pairs (array) do
      if modifier_name == "ammo_damage_modifier" then
        local string = "ammo-category-name."..name
        table.add{type = "label", caption = {"", ammos[name].localised_name, {"colon"}}}
      elseif modifier_name == "gun_speed_modifier" then
        table.add{type = "label", caption = {"", ammos[name].localised_name, {"colon"}}}
      elseif modifier_name == "turret_attack_modifier" then
        table.add{type = "label", caption = {"", entities[name].localised_name, {"colon"}}}
      elseif modifier_name == "character_modifiers" then
        table.add{type = "label", caption = {"", {name}, {"colon"}}}
      end
      local input = table.add{name = name.."text", type = "textfield"}
      input.text = tostring((modifier * 100) + 100).."%"
      input.style.maximal_width = 50
    end
  end
  local flow = frame.add{type = "flow", direction = "horizontal"}
  flow.style.horizontally_stretchable = true
  flow.style.horizontal_align = "right"
  flow.add{type = "button", name = "balance_options_cancel", caption = {"cancel"}, style = "back_button"}
  add_pusher(flow)
  flow.add{type = "button", name = "balance_options_confirm", caption = {"balance-confirm"}, style = "confirm_button"}
end

function create_disable_frame(gui)
  local frame = gui.disable_items_frame
  if gui.disable_items_frame then
    gui.disable_items_frame.clear()
  else
    frame = gui.add{name = "disable_items_frame", type = "frame", direction = "vertical", style = "inner_frame"}
  end
  local label = frame.add{type = "label", caption = {"", {"disabled-items"}, {"colon"}}}
  local disable_table = frame.add{type = "table", name = "disable_items_table", column_count = 7}
  disable_table.style.horizontal_spacing = 2
  disable_table.style.vertical_spacing = 2
  local items = game.item_prototypes
  if script_data.disabled_items then
    for item, bool in pairs (script_data.disabled_items) do
      if items[item] then
        local choose = disable_table.add{type = "choose-elem-button", elem_type = "item"}
        choose.elem_value = item
      end
    end
  end
  disable_table.add{type = "choose-elem-button", elem_type = "item"}
end

function set_balance_settings(player)
  local gui = player.gui.center
  local frame = gui.balance_options_frame
  local scroll = frame.balance_options_scrollpane
  local table = scroll.balance_options_big_table
  for modifier_name, array in pairs (script_data.modifier_list) do
    local flow = table[modifier_name.."_flow"]
    local modifier_table = flow[modifier_name.."table"]
    if modifier_table then
      for name, modifier in pairs (array) do
        local text = modifier_table[name.."text"].text
        if text then
          text = string.gsub(text, "%%", "")
          local n = tonumber(text)
          if n == nil then
            player.print({"must-be-number", {modifier_name}})
            return
          end
          if n <= 0 then
            player.print({"must-be-greater-than-0", {modifier_name}})
            return
          end
          script_data.modifier_list[modifier_name][name] = (n - 100) / 100
        end
      end
    end
  end
  balance.script_data = script_data
  return true
end

function config_confirm(player)
  if not parse_config(player) then return end
  destroy_config_for_all()
  prepare_next_round()
end

function parse_config(player)
  if not set_teams_from_gui(player) then return end
  local frame = get_config_holder(player)
  if not config.parse_config_from_gui(frame.map_config_gui, script_data.map_config) then return end
  if not config.parse_config_from_gui(frame.game_config_gui, script_data.game_config) then return end
  if not config.parse_config_from_gui(frame.team_config_gui, script_data.team_config) then return end
  config.script_data = script_data
  return true
end

function auto_assign(player)
  local teams = get_eligible_teams(player)
  if not teams then return end
  local online_count = 10000
  local all_count = 10000
  for k, this_team in pairs (teams) do
    local other_force = game.forces[this_team.name]
    if other_force ~= nil then
      if #other_force.connected_players < online_count or (#other_force.connected_players == online_count and #other_force.players < all_count) then
        online_count = #other_force.connected_players
        all_count = #other_force.players
        force = other_force
        team = this_team
      end
    end
  end
  set_player(player, team)
end

function get_eligible_teams(player)
  local limit = script_data.team_config.max_players
  local teams = {}
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      if limit <= 0 or #force.connected_players < limit or player.admin then
        table.insert(teams, team)
      end
    end
  end
  if #teams == 0 then
    spectator_join(player)
    player.print({"no-space-available"})
    return
  end
  return teams
end

function destroy_config_for_all()
  local names = {"config_holding_frame", "balance_options_frame", "waiting_frame"}
  for k, player in pairs (game.players) do
    local gui = player.gui.center
    for i, name in pairs (names) do
      if gui[name] then
        gui[name].destroy()
      end
    end
  end
end

function set_evolution_factor()
  local n = script_data.map_config.evolution_factor
  if n >= 1 then
    n = 1
  end
  if n <= 0 then
    n = 0
  end
  game.forces.enemy.evolution_factor = n
  script_data.map_config.evolution_factor = n
end

function set_difficulty()
  game.difficulty_settings.technology_price_multiplier = script_data.team_config.technology_price_multiplier
end

function random_join(player)
  local teams = get_eligible_teams(player)
  if not teams then return end
  set_player(player, teams[math.random(#teams)])
end

function spectator_join(player, winning_team)
  if player.character then player.character.destroy() end
  player.set_controller{type = defines.controllers.spectator}
  if winning_team ~= nil then
    local winning_team_name = winning_team[1] or winning_team
    if winning_team_name == "none" then
      player.teleport(script_data.spawn_offset, script_data.surface)
    else
      local winning_spawn_position = game.forces[winning_team_name].get_spawn_position(script_data.surface)
      player.teleport(winning_spawn_position, script_data.surface)
    end
  else
    player.force = "spectator"
    player.teleport(script_data.spawn_offset, script_data.surface)
    player.tag = ""
    player.color = script_data.colors[script_data.color_map["black"]].color
    player.chat_color = script_data.colors[script_data.color_map["red"]].color
    game.print({"joined-spectator", player.name})
  end
  player.spectator = true
  destroy_joining_guis(player.gui.center)
  init_player_gui(player)
end

local victory_conditions =
{
  ["last_silo_standing"] = true,
  ["production_score"] = true,
  ["space_race"] = true,
  ["oil_harvest"] = true
}

function objective_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.objective_frame
  if frame then
    frame.destroy()
    return
  end
  frame = flow.add{type = "frame", name = "objective_frame", caption = {"objective"}, direction = "vertical"}
  frame.visible = true
  local label_table = frame.add{type = "table", column_count = 2}
  local big_label = label_table.add{type = "label", caption = {"", {"game_mode"}, {"colon"}}}
  big_label.style.font = "default-bold"
  big_label.style.top_padding = 0
  local is_freeplay = true
  for objective, k in pairs (victory_conditions) do
    if script_data.game_config[objective] then
      local label = label_table.add{type = "label", caption = {objective}, tooltip = {objective.."_tooltip"}}
      label.style.font = "default-semibold"
      label_table.add{type = "label", name = objective.."_dummy"}
      is_freeplay = false
    end
  end
  if is_freeplay then
    label_table.add{type = "label", caption = {"freeplay"}, tooltip = {"freeplay_tooltip"}}
    label_table.add{type = "label", name = "freeplay_dummy"}
  end
  label_table.add{type = "label", name = "game_mode_dummy"}
  for k, name in pairs ({"friendly_fire", "diplomacy_enabled", "team_joining", "spawn_position"}) do
    label_table.add{type = "label", caption = {"", {name}, {"colon"}}, tooltip = {name.."_tooltip"}}
    local setting = script_data.team_config[name]
    if setting ~= nil then
      if type(setting) == "table" then
        label_table.add{type = "label", caption = {setting.selected}}
      elseif type(setting) == "boolean" then
        label_table.add{type = "label", caption = {setting}}
      else
        label_table.add{type = "label", caption = setting}
      end
    end
  end
  if script_data.disabled_items then
    label_table.add{type = "label", caption = {"", {"disabled-items", {"colon"}}}}
    local flow = label_table.add{type = "table", column_count = 4}
    flow.style.horizontal_spacing = 2
    flow.style.vertical_spacing = 2
    local items = game.item_prototypes
    for item, bool in pairs (script_data.disabled_items) do
      if items[item] then
        flow.add{type = "sprite", sprite = "item/"..item, tooltip = items[item].localised_name}
      end
    end
  end
  label_table.add{type = "label", caption = "Elapsed time:"}
  label_table.add{type = "label", caption = formattime(game.tick - script_data.round_start_tick)}
  label_table.add{type = "label", caption = "Science multiplier:"}
  label_table.add{type = "label", caption = string.format("%.2f", script_data.science_speedup)}
end

function list_teams_button_press(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.team_list
  if frame then
    frame.destroy()
    return
  end
  frame = flow.add{type = "frame", caption = {"teams"}, direction = "vertical", name = "team_list"}
  update_team_list_frame(player)
end

function update_team_list_frame(player)
  if not (player and player.valid) then return end
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.team_list
  if not frame then return end
  frame.clear()
  local inner = frame.add{type = "frame", style = "image_frame"}
  inner.style.left_padding = 8
  inner.style.right_padding = 8
  inner.style.top_padding = 8
  inner.style.bottom_padding = 8
  local scroll = inner.add{type = "scroll-pane"}
  scroll.style.maximal_height = player.display_resolution.height * 0.8
  local team_table = scroll.add{type = "table", column_count = 2}
  team_table.style.vertical_spacing = 8
  team_table.style.horizontal_spacing = 16
  team_table.draw_horizontal_lines = true
  team_table.draw_vertical_lines = true
  team_table.add{type = "label", caption = {"team-name"}, style = "bold_label"}
  team_table.add{type = "label", caption = {"players"}, style = "bold_label"}
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      local label = team_table.add{type = "label", caption = team.name, style = "description_label"}
      label.style.font_color = get_color(team, true)
      add_player_list_gui(force, team_table)
    end
  end
end

function admin_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  if flow.admin_frame then
    flow.admin_frame.visible = not flow.admin_frame.visible
    return
  end
  local frame = flow.add{type = "frame", caption = {"admin"}, name = "admin_frame", direction = "vertical"}
  frame.visible = true
  set_button_style(frame.add{type = "button", caption = {"end-round"}, name = "admin_end_round", tooltip = {"end-round-tooltip"}})
  set_button_style(frame.add{type = "button", caption = {"reroll-round"}, name = "admin_reroll_round", tooltip = {"reroll-round-tooltip"}})
  set_button_style(frame.add{type = "button", caption = {"admin-change-team"}, name = "admin_change_team", tooltip = {"admin-change-team-tooltip"}})
end

function admin_frame_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if not gui.parent then return end
  if not gui.parent.valid then return end
  if gui.parent.name ~= "admin_frame" then return end
  local player = game.players[event.player_index]
  if not player.admin then
    player.print({"only-admins"})
    init_player_gui(player)
    return
  end
  if gui.name == "admin_end_round" then
    end_round(player)
    return
  end
  if gui.name == "admin_reroll_round" then
    end_round()
    destroy_config_for_all()
    prepare_next_round()
    return
  end
  if gui.name == "admin_change_team" then
    local gui = player.gui.center
    if gui.pick_join_frame then
      gui.pick_join_frame.destroy()
    else
      create_pick_join_gui(gui)
    end
    return
  end
end

function diplomacy_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  local flow = player.gui.center
  local frame = flow.diplomacy_frame
  if frame then
    frame.destroy()
    return
  end
  frame = player.gui.center.add{type = "frame", name = "diplomacy_frame", caption = {"diplomacy"}, direction = "vertical"}
  frame.visible = true
  frame.style.title_bottom_padding = 8
  player.opened = frame
  local inner_frame = frame.add{type = "frame", style = "image_frame", name = "diplomacy_inner_frame", direction = "vertical"}
  inner_frame.style.left_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.bottom_padding = 8
  update_diplomacy_frame(player)
end


function formattime(ticks)
  local hours = math.floor(ticks / (60 * 60 * 60))
  ticks = ticks - hours * (60 * 60 * 60)
  local minutes = math.floor(ticks / (60 * 60))
  ticks = ticks - minutes * (60 * 60)
  local seconds = math.floor(ticks / 60)
  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, seconds)
  else
    return string.format("%d:%02d", minutes, seconds)
  end
end

function get_time_left()
  if not script_data.round_start_tick then return "Invalid" end
  if not script_data.game_config.time_limit then return "Invalid" end
  return formattime((math.max(script_data.round_start_tick + (script_data.game_config.time_limit * 60 * 60) - game.tick, 0)))
end

function production_score_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.production_score_frame
  if frame then
    frame.destroy()
    return
  end
  frame = flow.add{type = "frame", name = "production_score_frame", caption = {"production_score"}, direction = "vertical"}
  frame.style.title_bottom_padding = 8
  if script_data.game_config.required_production_score > 0 then
    frame.add{type = "label", caption = {"", {"required_production_score"}, {"colon"}, " ", util.format_number(script_data.game_config.required_production_score)}}
  end
  if script_data.game_config.time_limit > 0 then
    frame.add{type = "label", caption = {"time_left", get_time_left()}, name = "time_left"}
  end
  local inner_frame = frame.add{type = "frame", style = "image_frame", name = "production_score_inner_frame", direction = "vertical"}
  inner_frame.style.left_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.bottom_padding = 8
  local flow = frame.add{type = "flow", direction = "horizontal", name = "recipe_picker_holding_flow"}
  flow.add{type = "label", caption = {"", {"recipe-calculator"}, {"colon"}}}
  flow.add{type = "choose-elem-button", name = "recipe_picker_elem_button", elem_type = "recipe"}
  flow.style.vertical_align = "center"
  update_production_score_frame(player)
end

function update_production_score_frame(player)
  local gui = mod_gui.get_frame_flow(player)
  local frame = gui.production_score_frame
  if not frame then return end
  inner_frame = frame.production_score_inner_frame
  if not inner_frame then return end
  if frame.time_left then
    frame.time_left.caption = {"time_left", get_time_left()}
  end
  inner_frame.clear()
  local information_table = inner_frame.add{type = "table", column_count = 4}
  information_table.draw_horizontal_line_after_headers = true
  information_table.draw_vertical_lines = true
  information_table.style.horizontal_spacing = 16
  information_table.style.vertical_spacing = 8
  information_table.style.column_alignments[3] = "right"
  information_table.style.column_alignments[4] = "right"

  for k, caption in pairs ({"", "team-name", "score", "score_per_minute"}) do
    local label = information_table.add{type = "label", caption = {caption}, tooltip = {caption.."_tooltip"}}
    label.style.font = "default-bold"
  end
  local team_map = {}
  for k, team in pairs (script_data.teams) do
    team_map[team.name] = team
  end
  local average_score = script_data.average_score
  if not average_score then return end
  local rank = 1
  for name, score in spairs (script_data.production_scores, function(t, a, b) return t[b] < t[a] end) do
    if not average_score[name] then
      average_score = nil
      return
    end
    if team_map[name] then
      local position = information_table.add{type = "label", caption = "#"..rank}
      if name == player.force.name then
        position.style.font = "default-semibold"
        position.style.font_color = {r = 1, g = 1}
      end
      local label = information_table.add{type = "label", caption = name}
      label.style.font = "default-semibold"
      label.style.font_color = get_color(team_map[name], true)
      information_table.add{type = "label", caption = util.format_number(score)}
      local delta_score = (score - (average_score[name] / statistics_period)) * (60 / statistics_period) * 2
      local delta_label = information_table.add{type = "label", caption = util.format_number(math.floor(delta_score))}
      if delta_score < 0 then
        delta_label.style.font_color = {r = 1, g = 0.2, b = 0.2}
      end
      rank = rank + 1
    end
  end
end

function oil_harvest_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if gui.name ~= "oil_harvest_button" then return end
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.oil_harvest_frame
  if frame then
    frame.destroy()
    return
  end
  frame = flow.add{type = "frame", name = "oil_harvest_frame", caption = {"oil_harvest"}, direction = "vertical"}
  frame.style.title_bottom_padding = 8
  if script_data.game_config.required_oil > 0 then
    frame.add{type = "label", caption = {"", {"required_oil"}, {"colon"}, " ", util.format_number(script_data.game_config.required_oil)}}
  end
  local inner_frame = frame.add{type = "frame", style = "image_frame", name = "oil_harvest_inner_frame", direction = "vertical"}
  inner_frame.style.left_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.bottom_padding = 8
  update_oil_harvest_frame(player)
end

function update_oil_harvest_frame(player)
  local gui = mod_gui.get_frame_flow(player)
  local frame = gui.oil_harvest_frame
  if not frame then return end
  inner_frame = frame.oil_harvest_inner_frame
  if not inner_frame then return end
  inner_frame.clear()
  local information_table = inner_frame.add{type = "table", column_count = 3}
  information_table.draw_horizontal_line_after_headers = true
  information_table.draw_vertical_lines = true
  information_table.style.horizontal_spacing = 16
  information_table.style.vertical_spacing = 8
  information_table.style.column_alignments[3] = "right"

  for k, caption in pairs ({"", "team-name", "oil_harvest"}) do
    local label = information_table.add{type = "label", caption = {caption}}
    label.style.font = "default-bold"
  end
  local team_map = {}
  for k, team in pairs (script_data.teams) do
    team_map[team.name] = team
  end
  if not script_data.oil_harvest_scores then
    script_data.oil_harvest_scores = {}
  end
  local rank = 1
  for name, score in spairs (script_data.oil_harvest_scores, function(t, a, b) return t[b] < t[a] end) do
    if team_map[name] then
      local position = information_table.add{type = "label", caption = "#"..rank}
      if name == player.force.name then
        position.style.font = "default-semibold"
        position.style.font_color = {r = 1, g = 1}
      end
      local label = information_table.add{type = "label", caption = name}
      label.style.font = "default-semibold"
      label.style.font_color = get_color(team_map[name], true)
      information_table.add{type = "label", caption = util.format_number(math.floor(score))}
      rank = rank + 1
    end
  end
end

function space_race_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if gui.name ~= "space_race_button" then return end
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.space_race_frame
  if frame then
    frame.destroy()
    return
  end
  frame = flow.add{type = "frame", name = "space_race_frame", caption = {"space_race"}, direction = "vertical"}
  frame.style.title_bottom_padding = 8
  if script_data.game_config.required_satellites_sent > 0 then
    frame.add{type = "label", caption = {"", {"required_satellites_sent"}, {"colon"}, " ", util.format_number(script_data.game_config.required_satellites_sent)}}
  end
  local inner_frame = frame.add{type = "frame", style = "image_frame", name = "space_race_inner_frame", direction = "vertical"}
  inner_frame.style.left_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.bottom_padding = 8
  update_space_race_frame(player)
end

function update_space_race_frame(player)
  local gui = mod_gui.get_frame_flow(player)
  local frame = gui.space_race_frame
  if not frame then return end
  inner_frame = frame.space_race_inner_frame
  if not inner_frame then return end
  inner_frame.clear()
  local information_table = inner_frame.add{type = "table", column_count = 4}
  information_table.draw_horizontal_line_after_headers = true
  information_table.draw_vertical_lines = true
  information_table.style.horizontal_spacing = 16
  information_table.style.vertical_spacing = 8
  information_table.style.column_alignments[4] = "right"

  for k, caption in pairs ({"", "team-name", "rocket_parts", "satellites_sent"}) do
    local label = information_table.add{type = "label", caption = {caption}}
    label.style.font = "default-bold"
  end
  local colors = {}
  for k, team in pairs (script_data.teams) do
    colors[team.name] = get_color(team, true)
  end
  local rank = 1

  for name, score in spairs (script_data.space_race_scores, function(t, a, b) return t[b] < t[a] end) do
    local position = information_table.add{type = "label", caption = "#"..rank}
    if name == player.force.name then
      position.style.font = "default-semibold"
      position.style.font_color = {r = 1, g = 1}
    end
    local label = information_table.add{type = "label", caption = name}
    label.style.font = "default-semibold"
    label.style.font_color = colors[name]
    local progress = information_table.add{type = "progressbar", value = 1}
    progress.style.width = 0
    progress.style.horizontally_squashable = true
    progress.style.horizontally_stretchable = true
    progress.style.color = colors[name]
    local silo = script_data.silos[name]
    if silo and silo.valid then
      if silo.get_inventory(defines.inventory.rocket_silo_rocket) then
        progress.value = 1
      else
        progress.value = silo.rocket_parts / silo.prototype.rocket_parts_required
      end
    else
      progress.visible = false
    end
    information_table.add{type = "label", caption = util.format_number(score)}
    rank = rank + 1
  end
end

function diplomacy_confirm(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end
  if script_data.team_config.who_decides_diplomacy.selected == "team_leader" then
    local team_leader =  player.force.connected_players[1]
    if player.name ~= team_leader.name then
      player.print({"not-team-leader", team_leader.name})
      return
    end
  end
  local diplomacy_table = gui.parent.diplomacy_inner_frame.diplomacy_table
  local some_change = false
  local force = player.force
  local changed_forces = {}
  for k, child in pairs (diplomacy_table.children) do
    if child.type == "checkbox" then
      if child.state then
        if child.name:find("_ally") then
          if child.state then
            local name = child.name:gsub("_ally", "")
            local other_force = game.forces[name]
            if get_stance(force, other_force) ~= "ally" then
              team_changed_diplomacy(force, other_force, "ally")
              table.insert(changed_forces, other_force)
              some_change = true
            end
          end
        elseif child.name:find("_neutral") then
          if child.state then
            local name = child.name:gsub("_neutral", "")
            local other_force = game.forces[name]
            if get_stance(force, other_force) ~= "neutral" then
              team_changed_diplomacy(force, other_force, "neutral")
              table.insert(changed_forces, other_force)
              some_change = true
            end
          end
        elseif child.name:find("_enemy") then
          if child.state then
            local name = child.name:gsub("_enemy", "")
            local other_force = game.forces[name]
            if get_stance(force, other_force) ~= "enemy" then
              team_changed_diplomacy(force, other_force, "enemy")
              table.insert(changed_forces, other_force)
              some_change = true
            end
          end
        end
      end
    end
  end
  if some_change then
    force.print({"player-changed-diplomacy", player.name})
    force.rechart()
    for k, changed_force in pairs (changed_forces) do
      for k, player in pairs (changed_force.players) do
        update_diplomacy_frame(player)
      end
      changed_force.rechart()
    end
    for k, player in pairs (force.players) do
      update_diplomacy_frame(player)
    end
  end
  if player.opened_gui_type == defines.gui_type.custom then
    local opened = player.opened
    if opened and opened.valid then
      opened.destroy()
    end
  end
end

function team_changed_diplomacy(force, other_force, stance)
  if not (force and force.valid and other_force and other_force.valid) then return end
  if stance == "ally" then
    force.set_friend(other_force, true)
    force.set_cease_fire(other_force, true)
  elseif stance == "neutral" then
    force.set_friend(other_force, false)
    force.set_cease_fire(other_force, true)
  elseif stance == "enemy" then
    force.set_friend(other_force, false)
    force.set_cease_fire(other_force, false)
  end
  game.print({"team-changed-diplomacy", force.name, other_force.name, {stance}})
end

function diplomacy_check_press(event)
  local gui = event.element
  if not gui.valid then return end
  if not
    (gui.name:find("_enemy") or
    gui.name:find("_neutral") or
    gui.name:find("_ally"))
  then
    return
  end
  if not gui.state then
    gui.state = true
    return
  end
  local index = 1
  for k, child in pairs (gui.parent.children) do
    if child.name == gui.name then
      index = k
      break
    end
  end
  if gui.name:find("_neutral") then
    gui.parent.children[index+1].state = false
    gui.parent.children[index-1].state = false
  elseif gui.name:find("_ally") then
    gui.parent.children[index-2].state = false
    gui.parent.children[index-1].state = false
  else
    gui.parent.children[index+1].state = false
    gui.parent.children[index+2].state = false
  end
end

function get_stance(force, other_force)
  if force.get_friend(other_force) == true then
    return "ally"
  elseif force.get_cease_fire(other_force) == true then
    return "neutral"
  else
    return "enemy"
  end
end

function give_inventory(player)
  if not script_data.inventory_list then return end
  if not script_data.inventory_list[script_data.team_config.starting_inventory.selected] then return end
  local list = script_data.inventory_list[script_data.team_config.starting_inventory.selected]
  util.insert_safe(player, list)
end

function setup_teams()

  local spectator = game.forces["spectator"]
  if not (spectator and spectator.valid) then
    spectator = game.create_force("spectator")
  end
  local names = {}
  for k, team in pairs (script_data.teams) do
    names[team.name] = true
  end

  for name, force in pairs (game.forces) do
    if not (is_ignored_force(name) or names[name]) then
      game.merge_forces(name, "player")
    end
  end

  for k, team in pairs (script_data.teams) do
    local new_team
    if game.forces[team.name] then
      new_team = game.forces[team.name]
    else
      new_team = game.create_force(team.name)
    end
    new_team.reset()
    set_spawn_position(k, new_team, script_data.surface)
    set_random_team(team)
  end
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    force.set_friend(spectator, true)
    spectator.set_friend(force, true)
    set_diplomacy(team)
    setup_research(force)
    balance.disable_combat_technologies(force)
    force.reset_technology_effects()
    balance.apply_combat_modifiers(force)
    local starting_equipment = script_data.team_config.starting_equipment.selected
    if script_data.game_config.fast_blueprinting_time > 0 then
      force.worker_robots_speed_modifier = -1
    end
  end
  disable_items_for_all()
end

function disable_items_for_all()
  if not script_data.disabled_items then return end
  local items = game.item_prototypes
  local recipes = game.recipe_prototypes
  local product_map = {}
  for k, recipe in pairs (recipes) do
    for k, product in pairs (recipe.products) do
      if not product_map[product.name] then
        product_map[product.name] = {}
      end
      table.insert(product_map[product.name], recipe)
    end
  end

  local recipes_to_disable = {}
  for name, k in pairs (script_data.disabled_items) do
    local mapping = product_map[name]
    if mapping then
      for k, recipe in pairs (mapping) do
        recipes_to_disable[recipe.name] = true
      end
    end
  end
  for k, force in pairs (game.forces) do
    for name, bool in pairs (recipes_to_disable) do
      force.recipes[name].enabled = false
    end
  end
end

function check_technology_for_disabled_items(event)
  if not script_data.disabled_items then return end
  local disabled_items = script_data.disabled_items
  local technology = event.research
  local recipes = technology.force.recipes
  for k, effect in pairs (technology.effects) do
    if effect.type == "unlock-recipe" then
      for k, product in pairs (recipes[effect.recipe].products) do
        if disabled_items[product.name] then
          recipes[effect.recipe].enabled = false
        end
      end
    end
  end
end

function set_random_team(team)
  if tonumber(team.team) then return end
  if team.team == "-" then return end
  team.team = "?"..math.random(#script_data.teams)
end

function set_diplomacy(team)
  local force = game.forces[team.name]
  if not force or not force.valid then return end
  local team_number
  if tonumber(team.team) then
    team_number = team.team
  elseif team.team:find("?") then
    team_number = team.team:gsub("?", "")
    team_number = tonumber(team_number)
  else
    team_number = "Don't match me"
  end
  for k, other_team in pairs (script_data.teams) do
    if game.forces[other_team.name] then
      local other_number
      if tonumber(other_team.team) then
        other_number = other_team.team
      elseif other_team.team:find("?") then
        other_number = other_team.team:gsub("?", "")
        other_number = tonumber(other_number)
      else
        other_number = "Okay i won't match"
      end
      if other_number == team_number then
        force.set_cease_fire(other_team.name, true)
        force.set_friend(other_team.name, true)
      else
        force.set_cease_fire(other_team.name, false)
        force.set_friend(other_team.name, false)
      end
    end
  end
end

function set_spawn_position(k, force, surface)
  local setting = script_data.team_config.spawn_position.selected
  if setting == "fixed" then
    local position = script_data.spawn_positions[k]
    force.set_spawn_position(position, surface)
    return
  end
  if setting == "random" then
    local position
    local index
    repeat
      index = math.random(1, #script_data.spawn_positions)
      position = script_data.spawn_positions[index]
    until position ~= nil
    force.set_spawn_position(position, surface)
    table.remove(script_data.spawn_positions, index)
    return
  end
  if setting == "team_together" then
    if k == #script_data.spawn_positions then
      set_team_together_spawns(surface)
    end
  end
end

function set_team_together_spawns(surface)
  local grouping = {}
  for k, team in pairs (script_data.teams) do
    local team_number
    if tonumber(team.team) then
      team_number = team.team
    elseif team.team:find("?") then
      team_number = team.team:gsub("?", "")
      team_number = tonumber(team_number)
    else
      team_number = "-"
    end
    if tonumber(team_number) then
      if not grouping[team_number] then
        grouping[team_number] = {}
      end
      table.insert(grouping[team_number], team.name)
    else
      if not grouping.no_group then
        grouping.no_group = {}
      end
      table.insert(grouping.no_group, team.name)
    end
  end
  local count = 1
  for k, group in pairs (grouping) do
    for j, team_name in pairs (group) do
      local force = game.forces[team_name]
      if force then
        local position = script_data.spawn_positions[count]
        if position then
          force.set_spawn_position(position, surface)
          count = count + 1
        end
      end
    end
  end
end

function chart_starting_area_for_force_spawns()
  local surface = script_data.surface
  local radius = config.get_starting_area_radius() + script_data.map_config.chunks_to_extend_duplication
  local size = radius*32
  for k, team in pairs (script_data.teams) do
    local name = team.name
    local force = game.forces[name]
    if force ~= nil then
      local origin = force.get_spawn_position(surface)
      local area = {{origin.x - size, origin.y - size},{origin.x + (size - 32), origin.y + (size - 32)}}
      surface.request_to_generate_chunks(origin, radius)
      force.chart(surface, area)
    end
  end
  script_data.check_starting_area_generation = true
end

function check_starting_area_chunks_are_generated()
  if not script_data.check_starting_area_generation then return end
  if game.tick % (#script_data.teams) ~= 0 then return end
  local surface = script_data.surface
  local width = surface.map_gen_settings.width / 2
  local height = surface.map_gen_settings.height / 2
  local size = script_data.map_config.starting_area_size.selected
  local check_radius = config.get_starting_area_radius() + script_data.map_config.chunks_to_extend_duplication
  local total = 0
  local generated = 0
  local abs = math.abs
  for k, team in pairs (script_data.teams) do
    local name = team.name
    local force = game.forces[name]
    if force ~= nil then
      local origin = force.get_spawn_position(surface)
      local origin_X = math.ceil(origin.x/32)
      local origin_Y = math.ceil(origin.y/32)
      for X = -check_radius, check_radius -1 do
        for Y = -check_radius, check_radius -1 do
          total = total + 1
          local chunk_position = {x = X + origin_X,y = Y + origin_Y}
          if (surface.is_chunk_generated(chunk_position)) then
            generated = generated + 1
          elseif (abs(chunk_position.x * 32) > width) or (abs(chunk_position.y * 32) > height) then
            --The chunk is outside the map
            generated = generated + 1
          end
        end
      end
    end
  end
  script_data.progress = generated/total
  if total == generated then
    script_data.check_starting_area_generation = false
    script_data.finish_setup = game.tick + (#script_data.teams)
    update_progress_bar()
    return
  end
  update_progress_bar()
end

function check_player_color()
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      local color = get_color(team)
      for k, player in pairs (force.connected_players) do
        local player_color = player.color
        for c, v in pairs (color) do
          if math.abs(player_color[c] - v) > 0.1 then
            game.print({"player-color-changed-back", player.name})
            player.color = color
            player.chat_color = get_color(team, true)
            break
          end
        end
      end
    end
  end
end

local is_fast_blueprinting_item =
{
  ["construction-robot"] = true,
  ["modular-armor"] = true,
  ["personal-roboport-equipment"] = true
}

function clear_inventory_of_fast_blueprinting_items(inventory)
  if inventory then
    for i = 1, #inventory do
      local inventory_slot = inventory[i]
      if inventory_slot.valid_for_read then
        if is_fast_blueprinting_item[inventory_slot.name] then
          inventory_slot.clear()
        end
      end
    end
  end
end

function check_fast_blueprinting()
  if not script_data.end_fast_blueprinting then return end
  if game.tick > script_data.end_fast_blueprinting then
    if script_data.game_config.fast_blueprinting_time > 0 then
      game.print({"fast-blueprinting-ends"})
    end
    script_data.end_fast_blueprinting = nil
    local starting_equipment = script_data.team_config.starting_equipment.selected
    for force_name, force in pairs (game.forces) do
      if not is_ignored_force(force_name) then
        force.worker_robots_speed_modifier = 0
      end
    end
    if starting_equipment == "medium" then
      for k, player in pairs (game.players) do
        for j, inventory_type in pairs ({"player_main", "player_armor"}) do
          local inventory = player.get_inventory(defines.inventory[inventory_type])
          clear_inventory_of_fast_blueprinting_items(inventory)
        end
        local cursor = player.cursor_stack
        if cursor and cursor.valid_for_read and is_fast_blueprinting_item[cursor.name] then
          cursor.clear()
        end
      end
      for k, item in pairs (script_data.surface.find_entities_filtered{name="item-on-ground"}) do
        if is_fast_blueprinting_item[item.stack.name] then
          item.destroy()
        end
      end
      -- for flying bots:
      for k, item in pairs (script_data.surface.find_entities_filtered{name="construction-robot"}) do
        item.destroy()
      end
      for k, container_type in pairs ({"container", "logistic-container", "character-corpse", "item-with-entity-data", "roboport", "assembling-machine"}) do
        for j, container in pairs(script_data.surface.find_entities_filtered{type=container_type}) do
          local inventory = container.get_output_inventory() or container.get_inventory(defines.inventory.character_corpse)
          clear_inventory_of_fast_blueprinting_items(inventory)
        end
      end
    end
  else
    for k, player in pairs (game.connected_players) do
      if not is_ignored_force(player.force.name) and player.character then
        local pos = player.position
        for k, bot in pairs (script_data.surface.find_entities_filtered{name="construction-robot", area={{pos.x-4, pos.y-4}, {pos.x+4, pos.y+4}}}) do
          bot.energy = 1500000
        end
        local armor_slot = player.get_inventory(defines.inventory.player_armor)
        if armor_slot and not armor_slot.is_empty() then
          local armor = armor_slot[1]
          if armor and armor.valid and armor.grid then
            for k, equipment in pairs(armor.grid.equipment) do
              if equipment.type == "roboport-equipment" then
                equipment.energy = 35000000
              end
            end
          end
        end
      end
    end
  end
end

function check_no_rush()
  if not script_data.end_no_rush then return end
  if game.tick > script_data.end_no_rush then
    if script_data.game_config.no_rush_time > 0 then
      game.print({"no-rush-ends"})
    end
    script_data.end_no_rush = nil
    script_data.surface.peaceful_mode = script_data.map_config.peaceful_mode
    game.forces.enemy.kill_all_units()
    return
  end
end

function check_player_no_rush(player)
  if not script_data.end_no_rush then return end
  local force = player.force
  if not is_ignored_force(force.name) then
    local origin = force.get_spawn_position(player.surface)
    local Xo = origin.x
    local Yo = origin.y
    local position = player.position
    local radius = config.get_starting_area_radius(true)
    local Xp = position.x
    local Yp = position.y
    if Xp > (Xo + radius) then
      Xp = Xo + radius
    elseif Xp < (Xo - radius) then
      Xp = Xo - radius
    end
    if Yp > (Yo + radius) then
      Yp = Yo + radius
    elseif Yp < (Yo - radius) then
      Yp = Yo - radius
    end
    if position.x ~= Xp or position.y ~= Yp then
      local new_position = {x = Xp, y = Yp}
      local vehicle = player.vehicle
      if vehicle then
        if not vehicle.teleport(new_position) then
          player.driving = false
        end
        vehicle.orientation = vehicle.orientation + 0.5
      else
        player.teleport(new_position)
      end
      local time_left = math.ceil((script_data.end_no_rush-game.tick) / 3600)
      player.print({"no-rush-teleport", time_left})
    end
  end
end

function check_update_production_score()
  if not script_data.game_config.production_score then return end
  local tick = game.tick
  if script_data.team_won then return end
  local new_scores = production_score.get_production_scores(script_data.price_list)
  local scale = statistics_period / 60
  local index = tick % (60 * statistics_period)

  if not (script_data.scores and script_data.average_score) then
    local average_score = {}
    local scores = {}
    for name, score in pairs (new_scores) do
      scores[name] = {}
      average_score[name] = score * statistics_period
      for k = 0, statistics_period do
        scores[name][k * 60] = score
      end
    end
    script_data.scores = scores
    script_data.average_score = average_score
  end

  local scores = script_data.scores
  local average_score = script_data.average_score
  for name, score in pairs (new_scores) do
    local old_amount = scores[name][index]
    if not old_amount then
      --Something went wrong, reinitialize it next update
      script_data.scores = nil
      script_data.average_score = nil
      return
    end
    average_score[name] = (average_score[name] + score) - old_amount
    scores[name][index] = score
  end

  script_data.production_scores = new_scores

  for k, player in pairs (game.connected_players) do
    update_production_score_frame(player)
  end
  local required = script_data.game_config.required_production_score
  if required > 0 then
    for team_name, score in pairs (script_data.production_scores) do
      if score >= required then
        team_won(team_name)
      end
    end
  end
  if script_data.game_config.time_limit > 0 and tick > script_data.round_start_tick + (script_data.game_config.time_limit * 60 * 60) then
    local winner = {"none"}
    local winning_score = 0
    for team_name, score in pairs (script_data.production_scores) do
      if score > winning_score then
        winner = team_name
        winning_score = score
      end
    end
    team_won(winner)
  end
end

function check_update_oil_harvest_score()
  if script_data.team_won then return end
  if not script_data.game_config.oil_harvest then return end
  local fluid_to_check = script_data.prototypes.oil or ""
  if not game.fluid_prototypes[fluid_to_check] then
    log("Disabling oil harvest check as "..fluid_to_check.." is not a valid fluid")
    script_data.game_config.oil_harvest = false
    return
  end
  local scores = {}
  for force_name, force in pairs (game.forces) do
    local statistics = force.fluid_production_statistics
    local input = statistics.get_input_count(fluid_to_check)
    local output = statistics.get_output_count(fluid_to_check)
    scores[force_name] = input - output
  end
  script_data.oil_harvest_scores = scores
  for k, player in pairs (game.connected_players) do
    update_oil_harvest_frame(player)
  end
  local required = script_data.game_config.required_oil
  if required > 0 then
    for team_name, score in pairs (script_data.oil_harvest_scores) do
      if score >= required then
        team_won(team_name)
      end
    end
  end
  if script_data.game_config.time_limit > 0 and game.tick > (script_data.round_start_tick + (script_data.game_config.time_limit * 60 * 60)) then
    local winner = {"none"}
    local winning_score = 0
    for team_name, score in pairs (script_data.oil_harvest_scores) do
      if score > winning_score then
        winner = team_name
        winning_score = score
      end
    end
    team_won(winner)
  end
end

function check_update_space_race_score()
  if script_data.team_won then return end
  if not script_data.game_config.space_race then return end
  local item_to_check = script_data.prototypes.satellite or ""
  if not game.item_prototypes[item_to_check] then
    log("Disabling space race as "..item_to_check.." is not a valiud item")
    script_data.game_config.space_race = false
    return
  end
  local scores = {}
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      scores[team.name] = force.get_item_launched(item_to_check)
    end
  end
  script_data.space_race_scores = scores
  for k, player in pairs (game.connected_players) do
    update_space_race_frame(player)
  end
  local required = script_data.game_config.required_satellites_sent
  if required > 0 then
    for team_name, score in pairs (script_data.space_race_scores) do
      if score >= required then
        team_won(team_name)
      end
    end
  end
end

function finish_setup()
  if not script_data.finish_setup then return end
  local index = script_data.finish_setup - game.tick
  local surface = script_data.surface
  if index == 0 then
    final_setup_step()
    script_data.match_started = false
    for k, player in pairs (game.players) do
      create_start_match_gui(player)
    end
    return
  end
  local name = script_data.teams[index].name
  if not name then return end
  local force = game.forces[name]
  if not force then return end
  if script_data.map_config.reveal_team_positions then
    for name, other_force in pairs (game.forces) do
      if not is_ignored_force(name) then
        force.chart(surface, get_force_area(other_force))
      end
    end
  end
  force.friendly_fire = script_data.team_config.friendly_fire
  force.share_chart = script_data.team_config.share_chart
end

function final_setup_step()
  local surface = script_data.surface
  duplicate_starting_area_entities()
  script_data.finish_setup = nil
  if script_data.game_config.team_prep_time > 0 then
    game.print({"map-ready-auto", script_data.game_config.team_prep_time})
  else
    game.print({"map-ready"})
  end

  script_data.map_prepared_tick = game.tick
  script_data.setup_finished = true
  for k, player in pairs (game.connected_players) do
    destroy_player_gui(player)
    player.teleport({0, 1000}, "Lobby")
    choose_joining_gui(player)
  end
  script_data.surface.peaceful_mode = true
  game.forces.enemy.kill_all_units()
  if script_data.map_config.reveal_map_center then
    local radius = script_data.map_config.average_team_displacement/2
    local origin = script_data.spawn_offset
    local area = {{origin.x - radius, origin.y - radius}, {origin.x + (radius - 32), origin.y + (radius - 32)}}
    for k, force in pairs (game.forces) do
      force.chart(surface, area)
    end
  end
  script_data.space_race_scores = {}
  script_data.science_speedup = 1
  script_data.elapsed_seconds = 0
  script_data.oil_harvest_scores = {}
  script_data.production_scores = {}
  if script_data.game_config.production_score then
    script_data.price_list = script_data.price_list or production_score.generate_price_list()
  end
  script_data.research_time_wasted = {}
  script_data.previous_tech = {}
end

function start_match()
  script_data.match_started = true
  script_data.round_start_tick = game.tick
  game.print({"match-started"})
  script_data.end_no_rush = game.tick + (script_data.game_config.no_rush_time * 60 * 60)
  if script_data.game_config.no_rush_time > 0 then
    game.forces.enemy.kill_all_units()
    game.print({"no-rush-begins", script_data.game_config.no_rush_time})
  else
    script_data.surface.peaceful_mode = script_data.map_config.peaceful_mode
  end
  local fast_bp_time = script_data.game_config.fast_blueprinting_time
  script_data.end_fast_blueprinting = game.tick + (fast_bp_time * 60 * 60)
  if fast_bp_time > 0 then
    game.print({"fast-blueprinting-begins", fast_bp_time})
  end
  create_exclusion_map()
  if script_data.game_config.base_exclusion_time > 0 then
    script_data.check_base_exclusion = true
    game.print({"base-exclusion-begins", script_data.game_config.base_exclusion_time})
  end
  if script_data.team_config.defcon_mode then
    if script_data.team_config.defcon_random then
      defcon_research()
    else
      game.print({"defcon-non-random-begins"})
      if script_data.game_config.nuclear_research_buff then
        game.print({"nuclear-research-buff-alert"})
      end
      if script_data.game_config.tanks_research_nerf then
        game.print({"tanks-research-nerf-alert"})
      end
    end
  end
  for k, player in pairs (game.players) do
    local start_match_frame = player.gui.center.start_match_frame
    if start_match_frame then start_match_frame.destroy() end
    if player.force.name ~= "player" and player.force.name ~= "spectator" then
      place_player_on_battle_surface(player)
    end
  end

  script.raise_event(events.on_round_start, {})
end

function check_force_protection(force)
  if not script_data.map_config.protect_empty_teams then return end
  if not (force and force.valid) then return end
  if is_ignored_force(force.name) then return end
  if not script_data.protected_teams then script_data.protected_teams = {} end
  local protected = script_data.protected_teams[force.name] ~= nil
  local should_protect = #force.connected_players == 0
  if protected and should_protect then return end
  if (not protected) and (not should_protect) then return end
  if protected and (not should_protect) then
    unprotect_force_area(force)
    return
  end
  if (not protected) and should_protect then
    protect_force_area(force)
    check_base_exclusion()
    return
  end
end

function protect_force_area(force)
  if not script_data.map_config.protect_empty_teams then return end
  local surface = script_data.surface
  if not (surface and surface.valid) then return end
  local non_destructible = {}
  for k, entity in pairs (surface.find_entities_filtered{force = force, area = get_force_area(force)}) do
    if entity.destructible == false and entity.unit_number then
      non_destructible[entity.unit_number] = true
    end
    entity.destructible = false
  end
  if not script_data.protected_teams then
    script_data.protected_teams = {}
  end
  script_data.protected_teams[force.name] = non_destructible
end

function unprotect_force_area(force)
  if not script_data.map_config.protect_empty_teams then return end
  local surface = script_data.surface
  if not (surface and surface.valid) then return end
  if not script_data.protected_teams then
    script_data.protected_teams = {}
  end
  local entities = script_data.protected_teams[force.name] or {}
  for k, entity in pairs (surface.find_entities_filtered{force = force, area = get_force_area(force)}) do
    if (not entity.unit_number) or (not entities[entity.unit_number]) then
      entity.destructible = true
    end
  end
  script_data.protected_teams[force.name] = nil
end

function get_force_area(force)
  if not (force and force.valid) then return end
  local surface = script_data.surface
  if not (surface and surface.valid) then return end
  local radius = config.get_starting_area_radius(true)
  local origin = force.get_spawn_position(surface)
  return {{origin.x - radius, origin.y - radius}, {origin.x + (radius - 1), origin.y + (radius - 1)}}
end

function update_progress_bar()
  if not script_data.progress then return end
  local percent = script_data.progress
  local finished = (percent >=1)
  function update_bar_gui(gui)
    if gui.progress_bar then
      if finished then
        gui.progress_bar.destroy()
      else
        gui.progress_bar.bar.value = percent
      end
      return
    end
    if finished then return end
    local frame = gui.add{type = "frame", name = "progress_bar", caption = {"progress-bar"}}
    local bar = frame.add{type = "progressbar", size = 100, value = percent, name = "bar"}
  end
  for k, player in pairs (game.players) do
    update_bar_gui(player.gui.center)
  end
  if finished then
    script_data.progress = nil
    script_data.setup_duration = nil
    script_data.finish_tick = nil
  end
end

function create_silo_for_force(force)
  if not script_data.game_config.last_silo_standing then return end
  if not force then return end
  if not force.valid then return end
  local surface = script_data.surface
  local origin = force.get_spawn_position(surface)
  local offset = script_data.silo_offset
  local silo_position = {x = origin.x + (offset.x or offset[1]), y = origin.y + (offset.y or offset[2])}
  local silo_name = script_data.prototypes.silo
  if not game.entity_prototypes[silo_name] then log("Silo not created as "..silo_name.." is not a valid entity prototype") return end
  local silo = surface.create_entity{name = silo_name, position = silo_position, force = force, raise_built = true}

  --Event is sent, so some mod could kill the silo
  if not (silo and silo.valid) then return end

  silo.minable = false
  if silo.supports_backer_name() then
    silo.backer_name = tostring(force.name)
  end
  if not script_data.silos then script_data.silos = {} end
  script_data.silos[force.name] = silo

  local tile_name = script_data.prototypes.tile_2
  if not game.tile_prototypes[tile_name] then tile_name = get_walkable_tile() end

  local tiles_2 = {}
  local box = silo.bounding_box
  local x1, x2, y1, y2 =
    math.floor(box.left_top.x) - 1,
    math.floor(box.right_bottom.x) + 1,
    math.floor(box.left_top.y) - 1,
    math.floor(box.right_bottom.y) + 1
  for X = x1, x2 do
    for Y = y1, y2 do
      table.insert(tiles_2, {name = tile_name, position = {X, Y}})
    end
  end

  for i, entity in pairs(surface.find_entities_filtered({area = {{x1 - 1, y1 - 1},{x2 + 1, y2 + 1}}, force = "neutral"})) do
    entity.destroy()
  end

  set_tiles_safe(surface, tiles_2)
end

function setup_research(force)
  if not force then return end
  if not force.valid then return end
  local tier = script_data.team_config.research_level.selected
  local index
  local set = (tier ~= "none")
  for k, name in pairs (script_data.team_config.research_level.options) do
    if script_data.research_ingredient_list[name] ~= nil then
      script_data.research_ingredient_list[name] = set
    end
    if name == tier then set = false end
  end
  --[[Unlocks all research, and then unenables them based on a blacklist]]
  force.research_all_technologies()
  for k, technology in pairs (force.technologies) do
    for j, ingredient in pairs (technology.research_unit_ingredients) do
      if not script_data.research_ingredient_list[ingredient.name] then
        technology.researched = false
        break
      end
    end
  end
end

function create_starting_turrets(force)
  if not script_data.map_config.team_turrets then return end
  if not (force and force.valid) then return end
  local ammo_name = script_data.map_config.turret_ammunition.selected or "firearm-magazine"
  local turret_name
  if ammo_name == "laser-turret" then
    turret_name = "laser-turret"
  else
    turret_name = script_data.prototypes.turret
  end
  if not game.entity_prototypes[turret_name] then return end
  if not game.item_prototypes[ammo_name] then return end
  local surface = script_data.surface
  local height = surface.map_gen_settings.height / 2
  local width = surface.map_gen_settings.width / 2
  local origin = force.get_spawn_position(surface)
  local radius = config.get_starting_area_radius(true) - 18 --[[radius in tiles]]
  local limit = math.min(width - math.abs(origin.x), height - math.abs(origin.y)) - 6
  radius = math.min(radius, limit)
  local turret_positions = {}
  local pole_positions = {}
  local Xo = origin.x
  local Yo = origin.y
  for X = -radius, radius do
    local Xt = X + Xo
    if X == -radius then
      for Y = -radius, radius do
        local Yt = Y + Yo
        if  Yt % 8 == 0 then
          if turret_name == "laser-turret" then
            table.insert(pole_positions, {x = Xo - radius + 3, y = Yt})
            table.insert(pole_positions, {x = Xo + radius - 4, y = Yt})
          end
          if (Yt + 16) % 32 ~= 0 then
            table.insert(turret_positions, {x = Xo - radius, y = Yt, direction = defines.direction.west})
            table.insert(turret_positions, {x = Xo + radius, y = Yt, direction = defines.direction.east})
          end
        end
      end
    elseif Xt % 8 == 0 then
      if turret_name == "laser-turret" then
        table.insert(pole_positions, {x = Xt, y = Yo - radius + 3})
        table.insert(pole_positions, {x = Xt, y = Yo + radius - 4})
      end
      if (Xt + 16) % 32 ~= 0 then
        table.insert(turret_positions, {x = Xt, y = Yo - radius, direction = defines.direction.north})
        table.insert(turret_positions, {x = Xt, y = Yo + radius, direction = defines.direction.south})
      end
    end
  end
  local tiles = {}
  local tile_name = script_data.prototypes.tile_2
  if not game.tile_prototypes[tile_name] then tile_name = get_walkable_tile() end
  local stack = {name = ammo_name, count = 20}
  local floor = math.floor
  for k, position in pairs (turret_positions) do
    local turret = surface.create_entity{name = turret_name, position = position, force = force, direction = position.direction}
    local box = turret.bounding_box
    for k, entity in pairs (surface.find_entities_filtered{area = turret.bounding_box, force = "neutral"}) do
      entity.destroy({do_cliff_correction = true})
    end
    if ammo_name ~= "laser-turret" then
      turret.insert(stack)
    end
    for x = floor(box.left_top.x), floor(box.right_bottom.x) do
      for y = floor(box.left_top.y), floor(box.right_bottom.y) do
        table.insert(tiles, {name = tile_name, position = {x, y}})
      end
    end
  end
  for k, position in pairs (pole_positions) do
    local pole = surface.create_entity{name = "medium-electric-pole", position = position, force = force}
    for k, entity in pairs (surface.find_entities_filtered{area = pole.bounding_box, force = "neutral"}) do
      entity.destroy({do_cliff_correction = true})
    end
    table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y}})
  end
  set_tiles_safe(surface, tiles)
end

function create_starting_artillery(force)
  if not script_data.map_config.team_artillery then return end
  if not (force and force.valid) then return end
  local turret_name = script_data.prototypes.artillery
  if not game.entity_prototypes[turret_name] then return end
  local ammo_name = script_data.prototypes.artillery_ammo
  if not game.item_prototypes[ammo_name] then return end
  local surface = script_data.surface
  local height = surface.map_gen_settings.height / 2
  local width = surface.map_gen_settings.width / 2
  local origin = force.get_spawn_position(surface)
  local size = script_data.map_config.starting_area_size.selected
  local radius = config.get_starting_area_radius() - 1 --[[radius in chunks]]
  if radius < 1 then return end
  local positions = {}
  local tile_positions = {}
  for x = -radius, 0 do
    if x == -radius then
      for y = -radius, 0 do
        table.insert(positions, {x = 1 + origin.x + 32*x, y = 1 + origin.y + 32*y})
      end
    else
      table.insert(positions, {x = 1 + origin.x + 32*x, y = 1 + origin.y - radius*32})
    end
  end
  for x = 1, radius do
    if x == radius then
      for y = -radius, -1 do
        table.insert(positions, {x = -2 + origin.x + 32*x, y = 1 + origin.y + 32*y})
      end
    else
      table.insert(positions, {x = -2 + origin.x + 32*x, y = 1 + origin.y - radius*32})
    end
  end
  for x = -radius, -1 do
    if x == -radius then
      for y = 1, radius do
        table.insert(positions, {x = 1 + origin.x + 32*x, y = -2 + origin.y + 32*y})
      end
    else
      table.insert(positions, {x = 1 + origin.x + 32*x, y = -2 + origin.y + radius*32})
    end
  end
  for x = 0, radius do
    if x == radius then
      for y = 0, radius do
        table.insert(positions, {x = -2 + origin.x + 32*x, y = -2 + origin.y + 32*y})
      end
    else
      table.insert(positions, {x = -2 + origin.x + 32*x, y = -2 + origin.y + radius*32})
    end
  end
  local stack = {name = ammo_name, count = 20}
  local tiles = {}
  local tile_name = script_data.prototypes.tile_2
  if not game.tile_prototypes[tile_name] then tile_name = get_walkable_tile() end
  local floor = math.floor
  for k, position in pairs (positions) do
    local turret = surface.create_entity{name = turret_name, position = position, force = force, direction = position.direction}
    local box = turret.bounding_box
    for k, entity in pairs (surface.find_entities_filtered{area = turret.bounding_box, force = "neutral"}) do
      entity.destroy({do_cliff_correction = true})
    end
    turret.insert(stack)
    for x = floor(box.left_top.x), floor(box.right_bottom.x) do
      for y = floor(box.left_top.y), floor(box.right_bottom.y) do
        table.insert(tiles, {name = tile_name, position = {x, y}})
      end
    end
  end
  set_tiles_safe(surface, tiles)
end

function create_wall_for_force(force)
  if not script_data.map_config.team_walls then return end
  if not force.valid then return end
  local surface = script_data.surface
  local height = surface.map_gen_settings.height / 2
  local width = surface.map_gen_settings.width / 2
  local origin = force.get_spawn_position(surface)
  local size = script_data.map_config.starting_area_size.selected
  local radius = config.get_starting_area_radius(true) - 11 --[[radius in tiles]]
  local limit = math.min(width - math.abs(origin.x), height - math.abs(origin.y)) - 1
  radius = math.min(radius, limit)
  if radius < 2 then return end
  local perimeter_top = {}
  local perimeter_bottom = {}
  local perimeter_left = {}
  local perimeter_right = {}
  local tiles = {}
  local insert = table.insert
  for X = -radius, radius - 1 do
    insert(perimeter_top, {x = origin.x + X, y = origin.y - radius})
    insert(perimeter_bottom, {x = origin.x + X, y = origin.y + (radius-1)})
  end
  for Y = -radius, radius - 1 do
    insert(perimeter_left, {x = origin.x - radius, y = origin.y + Y})
    insert(perimeter_right, {x = origin.x + (radius-1), y = origin.y + Y})
  end
  local tile_name = script_data.prototypes.tile_1
  if not game.tile_prototypes[tile_name] then tile_name = get_walkable_tile() end
  local areas = {
    {{perimeter_top[1].x, perimeter_top[1].y - 1}, {perimeter_top[#perimeter_top].x, perimeter_top[1].y + 3}},
    {{perimeter_bottom[1].x, perimeter_bottom[1].y - 3}, {perimeter_bottom[#perimeter_bottom].x, perimeter_bottom[1].y + 1}},
    {{perimeter_left[1].x - 1, perimeter_left[1].y}, {perimeter_left[1].x + 3, perimeter_left[#perimeter_left].y}},
    {{perimeter_right[1].x - 3, perimeter_right[1].y}, {perimeter_right[1].x + 1, perimeter_right[#perimeter_right].y}},
  }
  for k, area in pairs (areas) do
    for i, entity in pairs(surface.find_entities_filtered({area = area})) do
      entity.destroy({do_cliff_correction = true})
    end
  end
  local wall_name = script_data.prototypes.wall
  local gate_name = script_data.prototypes.gate
  if not game.entity_prototypes[wall_name] then
    log("Setting walls cancelled as "..wall_name.." is not a valid entity prototype")
    return
  end
  if not game.entity_prototypes[gate_name] then
    log("Setting walls cancelled as "..gate_name.." is not a valid entity prototype")
    return
  end
  local should_gate = {
    [12] = true,
    [13] = true,
    [14] = true,
    [15] = true,
    [16] = true,
    [17] = true,
    [18] = true,
    [19] = true
  }
  for k, position in pairs (perimeter_left) do
    if (k ~= 1) and (k ~= #perimeter_left) then
      insert(tiles, {name = tile_name, position = {position.x + 2, position.y}})
      insert(tiles, {name = tile_name, position = {position.x + 1, position.y}})
    end
    if should_gate[position.y % 32] then
      surface.create_entity{name = gate_name, position = position, direction = 0, force = force}
    else
      surface.create_entity{name = wall_name, position = position, force = force}
    end
  end
  for k, position in pairs (perimeter_right) do
    if (k ~= 1) and (k ~= #perimeter_right) then
      insert(tiles, {name = tile_name, position = {position.x - 2, position.y}})
      insert(tiles, {name = tile_name, position = {position.x - 1, position.y}})
    end
    if should_gate[position.y % 32] then
      surface.create_entity{name = gate_name, position = position, direction = 0, force = force}
    else
      surface.create_entity{name = wall_name, position = position, force = force}
    end
  end
  for k, position in pairs (perimeter_top) do
    if (k ~= 1) and (k ~= #perimeter_top) then
      insert(tiles, {name = tile_name, position = {position.x, position.y + 2}})
      insert(tiles, {name = tile_name, position = {position.x, position.y + 1}})
    end
    if should_gate[position.x % 32] then
      surface.create_entity{name = gate_name, position = position, direction = 2, force = force}
    else
      surface.create_entity{name = wall_name, position = position, force = force}
    end
  end
  for k, position in pairs (perimeter_bottom) do
    if (k ~= 1) and (k ~= #perimeter_bottom) then
      insert(tiles, {name = tile_name, position = {position.x, position.y - 2}})
      insert(tiles, {name = tile_name, position = {position.x, position.y - 1}})
    end
    if should_gate[position.x % 32] then
      surface.create_entity{name = gate_name, position = position, direction = 2, force = force}
    else
      surface.create_entity{name = wall_name, position = position, force = force}
    end
  end
  if script_data.map_config.team_paved then
    for X = origin.x - radius + 2, origin.x + radius - 2 do
      for Y = origin.y - radius + 2, origin.y + radius - 2 do
        local tile = surface.get_tile(X, Y)
        if not tile.collides_with("water-tile") then
          insert(tiles, {name = tile_name, position = {X, Y}})
        end
      end
    end
  end
  set_tiles_safe(surface, tiles)
end

function spairs(t, order)
  local keys = {}
  for k in pairs(t) do keys[#keys+1] = k end
  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

function oil_harvest_prune_oil(event)
  if not script_data.game_config.oil_harvest then return end
  if not script_data.game_config.oil_only_in_center then return end
  local area = event.area
  local center = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
  local origin = script_data.spawn_offset
  local distance_from_center = (((center.x - origin.x) ^ 2) + ((center.y - origin.y) ^ 2)) ^ 0.5
  if distance_from_center > script_data.map_config.average_team_displacement / 2.5 then
    for k, entity in pairs (event.surface.find_entities_filtered{area = area, name = script_data.prototypes.oil_resource}) do
      entity.destroy()
    end
  end
end

button_press_functions = {
  add_team_button = add_team_button_press,
  admin_button = admin_button_press,
  auto_assign_button = function(event) event.element.parent.destroy() auto_assign(game.players[event.player_index]) end,
  balance_options_cancel = function(event) toggle_balance_options_gui(game.players[event.player_index]) end,
  balance_options_confirm = function(event) local player = game.players[event.player_index]  if set_balance_settings(player) then toggle_balance_options_gui(player) end end,
  balance_options = function(event) toggle_balance_options_gui(game.players[event.player_index]) end,
  config_confirm = function(event) config_confirm(game.players[event.player_index]) end,
  start_match_button = start_match,
  diplomacy_button = diplomacy_button_press,
  diplomacy_cancel = function(event) game.players[event.player_index].opened.destroy() end,
  diplomacy_confirm = diplomacy_confirm,
  join_spectator = function(event) event.element.parent.destroy() spectator_join(game.players[event.player_index]) end,
  objective_button = objective_button_press,
  list_teams_button = list_teams_button_press,
  oil_harvest_button = oil_harvest_button_press,
  space_race_button = space_race_button_press,
  production_score_button = production_score_button_press,
  random_join_button = function(event) event.element.parent.destroy() random_join(game.players[event.player_index]) end,
  spectator_join_team_button = function(event) choose_joining_gui(game.players[event.player_index]) end,
  pvp_export_button = function (event) export_button_press(game.players[event.player_index]) end,
  pvp_export_close = function(event) local player = game.players[event.player_index] player.gui.center.clear() create_config_gui(player) end,
  pvp_import_button = function (event) import_button_press(game.players[event.player_index]) end,
  pvp_import_confirm = function(event) import_confirm(game.players[event.player_index]) end,
}

function duplicate_starting_area_entities()
  if not script_data.map_config.duplicate_starting_area_entities then return end
  local copy_team = script_data.teams[1]
  if not copy_team then return end
  local force = game.forces[copy_team.name]
  if not force then return end
  local surface = script_data.surface
  local origin_spawn = force.get_spawn_position(surface)
  local starting_radius = config.get_starting_area_radius(true)
  local uranium_x = origin_spawn.x - starting_radius - 8 + 0.5
  local uranium_y = origin_spawn.y + starting_radius/2 + 0.5
  local uranium_radius = 17
  for x_offset = -uranium_radius, uranium_radius do
    for y_offset = -uranium_radius, uranium_radius do
      if x_offset * x_offset + y_offset * y_offset < uranium_radius * uranium_radius then
        local pos = {x = uranium_x + x_offset, y = uranium_y + y_offset}
        for k, resource_tile in pairs(surface.find_entities_filtered{position = pos, type = "resource"}) do
          resource_tile.destroy()
        end
        surface.create_entity({name = "uranium-ore", amount = 200, position = pos})
      end
    end
  end
  local radius = starting_radius + script_data.map_config.chunks_to_extend_duplication * 32
  local area = {{origin_spawn.x - radius, origin_spawn.y - radius}, {origin_spawn.x + radius, origin_spawn.y + radius}}
  local entities = surface.find_entities_filtered{area = area, force = "neutral"}
  local insert = table.insert
  local tiles = {}
  local counts = {}
  local ignore_counts = {
    ["refined-concrete"] = true,
    ["water"] = true,
    ["deepwater"] = true,
    ["refined-hazard-concrete-left"] = true
  }
  local tile_map = {}
  for name, tile in pairs (game.tile_prototypes) do
    tile_map[name] = tile.collision_mask["resource-layer"] ~= nil
    counts[name] = surface.count_tiles_filtered{name = name, area = area}
  end
  local tile_name = get_walkable_tile()
  local top_count = 0
  for name, count in pairs (counts) do
    if not ignore_counts[name] then
      if count > top_count then
        top_count = count
        tile_name = name
      end
    end
  end

  for name, bool in pairs (tile_map) do
    if bool and counts[name] > 0 then
      for k, tile in pairs (surface.find_tiles_filtered{area = area, name = name}) do
        insert(tiles, tile)
      end
    end
  end

  local mirror = #script_data.teams == 2
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      if team.name ~= copy_team.name then
        local spawn = force.get_spawn_position(surface)
        local area = {{spawn.x - radius, spawn.y - radius}, {spawn.x + radius, spawn.y + radius}}
        for k, entity in pairs (surface.find_entities_filtered{area = area, force = "neutral"}) do
          entity.destroy()
        end
        local set_tiles = {}
        for name, bool in pairs (tile_map) do
          if bool then
            for k, tile in pairs (surface.find_tiles_filtered{area = area, name = name}) do
              insert(set_tiles, {name = tile_name, position = {x = tile.position.x, y = tile.position.y}})
            end
          end
        end
        for k, tile in pairs (tiles) do
          local position
          if mirror then
            position = {x = (origin_spawn.x - tile.position.x) + spawn.x - 1, y = (origin_spawn.y - tile.position.y) + spawn.y - 1}
          else
             position = {x = (tile.position.x - origin_spawn.x) + spawn.x, y = (tile.position.y - origin_spawn.y) + spawn.y}
          end
          insert(set_tiles, {name = tile.name, position = position})
        end
        surface.set_tiles(set_tiles)
        for k, entity in pairs (entities) do
          if entity.valid then
            local position
            if mirror then
              position = {x = (origin_spawn.x - entity.position.x) + spawn.x, y = (origin_spawn.y - entity.position.y) + spawn.y}
            else
              position = {x = (entity.position.x - origin_spawn.x) + spawn.x, y = (entity.position.y - origin_spawn.y) + spawn.y}
            end
            local type = entity.type
            local amount = (type == "resource" and entity.amount) or nil
            local cliff_orientation = (type == "cliff" and entity.cliff_orientation) or nil
            if mirror and cliff_orientation then
              cliff_orientation = cliff_orientation:gsub("[^-]+", {east="west",west="east",north="south",south="north"})
            end
            surface.create_entity{name = entity.name, position = position, force = "neutral", amount = amount, cliff_orientation = cliff_orientation}
          end
        end
      end
    end
  end
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      create_wall_for_force(force)
      create_silo_for_force(force)
      create_starting_chest(force)
      create_starting_turrets(force)
      create_starting_artillery(force)
      protect_force_area(force)
    end
  end
end

function check_spectator_chart()
  local chart_all = function(force)
    if not (force and force.valid) then return end
    if #force.connected_players > 0 then
      force.chart_all(script_data.surface)
    end
  end
  if script_data.team_won or not script_data.map_config.spectator_fog_of_war then
    chart_all(game.forces.spectator)
  end
  if script_data.team_won then
    for k, team in pairs (script_data.teams) do
      local force = game.forces[team.name]
      chart_all(force)
    end
  end
end

function create_starting_chest(force)
  if not (force and force.valid) then return end
  local value = script_data.team_config.starting_chest.selected
  if value == "none" then return end
  local multiplier = script_data.team_config.starting_chest_multiplier
  if not (multiplier > 0) then return end
  local inventory = script_data.inventory_list[value]
  if not inventory then return end
  local surface = script_data.surface
  local chest_name = script_data.prototypes.chest
  local prototype = game.entity_prototypes[chest_name]
  if not prototype then
    log("Starting chest "..chest_name.." is not a valid entity prototype, picking a new container from prototype list")
    for name, chest in pairs (game.entity_prototypes) do
      if chest.type == "container" then
        chest_name = name
        prototype = chest
        break
      end
    end
  end
  local bounding_box = prototype.collision_box
  local size = math.ceil(math.max(bounding_box.right_bottom.x - bounding_box.left_top.x, bounding_box.right_bottom.y - bounding_box.left_top.y))
  local origin = force.get_spawn_position(surface)
  origin.y = origin.y + 8
  local index = 1
  local position = {x = origin.x + get_chest_offset(index).x * size, y = origin.y + get_chest_offset(index).y * size}
  local chest = surface.create_entity{name = chest_name, position = position, force = force}
  for k, v in pairs (surface.find_entities_filtered{force = "neutral", area = chest.bounding_box}) do
    v.destroy()
  end
  local tiles = {}
  local grass = {}
  local tile_name = script_data.prototypes.tile_1
  if not game.tile_prototypes[tile_name] then tile_name = get_walkable_tile() end
  table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y}})
  chest.destructible = false
  local items = game.item_prototypes
  for name, count in pairs (inventory) do
    if items[name] then
      local count_to_insert = math.ceil(count*multiplier)
      local difference = count_to_insert - chest.insert{name = name, count = count_to_insert}
      while difference > 0 do
        index = index + 1
        position = {x = origin.x + get_chest_offset(index).x * size, y = origin.y + get_chest_offset(index).y * size}
        chest = surface.create_entity{name = chest_name, position = position, force = force}
        for k, v in pairs (surface.find_entities_filtered{force = "neutral", area = chest.bounding_box}) do
          v.destroy()
        end
        table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y}})
        chest.destructible = false
        difference = difference - chest.insert{name = name, count = difference}
      end
    end
  end
  set_tiles_safe(surface, tiles)
end

function get_chest_offset(n)
  local offset_x = 0
  n = n/2
  if n % 1 == 0.5 then
    offset_x = -1
    n = n + 0.5
  end
  local root = n^0.5
  local nearest_root = math.floor(root+0.5)
  local upper_root = math.ceil(root)
  local root_difference = math.abs(nearest_root^2 - n)
  if nearest_root == upper_root then
    x = upper_root - root_difference
    y = nearest_root
  else
    x = upper_root
    y = root_difference
  end
  local orientation = 2 * math.pi * (45/360)
  x = x * (2^0.5)
  y = y * (2^0.5)
  local rotated_x = math.floor(0.5 + x * math.cos(orientation) - y * math.sin(orientation))
  local rotated_y = math.floor(0.5 + x * math.sin(orientation) + y * math.cos(orientation))
  return {x = rotated_x + offset_x, y = rotated_y}
end

function get_walkable_tile()
  for name, tile in pairs (game.tile_prototypes) do
    if tile.collision_mask["player-layer"] == nil and not tile.items_to_place_this then
      return name
    end
  end
  error("No walkable tile in prototype list")
end

function set_tiles_safe(surface, tiles)
  local grass = get_walkable_tile()
  local grass_tiles = {}
  for k, tile in pairs (tiles) do
    grass_tiles[k] = {position = {x = (tile.position.x or tile.position[1]), y = (tile.position.y or tile.position[2])}, name = grass}
  end
  surface.set_tiles(grass_tiles, false)
  surface.set_tiles(tiles)
end

function create_exclusion_map()
  local surface = script_data.surface
  if not (surface and surface.valid) then return end
  local exclusion_map = {}
  local radius = config.get_starting_area_radius() --[[radius in chunks]]
  for k, team in pairs (script_data.teams) do
    local name = team.name
    local force = game.forces[name]
    if force then
      local origin = force.get_spawn_position(surface)
      local Xo = math.floor(origin.x / 32)
      local Yo = math.floor(origin.y / 32)
      for X = -radius, radius - 1 do
        Xb = X + Xo
        if not exclusion_map[Xb] then exclusion_map[Xb] = {} end
        for Y = -radius, radius - 1 do
          local Yb = Y + Yo
          exclusion_map[Xb][Yb] = name
        end
      end
    end
  end
  script_data.exclusion_map = exclusion_map
end

function check_base_exclusion()
  if not (script_data.check_base_exclusion or script_data.protected_teams) then return end

  if script_data.check_base_exclusion and game.tick > (script_data.round_start_tick + (script_data.game_config.base_exclusion_time * 60 * 60)) then
    script_data.check_base_exclusion = nil
    game.print({"base-exclusion-ends"})
  end

end

function check_player_base_exclusion(player)
  if not (script_data.check_base_exclusion or script_data.protected_teams) then return end

  if not is_ignored_force(player.force.name) then
    check_player_exclusion(player, get_chunk_map_position(player.position))
  end
end

function get_chunk_map_position(position)
  local map = script_data.exclusion_map
  local chunk_x = math.floor(position.x / 32)
  local chunk_y = math.floor(position.y / 32)
  if map[chunk_x] then
    return map[chunk_x][chunk_y]
  end
end


local disallow =
{
  ["player"] = true,
  ["enemy"] = true,
  ["neutral"] = true,
  ["spectator"] = true
}

function is_ignored_force(name)
  return disallow[name]
end

function check_player_exclusion(player, force_name)
  if not force_name then return end
  local force = game.forces[force_name]
  if not (force and force.valid and player and player.valid) then return end
  if force == player.force or force.get_friend(player.force) then return end
  if not (script_data.check_base_exclusion or (script_data.protected_teams and script_data.protected_teams[force_name])) then return end
  local surface = script_data.surface
  local origin = force.get_spawn_position(surface)
  local radius = config.get_starting_area_radius(true) --[[radius in tiles]]
  local position = {x = player.position.x, y = player.position.y}
  local vector = {x = 0, y = 0}

  if position.x < origin.x then
    vector.x = (origin.x - radius) - position.x
  elseif position.x > origin.x then
    vector.x = (origin.x + radius) - position.x
  end

  if position.y < origin.y then
    vector.y = (origin.y - radius) - position.y
  elseif position.y > origin.y then
    vector.y = (origin.y + radius) - position.y
  end

  if math.abs(vector.x) < math.abs(vector.y) then
    vector.y = 0
  else
    vector.x = 0
  end

  local new_position = {x = position.x + vector.x, y = position.y + vector.y}
  local vehicle = player.vehicle
  if vehicle then
    if not vehicle.teleport(new_position) then
      player.driving = false
    end
    vehicle.orientation = vehicle.orientation + 0.5
  else
    player.teleport(new_position)
  end

  if script_data.check_base_exclusion then
    local time_left = math.ceil((script_data.round_start_tick + (script_data.game_config.base_exclusion_time * 60 * 60) - game.tick) / 3600)
    player.print({"base-exclusion-teleport", time_left})
  else
    player.print({"protected-base-area"})
  end

end

function set_button_style(button)
  if not button.valid then return end
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function check_start_match()
  if script_data.game_config.team_prep_time <= 0 or game.tick < (script_data.game_config.team_prep_time * 60 * 60) + script_data.map_prepared_tick then return end
  start_match()
end

function check_restart_round()
  if not script_data.team_won then return end
  local time = script_data.game_config.auto_new_round_time
  if not (time > 0) then return end
  if game.tick < (time * 60 * 60) + script_data.team_won then return end
  end_round()
  destroy_config_for_all()
  prepare_next_round()
end

function team_won(name)
  script_data.team_won = game.tick
  if script_data.game_config.auto_new_round_time > 0 then
    game.print({"team-won-auto", name, script_data.game_config.auto_new_round_time}, game_message_color)
  else
    game.print({"team-won", name}, game_message_color)
  end
  for k, player in pairs(game.players) do
    spectator_join(player, name)
  end
  script.raise_event(events.on_team_won, {name = name})
end


function offset_respawn_position(player)
  --This is to help the spawn camping situations.
  if not (player and player.valid and player.character) then return end
  local surface = player.surface
  local origin = player.force.get_spawn_position(surface)
  local radius = config.get_starting_area_radius(true) - 32
  if not (radius > 0) then return end
  local random_position = {origin.x + math.random(-radius, radius), origin.y + math.random(-radius, radius)}
  local position = surface.find_non_colliding_position(player.character.name, random_position, 32, 1)
  if not position then return end
  player.teleport(position)
end

function disband_team(force, desination_force)
  local count = 0
  for k, team in pairs (script_data.teams) do
    if game.forces[team.name] then
      count = count + 1
    end
  end
  if not (count > 1) then
    --Can't disband the last team.
    return
  end
  force.print{"join-new-team"}
  local players = script_data.players_to_disband or {}
  for k, player in pairs (force.players) do
    players[player.name] = true
  end
  script_data.players_to_disband = players
  if desination_force and force ~= desination_force then
    game.merge_forces(force, desination_force)
  else
    game.merge_forces(force, "neutral")
  end
end

recursive_data_check = function(new_data, old_data)
  for k, data in pairs (new_data) do
    if not old_data[k] then
      old_data[k] = data
    elseif type(data) == "table" then
      recursive_data_check(new_data[k], old_data[k])
    end
  end
end

check_cursor_for_disabled_items = function(event)
  if not script_data.disabled_items then return end
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  local stack = player.cursor_stack
  if (stack and stack.valid_for_read) then
    local disable_bp = script_data.game_config.disable_starting_blueprints and not player.force.technologies["construction-robotics"].researched
    if script_data.disabled_items[stack.name] or disable_bp and (stack.name == "blueprint" or stack.name == "blueprint-book") then
      stack.clear()
    end
  end
end

disable_items_elem_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end
  local parent = gui.parent
  if not script_data.disabled_items then
    script_data.disabled_items = {}
  end
  local items = script_data.disabled_items
  if parent.name ~= "disable_items_table" then return end
  local value = gui.elem_value
  if not value then
    local map = {}
    for k, child in pairs (parent.children) do
      if child.elem_value then
        map[child.elem_value] = true
      end
    end
    for item, bool in pairs (items) do
      if not map[item] then
        items[item] = nil
      end
    end
    gui.destroy()
    return
  end
  if items[value] then
    if items[value] ~= gui.index then
      gui.elem_value = nil
      player.print({"duplicate-disable"})
    end
  else
    items[value] = gui.index
    parent.add{type = "choose-elem-button", elem_type = "item"}
  end
  script_data.disabled_items = items
end

recipe_picker_elem_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  recipe_picker_elem_update(gui, player)
end

function recipe_picker_elem_update(gui, player)
  if not (player and player.valid and gui and gui.valid) then return end
  local flow = gui.parent
  if not flow then return end
  local frame = flow.parent
  if not (frame and frame.name == "production_score_frame") then return end
  if frame.recipe_check_frame then
    frame.recipe_check_frame.destroy()
  end
  if gui.elem_value == nil then
    return
  end
  local recipe = player.force.recipes[gui.elem_value]
  local recipe_frame = frame.add{type = "frame", direction = "vertical", style = "image_frame", name = "recipe_check_frame"}
  local title_flow = recipe_frame.add{type = "flow"}
  title_flow.style.horizontal_align = "center"
  title_flow.style.horizontally_stretchable = true
  title_flow.add{type = "label", caption = recipe.localised_name, style = "frame_caption_label"}
  local table = recipe_frame.add{type = "table", column_count = 2, name = "recipe_checker_table"}
  table.draw_horizontal_line_after_headers = true
  table.draw_vertical_lines = true
  table.style.horizontal_spacing = 16
  table.style.vertical_spacing = 2
  table.style.left_padding = 4
  table.style.right_padding = 4
  table.style.top_padding = 4
  table.style.bottom_padding = 4
  table.style.column_alignments[1] = "center"
  table.style.column_alignments[2] = "center"
  table.add{type = "label", caption = {"ingredients"}, style = "bold_label"}
  table.add{type = "label", caption = {"products"}, style = "bold_label"}
  local ingredients = recipe.ingredients
  local products = recipe.products
  local prices = script_data.price_list
  local cost = 0
  local gain = 0
  local prototypes = {
    fluid = game.fluid_prototypes,
    item = game.item_prototypes
  }
  for k = 1, math.max(#ingredients, #products) do
    local ingredient = ingredients[k]
    local flow = table.add{type = "flow", direction = "horizontal"}
    if k == 1 then
      flow.style.top_padding = 8
    end
    flow.style.vertical_align = "center"
    if ingredient then
      local ingredient_price = prices[ingredient.name] or 0
      flow.add
      {
        type = "sprite-button",
        name = ingredient.type.."/"..ingredient.name,
        sprite = ingredient.type.."/"..ingredient.name,
        number = ingredient.amount,
        style = "slot_button",
        tooltip = {"", "1 ", prototypes[ingredient.type][ingredient.name].localised_name, " = ", util.format_number(math.floor(ingredient_price * 100) / 100)},
      }
      local price = ingredient.amount * ingredient_price or 0
      add_pusher(flow)
      flow.add{type = "label", caption = util.format_number(math.floor(price * 100) / 100)}
      cost = cost + price
    end
    local product = products[k]
    flow = table.add{type = "flow", direction = "horizontal"}
    if k == 1 then
      flow.style.top_padding = 8
    end
    flow.style.vertical_align = "center"
    if product then
      local amount = product.amount or product.probability * (product.amount_max + product.amount_min) / 2 or 0
      local product_price = prices[product.name] or 0
      flow.add
      {
        type = "sprite-button",
        name = product.type.."/"..product.name,
        sprite = product.type.."/"..product.name,
        number = amount,
        style = "slot_button",
        tooltip = {"", "1 ", prototypes[product.type][product.name].localised_name, " = ", util.format_number(math.floor(product_price * 100) / 100)},
        show_percent_for_small_numbers = true
      }
      add_pusher(flow)
      local price = amount * product_price or 0
      flow.add{type = "label", caption = util.format_number(math.floor(price * 100) / 100)}
      gain = gain + price
    end
  end
  local line = table.add{type = "table", column_count = 1}
  line.draw_horizontal_lines = true
  add_pusher(line)
  add_pusher(line)
  line.style.top_padding = 8
  line.style.bottom_padding = 4
  local line = table.add{type = "table", column_count = 1}
  line.draw_horizontal_lines = true
  add_pusher(line)
  add_pusher(line)
  line.style.top_padding = 8
  line.style.bottom_padding = 4
  local cost_flow = table.add{type = "flow"}
  cost_flow.add{type = "label", caption = {"", {"cost"}, {"colon"}}}
  add_pusher(cost_flow)
  cost_flow.add{type = "label", caption = util.format_number(math.floor(cost * 100) / 100)}
  local gain_flow = table.add{type = "flow"}
  gain_flow.add{type = "label", caption = {"", {"gain"}, {"colon"}}}
  add_pusher(gain_flow)
  gain_flow.add{type = "label", caption = util.format_number(math.floor(gain * 100) / 100)}
  table.add{type = "flow"}
  local total_flow = table.add{type = "flow"}
  total_flow.add{type = "label", caption = {"", {"total"}, {"colon"}}, style = "bold_label"}
  add_pusher(total_flow)
  local total = total_flow.add{type = "label", caption = util.format_number(math.floor((gain-cost) * 100) / 100), style = "bold_label"}
  if cost > gain then
    total.style.font_color = {r = 1, g = 0.3, b = 0.3}
  end

end

function add_pusher(gui)
  local pusher = gui.add{type = "flow"}
  pusher.style.horizontally_stretchable = true
end

function check_on_built_protection(event)
  if not script_data.map_config.enemy_building_restriction then return end
  local entity = event.created_entity
  local player = game.players[event.player_index]
  if not (entity and entity.valid and player and player.valid) then return end
  local force = entity.force
  local name = get_chunk_map_position(entity.position)
  if not name then return end
  if force.name == name then return end
  local other_force = game.forces[name]
  if not other_force then return end
  if other_force.get_friend(force) then return end
  if not player.mine_entity(entity, true) then
    entity.destroy()
  end
  player.print({"enemy-building-restriction"})
end

function check_defcon()
  if not script_data.team_config.defcon_mode then return end
  if script_data.team_config.defcon_random then
    local defcon_tick = script_data.last_defcon_tick
    if not defcon_tick then
      script_data.last_defcon_tick = game.tick
      return
    end
    local duration = math.max(60, (script_data.team_config.defcon_timer * 60 * 60))
    local tick_of_defcon = defcon_tick + duration
    local current_tick = game.tick
    local progress = math.max(0, math.min(1, 1 - (tick_of_defcon - current_tick) / duration))
    local tech = script_data.next_defcon_tech
    if tech and tech.valid then
      for k, team in pairs (script_data.teams) do
        local force = game.forces[team.name]
        if force then
          if force.current_research ~= tech.name then
            force.current_research = tech.name
          end
          force.research_progress = progress
        end
      end
    end
    if current_tick >= tick_of_defcon then
      defcon_research()
      script_data.last_defcon_tick = current_tick
    end
  else
    local seconds = script_data.elapsed_seconds
    if seconds == nil then
      seconds = 0
    else
      seconds = seconds + 1
    end
    script_data.elapsed_seconds = seconds
    for k, team in pairs (script_data.teams) do
      local force = game.forces[team.name]
      if force then
        local tech = force.current_research
        if tech and tech.valid then
          local cost = 0
          for j, ingredient in pairs (tech.research_unit_ingredients) do
            local ingredient_cost = script_data.science_pack_costs[ingredient.name] * ingredient.amount * tech.research_unit_count
            cost = cost + ingredient_cost
          end
          if script_data.game_config.nuclear_research_buff and (tech.name == "atomic-bomb" or tech.name == "nuclear-power") then
            cost = cost / 4
            if script_data.previous_tech[team.name] ~= tech.name then
              force.print({"nuclear-research-buff-alert"})
            end
          end
          if script_data.game_config.tanks_research_nerf and tech.name == "tanks" then
            cost = cost * 8
            if script_data.previous_tech[team.name] ~= tech.name then
              force.print({"tanks-research-nerf-alert"})
            end
          end
          local progress = force.research_progress
          local increment = (force.laboratory_speed_modifier + 1) * script_data.science_speedup * script_data.team_config.defcon_random_multiplier / cost
          progress = math.min(1, progress + increment)
          force.research_progress = progress
          if script_data.research_time_wasted then script_data.research_time_wasted[team.name] = 100 end
          if script_data.previous_tech then script_data.previous_tech[team.name] = tech.name end
        else
          if script_data.previous_tech then 
            script_data.previous_tech[team.name] = "none"
            if script_data.research_time_wasted then 
              local time_wasted = script_data.research_time_wasted[team.name]
              if not time_wasted then time_wasted = 100 end
              if time_wasted % 120 == 0 then
                force.print({"defcon-select-research-warning"}, game_message_color)
              end
              script_data.research_time_wasted[team.name] = time_wasted + 1
            end
          end
        end
      end
    end
    local match_ticks = math.max(0, game.tick - script_data.round_start_tick)
    local minutes = match_ticks / 60 / 60
    local minutes_squared = minutes * minutes
    script_data.science_speedup = 2.8 + 0.083 * minutes + 0.0042 * minutes_squared + 0.00000056 * minutes_squared * minutes_squared
  end
end

function check_game_speed(wakeup)
  if game.tick % 300 ~= 0 and game.speed == 1 then return end
  if wakeup then
    game.speed = script_data.game_speed
    return
  end
  local game_slowed
  if not script_data.setup_finished then
    game_slowed = false
  else
    game_slowed = true
    for k, player in pairs (game.players) do
      if player.connected and player.afk_time < 60 * 60 then
        game_slowed = false
        break
      end
    end
  end
  if game_slowed then
    if game.speed == 0.05 then
      script_data.game_speed = 1
    else
      script_data.game_speed = game.speed
    end
    game.speed = 0.05
  else
    game.speed = script_data.game_speed
  end
end

recursive_technology_prerequisite = function(tech)
  for name, prerequisite in pairs (tech.prerequisites) do
    if not prerequisite.researched then
      return recursive_technology_prerequisite(prerequisite)
    end
  end
  return tech
end

function defcon_research()

  local tech = script_data.next_defcon_tech
  if tech and tech.valid then
    for k, team in pairs (script_data.teams) do
      local force = game.forces[team.name]
      if force then
        local tech = force.technologies[tech.name]
        if tech then
          tech.researched = true
        end
      end
    end
    local sound = "utility/research_completed"
    if game.is_valid_sound_path(sound) then
      game.play_sound({path = sound})
    end
    game.print({"defcon-unlock", tech.localised_name}, {r = 1, g = 0.5, b = 0.5})
  end

  local force
  for k, team in pairs (script_data.teams) do
    force = game.forces[team.name]
    if force and force.valid then
      break
    end
  end
  if not force then return end
  local available_techs = {}
  for name, tech in pairs (force.technologies) do
    if tech.enabled and tech.researched == false then
      table.insert(available_techs, tech)
    end
  end
  if #available_techs == 0 then return end
  local random_tech = available_techs[math.random(#available_techs)]
  if not random_tech then return end
  random_tech = recursive_technology_prerequisite(random_tech)
  script_data.next_defcon_tech = game.technology_prototypes[random_tech.name]
  for k, team in pairs (script_data.teams) do
    local force = game.forces[team.name]
    if force then
      force.current_research = random_tech.name
    end
  end
end

function check_neutral_chests_and_vehicles(event)
  local entity = event.created_entity
  if not (entity and entity.valid) then return end
  local neutralize_chest = script_data.game_config.neutral_chests and entity.type == "container"
  local neutralize_vehicle = script_data.game_config.neutral_vehicles and entity.type == "item-with-entity-data" and entity.name ~= "locomotive"
  if neutralize_chest or neutralize_vehicle then
    entity.force = "neutral"
  end
end

function check_wrecks_corpse_timer()
  if not script_data.wrecks then return end
  for wreck, tick in pairs(script_data.wrecks) do
    if wreck and wreck.valid then
      local wreck_inventory = wreck.get_inventory(defines.inventory.item_main)
      if wreck_inventory.is_empty() or game.tick > tick + 15 * 60 * 60 then
        wreck.destroy()
      end
    end
  end
end

function export_button_press(player)
  if not (player and player.valid) then return end
  if not parse_config(player) then return end
  local gui = player.gui.center
  gui.clear()
  local frame = gui.add{type = "frame", caption = {"gui.export-to-string"}, name = "pvp_export_frame", direction = "vertical"}
  local textfield = frame.add{type = "text-box"}
  textfield.word_wrap = true
  textfield.read_only = true
  textfield.style.height = player.display_resolution.height * 0.6
  textfield.style.width = player.display_resolution.width * 0.6
  local data =
  {
    game_config = script_data.game_config,
    team_config = script_data.team_config,
    map_config = script_data.map_config,
    modifier_list = script_data.modifier_list,
    teams = script_data.teams,
    disabled_items = script_data.disabled_items
  }
  textfield.text = util.encode(serpent.dump(data))
  local button = frame.add{type = "button", caption = {"gui.close"}, name = "pvp_export_close"}
  frame.visible = true
end

function import_button_press(player)
  if not (player and player.valid) then return end
  local gui = player.gui.center
  gui.clear()
  local frame = gui.add{type = "frame", caption = {"gui-blueprint-library.import-string"}, name = "pvp_import_frame", direction = "vertical"}
  local textfield = frame.add{type = "text-box", name = "import_textfield"}
  textfield.word_wrap = true
  textfield.style.height = player.display_resolution.height * 0.6
  textfield.style.width = player.display_resolution.width * 0.6
  local flow = frame.add{type = "flow", direction = "horizontal"}
  flow.add{type = "button", caption = {"gui.close"}, name = "pvp_export_close"}
  local pusher = flow.add{type = "flow"}
  pusher.style.horizontally_stretchable = true
  flow.add{type = "button", caption = {"gui-blueprint-library.import"}, name = "pvp_import_confirm"}
  frame.visible = true
end

function import_confirm(player)
  if not (player and player.valid) then return end
  local gui = player.gui.center
  local frame = gui.pvp_import_frame
  if not frame then return end
  local textfield = frame.import_textfield
  if not textfield then return end
  local text = textfield.text
  if text == "" then player.print({"import-failed"}) return end
  local result = loadstring(util.decode(text))
  local new_config
  if result then
    new_config = result()
  else
    player.print({"import-failed"})
    return
  end
  for k, v in pairs (new_config) do
    script_data[k] = v
  end
  gui.clear()
  create_config_gui(player)
  player.print({"import-success"})
end

function on_calculator_button_press(event)
  local gui = event.element
  if not (gui and gui.valid) then return end
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  local name = gui.name
  if (not name) or name == "" then return end
  local flow = gui.parent
  if not flow then return end
  local recipe_table = flow.parent
  if not (recipe_table and recipe_table.name and recipe_table.name == "recipe_checker_table") then return end
  local delim = "/"
  local pos = name:find(delim)
  local type = name:sub(1, pos - 1)
  local elem_name = name:sub(pos + 1, name:len())
  local items = game.item_prototypes
  local fluids = game.fluid_prototypes
  local recipes = game.recipe_prototypes
  if type == "item" then
    if not items[elem_name] then return end
  elseif type == "fluid" then
    if not fluids[elem_name] then return end
  else
    return
  end
  local frame = mod_gui.get_frame_flow(player).production_score_frame
  if not frame then return end
  local flow = frame.recipe_picker_holding_flow
  if not flow then return end
  local elem_button = flow.recipe_picker_elem_button
  local selected = elem_button.elem_value
  local candidates = {}
  for name, recipe in pairs (recipes) do
    for k, product in pairs (recipe.products) do
      if product.type == type and product.name == elem_name then
        table.insert(candidates, name)
      end
    end
  end
  if #candidates == 0 then return end
  local index = 0
  for k, name in pairs (candidates) do
    if name == selected then
      index = k
      break
    end
  end
  local recipe_name = candidates[index + 1] or candidates[1]
  if not recipe_name then return end
  elem_button.elem_value = recipe_name
  recipe_picker_elem_update(elem_button, player)
end

local pvp = {}

pvp.on_init = function()
  script_data = config.get_config()
  global.pvp = script_data
  balance.script_data = script_data
  config.script_data = script_data
  balance.init()
  local surface = game.surfaces[1]
  --local settings = surface.map_gen_settings
  --script_data.map_config.starting_area_size.selected = settings.starting_area
  --script_data.map_config.map_height = settings.height
  --script_data.map_config.map_width = settings.width
  --script_data.map_config.starting_area_size.selected = settings.starting_area
  script_data.round_number = 0

  --constants for the server host info spam
  script_data.timer_value = 0
  script_data.timer_wait = 600
  script_data.timer_display = 1

  local surface = game.create_surface("Lobby",{width = 1, height = 1})
  surface.set_tiles({{name = "out-of-map",position = {1,1}}})
  for k, force in pairs (game.forces) do
    force.disable_all_prototypes()
    force.disable_research()
  end
  for k, entity in pairs (surface.find_entities()) do
    entity.destroy()
  end
  surface.destroy_decoratives({area={{-500,-500},{500,500}}})
end

pvp.on_rocket_launched = function(event)
  production_score.on_rocket_launched(event)
  local is_freeplay = true
  for mode, k in pairs(victory_conditions) do
    if script_data.game_config[mode] then
      is_freeplay = false
      break
    end
  end
  local force = event.rocket.force
  if is_freeplay then
    local item_to_check = "satellite"
    if not game.item_prototypes[item_to_check] then error("Playing space race when satellites don't exist") end
    if force.get_item_launched(item_to_check) == 1 then
      game.print({"freeplay_launch", force.name})
    end
  end

  if not script_data.game_config.space_race then return end

  local item = game.item_prototypes[script_data.prototypes.satellite or ""]
  if not item then log("Failed to check space race victory, invalid item: "..script_data.prototypes.satellite) return end

  if event.rocket.get_item_count(item.name) == 0 then
    force.print({"rocket-launched-without-satellite"})
    return
  end

  --I think the following is incorrect. -JuicyJuuce
  --if not script_data.team_won then
  --  team_won(force.name)
  --end
end

pvp.on_entity_died = function(event)
  local dying_entity = event.entity
  if not (dying_entity and dying_entity.valid) then return end
  local force = dying_entity.force
  if script_data.game_config.vehicle_wreckage and dying_entity.type == "car" then
    local pos = dying_entity.position
    local wreck = script_data.surface.create_entity{name = "big-ship-wreck-2", position = pos, force = "neutral"}
    wreck.destructible = false
    wreck_inventory = wreck.get_inventory(defines.inventory.item_main)
    for k, inventory_type in pairs ({"car_ammo", "fuel", "car_trunk"}) do
      dying_inventory = dying_entity.get_inventory(defines.inventory[inventory_type])
      for i = 1, #dying_inventory do
        local item = dying_inventory[i]
        if item.valid_for_read then
          wreck_inventory.insert(item)
        end
      end
    end
    if not script_data.wrecks then
      script_data.wrecks = {}
    end
    script_data.wrecks[wreck] = game.tick
    local area = {left_top = {x = pos.x - 3, y = pos.y - 3}, right_bottom = {x = pos.x + 3, y = pos.y + 3}}
    for k, player in pairs(game.connected_players) do
      if not is_ignored_force(player.force.name) then
        local posx = player.position.x
        local posy = player.position.y
        if posx > area.left_top.x and posx < area.right_bottom.x and posy > area.left_top.y and posy < area.right_bottom.y then
          local non_collide = script_data.surface.find_non_colliding_position("player", player.position, 32, 1)
          if non_collide then
            if player.vehicle then
              player.vehicle.set_driver(nil)
            end
            if player.vehicle then
              player.vehicle.set_passenger(nil)
            end
            player.driving = false
            if not player.teleport(non_collide) then
              -- This should never happen.
              game.print("player.teleport failed, non_collide.x = "..non_collide.x.." non_collide.y = "..non_collide.y)
            end
          end
        end
      end
    end
  elseif dying_entity.name == (script_data.prototypes.silo or "") then
    if not script_data.game_config.last_silo_standing then return end
    local killing_force = event.force
    if not script_data.silos then return end
    script_data.silos[force.name] = nil
    if killing_force then
      game.print({"silo-destroyed", force.name, killing_force.name}, game_message_color)
    else
      game.print({"silo-destroyed", force.name, {"neutral"}}, game_message_color)
    end
    script.raise_event(events.on_team_lost, {name = force.name})
    if script_data.game_config.disband_on_loss then
      disband_team(force, killing_force)
    end
    if not script_data.team_won then
      local index = 0
      local winner_name = {"none"}
      for name, listed_silo in pairs (script_data.silos) do
        if listed_silo ~= nil then
          index = index + 1
          winner_name = name
        end
      end
      if index == 1  then
          team_won(winner_name)
      end
    end
  end
end

pvp.on_player_joined_game = function(event)
  local player = game.players[event.player_index]
  if script_data.setup_finished == true then
    check_game_speed(true)
  end
  if not (player and player.valid) then return end
  if player.force.name ~= "player" then
    --If they are not on the player force, they have already picked a team this round.
    check_force_protection(player.force)
    for k, player in pairs (game.connected_players) do
      update_team_list_frame(player)
    end
    return
  end
  player_join_lobby(player)
  player.gui.center.clear()
  if script_data.setup_finished then
    choose_joining_gui(player)
    if not script_data.match_started then
      create_start_match_gui(player)
    end
  else
    if player.admin then
      create_config_gui(player)
    else
      create_waiting_gui(player)
    end
  end
end

pvp.on_gui_selection_state_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  set_mode_input(player)
end

pvp.on_gui_checked_state_changed = function(event)
  diplomacy_check_press(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  set_mode_input(player)
end

pvp.on_player_left_game = function(event)
  for k, player in pairs (game.players) do
    local gui = player.gui.center
    if gui.pick_join_frame then
      create_pick_join_gui(gui)
    end
    if player.connected then
      update_team_list_frame(player)
    end
  end
  if script_data.map_config.protect_empty_teams then
    local player = game.players[event.player_index]
    local force = player.force
    check_force_protection(force)
  end
end

pvp.on_pre_player_left_game = function(event)
  kill_cowards(event)
end

pvp.on_gui_elem_changed = function(event)
  disable_items_elem_changed(event)
  recipe_picker_elem_changed(event)
end

pvp.on_gui_click = function(event)
  local gui = event.element
  local player = game.players[event.player_index]

  if not (player and player.valid and gui and gui.valid) then return end

  if gui.name then
    local button_function = button_press_functions[gui.name]
    if button_function then
      button_function(event)
      return
    end
  end

  trash_team_button_press(event)
  on_team_button_press(event)
  admin_frame_button_press(event)
  on_pick_join_button_press(event)
  on_calculator_button_press(event)
end

pvp.on_gui_closed = function(event)
  local gui = event.element
  if not (gui and gui.valid) then return end
  if gui.name == "diplomacy_frame" then
    gui.destroy()
    return
  end
end

pvp.on_tick = function(event)
  if script_data.setup_finished == false then
    check_starting_area_chunks_are_generated()
    finish_setup()
  end
end

pvp.on_nth_tick = {
  [5] = function(event)
    if script_data.setup_finished == true then
      check_game_speed()
    end
  end,
  [20] = function(event)
    if script_data.setup_finished == true and script_data.match_started == true then
      check_damaged_players()
    end
  end,
  [60] = function(event)
    if script_data.setup_finished == true then
      if script_data.match_started == true then
        check_no_rush()
        check_fast_blueprinting()
        check_update_production_score()
        check_update_oil_harvest_score()
        check_update_space_race_score()
        check_restart_round()
        check_base_exclusion()
        check_defcon()
        check_wrecks_corpse_timer()
      else
        check_start_match()
      end
    end
  end,
  [300] = function(event)
    if script_data.setup_finished == true then
      check_player_color()
      check_spectator_chart()
    end
  end,
  [54000] = function(event)
    if script_data.setup_finished == true then
      game.print({"msg-announce"..script_data.timer_display})
      script_data.timer_display = script_data.timer_display + 1
      if script_data.timer_display == 6 then script_data.timer_display = 1 end
    end
  end
}

function check_damaged_players()
  for k, player in pairs (game.connected_players) do
		if player.character and player.character.health ~= nil then
			local index = player.index
			local health_missing = 1 - math.ceil(player.character.health) / (250 + player.character.character_health_bonus)
      if health_missing > 0 then
        current_modifier = script_data.modifier_list.character_modifiers.character_running_speed_modifier
        local hurt_speed_percent = string.match(script_data.game_config.character_speed_when_hurt, "^([^%%]+)%%?$")
        local reduction = 1 - hurt_speed_percent / 100
        player.character_running_speed_modifier = (1 - health_missing * reduction) * (current_modifier + 1) - 1
      end
    end
  end
end

kill_cowards = function(event)
  if not script_data.game_config.kill_cowards then return end
  local player = game.players[event.player_index]
  if not player and player.valid then return end
  if not player.in_combat then return end
  local character = player.character
  if not character then game.print("has no character") return end
  character.die()
  game.print({"cowards-way-out", player.name})
end

pvp.on_chunk_generated = function(event)
  oil_harvest_prune_oil(event)
end

pvp.on_player_respawned = function(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  if script_data.setup_finished == true and script_data.match_started == true then
    config.give_equipment(player, true)
    offset_respawn_position(player)
    balance.apply_character_modifiers(player)
  else
    if player.character then
      player.character.destroy()
    end
  end
end

pvp.on_configuration_changed = function(event)
  recursive_data_check(config.get_config(), script_data)
end

pvp.on_player_display_resolution_changed = function(event)
  check_config_frame_size(event)
  check_balance_frame_size(event)
  local player = game.players[event.player_index]
  if player and player.valid then
    update_team_list_frame(player)
  end
end

pvp.on_player_driving_changed_state = function(event)
  local player = game.players[event.player_index]
  local vehicle = player.vehicle
  if not (vehicle and vehicle.valid) then return end
  if vehicle.name ~= "tank" then return end
  local tank_speed_multiplier = string.match(script_data.game_config.tank_speed, "^([^%%]+)%%?$") / 100
  vehicle.friction_modifier = 1 / (tank_speed_multiplier * tank_speed_multiplier)
end

pvp.on_research_finished = function(event)
  check_technology_for_disabled_items(event)
end

pvp.on_player_cursor_stack_changed = function(event)
  check_cursor_for_disabled_items(event)
end

pvp.on_built_entity = function(event)
  check_on_built_protection(event)
  check_neutral_chests_and_vehicles(event)
end

pvp.on_robot_built_entity = function(event)
  check_neutral_chests_and_vehicles(event)
end

pvp.on_research_started = function(event)
  if script_data.team_config.defcon_mode then
    local tech = script_data.next_defcon_tech
    if tech and tech.valid and event.research.name ~= tech.name then
      event.research.force.current_research = nil
    end
  end
end

pvp.on_player_promoted = function(event)
  local player = game.players[event.player_index]
  init_player_gui(player)
end

pvp.on_forces_merged = function (event)
  if not script_data.players_to_disband then return end
  for name, k in pairs (script_data.players_to_disband) do
    local player = game.players[name]
    if player and player.valid then
      player.force = game.forces.player
      if player.connected then
        player_join_lobby(player)
        destroy_player_gui(player)
        choose_joining_gui(player)
      end
    end
  end
  script_data.players_to_disband = nil
  create_exclusion_map()
end

pvp.on_player_changed_position = function(event)
  local player = game.players[event.player_index]
  check_player_base_exclusion(player)
  check_player_no_rush(player)
end

pvp.add_remote_interface = function()
  remote.add_interface("pvp",
  {
    get_event_name = function(name)
      return events[name]
    end,
    get_events = function()
      return events
    end,
    get_teams = function()
      return script_data.teams
    end,
    get_config = function()
      return script_data
    end,
    set_config = function(array)
      log("pvp global config set by remote call - Can expect script errors after this point.")
      script_data = array
      balance.script_data = script_data
      config.script_data = script_data
    end
  })
end

pvp.on_load = function()
  script_data = global.pvp or config.get_config()
  balance.script_data = script_data
  config.script_data = script_data
end

local script_events =
{
  [defines.events.on_built_entity] = pvp.on_built_entity,
  [defines.events.on_chunk_generated] = pvp.on_chunk_generated,
  [defines.events.on_entity_died] = pvp.on_entity_died,
  [defines.events.on_forces_merged] = pvp.on_forces_merged,
  [defines.events.on_gui_checked_state_changed] = pvp.on_gui_checked_state_changed,
  [defines.events.on_gui_click] = pvp.on_gui_click,
  [defines.events.on_gui_closed] = pvp.on_gui_closed,
  [defines.events.on_gui_elem_changed] = pvp.on_gui_elem_changed,
  [defines.events.on_gui_selection_state_changed] = pvp.on_gui_selection_state_changed,
  [defines.events.on_player_changed_position] = pvp.on_player_changed_position,
  [defines.events.on_player_driving_changed_state] = pvp.on_player_driving_changed_state,
  [defines.events.on_player_cursor_stack_changed] = pvp.on_player_cursor_stack_changed,
  [defines.events.on_player_display_resolution_changed] = pvp.on_player_display_resolution_changed,
  [defines.events.on_player_joined_game] = pvp.on_player_joined_game,
  [defines.events.on_pre_player_left_game] = pvp.on_pre_player_left_game,
  [defines.events.on_player_left_game] = pvp.on_player_left_game,
  [defines.events.on_player_promoted] = pvp.on_player_promoted,
  [defines.events.on_player_respawned] = pvp.on_player_respawned,
  [defines.events.on_research_finished] = pvp.on_research_finished,
  [defines.events.on_research_started] = pvp.on_research_started,
  [defines.events.on_robot_built_entity] = pvp.on_robot_built_entity,
  [defines.events.on_rocket_launched] = pvp.on_rocket_launched,
  [defines.events.on_tick] = pvp.on_tick
}

pvp.on_event = function(event)
  local action = script_events[event.name]
  if not action then return end
  return action(event)
end

pvp.get_event_handler = function(name)
  return script_events[name]
end

return pvp

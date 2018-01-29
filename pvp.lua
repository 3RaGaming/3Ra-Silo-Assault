require("config")
require("balance")
local mod_gui = require("mod-gui")
require("production-score")
require("util")

function create_spawn_positions()
  local config = global.map_config
  local width = config.map_width
  local height = config.map_height
  local displacement = config.average_team_displacement
  local horizontal_offset = (width/displacement) * 10
  local vertical_offset = (height/displacement) * 10
  global.spawn_offset = {x = math.floor(0.5 + math.random(-horizontal_offset, horizontal_offset) / 32) * 32, y = math.floor(0.5 + math.random(-vertical_offset, vertical_offset) / 32) * 32}
  local height_scale = height/width
  local radius = get_starting_area_radius()
  local count = #global.teams
  local max_distance = get_starting_area_radius(true) * 2 + displacement
  local min_distance = get_starting_area_radius(true) + (32 * (count - 1))
  local edge_addition = (radius + 2) * 32
  local elevator_set = false
  if height_scale == 1 then
    if max_distance > width then
      displacement = width - edge_addition
    end
  end
  if height_scale < 1 then
    if #global.teams == 2 then
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
    if #global.teams == 2 then
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
    position.x = position.x + global.spawn_offset.x
    position.y = position.y + global.spawn_offset.y
  end
  global.spawn_positions = positions
  return positions
end

function create_next_surface()
  local name = "battle_surface_1"
  if game.surfaces[name] ~= nil then
    name = "battle_surface_2"
  end
  global.round_number = global.round_number + 1
  local settings = game.surfaces[1].map_gen_settings
  settings.starting_area = global.map_config.starting_area_size.selected
  if global.map_config.biters_disabled then
    settings.autoplace_controls["enemy-base"].size = "none"
  end
  if global.map_config.seed ~= 0 then
    settings.seed = math.random(4000000000)
  else
    settings.seed = global.map_config.seed
  end
  settings.height = global.map_config.map_height
  settings.width = global.map_config.map_width
  settings.starting_points = create_spawn_positions()
  global.surface = game.create_surface(name, settings)
  global.surface.daytime = 0
  global.surface.always_day = global.map_config.always_day
end

function destroy_player_gui(player)
  local button_flow = mod_gui.get_button_flow(player)
  for k, name in pairs (
    {
      "objective_button", "diplomacy_button", "admin_button",
      "silo_gui_sprite_button", "production_score_button", "oil_harvest_button"
    }) do
    if button_flow[name] then
      button_flow[name].destroy()
    end
  end
  local frame_flow = mod_gui.get_frame_flow(player)
  for k, name in pairs (
    {
      "objective_frame", "admin_button", "admin_frame",
      "silo_gui_frame", "production_score_frame", "oil_harvest_frame"
    }) do
    if frame_flow[name] then
      frame_flow[name].destroy()
    end
  end
  local center_gui = player.gui.center
  for k, name in pairs ({"diplomacy_frame"}) do
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
  local team = global.teams[k]
  local menu = gui.add{type = "drop-down", name = k.."_color"}
  local count = 1
  for k, color in pairs (global.colors) do
    menu.add_item({color.name})
    if color.name == team.color then
      menu.selected_index = count
    end
    count = count + 1
  end
end

function add_team_to_team_table(gui, k)
  local team = global.teams[k]
  local textfield = gui.add{type = "textfield", name = k, text = team.name}
  textfield.style.maximal_width = 100
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
  local frame = gui[name]
  if frame then
    frame.clear()
  else
    frame = gui.add{type = "frame", name = name, caption = {"game-config-gui"}, direction = "vertical", style = "inner_frame"}
  end
  make_config_table(frame, global.game_config)
  create_disable_frame(frame)
end

function create_team_config_gui(gui)
  local name = "team_config_gui"
  local frame = gui[name]
  if frame then
    frame.clear()
  else
    frame = gui.add{type = "frame", name = name, caption = {"team-config-gui"}, direction = "vertical", style = "inner_frame"}
  end
  local inner_frame = frame.add{type = "frame", style = "image_frame", name = "team_config_gui_inner_frame", direction = "vertical"}
  inner_frame.style.left_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.bottom_padding = 8
  local scroll = inner_frame.add{type = "scroll-pane", name = "team_config_gui_scroll"}
  scroll.style.maximal_height = 200
  local team_table = scroll.add{type = "table", column_count = 4, name = "team_table"}
  for k, name in pairs ({"team-name", "color", "team", "remove"}) do
    team_table.add{type = "label", caption = {name}}
  end
  for k, team in pairs (global.teams) do
    add_team_to_team_table(team_table, k)
  end
  set_button_style(inner_frame.add{name = "add_team_button", type = "button", caption = {"add-team"}, tooltip = {"add-team-tooltip"}})
  make_config_table(frame, global.team_config)
end

function get_config_holder(player)
  local gui = player.gui.center
  local frame = gui.config_holding_frame
  if frame then return frame.scrollpane.horizontal_flow end
  frame = gui.add{name = "config_holding_frame", type = "frame", direction = "vertical"}
  frame.style.scaleable = false
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
  local visiblity = frame.style.visible
  frame.destroy()
  --In this case, it is better to destroy and re-create, instead of handling the sizing and scaling of all the elements in the gui
  create_config_gui(player)
  get_config_frame(player).style.visible = visiblity
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
    button_flow.add{type = "button", name = "balance_options", caption = {"balance-options"}}
    local spacer = button_flow.add{type = "flow"}
    spacer.style.horizontally_stretchable = true
    button_flow.add{type = "button", name = "config_confirm", caption = {"config-confirm"}}
  end
  set_mode_input(player)
end

function create_map_config_gui(gui)
  local name = "map_config_gui"
  local frame = gui[name]
  if frame then
    frame.clear()
  else
    frame = gui.add{type = "frame", name = name, caption = {"map-config-gui"}, direction = "vertical", style = "inner_frame"}
  end
  make_config_table(frame, global.map_config)
end

function create_waiting_gui(player)
  local gui = player.gui.center
  local frame = gui.add{type = "frame", name = "waiting_frame"}
  local label = frame.add{type = "label", caption = {"setup-in-progress"}}
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
      local character = player.character
      player.character = nil
      if character then character.destroy() end
      player.set_controller{type = defines.controllers.ghost}
      player.teleport({0,1000}, game.surfaces.Lobby)
      if player.admin then
        create_config_gui(player)
      end
    end
  end
  if global.surface ~= nil then
    game.delete_surface(global.surface)
  end
  if admin then
    game.print({"admin-ended-round", admin.name})
    print("PVPROUND$end,adminforceend," .. match_elapsed_time())
  end
  global.setup_finished = false
  global.average_deltas = nil
end

function prepare_map()
  create_next_surface()
  setup_teams()
  chart_starting_area_for_force_spawns()
  set_evolution_factor()
end

function prepare_next_round()
  global.setup_finished = false
  global.team_won = false
  prepare_map()
  local tempstring = "PVPROUND$begin," .. global.round_number .. ","
  for i = 1, #global.teams, 1 do
    local force_name = global.teams[i].name
    tempstring = tempstring .. force_name .. ","
  end
  print(tempstring:sub(1,#tempstring-1))
end

function set_mode_input(player)
  if not (player and player.valid and player.gui.center.config_holding_frame) then return end
  local visibility_map = {
    required_production_score = function(gui)
      local dropdown = gui.game_mode_dropdown
      if not dropdown then return end
      local name = global.game_config.game_mode.options[dropdown.selected_index]
      return name == "production_score"
    end,
    required_oil_barrels = function(gui)
      local dropdown = gui.game_mode_dropdown
      if not dropdown then return end
      local name = global.game_config.game_mode.options[dropdown.selected_index]
      return name == "oil_harvest"
    end,
    oil_only_in_center = function(gui)
      local dropdown = gui.game_mode_dropdown
      if not dropdown then return end
      local name = global.game_config.game_mode.options[dropdown.selected_index]
      return name == "oil_harvest"
    end,
    time_limit = function(gui)
      local dropdown = gui.game_mode_dropdown
      if not dropdown then return end
      local name = global.game_config.game_mode.options[dropdown.selected_index]
      return name == "oil_harvest" or name == "production_score"
    end,
    spectator_fog_of_war = function(gui) return gui.allow_spectators_boolean and gui.allow_spectators_boolean.state end,
    starting_chest_multiplier = function(gui)
      local dropdown = gui.starting_chest_dropdown
      local name = global.team_config.starting_chest.options[dropdown.selected_index]
      return name ~= "none"
    end,
    disband_on_loss = function(gui)
      local dropdown = gui.game_mode_dropdown
      if not dropdown then return end
      local name = global.game_config.game_mode.options[dropdown.selected_index]
      return name == "conquest" or name == "last_silo_standing"
    end,
    give_artillery_remote = function(gui)
      local option = gui.team_artillery_boolean
      if not option then return end
      return option.state
    end
  }
  local gui = get_config_holder(player)
  for k, frame in pairs ({gui.map_config_gui, gui.game_config_gui, gui.team_config_gui}) do
    if frame and frame.valid then
      local config = frame.config_table
      if (config and config.valid) then
        local children = config.children
        for k, child in pairs (children) do
          local name = child.name or ""
          local mapped = visibility_map[name]
          if mapped then
            local bool = mapped(config)
            children[k].style.visible = bool
            children[k+1].style.visible = bool
          end
        end
      end
    end
  end
end

game_mode_buttons = {
  ["production_score"] = {type = "button", caption = {"production_score"}, name = "production_score_button", style = mod_gui.button_style},
  ["oil_harvest"] = {type = "button", caption = {"oil_harvest"}, name = "oil_harvest_button", style = mod_gui.button_style}
}

function init_player_gui(player)
  destroy_player_gui(player)
  local button_flow = mod_gui.get_button_flow(player)
  button_flow.add{type = "button", caption = {"objective"}, name = "objective_button", style = mod_gui.button_style}
  local button = button_flow.add{type = "button", caption = {"diplomacy"}, name = "diplomacy_button", style = mod_gui.button_style}
  button.style.visible = #global.teams > 1 and player.force.name ~= "spectator"
  local game_mode_button = game_mode_buttons[global.game_config.game_mode.selected]
  if game_mode_button then
    button_flow.add(game_mode_button)
  end
  if player.admin then
    button_flow.add{type = "button", caption = {"admin"}, name = "admin_button", style = mod_gui.button_style}
  end
end

function fpn(n)
  return (math.floor(n*32)/32)
end

function get_color(team, lighten)
  local c = global.colors[global.color_map[team.color]].color
  if lighten then
    return {r = 1 - (1 - c[1]) * 0.5, g = 1 - (1 - c[2]) * 0.5, b = 1 - (1 - c[3]) * 0.5, a = 1}
  end
  return {r = fpn(c[1]), g = fpn(c[2]), b = fpn(c[3]), a = fpn(c[4])}
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
    diplomacy_table = gui.add{type = "table", name = "diplomacy_table", column_count = 6}
    diplomacy_table.style.horizontal_spacing = 16
    diplomacy_table.style.vertical_spacing = 8
    diplomacy_table.draw_horizontal_lines = true
    diplomacy_table.draw_vertical_lines = true
  else
    diplomacy_table.clear()
  end
  for k, name in pairs ({"team-name", "players", "stance", "enemy", "neutral", "ally"}) do
    local label = diplomacy_table.add{type = "label", name = name, caption = {name}}
    label.style.font = "default-bold"
  end
  for k, team in pairs (global.teams) do
    local force = game.forces[team.name]
    if force then
      local label = diplomacy_table.add{type = "label", name = team.name.."_name", caption = team.name}
      label.style.single_line = false
      label.style.maximal_width = 150
      label.style.font = "default-semibold"
      label.style.font_color = get_color(team, true)
      add_player_list_gui(force, diplomacy_table)
      if force.name == player.force.name then
        diplomacy_table.add{type = "label"}
        diplomacy_table.add{type = "label"}
        diplomacy_table.add{type = "label"}
        diplomacy_table.add{type = "label"}
      else
        local stance = get_stance(player.force, force)
        local their_stance = get_stance(force, player.force)
        local stance_label = diplomacy_table.add{type = "label", name = team.name.."_stance", caption = {their_stance}}
        if their_stance == "ally" then
          stance_label.style.font_color = {r = 0.5, g = 1, b = 0.5}
        elseif their_stance == "enemy" then
          stance_label.style.font_color = {r = 1, g = 0.5, b = 0.5}
        end
        diplomacy_table.add{type = "checkbox", name = team.name.."_enemy", state = (stance == "enemy")}.enabled = not global.team_config.locked_teams
        diplomacy_table.add{type = "checkbox", name = team.name.."_neutral", state = (stance == "neutral")}.enabled = not global.team_config.locked_teams
        diplomacy_table.add{type = "checkbox", name = team.name.."_ally", state = (stance == "ally")}.enabled = not global.team_config.locked_teams
      end
    end
  end
  if not flow.diplomacy_confirm then
    local button = flow.add{type = "button", name = "diplomacy_confirm", caption = {"confirm"}}
    button.enabled = not global.team_config.locked_teams
  end
end

function set_player(player, team)
  local force = game.forces[team.name]
  local surface = global.surface
  if not surface.valid then return end
  local position = surface.find_non_colliding_position("player", force.get_spawn_position(surface), 320, 1)
  if position then
    player.teleport(position, surface)
  else
    player.print({"cant-find-position"})
    choose_joining_gui(player)
    return
  end
  if player.character then
    player.character.destroy()
  end
  player.force = force
  player.color = get_color(team)
  player.chat_color = get_color(team, true)
  player.tag = "["..force.name.."]"
  player.set_controller
  {
    type = defines.controllers.character,
    character = surface.create_entity{name = "player", position = position, force = force}
  }
  init_player_gui(player)
  for k, other_player in pairs (game.players) do
    update_diplomacy_frame(other_player)
  end
  if global.game_config.team_artillery and global.game_config.give_artillery_remote and game.item_prototypes["artillery-targeting-remote"] then
    player.insert("artillery-targeting-remote")
  end
  give_inventory(player)
  give_equipment(player)

  pcall(apply_character_modifiers, player)

  game.print({"joined", player.name, player.force.name})
end

function choose_joining_gui(player)
  if #global.teams == 1 then
    local team = global.teams[1]
    local force = game.forces[team.name]
    set_player(player, team)
    return
  end
  local setting = global.team_config.team_joining.selected
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
  if not global.game_config.allow_spectators then return end
  set_button_style(gui.add{type = "button", name = "join_spectator", caption = {"join-spectator"}})
end

function create_random_join_gui(gui)
  local name = "random_join_frame"
  local frame = gui[name]
  if frame then
    frame.clear()
  else
    frame = gui.add{type = "frame", name = name, caption = {"random-join"}}
  end
  set_button_style(frame.add{type = "button", name = "random_join_button", caption = {"random-join-button"}})
  add_join_spectator_button(frame)
end


function create_auto_assign_gui(gui)
  local name = "auto_assign_frame"
  local frame = gui[name]
  if frame then
    frame.clear()
  else
    frame = gui.add{type = "frame", name = name, caption = {"auto-assign"}}
  end
  set_button_style(frame.add{type = "button", name = "auto_assign_button", caption = {"auto-assign-button"}})
  add_join_spectator_button(frame)
end

function create_pick_join_gui(gui)
  local name = "pick_join_frame"
  local frame = gui[name]
  if frame then
    frame.clear()
  else
    frame = gui.add{type = "frame", name = name, caption = {"pick-join"}, direction = "vertical"}
  end
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
  for k, team in pairs (global.teams) do
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
  for k, team in pairs (global.teams) do
    if team_name == team.name then
      joined_team = team
      break
    end
  end
  if not joined_team then return end
  local force = game.forces[joined_team.name]
  if not force then return end
  set_player(player, joined_team)
  player.gui.center.clear()

  for k, player in pairs (game.forces.player.players) do
    create_pick_join_gui(player.gui.center)
  end

end

function add_team_button_press(event)
  local gui = event.element
  local index = #global.teams + 1
  for k = 1, index do
    if not global.teams[k] then
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
  local color = global.colors[(1+index%(#global.colors))]
  local name = color.name.." "..index
  local team = {name = name, color = color.name, team = "-"}
  global.teams[index] = team
  for k, player in pairs (game.players) do
    local gui = get_config_holder(player).team_config_gui
    if gui then
      add_team_to_team_table(gui.team_config_gui_inner_frame.team_config_gui_scroll.team_table, index)
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
  for k, team in pairs (global.teams) do
    count = count + 1
  end
  if count > 1 then
    global.teams[team_index] = nil
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
      local children = gui.team_config_gui_inner_frame.team_config_gui_scroll.team_table.children
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
  local disallow =
  {
    ["player"] = true,
    ["enemy"] = true,
    ["neutral"] = true,
    ["spectator"] = true
  }
  local duplicates = {}
  local team_table = gui.team_config_gui_inner_frame.team_config_gui_scroll.team_table
  local children = team_table.children
  local index = 1
  local element = team_table[index]
  while element and element.valid do
    local text = element.text
    if disallow[text] then
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
    team.color = global.colors[team_table[index.."_color"].selected_index].name
    local caption = team_table[index.."_next_team_button"].caption
    team.team = tonumber(caption) or caption
    table.insert(teams, team)
    index = index + 1
    element = team_table[index]
  end
  if #teams > 24 then
    player.print({"too-many-teams", 24})
    return
  end
  global.teams = teams
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
      index = #global.teams
    end
  elseif index == tostring(#global.teams) then
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
      config.style.visible = true
    end
    return
  end
  if config then
    config.style.visible = false
  end
  frame = gui.add{name = "balance_options_frame", type = "frame", direction = "vertical", caption = {"balance-options"}}
  frame.style.scaleable = false
  frame.style.maximal_height = player.display_resolution.height * 0.95
  frame.style.maximal_width = player.display_resolution.width * 0.95
  local scrollpane = frame.add{name = "balance_options_scrollpane", type = "scroll-pane"}
  local big_table = scrollpane.add{type = "table", column_count = 4, name = "balance_options_big_table", direction = "horizontal"}
  big_table.style.horizontal_spacing = 32
  big_table.draw_vertical_lines = true
  local entities = game.entity_prototypes
  for modifier_name, array in pairs (global.modifier_list) do
    local flow = big_table.add{type = "frame", name = modifier_name.."_flow", caption = {modifier_name}, style = "inner_frame"}
    local table = flow.add{name = modifier_name.."table", type = "table", column_count = 2}
    table.style.column_alignments[2] = "right"
    for name, modifier in pairs (array) do
      if modifier_name == "ammo_damage_modifier" then
        local string = "ammo-category-name."..name
        table.add{type = "label", caption = {"", {"ammo-category-name."..name}, {"colon"}}}
      elseif modifier_name == "gun_speed_modifier" then
        table.add{type = "label", caption = {"", {"ammo-category-name."..name}, {"colon"}}}
      elseif modifier_name == "turret_attack_modifier" then
        table.add{type = "label", caption = {"", entities[name].localised_name, {"colon"}}}
      elseif modifier_name == "character_modifiers" then
        table.add{type = "label", caption = {"", {name}, {"colon"}}}
      end
      local input = table.add{name = name.."text", type = "textfield"}
      input.text = modifier
      input.style.maximal_width = 50
    end
  end
  local flow = frame.add{type = "flow", direction = "horizontal"}
  flow.style.horizontally_stretchable = true
  flow.style.align = "right"
  flow.add{type = "button", name = "balance_options_confirm", caption = {"balance-confirm"}}
  flow.add{type = "button", name = "balance_options_cancel", caption = {"cancel"}}
end

function create_disable_frame(gui)
  local frame = gui.disable_items_frame
  if gui.disable_items_frame then
    gui.disable_items_frame.clear()
  else
    frame = gui.add{name = "disable_items_frame", type = "frame", direction = "vertical", style = "inner_frame"}
    --frame.style.horizontally_stretchable = true
  end
  local label = frame.add{type = "label", caption = {"", {"disabled-items"}, {"colon"}}}
  local disable_table = frame.add{type = "table", name = "disable_items_table", column_count = 7}
  disable_table.style.horizontal_spacing = 2
  disable_table.style.vertical_spacing = 2
  local items = game.item_prototypes
  if global.disabled_items then
    for item, bool in pairs (global.disabled_items) do
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
  local frame =gui.balance_options_frame
  local scroll = frame.balance_options_scrollpane
  local table = scroll.balance_options_big_table
  for modifier_name, array in pairs (global.modifier_list) do
    local flow = table[modifier_name.."_flow"]
    local modifier_table = flow[modifier_name.."table"]
    if modifier_table then
      for name, modifier in pairs (array) do
        local text = modifier_table[name.."text"].text
        if text then
          local n = tonumber(text)
          if n == nil then
            player.print({"must-be-number", {modifier_name}})
            return
          end
          if n < -1 then
            player.print({"must-be-greater-than-negative-1", {modifier_name}})
            return
          end
          global.modifier_list[modifier_name][name] = n
        end
      end
    end
  end
  return true
end

function config_confirm(gui)
  local player = game.players[gui.player_index]
  if not set_teams_from_gui(player) then return end
  local frame = get_config_holder(player)
  if not parse_config_from_gui(frame.map_config_gui, global.map_config) then return end
  if not parse_config_from_gui(frame.game_config_gui, global.game_config) then return end
  if not parse_config_from_gui(frame.team_config_gui, global.team_config) then return end
  destroy_config_for_all()
  prepare_next_round()
end

function auto_assign(player)
  local force
  local team
  repeat
    local index = math.random(#global.teams)
    team = global.teams[index]
    force = game.forces[team.name]
  until force ~= nil
  local count = #force.connected_players
  for k, this_team in pairs (global.teams) do
    local other_force = game.forces[this_team.name]
    if other_force ~= nil then
      if #other_force.connected_players < count then
        count = #other_force.connected_players
        force = other_force
        team = this_team
      end
    end
  end
  set_player(player, team)
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
  local n = global.map_config.evolution_factor
  if n >= 1 then
    n = 1
  end
  if n <= 0 then
    n = 0
  end
  game.forces.enemy.evolution_factor = n
  global.map_config.evolution_factor = n
end

function random_join(player)
  local force
  local team
  repeat
    local index = math.random(#global.teams)
    team = global.teams[index]
    force = game.forces[team.name]
  until force ~= nil
  set_player(player, team)
end

function spectator_join(player)
  if player.character then player.character.destroy() end
  player.set_controller{type = defines.controllers.ghost}
  player.force = "spectator"
  player.teleport(global.spawn_offset, global.surface)
  init_player_gui(player)
  game.print({"joined-spectator", player.name})
end

function objective_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.objective_frame
  if frame then
    frame.style.visible = not frame.style.visible
    return
  end
  frame = flow.add{type = "frame", name = "objective_frame", caption = {"objective"}, direction = "vertical"}
  frame.style.visible = true
  local big_label = frame.add{type = "label", caption = {global.game_config.game_mode.selected.."_description"}}
  big_label.style.single_line = false
  big_label.style.font = "default-bold"
  big_label.style.top_padding = 0
  big_label.style.maximal_width = 300
  local label_table = frame.add{type = "table", column_count = 2}
  for k, name in pairs ({"friendly_fire", "locked_teams", "team_joining", "spawn_position"}) do
    label_table.add{type = "label", caption = {"", {name}, {"colon"}}, tooltip = {name.."_tooltip"}}
    local setting = global.team_config[name]
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
  if global.disabled_items then
    label_table.add{type = "label", caption = {"", {"disabled-items", {"colon"}}}}
    local flow = label_table.add{type = "table", column_count = 4}
    flow.style.horizontal_spacing = 2
    flow.style.vertical_spacing = 2
    local items = game.item_prototypes
    for item, bool in pairs (global.disabled_items) do
      if items[item] then
        flow.add{type = "sprite", sprite = "item/"..item, tooltip = items[item].localised_name}
      end
    end
  end
end

function admin_button_press(event)
  local gui = event.element
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  if flow.admin_frame then
    flow.admin_frame.style.visible = not flow.admin_frame.style.visible
    return
  end
  local frame = flow.add{type = "frame", caption = {"admin"}, name = "admin_frame"}
  frame.style.visible = true
  set_button_style(frame.add{type = "button", caption = {"end-round"}, name = "admin_end_round", tooltip = {"end-round-tooltip"}})
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
  frame.style.visible = true
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
  if not global.round_start_tick then return "Invalid" end
  if not global.game_config.time_limit then return "Invalid" end
  return formattime((math.max(global.round_start_tick + (global.game_config.time_limit * 60 * 60) - game.tick, 0)))
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
  if global.game_config.required_production_score > 0 then
    frame.add{type = "label", caption = {"", {"required_production_score"}, {"colon"}, " ", util.format_number(global.game_config.required_production_score)}}
  end
  if global.game_config.time_limit > 0 then
    frame.add{type = "label", caption = {"time_left", get_time_left()}, name = "time_left"}
  end
  local inner_frame = frame.add{type = "frame", style = "image_frame", name = "production_score_inner_frame", direction = "vertical"}
  inner_frame.style.left_padding = 8
  inner_frame.style.top_padding = 8
  inner_frame.style.right_padding = 8
  inner_frame.style.bottom_padding = 8
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
  for k, team in pairs (global.teams) do
    team_map[team.name] = team
  end
  local deltas = global.average_deltas or {}
  local rank = 1
  for name, score in spairs (global.production_scores, function(t, a, b) return t[b] < t[a] end) do
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
      local delta_score = deltas[name] or 0
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
  if global.game_config.required_oil_barrels > 0 then
    frame.add{type = "label", caption = {"", {"required_oil_barrels"}, {"colon"}, " ", util.format_number(global.game_config.required_oil_barrels)}}
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
  for k, team in pairs (global.teams) do
    team_map[team.name] = team
  end
  if not global.oil_harvest_scores then
    global.oil_harvest_scores = {}
  end
  local rank = 1
  for name, score in spairs (global.oil_harvest_scores, function(t, a, b) return t[b] < t[a] end) do
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
      rank = rank + 1
    end
  end
end

function diplomacy_confirm(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end
  if global.team_config.locked_teams then
    player.print({"locked-teams"})
    return
  end
  if global.team_config.who_decides_diplomacy.selected == "team_leader" then
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
  if global.team_config.locked_teams then
    gui.state = not gui.state
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
  if not global.inventory_list then return end
  if not global.inventory_list[global.team_config.starting_inventory.selected] then return end
  local list = global.inventory_list[global.team_config.starting_inventory.selected]
  for name, count in pairs (list) do
    if game.item_prototypes[name] then
      player.insert{name = name, count = count}
    else
      game.print(name.." is not a valid item")
    end
  end
end

function setup_teams()
  local ignore =
  {
    ["player"] = true,
    ["enemy"] = true,
    ["neutral"] = true,
    ["spectator"] = true
  }
  local spectator = game.forces["spectator"]
  if not (spectator and spectator.valid) then
    spectator = game.create_force("spectator")
  end

  for name, force in pairs (game.forces) do
    if not ignore[name] then
      game.merge_forces(name, "player")
    end
  end
  for k, team in pairs (global.teams) do
    local new_team
    if game.forces[team.name] then
      new_team = game.forces[team.name]
      log("In function 'setup_teams' something went wrong where a team which should have been merged into player was still valid")
    else
      new_team = game.create_force(team.name)
    end
    new_team.reset()
    set_spawn_position(k, new_team, global.surface)
    set_random_team(team)
  end
  for k, team in pairs (global.teams) do
    local force = game.forces[team.name]
    force.set_friend(spectator, true)
    spectator.set_friend(force, true)
    set_diplomacy(team)
    setup_research(force)
    disable_combat_technologies(force)
    force.reset_technology_effects()
    pcall(apply_combat_modifiers, force)
  end
  disable_items_for_all()
end

function disable_items_for_all()
  if not global.disabled_items then return end
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
  for name, k in pairs (global.disable_items) do
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

function set_random_team(team)
  if tonumber(team.team) then return end
  if team.team == "-" then return end
  team.team = "?"..math.random(#global.teams)
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
  for k, other_team in pairs (global.teams) do
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
  local setting = global.team_config.spawn_position.selected
  if setting == "fixed" then
    local position = global.spawn_positions[k]
    force.set_spawn_position(position, surface)
    return
  end
  if setting == "random" then
    local position
    local index
    repeat
      index = math.random(1, #global.spawn_positions)
      position = global.spawn_positions[index]
    until position ~= nil
    force.set_spawn_position(position, surface)
    table.remove(global.spawn_positions, index)
    return
  end
  if setting == "team_together" then
    if k == #global.spawn_positions then
      set_team_together_spawns(surface)
    end
  end
end

function set_team_together_spawns(surface)
  local grouping = {}
  for k, team in pairs (global.teams) do
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
        local position = global.spawn_positions[count]
        if position then
          force.set_spawn_position(position, surface)
          count = count + 1
        end
      end
    end
  end
end

function chart_starting_area_for_force_spawns()
  local surface = global.surface
  local radius = get_starting_area_radius()
  local size = radius*32
  for k, team in pairs (global.teams) do
    local name = team.name
    local force = game.forces[name]
    if force ~= nil then
      local origin = force.get_spawn_position(surface)
      local area = {{origin.x - size, origin.y - size},{origin.x + (size - 32), origin.y + (size - 32)}}
      surface.request_to_generate_chunks(origin, radius)
      force.chart(surface, area)
    end
  end
  global.check_starting_area_generation = true
end

function check_starting_area_chunks_are_generated()
  if not global.check_starting_area_generation then return end
  if game.tick % (#global.teams) ~= 0 then return end
  local surface = global.surface
  local size = global.map_config.starting_area_size.selected
  local check_radius = get_starting_area_radius() - 1
  local total = 0
  local generated = 0
  local width = surface.map_gen_settings.width/2
  local height = surface.map_gen_settings.height/2
  local abs = math.abs
  for k, team in pairs (global.teams) do
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
  global.progress = generated/total
  if total == generated then
    game.speed = 1
    global.check_starting_area_generation = false
    global.finish_setup = game.tick +(#global.teams)
    update_progress_bar(true)
    return
  end
  update_progress_bar()
end

function check_player_color()
  if game.tick % 300 ~= 0 then return end
  local color_map = {}
  for k, team in pairs (global.teams) do
    color_map[team.name] = get_color(team)
  end
  for k, player in pairs (game.connected_players) do
    local c = color_map[player.force.name]
    if c then
      if (fpn(player.color.r) ~= fpn(c.r)) or (fpn(player.color.g) ~= fpn(c.g)) or (fpn(player.color.b) ~= fpn(c.b)) then
        player.color = c
        player.chat_color = c
        game.print({"player-color-changed-back", player.name})
      end
    end
  end
end

function check_no_rush()
  if not global.end_no_rush then return end
  if game.tick % 60 ~= 0 then return end
  if game.tick > global.end_no_rush then
    if global.game_config.no_rush_time > 0 then
      game.print({"no-rush-ends"})
    end
    global.end_no_rush = nil
    global.surface.peaceful_mode = global.map_config.peaceful_mode
    game.forces.enemy.kill_all_units()
    return
  end
  local radius = get_starting_area_radius(true)
  local surface = global.surface
  for k, player in pairs (game.connected_players) do
    local force = player.force
    if (force.name ~= "player" and force.name ~= "spectator") then
      local origin = force.get_spawn_position(surface)
      local Xo = origin.x
      local Yo = origin.y
      local position = player.position
      local Xp = position.x
      local Yp = position.y
      if Xp > (Xo + radius) then
        Xp = Xo + (radius - 5)
      elseif Xp < (Xo - radius) then
        Xp = Xo - (radius - 5)
      end
      if Yp > (Yo + radius) then
        Yp = Yo + (radius - 5)
      elseif Yp < (Yo - radius) then
        Yp = Yo - (radius - 5)
      end
      if position.x ~= Xp or position.y ~= Yp then
        local new_position = {x = Xp, y = Yp}
        local vehicle = player.vehicle
        if vehicle then
          new_position = surface.find_non_colliding_position(vehicle.name, new_position, 32, 1) or new_position
          if not vehicle.teleport(new_position) then
            player.driving = false
          end
          vehicle.orientation = vehicle.orientation + 0.5
        elseif player.character then
          new_position = surface.find_non_colliding_position(player.character.name, new_position, 32, 1) or new_position
          player.teleport(new_position)
        else
          player.teleport(new_position)
        end
        local time_left = math.ceil((global.end_no_rush-game.tick)/3600)
        player.print({"no-rush-teleport", time_left})
      end
    end
  end
end

function check_update_production_score()
  if global.game_config.game_mode.selected ~= "production_score" then return end
  local tick = game.tick
  if global.team_won or tick % 60 ~= 0 then return end
  local new_scores = production_score.get_production_scores(global.price_list)
  local old_scores = global.production_scores or new_scores
  local index = tick % (60 * 60) --Average the deltas 1 minute.
  local old_deltas = global.previous_deltas or {}
  local average_deltas = global.average_deltas or {}
  for team, score in pairs (new_scores) do
    if not old_deltas[team] then old_deltas[team] = {} end
    if not old_deltas[team][index] then old_deltas[team][index] = 0 end
    local old_delta = old_deltas[team][index]
    local new_delta = (score - (old_scores[team] or 0))
    old_deltas[team][index] = new_delta
    average_deltas[team] = ((average_deltas[team] or 0) - old_delta) + new_delta
  end
  global.production_scores = new_scores
  global.previous_deltas = old_deltas
  global.average_deltas = average_deltas
  for k, player in pairs (game.players) do
    update_production_score_frame(player)
  end
  local required = global.game_config.required_production_score
  if required > 0 then
    for team_name, score in pairs (global.production_scores) do
      if score >= required then
        team_won(team_name)
      end
    end
  end
  if global.game_config.time_limit > 0 and tick > global.round_start_tick + (global.game_config.time_limit * 60 * 60) then
    local winner = {"none"}
    local winning_score = 0
    for team_name, score in pairs (global.production_scores) do
      if score > winning_score then
        winner = team_name
        winning_score = score
      end
    end
    team_won(winner)
  end
end

function check_update_oil_harvest_score()
  if global.game_config.game_mode.selected ~= "oil_harvest" then return end
  if global.team_won or game.tick % 60 ~= 0 then return end
  local item_to_check = "crude-oil-barrel"
  if not game.item_prototypes[item_to_check] then error("Playing oil harvest game mode when crude oil barrels don't exist") end
  local scores = {}
  for force_name, force in pairs (game.forces) do
    local statistics = force.item_production_statistics
    local input = statistics.get_input_count(item_to_check)
    local output = statistics.get_output_count(item_to_check)
    scores[force_name] = input - output
  end
  global.oil_harvest_scores = scores
  for k, player in pairs (game.players) do
    update_oil_harvest_frame(player)
  end
  local required = global.game_config.required_oil_barrels
  if required > 0 then
    for team_name, score in pairs (global.oil_harvest_scores) do
      if score >= required then
        team_won(team_name)
      end
    end
  end
  if global.game_config.time_limit > 0 and game.tick > (global.round_start_tick + (global.game_config.time_limit * 60 * 60)) then
    local winner = {"none"}
    local winning_score = 0
    for team_name, score in pairs (global.oil_harvest_scores) do
      if score > winning_score then
        winner = team_name
        winning_score = score
      end
    end
    team_won(winner)
  end
end

function finish_setup()
  if not global.finish_setup then return end
  local index = global.finish_setup - game.tick
  local surface = global.surface
  if index == 0 then
    final_setup_step()
    return
  end
  local name = global.teams[index].name
  if not name then return end
  local force = game.forces[name]
  if not force then return end
  create_silo_for_force(force)
  local radius = get_starting_area_radius(true) --[[radius in tiles]]
  if global.game_config.reveal_team_positions then
    for k, other_force in pairs (game.forces) do
      chart_area_for_force(surface, force.get_spawn_position(surface), radius, other_force)
    end
  end
  create_wall_for_force(force)
  create_starting_chest(force)
  create_starting_turrets(force)
  create_starting_artillery(force)
  force.friendly_fire = global.team_config.friendly_fire
  force.share_chart = global.team_config.share_chart
  local hide_crude_recipe_in_stats = global.game_config.game_mode.selected ~= "oil_harvest"
  local fill_recipe = force.recipes["fill-crude-oil-barrel"]
  if fill_recipe then
    fill_recipe.hidden_from_flow_stats = hide_crude_recipe_in_stats
  end
  local empty_recipe = force.recipes["empty-crude-oil-barrel"]
  if empty_recipe then
    empty_recipe.hidden_from_flow_stats = hide_crude_recipe_in_stats
  end
end

function final_setup_step()
  local surface = global.surface
  duplicate_starting_area_entities()
  global.finish_setup = nil
  game.print({"map-ready"})
  global.setup_finished = true
  global.round_start_tick = game.tick
  for k, player in pairs (game.connected_players) do
    destroy_player_gui(player)
    player.teleport({0, 1000}, "Lobby")
    choose_joining_gui(player)
  end
  global.end_no_rush = game.tick + (global.game_config.no_rush_time * 60 * 60)
  if global.game_config.no_rush_time > 0 then
    global.surface.peaceful_mode = true
    game.forces.enemy.kill_all_units()
    game.print({"no-rush-begins", global.game_config.no_rush_time})
  end
  global.exclusion_map = nil
  if global.game_config.base_exclusion_time > 0 then
    global.check_base_exclusion = true
    game.print({"base-exclusion-begins", global.game_config.base_exclusion_time})
  end
  if global.game_config.reveal_map_center then
    local radius = global.map_config.average_team_displacement/2
    local origin = global.spawn_offset
    local area = {{origin.x - radius, origin.y - radius}, {origin.x + (radius - 32), origin.y + (radius - 32)}}
    for k, force in pairs (game.forces) do
      force.chart(surface, area)
    end
  end
end

function chart_area_for_force(surface, origin, radius, force)
  if not force.valid then return end
  if (not origin.x) or (not origin.y) then
    game.print ("No valid value in position array")
    return
  end
  local area = {{origin.x - radius, origin.y - radius}, {origin.x + (radius - 32), origin.y + (radius - 32)}}
  force.chart(surface, area)
end

function update_progress_bar()
  if not global.progress then return end
  local percent = global.progress
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
    global.progress = nil
    global.setup_duration = nil
    global.finish_tick = nil
  end
end

function create_silo_for_force(force)
  local condition = global.game_config.game_mode.selected
  local need_silo = {conquest = true, space_race = true, last_silo_standing = true}
  if not need_silo[condition] then return end
  if not force then return end
  if not force.valid then return end
  local surface = global.surface
  local origin = force.get_spawn_position(surface)
  local offset_x = 0
  local offset_y = -25
  local silo_position = {origin.x+offset_x, origin.y+offset_y}
  local area = {{silo_position[1]-5,silo_position[2]-6},{silo_position[1]+6, silo_position[2]+6}}
  for i, entity in pairs(surface.find_entities_filtered({area = area, force = "neutral"})) do
    entity.destroy()
  end
  local silo = surface.create_entity{name = "rocket-silo", position = silo_position, force = force}
  silo.minable = false
  silo.backer_name = tostring(force.name)
  local tiles_1 = {}
  local tiles_2 = {}
  for X = -5, 5 do
    for Y = -6, 5 do
      table.insert(tiles_2, {name = "hazard-concrete-left", position = {silo_position[1]+X, silo_position[2]+Y}})
    end
  end
  surface.set_tiles(tiles_2)
  if global.game_config.game_mode.selected ~= "space_race" then
    if not global.silos then global.silos = {} end
    global.silos[force.name] = silo
  end
end

function setup_research(force)
  if not force then return end
  if not force.valid then return end
  local tier = global.team_config.research_level.selected
  local index
  local set = (tier ~= "none")
  for k, name in pairs (global.team_config.research_level.options) do
    if global.research_ingredient_list[name] ~= nil then
      global.research_ingredient_list[name] = set
    end
    if name == tier then set = false end
  end
  --[[Unlocks all research, and then unenables them based on a blacklist]]
  force.research_all_technologies()
  for k, technology in pairs (force.technologies) do
    for j, ingredient in pairs (technology.research_unit_ingredients) do
      if not global.research_ingredient_list[ingredient.name] then
        technology.researched = false
        break
      end
    end
  end
end

function create_starting_turrets(force)
  if not global.game_config.team_turrets then return end
  if not (force and force.valid) then return end
  local turret_name = "gun-turret"
  if not game.entity_prototypes[turret_name] then return end
  local ammo_name = "piercing-rounds-magazine"
  if not game.item_prototypes[ammo_name] then return end
  local surface = global.surface
  local height = global.map_config.map_height/2
  local width = global.map_config.map_width/2
  local origin = force.get_spawn_position(surface)
  local radius = get_starting_area_radius(true) - 18 --[[radius in tiles]]
  local limit = math.min(width - math.abs(origin.x), height - math.abs(origin.y)) - 6
  radius = math.min(radius, limit)
  local positions = {}
  local Xo = origin.x
  local Yo = origin.y
  for X = -radius, radius do
    local Xt = X + Xo
    if X == -radius then
      for Y = -radius, radius do
        local Yt = Y + Yo
        if (Yt + 16) % 32 ~= 0 and Yt % 8 == 0 then
          table.insert(positions, {x = Xo - radius, y = Yt, direction = defines.direction.west})
          table.insert(positions, {x = Xo + radius, y = Yt, direction = defines.direction.east})
        end
      end
    elseif (Xt + 16) % 32 ~= 0 and Xt % 8 == 0 then
      table.insert(positions, {x = Xt, y = Yo - radius, direction = defines.direction.north})
      table.insert(positions, {x = Xt, y = Yo + radius, direction = defines.direction.south})
    end
  end
  local tiles = {}
  local tile_name = "hazard-concrete-left"
  local stack = {name = ammo_name, count = 20}
  for k, position in pairs (positions) do
    local area = {{x = position.x - 1, y = position.y - 1},{x = position.x + 1, y = position.y + 1}}
    for k, entity in pairs (surface.find_entities_filtered{area = area, force = "neutral"}) do
      entity.destroy()
    end
    local turret = surface.create_entity{name = turret_name, position = position, force = force, direction = position.direction}
    turret.insert(stack)
    table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y}})
    table.insert(tiles, {name = tile_name, position = {x = position.x - 1, y = position.y}})
    table.insert(tiles, {name = tile_name, position = {x = position.x, y = position.y - 1}})
    table.insert(tiles, {name = tile_name, position = {x = position.x - 1, y = position.y - 1}})
  end
  surface.set_tiles(tiles)
end

function create_starting_artillery(force)
  if not global.game_config.team_artillery then return end
  if not (force and force.valid) then return end
  local turret_name = "artillery-turret"
  if not game.entity_prototypes[turret_name] then return end
  local ammo_name = "artillery-shell"
  if not game.item_prototypes[ammo_name] then return end
  local surface = global.surface
  local height = global.map_config.map_height/2
  local width = global.map_config.map_width/2
  local origin = force.get_spawn_position(surface)
  local size = global.map_config.starting_area_size.selected
  local radius = get_starting_area_radius() - 1 --[[radius in chunks]]
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
  local tile_name = "hazard-concrete-left"
  for k, position in pairs (positions) do
    local turret = surface.create_entity{name = turret_name, position = position, force = force, direction = position.direction}
    turret.insert(stack)
    for k, entity in pairs (surface.find_entities_filtered{area = turret.selection_box, force = "neutral"}) do
      entity.destroy()
    end
    for x = -1, 1 do
      for y = -1, 1 do
        table.insert(tiles, {name = tile_name, position = {position.x + x, position.y + y}})
      end
    end
  end
  surface.set_tiles(tiles)
end

function create_wall_for_force(force)
  if not global.game_config.team_walls then return end
  if not force.valid then return end
  local surface = global.surface
  local height = global.map_config.map_height/2
  local width = global.map_config.map_width/2
  local origin = force.get_spawn_position(surface)
  local size = global.map_config.starting_area_size.selected
  local radius = get_starting_area_radius(true) - 13 --[[radius in tiles]]
  local limit = math.min(width - math.abs(origin.x), height - math.abs(origin.y)) - 1
  radius = math.min(radius, limit)
  local perimeter_top = {}
  local perimeter_bottom = {}
  local perimeter_left = {}
  local perimeter_right = {}
  local tiles = {}
  local insert = table.insert
  for X = -radius, radius-1 do
    for Y = -radius, radius-1 do
      if X == -radius then
        insert(perimeter_left, {origin.x + X, origin.y + Y})
      elseif X == radius -1 then
        insert(perimeter_right, {origin.x + X, origin.y + Y})
      end
      if Y == -radius then
        insert(perimeter_top, {origin.x + X, origin.y + Y})
      elseif Y == radius -1 then
        insert(perimeter_bottom, {origin.x + X, origin.y + Y})
      end
    end
  end
  local tile_name = "concrete"
  local areas = {
    {{perimeter_top[1][1], perimeter_top[1][2]-1}, {perimeter_top[#perimeter_top][1], perimeter_top[1][2]+2}},
    {{perimeter_bottom[1][1], perimeter_bottom[1][2]-2}, {perimeter_bottom[#perimeter_bottom][1], perimeter_bottom[1][2]+1}},
    {{perimeter_left[1][1]-1, perimeter_left[1][2]}, {perimeter_left[1][1]+2, perimeter_left[#perimeter_left][2]}},
    {{perimeter_right[1][1]-2, perimeter_right[1][2]}, {perimeter_right[1][1]+1, perimeter_right[#perimeter_right][2]}},
  }
  for k, area in pairs (areas) do
    for i, entity in pairs(surface.find_entities_filtered({area = area})) do
      entity.destroy()
    end
  end
  for k, position in pairs (perimeter_left) do
    insert(tiles, {name = tile_name, position = {position[1],position[2]}})
    insert(tiles, {name = tile_name, position = {position[1]+1,position[2]}})
    if (position[2] % 32 == 14) or (position[2] % 32 == 15) or (position[2] % 32 == 16) or (position[2] % 32 == 17) then
      surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 0, force = force}
    else
      surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
    end
  end
  for k, position in pairs (perimeter_right) do
    insert(tiles, {name = tile_name, position = {position[1]-1,position[2]}})
    insert(tiles, {name = tile_name, position = {position[1],position[2]}})
    if (position[2] % 32 == 14) or (position[2] % 32 == 15) or (position[2] % 32 == 16) or (position[2] % 32 == 17) then
      surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 0, force = force}
    else
      surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
    end
  end
  for k, position in pairs (perimeter_top) do
    insert(tiles, {name = tile_name, position = {position[1],position[2]}})
    insert(tiles, {name = tile_name, position = {position[1],position[2]+1}})
    if (position[1] % 32 == 14) or (position[1] % 32 == 15) or (position[1] % 32 == 16) or (position[1] % 32 == 17) then
      surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 2, force = force}
    else
      surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
    end
  end
  for k, position in pairs (perimeter_bottom) do
    insert(tiles, {name = tile_name, position = {position[1],position[2]-1}})
    insert(tiles, {name = tile_name, position = {position[1],position[2]}})
    if (position[1] % 32 == 14) or (position[1] % 32 == 15) or (position[1] % 32 == 16) or (position[1] % 32 == 17) then
      surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 2, force = force}
    else
      surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
    end
  end
  surface.set_tiles(tiles)
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

function verify_oil_harvest()
  if game.item_prototypes["crude-oil-barrel"] and game.entity_prototypes["crude-oil"] and game.recipe_prototypes["fill-crude-oil-barrel"] and game.recipe_prototypes["empty-crude-oil-barrel"] then return end
  for k, mode in pairs (global.game_config.game_mode.options) do
    if mode == "oil_harvest" then
      table.remove(global.game_config.game_mode.options, k)
      log("Oil harvest mode removed from scenario, as oil barrels and crude oil were not present in this configuration.")
      break
    end
  end
end

function oil_harvest_prune_oil(event)
  if global.game_config.game_mode.selected ~= "oil_harvest" then return end
  if not global.game_config.oil_only_in_center then return end
  local area = event.area
  local center = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
  local distance_from_center = (center.x*center.x + center.y*center.y)^0.5
  if distance_from_center > global.map_config.average_team_displacement/2.5 then
    for k, entity in pairs (event.surface.find_entities_filtered{area = area, name = "crude-oil"}) do
      entity.destroy()
    end
  end
end

button_press_functions = {
  ["add_team_button"] = add_team_button_press,
  ["admin_button"] = admin_button_press,
  ["auto_assign_button"] = function(event) event.element.parent.destroy() auto_assign(game.players[event.player_index]) end,
  ["balance_options_cancel"] = function(event) toggle_balance_options_gui(game.players[event.player_index]) end,
  ["balance_options_confirm"] = function(event) local player = game.players[event.player_index]  if set_balance_settings(player) then toggle_balance_options_gui(player) end end,
  ["balance_options"] = function(event) toggle_balance_options_gui(game.players[event.player_index]) end,
  ["config_confirm"] = function(event) config_confirm(event.element) end,
  ["diplomacy_button"] = diplomacy_button_press,
  ["diplomacy_cancel"] = function(event) game.players[event.player_index].opened.destroy() end,
  ["diplomacy_confirm"] = diplomacy_confirm,
  ["join_spectator"] = function(event) event.element.parent.destroy() spectator_join(game.players[event.player_index]) end,
  ["objective_button"] = objective_button_press,
  ["oil_harvest_button"] = oil_harvest_button_press,
  ["production_score_button"] = production_score_button_press,
  ["random_join_button"] = function(event) event.element.parent.destroy() random_join(game.players[event.player_index]) end,
}

function duplicate_starting_area_entities()
  if not global.map_config.duplicate_starting_area_entities then return end
  local copy_team = global.teams[1]
  if not copy_team then return end
  local force = game.forces[copy_team.name]
  if not force then return end
  local surface = global.surface
  local origin_spawn = force.get_spawn_position(surface)
  local radius = get_starting_area_radius(true) --[[radius in tiles]]
  local area = {{origin_spawn.x - radius, origin_spawn.y - radius}, {origin_spawn.x + radius, origin_spawn.y + radius}}
  local entities = surface.find_entities_filtered{area = area, force = "neutral"}
  local insert = table.insert
  local tiles = {}
  local counts = {}
  local ignore_counts = {
    ["concrete"] = true,
    ["water"] = true,
    ["deepwater"] = true,
    ["hazard-concrete-left"] = true
  }
  local tile_map = {}
  for name, tile in pairs (game.tile_prototypes) do
    tile_map[name] = tile.collision_mask["resource-layer"] ~= nil
    counts[name] = surface.count_tiles_filtered{name = name, area = area}
  end
  local tile_name = "grass-1"
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

  for k, team in pairs (global.teams) do
    if team.name ~= copy_team.name then
      local force = game.forces[team.name]
      if force then
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
          local position = {x = (tile.position.x - origin_spawn.x) + spawn.x, y = (tile.position.y - origin_spawn.y) + spawn.y}
          insert(set_tiles, {name = tile.name, position = position})
        end
        surface.set_tiles(set_tiles)
        for k, entity in pairs (entities) do
          if entity.valid then
            local position = {x = (entity.position.x - origin_spawn.x) + spawn.x, y = (entity.position.y - origin_spawn.y) + spawn.y}
            local type = entity.type
            local amount = (type == "resource" and entity.amount) or nil
            local cliff_orientation = (type == "cliff" and entity.cliff_orientation) or nil
            surface.create_entity{name = entity.name, position = position, force = "neutral", amount = amount, cliff_orientation = cliff_orientation}
          end
        end
      end
    end
  end
end

function check_spectator_chart()
  --if not global.game_config.allow_spectators then return end
  if global.game_config.spectator_fog_of_war then return end
  if game.tick % 281 ~= 0 then return end
  local force = game.forces.spectator
  if not (force and force.valid) then return end
  force.chart_all(global.surface)
end

function create_starting_chest(force)
  if not (force and force.valid) then return end
  local value = global.team_config.starting_chest.selected
  if value == "none" then return end
  local multiplier = global.team_config.starting_chest_multiplier
  if not (multiplier > 0) then return end
  local inventory = global.inventory_list[value]
  if not inventory then return end
  local surface = global.surface
  local chest_name = "steel-chest"
  local origin = force.get_spawn_position(surface)
  local position = surface.find_non_colliding_position(chest_name, origin, 100, 0.5)
  if not position then return end
  local chest = surface.create_entity{name = chest_name, position = position, force = force}
  chest.destructible = false
  for name, count in pairs (inventory) do
    local count_to_insert = math.ceil(count*multiplier)
    local difference = count_to_insert - chest.insert{name = name, count = count_to_insert}
    while difference > 0 do
      position = surface.find_non_colliding_position(chest_name, origin, 100, 0.5)
      if not position then return end
      chest = surface.create_entity{name = chest_name, position = position, force = force}
      chest.destructible = false
      difference = difference - chest.insert{name = name, count = difference}
    end
  end
end

function check_base_exclusion()
  if not global.check_base_exclusion then return end
  if not (global.game_config.base_exclusion_time > 0) then return end
  if game.tick % 60 ~= 0 then return end
  if game.tick > (global.round_start_tick + (global.game_config.base_exclusion_time * 60 * 60)) then
    global.check_base_exclusion = nil
    global.exclusion_map = nil
    game.print({"base-exclusion-ends"})
    return
  end
  local surface = global.surface
  local exclusion_map = global.exclusion_map
  if not exclusion_map then
    exclusion_map = {}
    local radius = get_starting_area_radius() --[[radius in chunks]]
    for k, team in pairs (global.teams) do
      local name = team.name
      local force = game.forces[name]
      if force then
        local origin = force.get_spawn_position(surface)
        local Xo = origin.x/32
        local Yo = origin.y/32
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
    global.exclusion_map = exclusion_map
  end
  for k, player in pairs (game.connected_players) do
    if player.force.name ~= "spectator" then
      local position = player.position
      local chunk_x = math.floor(position.x/32)
      local chunk_y = math.floor(position.y/32)
      if exclusion_map[chunk_x] then
        local name = exclusion_map[chunk_x][chunk_y]
        if name and name ~= player.force.name then
          check_player_exclusion(player, name)
        end
      end
    end
  end
end

function check_player_exclusion(player, force_name)
  local force = game.forces[force_name]
  if not (force and force.valid and player and player.valid) then return end
  if force.get_friend(player.force) then return end
  local surface = global.surface
  local origin = force.get_spawn_position(surface)
  local size = global.map_config.starting_area_size.selected
  local radius = get_starting_area_radius(true) + 5 --[[radius in tiles]]
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
  position = {x = position.x + vector.x, y = position.y + vector.y}
  local vehicle = player.vehicle
  if vehicle then
    position = surface.find_non_colliding_position(vehicle.name, position, 32, 1) or position
    if not vehicle.teleport(position) then
      player.driving = false
    end
    vehicle.orientation = vehicle.orientation + 0.5
  elseif player.character then
    position = surface.find_non_colliding_position(player.character.name, position, 32, 1) or position
    player.teleport(position)
  else
    player.teleport(position)
  end
  local time_left = math.ceil((global.round_start_tick + (global.game_config.base_exclusion_time * 60 * 60) - game.tick)/3600)
  player.print({"base-exclusion-teleport", time_left})
end

function set_button_style(button)
  if not button.valid then return end
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function check_restart_round()
  if not global.team_won then return end
  if game.tick % 60 ~= 0 then return end
  local time = global.game_config.auto_new_round_time
  if not (time > 0) then return end
  if game.tick < (global.game_config.auto_new_round_time * 60 * 60) + global.team_won then return end
  end_round()
  destroy_config_for_all()
  prepare_next_round()
end

local function match_elapsed_time()
  local returnstring = ""
  local ticks = game.tick - global.round_start_tick
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

function team_won(name)
  print("PVPROUND$end," .. global.round_number .. "," .. name .. "," .. match_elapsed_time())
  global.team_won = game.tick
  if global.game_config.auto_new_round_time > 0 then
    game.print({"team-won-auto", name, global.game_config.auto_new_round_time})
  else
    game.print({"team-won", name})
  end
end


function offset_respawn_position(player)
  --This is to help the spawn camping situations.
  if not (player and player.valid and player.character) then return end
  local surface = player.surface
  local origin = player.force.get_spawn_position(surface)
  local radius = get_starting_area_radius(true) - 32
  if not (radius > 0) then return end
  local random_position = {origin.x + math.random(-radius, radius), origin.y + math.random(-radius, radius)}
  local position = surface.find_non_colliding_position(player.character.name, random_position, 32, 1)
  if not position then return end
  player.teleport(position)
end

function disband_team(force, desination_force)
  local count = 0
  for k, team in pairs (global.teams) do
    if game.forces[team.name] then
      count = count + 1
    end
  end
  if not (count > 1) then
    --Can't disband the last team.
    return
  end
  force.print{"join-new-team"}
  local players = force.players
  if desination_force and force ~= desination_force then
    game.merge_forces(force, desination_force)
  else
    game.merge_forces(force, "neutral")
  end
  for k, player in pairs (players) do
    player.force = game.forces.player
    if player.connected then
      local character = player.character
      player.character = nil
      if character then character.destroy() end
      player.set_controller{type = defines.controllers.ghost}
      player.teleport({0,1000}, game.surfaces.Lobby)
      destroy_player_gui(player)
      choose_joining_gui(player)
    end
  end
end

pvp = {}

pvp.on_init = function()
  load_config()
  init_balance_modifiers()
  verify_oil_harvest()
  local surface = game.surfaces[1]
  local settings = surface.map_gen_settings
  global.map_config.starting_area_size.selected = settings.starting_area
  global.map_config.map_height = settings.height
  global.map_config.map_width = settings.width
  global.map_config.starting_area_size.selected = settings.starting_area
  global.round_number = 0
  local surface = game.create_surface("Lobby",{width = 1, height = 1})
  surface.set_tiles({{name = "out-of-map",position = {1,1}}})
  for k, force in pairs (game.forces) do
    force.disable_all_prototypes()
    force.disable_research()
  end
  global.price_list = production_score.generate_price_list()
  for k, entity in pairs (surface.find_entities()) do
    entity.destroy()
  end
  surface.destroy_decoratives({{-500,-500},{500,500}})
end

pvp.on_load = function()
  if not global.setup_finished then return end
  local tempstring = "PVPROUND$ongoing," .. global.round_number .. ","
  for i = 1, #global.teams, 1 do
    if global.teams[i] then
      local force_name = global.teams[i].name
      tempstring = tempstring .. force_name .. ","
    end
  end
  print(tempstring:sub(1,#tempstring-1))
end

pvp.on_rocket_launched = function(event)
  production_score.on_rocket_launched(event)
  local launch_victory = {
    conquest = true,
    space_race = true,
    freeplay = true
  }
  if not launch_victory[global.game_config.game_mode.selected] then return end
  local force = event.rocket.force
  if event.rocket.get_item_count("satellite") == 0 then
    force.print({"rocket-launched-without-satellite"})
    return
  end
  if not global.team_won then
    team_won(force.name)
  end
end

pvp.on_entity_died = function(event)
  local mode = global.game_config.game_mode.selected
  if not (mode == "conquest" or mode == "last_silo_standing") then return end
  local silo = event.entity
  if not (silo and silo.valid and silo.name == "rocket-silo") then
    return
  end
  local killing_force = event.force
  local force = silo.force
  if not global.silos then return end
  global.silos[force.name] = nil
  if killing_force then
    game.print({"silo-destroyed", force.name, killing_force.name})
	print("PVPROUND$eliminated," .. force.name .. "," .. killing_force.name)
  else
    game.print({"silo-destroyed", force.name, {"neutral"}})
	print("PVPROUND$eliminated," .. force.name .. ",suicide")
  end
  if global.game_config.disband_on_loss then
    disband_team(force, killing_force)
  end
  if not global.team_won then
    local index = 0
    local winner_name = {"none"}
    for name, listed_silo in pairs (global.silos) do
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

pvp.on_player_joined_game = function(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  if player.force.name ~= "player" then return end --If they are not on the player force, they have already picked a team this round.
  local character = player.character
  player.character = nil
  if character then character.destroy() end
  player.set_controller{type = defines.controllers.ghost}
  player.teleport({0,1000}, game.surfaces.Lobby)
  if global.setup_finished then
    choose_joining_gui(player)
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
    if gui.diplomacy_frame then
      update_diplomacy_frame(player)
    end
    if gui.pick_join_frame then
      create_pick_join_gui(gui)
    end
  end
end

pvp.on_gui_elem_changed = function(event)
  local gui = event.element
  local player = game.players[event.player_index]
  if not (player and player.valid and gui and gui.valid) then return end
  local parent = gui.parent
  if not global.disabled_items then
    global.disabled_items = {}
  end
  local items = global.disabled_items
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
  global.disable_items = items
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
  if global.setup_finished == true then
    check_no_rush()
    check_player_color()
    check_update_production_score()
    check_update_oil_harvest_score()
    check_spectator_chart()
    check_base_exclusion()
    check_restart_round()
  else
    check_starting_area_chunks_are_generated()
    finish_setup()
  end
end

pvp.on_chunk_generated = function(event)
  oil_harvest_prune_oil(event)
end

pvp.on_player_respawned = function(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end
  if global.setup_finished == true then
    give_equipment(player)
    offset_respawn_position(player)
  else
    if player.character then
      player.character.destroy()
    end
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

pvp.on_configuration_changed = function(event)
  recursive_data_check(load_config(true), global)
end

pvp.on_player_crafted_item = function(event)
  production_score.on_player_crafted_item(event)
end

pvp.on_player_display_resolution_changed = function(event)
  check_config_frame_size(event)
  check_balance_frame_size(event)
end

return pvp

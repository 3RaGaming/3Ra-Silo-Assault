require("config")
require("balance")
require("mod-gui")
require("silo-script")
require ("locale/utils/showhealth")
require ("locale/utils/event")
require ("locale/utils/utils")
require ("locale/utils/bot")

silo_script.add_remote_interface()

Event.register(-1, function ()
  silo_script.init()
  load_config()
  global.copy_surface = game.surfaces[1]
  local settings = game.surfaces[1].map_gen_settings
  global.map_config.starting_area_size.selected = settings.starting_area
  global.map_config.map_height = settings.height
  global.map_config.map_width = settings.width
  global.map_config.starting_area_size.selected = settings.starting_area
  global.map_config.map_seed = settings.seed
  global.round_number = 0
  global.next_round_start_tick = 60*60
  local surface = game.create_surface("Lobby",{width = 1, height = 1})
  surface.set_tiles({{name = "out-of-map",position = {1,1}}})
  for k, force in pairs (game.forces) do
    force.disable_all_prototypes()
    force.disable_research()
  end
end)

function create_next_surface()
  if game.surfaces["Battle_surface"] ~= nil then
    return
  end
  global.round_number = global.round_number + 1
  local settings = global.copy_surface.map_gen_settings
  if #global.teams > 1 then
    settings.starting_area = "very-low"
  else
    settings.starting_area = global.map_config.starting_area_size.selected
  end
  if global.map_config.biters_disabled then
    settings.autoplace_controls["enemy-base"].size = "none"
  end  
  settings.height = global.map_config.map_height
  settings.width = global.map_config.map_width
  global.surface = game.create_surface("Battle_surface", settings)
  global.surface.daytime = 0
  global.surface.always_day = global.map_config.always_day
end

Event.register(defines.events.on_rocket_launched, function (event)
  global.silo_script.finish_on_launch = false
  silo_script.on_rocket_launched(event)
  if global.team_config.victory_condition.selected == "last_silo_standing" then return end
  local force = event.rocket.force
  if event.rocket.get_item_count("satellite") == 0 then
    force.print({"rocket-launched-without-satellite"})
    return
  end
  if not global.team_won then
    global.team_won = true
    game.print({"team-won",force.name})
    print("PVPROUND$end," .. global.round_number .. "," .. force.name .. "," .. match_elapsed_time())
  end
end)

function end_round(admin)
  for k, player in pairs (game.players) do
    destroy_player_gui(player)
    player.force = game.forces.player
    destroy_joining_guis(player.gui.center)
    if player.connected then
      local character = player.character
      player.character = nil
      if character then character.destroy() end
      player.teleport({0,1000}, game.surfaces.Lobby)
      if player.admin then
        create_config_gui(player)
      end
    end
  end
  if game.surfaces["Battle_surface"] ~= nil then
    game.delete_surface(game.surfaces["Battle_surface"])
  end
  if admin then
    game.print({"admin-ended-round", admin.name})
  end
  roll_starting_area()
  game.print{"next-round-start", global.time_between_rounds}
  global.next_round_start_tick = game.tick + global.time_between_rounds * 60
  global.setup_finished = false
end

function prepare_next_round()
  global.next_round_start_tick = nil
  global.setup_finished = false
  global.team_won = false
  prepare_map()
end

Event.register(defines.events.on_entity_died, function (event)
  if event.entity.name == "rocket-silo" then
    silo_died(event)
    return
  end
end)

function silo_died(event)
  local silo = event.entity
  local killing_force = event.force
  local force = silo.force
  if not global.silos then return end
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
    player.force = game.forces.player
    if player.connected then
      local character = player.character
      player.character = nil
      if character then character.destroy() end
      player.teleport({0,1000}, game.surfaces.Lobby)
      player.print{"join-new-team"}
      destroy_player_gui(player)
      choose_joining_gui(player)
    end
  end
  
  for i = 1, #global.teams do
    if global.teams[i].name == force.name then
      global.teams[i].status = "dead"
      break
    end
  end

  
  if force.name == killing_force.name then 
    print("PVPROUND$eliminated," .. force.name .. ",suicide")
    game.merge_forces(force.name, "neutral")
  else
    print("PVPROUND$eliminated," .. force.name .. "," .. killing_force.name)
    game.merge_forces(force.name, killing_force.name)
  end
  if index > 1 then return end
  if not global.team_won then
    global.team_won = true
    game.print({"team-won",winner_name})
    print("PVPROUND$end," .. global.round_number .. "," .. winner_name .. "," .. match_elapsed_time())
  end
end

Event.register(defines.events.on_player_joined_game, function(event)
  if game.tick < 10 then 
    global.next_round_start_tick = nil
    return
  end
  local player = game.players[event.player_index]
  if player.force.name ~= "player" then return end
  local character = player.character
  player.character = nil
  if character then character.destroy() end
  if global.setup_finished then
    player.teleport({0,1000}, game.surfaces.Lobby)
    choose_joining_gui(player)
  else
    if (global.copy_surface and global.copy_surface.valid) then
      player.teleport({0,0}, global.copy_surface)
    else
      player.teleport({0,1000}, game.surfaces.Lobby)
    end
    if player.admin then
      create_config_gui(player)
    end
    player.print({"setup-in-process"})
  end
  player.set_controller{type = defines.controllers.ghost}
end)

Event.register(defines.events.on_player_created, function(event)
  if event.player_index ~= 1 then return end
  if global.map_config.map_height < 64 or global.map_config.map_width < 64 then
    game.print({"minimum-map-size"})
  end
  local player = game.players[event.player_index]
  local character = player.character
  player.character = nil
  if character then character.destroy() end
  local size = global.map_config.starting_area_size.selected
  local radius = math.ceil(starting_area_constant[size]/2) --radius in tiles
  game.forces.player.chart(player.surface, {{-radius,-radius},{radius, radius}})
  create_config_gui(player)
  roll_starting_area()
  for k, v in pairs (game.surfaces[1].find_entities()) do
    v.destroy()
  end
end)

Event.register(defines.events.on_player_respawned, function(event)
	give_respawn_equipment(game.players[event.player_index])
end)

function choose_joining_gui(player)
  if #global.teams == 1 then
    local team = global.teams[1]
    local force = game.forces[team.name]
    set_player(player, force, get_color(team))
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
  local frame = gui.add{type = "frame", name = "random_join_frame", caption = {"random-join"}}
  local button = frame.add{type = "button", name = "random_join_button", caption = {"random-join-button"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function create_auto_assign_gui(gui)
  local name = "auto_assign"
  if gui[name.."_frame"] then
    gui[name.."_frame"].destroy()
  end
  local frame = gui.add{type = "frame", name = name.."_frame", caption = {name.."_frame"}}
  local button = frame.add{type = "button", name = name.."_button", caption = {name.."_button"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function create_pick_join_gui(gui)
  if gui.pick_join_frame then
    gui.pick_join_frame.destroy()
  end
  local frame = gui.add{type = "frame", name = "pick_join_frame", caption = {"pick-join"}, direction = "vertical"}
  local pick_join_table = frame.add{type = "table", name = "pick_join_table", colspan = 4}
  pick_join_table.add{type = "label", name = "pick_join_table_force_name", caption = {"team-name"}}
  pick_join_table.add{type = "label", name = "pick_join_table_player_count", caption = {"number-players"}}
  pick_join_table.add{type = "label", name = "pick_join_table_team", caption = {"team-number"}}
  pick_join_table.add{type = "label", name = "pick_join_table_pad", caption = {"join"}}
  for k, team in pairs (global.teams) do
    local force = game.forces[team.name]
    if force ~= nil then
      local name = pick_join_table.add{type = "label", name = force.name.."_label", caption = force.name}
      name.style.font_color = get_color(team, true)
      pick_join_table.add{type = "label", name = force.name.."_count", caption = #force.connected_players.."/"..#force.players}
      local caption
      if tonumber(team.team) then
        caption = team.team
      elseif team.team:find("?") then
        caption = team.team:gsub("?", "")
      else
        caption = team.team
      end
      pick_join_table.add{type = "label", name = force.name.."_team", caption = caption}
      pick_join_table.add{type = "checkbox", name = force.name,state = false}
    end
  end
  local button = frame.add{type = "button", name = "player_pick_confirm", caption = {"confirm"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function create_config_gui(player)
  local gui = mod_gui.get_frame_flow(player)
  if gui.config_gui then
    gui.config_gui.destroy()
  end
  if gui.team_gui then
    gui.team_gui.destroy()
  end
  local frame = gui.add{type = "frame", name = "config_gui", caption = {"config-gui"}, direction = "vertical"}
  local button = frame.add{type = "button", name = "balance_options", caption = {"balance-options"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
  local config_table = frame.add{type = "table", name = "config_table", colspan = 2}
  config_table.style.column_alignments[2] = "right"
  make_config_table(config_table, global.map_config)
  local button = frame.add{type = "button", name = "reroll_starting_area", caption = {"reroll-starting-area"}, tooltip = {"reroll-starting-area-tooltip"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
  local button = frame.add{type = "button", name = "config_confirm", caption = {"config-confirm"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
  make_team_gui(gui)
end

function make_config_table(gui, config)
  for k, name in pairs (config) do
    local label
    if tonumber(name) then
      label = gui.add{type = "label", name = k, tooltip = {k.."_tooltip"}}
      local input = gui.add{type = "textfield", name = k.."box"}
      input.text = name
      input.style.maximal_width = 100
    elseif tostring(type(name)) == "boolean" then
      label = gui.add{type = "label", name = k, tooltip = {k.."_tooltip"}}
      gui.add{type = "checkbox", name = k.."_"..tostring(type(name)), state = name}
    else
      label = gui.add{type = "label", name = k, tooltip = {k.."_tooltip"}}
      local menu = gui.add{type = "drop-down", name = k.."_dropdown"}
      menu.style.maximal_width = 150
      default = global[k] or "none"
      local index
      for j, option in pairs (name.options) do
        if game.item_prototypes[option] then
          menu.add_item(game.item_prototypes[option].localised_name)
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
    label.caption = {"colon", {k}}
  end
end

function make_team_gui(gui)
  local frame = gui.add{type = "frame", name = "team_gui", caption = {"team-gui"}, direction = "vertical"}
  local scroll = frame.add{type = "scroll-pane", name = "team_gui_scroll"}
  scroll.style.maximal_height = 200
  local team_table = scroll.add{type = "table", colspan = 4, name = "team_table"}
  for k, name in pairs ({"team-name", "color", "team", "remove"}) do
    local label = team_table.add{type = "label", caption = {name}}
    label.style.minimal_width = 50
  end
  for k, team in pairs (global.teams) do
    add_team_to_team_table(team_table, k)
  end
  local button = frame.add{name = "add_team_button", type = "button", caption = {"add-team"}, tooltip = {"add-team-tooltip"}}
  button.style.font = "default"
  button.style.top_padding = 2
  button.style.bottom_padding = 2
  make_team_gui_config(frame)
end

function make_team_gui_config(gui)
  if not gui.valid then return end
  local config_table = gui.add{name = "team_gui_config_table", colspan = 2, type = "table"}
  config_table.style.column_alignments[2] = "right"
  make_config_table(config_table, global.team_config)
end

function add_team_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if gui.name ~= "add_team_button" then
    return
  end
  local index = #global.teams + 1
  for k = 1, index do
    if not global.teams[k] then
      index = k
      break
    end
  end
  local color = global.colors[(1+index%(#global.colors))]
  local name = color.name.." "..index
  local team = {name = name, color = color.name, team = "-"}
  global.teams[index] = team
  for k, player in pairs (game.players) do
    local gui = mod_gui.get_frame_flow(player).team_gui
    if gui then
      add_team_to_team_table(gui.team_gui_scroll.team_table, index)
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
    local gui = mod_gui.get_frame_flow(player).team_gui
    if gui then
      for k, child in pairs (gui.team_gui_scroll.team_table.children) do
        if k == index - 3 or k == index - 2 or k == index - 1 or k == index then
          table.insert(delete_list, child)
        end
      end
    end
  end
  for k, element in pairs (delete_list) do
    element.destroy()
  end
end

function add_team_to_team_table(gui, k)
  local team = global.teams[k]
  local textfield = gui.add{type = "textfield", name = k.."_name", text = team.name}
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
  local team_button = gui.add{type = "button", name = k.."_next_team_button", caption = caption, tooltip = {"team-button-tooltip"}}
  team_button.style.font = "default"
  team_button.style.top_padding = 0
  team_button.style.bottom_padding = 0
  team_button.style.minimal_width = 30
  local bin = gui.add{name = k.."_trash_button", type = "sprite-button", sprite = "utility/trash_bin", tooltip = {"remove-team-tooltip"}}
  bin.style.top_padding = 0
  bin.style.bottom_padding = 0
  bin.style.right_padding = 0
  bin.style.left_padding = 0
  bin.style.minimal_height = 26
  bin.style.minimal_width = 26
end

function set_teams_from_gui(player)
  local gui = mod_gui.get_frame_flow(player).team_gui
  if not gui then return end
  local count = 1
  local teams = {}
  local team = {}
  local disallow = 
  {
    ["player"] = true,
    ["enemy"] = true,
    ["neutral"] = true,
    ["spectator"] = true
  }
  for k, child in pairs (gui.team_gui_scroll.team_table.children) do
    local name = child.name
    if name:find("_name") then
      if disallow[child.text] then
        player.print({"disallowed-team-name", child.text})
        return
      end
      team.name = child.text    
    end
    if name:find("_color") then
      team.color = global.colors[child.selected_index].name
    end
    if name:find("_next_team_button") then
      team.team = tonumber(child.caption) or child.caption
    end
    if name:find("_trash_button") then
      table.insert(teams, team)
      team = {}
    end
    for k, other_team in pairs (teams) do
      if other_team.name == team.name then
        player.print({"duplicate-team-name", team.name})
        return false
      end
    end
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

Event.register(defines.events.on_gui_checked_state_changed, function (event)
  local player = game.players[event.player_index]
  local gui = event.element
  if gui.parent.name == "pick_join_table" then
    for k, team in pairs (global.teams) do
      local force = game.forces[team.name]
      if force then
        local check = gui.parent[team.name]
        if check and (check.name ~= gui.name) then
          check.state = false
        end
      else
        if gui.parent[team.name] then
          create_pick_join_gui(player)
          return
        end
      end
    end
    return
  end
  diplomacy_check_press(event)
end)

function create_balance_option(gui)
  if gui.balance_options_frame then
    gui.balance_options_frame.destroy()
    return
  end
  local frame = gui.add{name = "balance_options_frame", type = "frame", direction = "vertical", caption = {"balance-options"}}
  local scrollpane = frame.add{name = "balance_options_scrollpane", type = "scroll-pane"}
  scrollpane.style.maximal_height = 500
  scrollpane.style.bottom_padding = 9
  for modifier_name, array in pairs (global.modifier_list) do
    local label = scrollpane.add{name = modifier_name.."label", type = "label", caption = {modifier_name}}
    label.style.font = "default-bold"
    local table = scrollpane.add{name = modifier_name.."table", type = "table", colspan = 2}
    table.style.column_alignments[2] = "right"
    for name, modifier in pairs (array) do
      local label
      if modifier_name == "ammo_damage_modifier" then
        local string = "ammo-category-name."..name
        label = table.add{name = name.."label", type = "label", caption = {"colon", {string}}}
      elseif modifier_name == "gun_speed_modifier" then
        local string = "ammo-category-name."..name
        label = table.add{name = name.."label", type = "label", caption = {"colon", {string}}}
      elseif modifier_name == "turret_attack_modifier" then
        local string = "entity-name."..name
        label = table.add{name = name.."label", type = "label", caption = {"colon", {string}}}
      else
        label = table.add{name = name.."label", type = "label", caption = {"colon", {name}}}
      end
      label.style.minimal_width = 200
      local input = table.add{name = name.."text", type = "textfield"}
      input.text = modifier
      input.style.maximal_width = 50
    end
  end
  local button = frame.add{type = "button", name = "balance_options_confirm", caption = {"balance-confirm"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
  local button = frame.add{type = "button", name = "balance_options_cancel", caption = {"cancel"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
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
            game.players[gui.player_index].print({"must-be-number", name})
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
  local player = game.players[gui.player_index]
  if not set_teams_from_gui(player) then return end
  if not parse_config_from_gui(config, global.map_config, player) then return end
  if global.map_config.copy_starting_area then
    local height = global.map_config.map_height
    if height == 0 then height = 2000000 end
    if height ~= global.copy_surface.map_gen_settings.height then
      game.print({"must-reroll"})
      return
    end
    local width = global.map_config.map_width
    if width == 0 then width = 2000000 end
    if width ~= global.copy_surface.map_gen_settings.width then
      game.print({"must-reroll"})
      return
    end 
  end
  if not parse_config_from_gui(mod_gui.get_frame_flow(player).team_gui.team_gui_config_table, global.team_config, player) then return end
  destroy_config_for_all()
  prepare_next_round()
  global.next_round_start_tick = nil
end

function parse_config_from_gui(gui, config, player)
  for name, value in pairs (config) do
    if gui[name.."box"] then
      local text = gui[name.."box"].text
      local n = tonumber(text)
      if text == "" then n = 0 end
      if n ~= nil then
        config[name] = n
      else
        player.print({"must-be-number", {name}})
        return
      end
    end
    if type(value) == "boolean" then
      if gui[name] then
        config[name] = gui[name.."_boolean"].state
      end
    end
    if type(value) == "table" then
      local menu = gui[name.."_dropdown"]
      if not menu then game.print("Error trying to read drop down menu of gui element "..name)return end
      config[name].selected = config[name].options[menu.selected_index]
    end
  end
  return true
end

Event.register(defines.events.on_gui_click, function(event)
  local gui = event.element
  local player = game.players[event.player_index]
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
    create_balance_option(mod_gui.get_frame_flow(player))
    return
  end
  if gui.name == "config_confirm" then
    config_confirm(gui)
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
    for k, team in pairs (global.teams) do
      local force = game.forces[team.name]
      if force then
        local check = gui.parent.pick_join_table[force.name]
        if check.state then 
          gui.parent.destroy()
          set_player(player,force,get_color(team))
          for k, player in pairs (game.forces.player.players) do
            update_players_on_team_count(player)
          end
          break
        end
      end
    end
    return
  end
  if gui.name == "reroll_starting_area" then
    parse_config_from_gui(gui.parent.config_table, global.map_config, player)
    roll_starting_area()
    for k, admin_player in pairs (game.connected_players) do
      if admin_player.admin and admin_player.name ~= player.name then
        admin_player.print({"player-rerolled", player.name})
      end
    end
    return
  end
  silo_script.on_gui_click(event)
  add_team_button_press(event)
  trash_team_button_press(event)
  on_team_button_press(event)
  objective_button_press(event)
  diplomacy_button_press(event)
  admin_button_press(event)
  diplomacy_frame_button_press(event)
  admin_frame_button_press(event)
end)

function get_color(team, lighten)
  local c = global.colors[global.color_map[team.color]].color
  if lighten then
    return {r = 1 - (1 - c[1]) * 0.5, g = 1 - (1 - c[2]) * 0.5, b = 1 - (1 - c[3]) * 0.5, a = 1}
  end
  return {r = fpn(c[1]), g = fpn(c[2]), b = fpn(c[3]), a = fpn(c[4])}
end

function roll_starting_area()
  local name = "reroll_surface_1"
  local delete = "reroll_surface_2"
  if game.surfaces[name] ~= nil then
    delete = "reroll_surface_1"
    name = "reroll_surface_2"
  end
  local settings = game.surfaces[1].map_gen_settings
  settings.starting_area = global.map_config.starting_area_size.selected
  local radius = starting_area_constant[settings.starting_area]/64
  settings.width = global.map_config.map_width
  settings.height = global.map_config.map_height
  settings.seed = global.map_config.map_seed
  if settings.seed == 0 then 
    settings.seed = math.random(999999999)
  end
  if global.map_config.biters_disabled then
    settings.autoplace_controls["enemy-base"].size = "none"
  end  
  global.copy_surface = game.create_surface(name, settings)
  global.copy_surface.request_to_generate_chunks({0,0}, radius)
  for k, player in pairs (game.connected_players) do
    player.teleport({0,0}, global.copy_surface)
  end
  if game.surfaces[delete] then
    game.delete_surface(delete)
  end
end

function delete_roll_surfaces()
  for k, name in pairs ({"reroll_surface_1", "reroll_surface_2"}) do
    if game.surfaces[name] then
      game.delete_surface(name)
    end
  end
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
  set_player(player,force,get_color(team))
end

function destroy_config_for_all()
  local names = {"config_gui", "balance_options_frame", "team_gui"}
  for i, name in pairs (names) do
    for k, player in pairs (game.players) do
      if mod_gui.get_frame_flow(player)[name] then
        mod_gui.get_frame_flow(player)[name].destroy()
      end
    end
  end
end

function prepare_map()
  create_next_surface()
  global.next_round_start_tick = nil
  create_spawn_positions(global.surface)
  setup_teams()
  if global.map_config.copy_starting_area then
    setup_start_area_copy()
  else
    chart_starting_area_for_force_spawns()
  end
  set_evolution_factor()
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

function update_players_on_team_count(player)
  local gui = player.gui.center
  if not gui.pick_join_frame then return end
  if not gui.pick_join_frame.pick_join_table then return end
  for k, team in pairs (global.teams) do
    local force = game.forces[team.name]
    if force then
      if gui.pick_join_frame.pick_join_table[force.name.."_count"] then
        gui.pick_join_frame.pick_join_table[force.name.."_count"].caption = #force.connected_players.."/"..#force.players
      end
    end
  end
end

function random_join(player)
  local force
  local team
  repeat
    local index = math.random(#global.teams)
    team = global.teams[index]
    force = game.forces[team.name]
  until force ~= nil
  set_player(player, force, get_color(team))
end

function set_player(player,force,color)
  local surface = global.surface
  if not surface.valid then return end
  local position
  local distance = 32
  repeat 
    position = surface.find_non_colliding_position("player", force.get_spawn_position(surface),distance,1)
    distance = distance + 32
  until (position ~= nil) or (distance >= 320)
  if position then
    player.teleport(position, surface)
  else
    player.print({"cant-find-position"})
    return
  end
  player.force = force
  player.color = color
  player.character = surface.create_entity{name = "player", position = position, force = force}
  init_player_gui(player)
  for k, other_player in pairs (game.players) do
    update_diplomacy_frame(other_player)
  end
  give_inventory(player)
  give_equipment(player)
  game.print({"joined", player.name, player.force.name})
end

function init_player_gui(player)
  local button_flow = mod_gui.get_button_flow(player)
  button_flow.add{type = "button", caption = {"objective"}, name = "objective_button", style = mod_gui.button_style}
  local button = button_flow.add{type = "button", caption = {"diplomacy"}, name = "diplomacy_button", style = mod_gui.button_style}
  button.style.visible = #global.teams > 1
  if player.admin then 
    button_flow.add{type = "button", caption = {"admin"}, name = "admin_button", style = mod_gui.button_style}
  end
end

function destroy_player_gui(player)
  local button_flow = mod_gui.get_button_flow(player)
  for k, name in pairs ({"objective_button", "diplomacy_button", "admin_button", "silo_gui_sprite_button"}) do
    if button_flow[name] then
      button_flow[name].destroy()
    end
  end
  local frame_flow = mod_gui.get_frame_flow(player)
  for k, name in pairs ({"objective_frame", "diplomacy_frame", "admin_button", "admin_frame", "silo_gui_frame"}) do
    if frame_flow[name] then
      frame_flow[name].destroy()
    end
  end
end

function objective_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if gui.name ~= "objective_button" then return end
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  local frame = flow.objective_frame
  if frame then
    frame.style.visible = not frame.style.visible
    return
  end
  frame = flow.add{type = "frame", name = "objective_frame", caption = {"objective"}, direction = "vertical"}
  frame.style.maximal_width = 400
  frame.style.visible = true
  local big_label = frame.add{type = "label", caption = {global.team_config.victory_condition.selected.."_description"}, single_line = false}
  big_label.style.font = "default-large"
  big_label.style.top_padding = 0
  local label_table = frame.add{type = "table", colspan = 2}
  label_table.style.column_alignments[2] = "right"
  for k, name in pairs ({"friendly_fire", "locked_teams", "team_joining", "spawn_position"}) do
    label_table.add{type = "label", caption = {"colon", {name}}, tooltip = {name.."_tooltip"}}
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
end

function admin_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if gui.name ~= "admin_button" then return end
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  if flow.admin_frame then
    flow.admin_frame.style.visible = not flow.admin_frame.style.visible    
    return 
  end
  local frame = flow.add{type = "frame", caption = {"admin"}, name = "admin_frame"}
  frame.style.visible = true
  local button = frame.add{type = "button", caption = {"end-round"}, name = "admin_end_round", tooltip = {"end-round-tooltip"}}
  button.style.font = "default"
  button.style.top_padding = 2
  button.style.bottom_padding = 2
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
    destroy_player_gui(player)
    init_player_gui(player)
    return
  end
  if gui.name == "admin_end_round" then
    end_round(player)
  end
end

function diplomacy_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if gui.name ~= "diplomacy_button" then return end
  local player = game.players[event.player_index]
  local flow = mod_gui.get_frame_flow(player)
  if flow.diplomacy_frame then
    flow.diplomacy_frame.style.visible = not flow.diplomacy_frame.style.visible
    return
  end
  local frame = mod_gui.get_frame_flow(player).add{type = "frame", name = "diplomacy_frame", caption = {"diplomacy"}, direction = "vertical"}
  frame.style.visible = true
  update_diplomacy_frame(player)
end

function update_diplomacy_frame(player)
  local gui = mod_gui.get_frame_flow(player).diplomacy_frame
  if not gui then return end
  local diplomacy_table = gui.diplomacy_table 
  if not diplomacy_table then 
    diplomacy_table = gui.add{type = "table", name = "diplomacy_table", colspan = 6}
  else
    diplomacy_table.clear()
  end
  for k, name in pairs ({"team-name", "number-players", "stance", "enemy", "neutral", "ally"}) do
    local label = diplomacy_table.add{type = "label", name = name, caption = {name}}
    label.style.minimal_width = 60
  end
  for k, team in pairs (global.teams) do
    local force = game.forces[team.name]
    if force then
      local label = diplomacy_table.add{type = "label", name = team.name.."_name", caption = team.name, single_line = false}
      label.style.maximal_width = 150
      label.style.font_color = get_color(team, true)
      diplomacy_table.add{type = "label", name = team.name.."_count", caption = "      "..#force.connected_players.."/"..#force.players}
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
        diplomacy_table.add{type = "checkbox", name = team.name.."_enemy", state = (stance == "enemy")}
        diplomacy_table.add{type = "checkbox", name = team.name.."_neutral", state = (stance == "neutral")}
        diplomacy_table.add{type = "checkbox", name = team.name.."_ally", state = (stance == "ally")}
      end
    end
  end
  if gui.button_holding_flow then return end
  local flow = gui.add{name = "button_holding_flow", type = "flow"}
  local button = flow.add{type = "button", name = "diplomacy_confirm", caption = {"confirm"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
  local button = flow.add{type = "button", name = "diplomacy_cancel", caption = {"cancel"}}
  button.style.font = "default"
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function diplomacy_frame_button_press(event)
  local gui = event.element
  if not gui.valid then return end
  if not (gui.name == "diplomacy_confirm" or gui.name == "diplomacy_cancel") then return end
  local player = game.players[event.player_index]
  gui.parent.parent.style.visible = false
  if gui.name == "diplomacy_cancel" then
    update_diplomacy_frame(player)
    return
  end
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
  local diplomacy_table = gui.parent.parent.diplomacy_table
  local some_change = false
  local changed_forces = {}
  for k, child in pairs (diplomacy_table.children) do
    if child.type == "checkbox" then
      if child.state then
        if child.name:find("_ally") then
          if child.state then            
            local name = child.name:gsub("_ally", "")
            local force = game.forces[name]
            if get_stance(player.force, force) ~= "ally" then
              team_changed_diplomacy(player.force, force, "ally")
              table.insert(changed_forces, force)
              some_change = true
            end
          end
        elseif child.name:find("_neutral") then
          if child.state then            
            local name = child.name:gsub("_neutral", "")
            local force = game.forces[name]
            if get_stance(player.force, force) ~= "neutral" then
              team_changed_diplomacy(player.force, force, "neutral")
              table.insert(changed_forces, force)
              some_change = true
            end
          end
        elseif child.name:find("_enemy") then
          if child.state then            
            local name = child.name:gsub("_enemy", "")
            local force = game.forces[name]
            if get_stance(player.force, force) ~= "enemy" then
              team_changed_diplomacy(player.force, force, "enemy")
              table.insert(changed_forces, force)
              some_change = true
            end
          end
        end
      end
    end
  end
  if some_change then
    player.force.print({"player-changed-diplomacy", player.name})
    for k, force in pairs (changed_forces) do
      for k, player in pairs (force.players) do
        update_diplomacy_frame(player)
      end
    end
    for k, player in pairs (player.force.players) do
      update_diplomacy_frame(player)
    end
  end
end

function team_changed_diplomacy(force, other_force, stance)
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
    global.teams[k].status = "alive"
  end
  for k, team in pairs (global.teams) do
    local force = game.forces[team.name]
    set_diplomacy(team)
    setup_research(force)
    disable_combat_technologies(force)
    force.reset_technology_effects()
    apply_balance(force)
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

function create_spawn_positions(surface)
  local settings = global.surface.map_gen_settings
  local config = global.map_config
  local width = config.map_width
  local height = config.map_height
  local displacement = config.average_team_displacement
  local height_scale = height/width
  local radius = starting_area_constant[config.starting_area_size.selected]/32
  local count = #global.teams
  local max_distance = starting_area_constant[config.starting_area_size.selected] + displacement
  local min_distance = starting_area_constant[config.starting_area_size.selected]/2 + (32*(count-1))
  local edge_addition = (radius +2)*32
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
  local distance = math.max(0.5*displacement, min_distance)
  local positions = {}
  if count == 1 then
    positions[1] = {0,0}
  else
    for k = 1, count do
      local rotation = (k*2*math.pi)/count
      local X = 32*(math.floor((math.cos(rotation)*distance+0.5)/32))
      local Y = 32*(math.floor((math.sin(rotation)*distance+0.5)/32))
      if elevator_set then
        --Swap X and Y for elevators
        Y = 32*(math.floor((math.cos(rotation)*distance+0.5)/32))
        X = 32*(math.floor((math.sin(rotation)*distance+0.5)/32))
      end
      positions[k] = {x = X, y = Y}
    end
  end
  global.spawn_positions = positions
end

function set_spawn_position(k, force, surface)
  local setting = global.team_config.spawn_position.selected
  if setting == "fixed" then
    local position = global.spawn_positions[k]
    force.set_spawn_position(position, surface)
    return
  end
  if setting == "random" then
    local rand = math.random
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
  local size = global.map_config.starting_area_size.selected
  local radius = math.ceil(starting_area_constant[size]/64)
  for k, team in pairs (global.teams) do
    local name = team.name
    local force = game.forces[name]
    if force ~= nil then
      local origin = force.get_spawn_position(surface)
      local area = {{origin.x-200, origin.y-200},{origin.x+200,origin.y+200}}
      surface.request_to_generate_chunks(origin, radius)
      force.chart(surface, area)
    end
  end
  game.speed = 10
  global.check_starting_area_generation = true
end

function check_starting_area_chunks_are_generated()
  if not global.check_starting_area_generation then return end
  if game.tick % 30 ~= 0 then return end
  local surface = global.surface
  local size = global.map_config.starting_area_size.selected
  local check_radius = math.ceil(starting_area_constant[size]/64) - 1
  local total = 0
  local generated = 0
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
          if (surface.is_chunk_generated({X+origin_X,Y+origin_Y})) then 
            generated = generated + 1 
          end
        end
      end
    end
  end
  global.progress = generated/total
  update_progress_bar()
  if total == generated then
    game.speed = 1
    global.check_starting_area_generation = false
    global.clear_starting_area_enemies = game.tick+(#global.teams)
  end
end

Event.register(defines.events.on_tick, function()
  check_no_rush_end()
  check_no_rush_players()
  check_player_color()
  show_health()
  if global.setup_finished then return end
  check_round_start()
  copy_paste_starting_area_tiles()
  copy_paste_starting_area_entities()
  check_starting_area_chunks_are_generated()
  clear_starting_area_enemies()
  finish_setup()
  update_copy_progress()
  update_copy_progress()
  update_progress_bar()
end)

function check_player_color()
  if game.tick % 300 ~= 0 then return end
  for k, player in pairs (game.connected_players) do
    for i, team in pairs (global.teams) do
      if team.name == player.force.name then
        local c = get_color(team)
        if (fpn(player.color.r) ~= fpn(c.r)) or (fpn(player.color.g) ~= fpn(c.g)) or (fpn(player.color.b) ~= fpn(c.b)) then
          player.color = c
          game.print({"player-changed-color", player.name, team.name})
        end
        break
      end
    end
  end
end

function check_round_start()
  if not global.next_round_start_tick then return end
  if game.tick ~= global.next_round_start_tick then return end
  destroy_config_for_all()
  prepare_next_round()
end

function clear_starting_area_enemies()
  if not global.clear_starting_area_enemies then return end
  local index = global.clear_starting_area_enemies - game.tick
  local surface = global.surface
  if index == 0 then 
    global.clear_starting_area_enemies = nil
    global.finish_setup = game.tick + (#global.teams)
    return
  end
  local name = global.teams[index].name
  if not name then return end
  local force = game.forces[name]
  if not force then return end
  local size = global.map_config.starting_area_size.selected
  local radius = math.ceil(starting_area_constant[size]/2) + 32
  local origin = force.get_spawn_position(surface)
  local area = {{origin.x-radius, origin.y-radius},{origin.x+radius, origin.y+radius}}
  for k, entity in pairs (surface.find_entities_filtered{area = area, force = "enemy"}) do
    entity.destroy()
  end
end

function check_no_rush_end()
  if not global.end_no_rush then return end
  if game.tick % 60 ~= 0 then return end
  if game.tick < global.end_no_rush then return end
  if global.team_config.no_rush_time > 0 then
    game.print({"no-rush-ends"})
  end
  global.end_no_rush = nil
  global.surface.peaceful_mode = global.map_config.peaceful_mode
  game.forces.enemy.kill_all_units()
end

function check_no_rush_players()
  if not global.end_no_rush then return end
  if game.tick % 60 ~= 0 then return end
  local size = global.map_config.starting_area_size.selected
  local radius = starting_area_constant[size]/2
  local surface = global.surface
  for k, player in pairs (game.connected_players) do
    local force = player.force
    if force.name ~= "player" then
      local origin = force.get_spawn_position(surface)
      local Xo = origin.x
      local Yo = origin.y
      local position = player.position
      local Xp = position.x
      local Yp = position.y
      if Xp > (Xo + radius) then Xp = Xo + radius end
      if Xp < (Xo - radius) then Xp = Xo - radius end
      
      if Yp > (Yo + radius) then Yp = Yo + radius end
      if Yp < (Yo - radius) then Yp = Yo - radius end
      
      if position.x ~= Xp or position.y ~= Yp then
        player.teleport({Xp, Yp})
        local time_left = math.ceil((global.end_no_rush-game.tick)/3600)
        player.print({"no-rush-teleport", time_left})
      end
    end
  end
end

function finish_setup()
  if not global.finish_setup then return end
  local index = global.finish_setup - game.tick
  local surface = global.surface
  if index == 0 then 
    global.finish_setup = nil
    game.print({"map-ready"})
    global.setup_finished = true
    for k, player in pairs (game.connected_players) do
      player.teleport({0,1000}, "Lobby")
      choose_joining_gui(player)
    end
    global.end_no_rush = game.tick + (global.team_config.no_rush_time*60*60)
    if global.team_config.no_rush_time > 0 then
      global.surface.peaceful_mode = true
      game.forces.enemy.kill_all_units()
      game.print({"no-rush-begins", global.team_config.no_rush_time})
    end
    delete_roll_surfaces()
    return
  end
  local name = global.teams[index].name
  if not name then return end
  local force = game.forces[name]
  if not force then return end
  create_silo_for_force(force)
  if global.team_config.reveal_team_positions then
    for k, other_force in pairs (game.forces) do
      --other_force.add_chart_tag(surface, {icon = {type = "item", name = "rocket-silo"}, position = {0,0}})
      chart_area_for_force(surface, force.get_spawn_position(surface), 64, other_force)
    end
  end
  create_wall_for_force(force)
  force.friendly_fire = global.team_config.friendly_fire
  global.match_start_time = game.tick
  
  local tempstring = "PVPROUND$begin," .. global.round_number .. ","
  for i = 1, #global.teams, 1 do
    local force_name = global.teams[i].name
    tempstring = tempstring .. force_name .. ","
  end
  print(tempstring:sub(1,#tempstring-1))
  
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
  local size = global.map_config.starting_area_size.selected
  local radius = math.ceil(starting_area_constant[size]/64) --radius in chunks
  global.copy_surface.request_to_generate_chunks({0,0}, radius)
  local limit = math.floor(math.min(global.map_config.map_height, global.map_config.map_width)/64)
  if global.map_config.map_height > 0 and global.map_config.map_width > 0 then
    radius = math.min(radius, limit)
  end
  if radius <= 0 then
    global.finish_setup = game.tick + #global.teams
    return 
  end
  global.chunk_offsets = {}
  for X = -radius, radius - 1 do
    for Y = -radius, radius - 1 do
      table.insert(global.chunk_offsets,{X,Y})
    end
  end
  global.setup_duration = ((#global.chunk_offsets * #global.teams)*2) + #global.teams -1
  global.finish_tick = game.tick + global.setup_duration
  global.copy_paste_starting_area_tiles_end = game.tick + (#global.chunk_offsets * #global.teams)
  update_copy_progress()
end

function update_copy_progress()
  if not global.finish_tick then return end
  local remaining = global.finish_tick - game.tick 
  global.progress = ((global.setup_duration-remaining)/global.setup_duration)
end

function update_progress_bar()
  if not global.progress then return end
  local percent = global.progress
  if game.tick % 2 ~= 0 then return end
  local finished = (percent >=1)
  local function update_bar_gui(gui)
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

function copy_paste_starting_area_tiles()
  if not global.copy_paste_starting_area_tiles_end then return end
  local surface = global.copy_surface
  local set_surface = global.surface
  local index = global.copy_paste_starting_area_tiles_end - game.tick
  local force_index = math.ceil((index)/(#global.chunk_offsets))
  local offset_index = (index - ((#global.chunk_offsets)*(force_index-1)))
  if index == 0 then
    global.copy_paste_starting_area_entities_end = game.tick + (#global.chunk_offsets * #global.teams)
    global.copy_paste_starting_area_tiles_end = nil
    local chunks = global.set_decorative_chunks
     for name, decorative in pairs (game.decorative_prototypes) do
       if decorative.autoplace_specification then
         set_surface.regenerate_decorative(name, chunks)
       end
     end
     global.set_decorative_chunks = nil
    return
  end
  local offset = global.chunk_offsets[offset_index]
  if not offset then return end
  if not surface.is_chunk_generated({offset[1],offset[2]}) then 
    global.copy_paste_starting_area_tiles_end = global.copy_paste_starting_area_tiles_end + 1
    global.finish_tick = global.copy_paste_starting_area_tiles_end + ((#global.chunk_offsets * #global.teams)) + #global.teams -1
    return
  end
  local this_force = global.teams[force_index]
  if not this_force then game.print("No force defined at selected force index") return end
  local force = game.forces[this_force.name]
  local origin = force.get_spawn_position(set_surface)
  local tiles = {}
  for X = offset[1]*32, (offset[1]+1)*32 do
    for Y = offset[2]*32, (offset[2]+1)*32 do
      local tile = surface.get_tile(X,Y)
      local position = tile.position
      table.insert(tiles, {name = tile.name, position = {position.x + origin.x, tile.position.y + origin.y}})
    end
  end
  
  set_surface.set_tiles(tiles)
  local chunk_position_x = offset[1]+((origin.x)/32)
  if not (chunk_position_x == math.floor(chunk_position_x)) then game.print("Chunk position calculated from force spawn was not an integer") return end
  local chunk_position_y = offset[2]+((origin.y)/32)
  if not (chunk_position_y == math.floor(chunk_position_y)) then game.print("Chunk position calculated from force spawn was not an integer") return end
  set_surface.set_chunk_generated_status({chunk_position_x,chunk_position_y}, defines.chunk_generated_status.entities)
  if not global.set_decorative_chunks then global.set_decorative_chunks = {} end
  table.insert(global.set_decorative_chunks, {x = chunk_position_x, y = chunk_position_y})
end

function copy_paste_starting_area_entities()
  if not global.copy_paste_starting_area_entities_end then return end
  local surface = global.copy_surface
  local index = global.copy_paste_starting_area_entities_end - game.tick
  local force_index = math.ceil((index)/(#global.chunk_offsets))
  local offset_index = (index - ((#global.chunk_offsets)*(force_index-1)))
  if index == 0 then
    global.copy_paste_starting_area_entities_end = nil
    global.finish_setup = game.tick + #global.teams
    return
  end
  local offset = global.chunk_offsets[offset_index]
  if not offset then return end
  if not surface.is_chunk_generated({offset[1],offset[2]}) then 
    global.copy_paste_starting_area_entities_end = global.copy_paste_starting_area_entities_end + 1
    return
  end
    local this_force = global.teams[force_index]
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
end

function create_silo_for_force(force)
  if global.team_config.victory_condition.selected == "freeplay" then return end
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
      table.insert(tiles_1, {name = "grass", position = {silo_position[1]+X, silo_position[2]+Y}})
      table.insert(tiles_2, {name = "hazard-concrete-left", position = {silo_position[1]+X, silo_position[2]+Y}})
    end
  end
  surface.set_tiles(tiles_1, false)
  surface.set_tiles(tiles_2)
  if global.team_config.victory_condition.selected ~= "space_race" then
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
  --Unlocks all research, and then unenables them based on a blacklist
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

function create_wall_for_force(force)
  if not global.team_config.team_walls then return end
  if not force.valid then return end
  local surface = global.surface
  local origin = force.get_spawn_position(surface)
  local size = global.map_config.starting_area_size.selected
  local radius = math.ceil(starting_area_constant[size]/2) -20 --radius in tiles
  local limit = math.floor(math.min(global.map_config.map_height, global.map_config.map_width)/2)
  if global.map_config.map_height > 0 and global.map_config.map_width > 0 then
    radius = math.min(radius, limit)
  end
  local perimeter_v = {}
  local perimeter_h = {}
  local tiles_grass = {}
  local tiles = {}
  local insert = table.insert
  for X = -radius, radius-1 do
    for Y = -radius, radius-1 do
      if (X == -radius) or (X == radius -1) then
        insert(perimeter_v, {origin.x+X,origin.y+Y})
      end
      if (Y == -radius) or (Y == radius -1) then
        insert(perimeter_h, {origin.x+X,origin.y+Y})
      end
    end
  end
  for k, position in pairs (perimeter_v) do
    insert(tiles_grass, {name = "grass", position = {position[1]-1,position[2]}})
    insert(tiles_grass, {name = "grass", position = {position[1],position[2]}})
    insert(tiles_grass, {name = "grass", position = {position[1]+1,position[2]}})
    insert(tiles, {name = "stone-path", position = {position[1]-1,position[2]}})
    insert(tiles, {name = "stone-path", position = {position[1],position[2]}})
    insert(tiles, {name = "stone-path", position = {position[1]+1,position[2]}})
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
    insert(tiles_grass, {name = "grass", position = {position[1],position[2]-1}})
    insert(tiles_grass, {name = "grass", position = {position[1],position[2]}})
    insert(tiles_grass, {name = "grass", position = {position[1],position[2]+1}})
    insert(tiles, {name = "stone-path", position = {position[1],position[2]-1}})
    insert(tiles, {name = "stone-path", position = {position[1],position[2]}})
    insert(tiles, {name = "stone-path", position = {position[1],position[2]+1}})
    for i, entity in pairs(surface.find_entities_filtered({area = {{position[1]-2,position[2]-2},{position[1]+2, position[2]+2}}, force = "neutral"})) do
      entity.destroy()
    end
    if (position[1] % 32 == 14) or (position[1] % 32 == 15) or (position[1] % 32 == 16) or (position[1] % 32 == 17) then
      surface.create_entity{name = "gate", position = {position[1],position[2]}, direction = 2, force = force}
    else
      surface.create_entity{name = "stone-wall", position = {position[1],position[2]}, force = force}
    end
  end
  surface.set_tiles(tiles_grass,false)
  surface.set_tiles(tiles)
end

function fpn(n)
  return (math.floor(n*32)/32)
end

function match_elapsed_time()
	local returnstring = ""
	local ticks = game.tick - global.match_start_time
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

function ongoingRound()
  if not global.setup_finished then return end
  local tempstring = "PVPROUND$ongoing," .. global.round_number .. ","
  for i = 1, #global.teams, 1 do
    local force_name = global.teams[i].name
    if global.teams[i].status == "alive" then tempstring = tempstring .. force_name .. "," end
  end
  print(tempstring:sub(1,#tempstring-1))
end

Event.register(-2, ongoingRound)

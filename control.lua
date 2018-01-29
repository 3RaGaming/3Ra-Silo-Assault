local silo_script = require("silo-script")
local pvp = require("pvp")
require("locale/utils/event")
require("locale/utils/bot")

silo_script.add_remote_interface()

Event.register(-1, function ()
  silo_script.on_init()
  global.silo_script.finish_on_launch = false
  pvp.on_init()
end)

Event.register(-2, function()
  pvp.on_load()
end)

Event.register(-3, function()
  pvp.on_configuration_changed()
end)

Event.register(defines.events.on_rocket_launched, function (event)
  silo_script.on_rocket_launched(event)
  pvp.on_rocket_launched(event)
end)

Event.register(defines.events.on_entity_died, function (event)
  pvp.on_entity_died(event)
end)

Event.register(defines.events.on_player_joined_game, function(event)
  pvp.on_player_joined_game(event)
end)

Event.register(defines.events.on_player_respawned, function(event)
  pvp.on_player_respawned(event)
end)

Event.register(defines.events.on_gui_selection_state_changed, function(event)
  pvp.on_gui_selection_state_changed(event)
end)

Event.register(defines.events.on_gui_checked_state_changed, function (event)
  pvp.on_gui_checked_state_changed(event)
end)

Event.register(defines.events.on_player_left_game, function(event)
  pvp.on_player_left_game(event)
end)

Event.register(defines.events.on_gui_click, function(event)
  pvp.on_gui_click(event)
  silo_script.on_gui_click(event)
end)

Event.register(defines.events.on_gui_closed, function(event)
  pvp.on_gui_closed(event)
end)

Event.register(defines.events.on_tick, function(event)
  pvp.on_tick(event)
end)

Event.register(defines.events.on_chunk_generated, function(event)
  pvp.on_chunk_generated(event)
end)

Event.register(defines.events.on_gui_elem_changed, function(event)
  pvp.on_gui_elem_changed(event)
end)

Event.register(defines.events.on_player_crafted_item, function(event)
  pvp.on_player_crafted_item(event)
end)

Event.register(defines.events.on_player_display_resolution_changed, function(event)
  pvp.on_player_display_resolution_changed(event)
end)



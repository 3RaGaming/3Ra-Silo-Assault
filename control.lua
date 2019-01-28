--require("event")
--require("bot")
--Event.register = Event.register
--script.on_init = function(handler) Event.register(-1, handler) end
--script.on_load = function(handler) Event.register(-2, handler) end
--script.on_configuration_changed = function(handler) Event.register(-3, handler) end
-- script.on_nth_tick is not implemented in the Event library as the default on_nth_tick already allows registering multiple handlers to a tick

local pvp = require("pvp")
require "event"
require "bot"
require "bot_pvp"

pvp.add_remote_interface()

Event.register(-1, function()
  pvp.on_init()
end)

script.on_load(function()
  pvp.on_load()
end)

script.on_configuration_changed(function()
  pvp.on_configuration_changed()
end)

script.on_nth_tick(5, function(event)
  pvp.on_nth_tick[5](event)
end)

script.on_nth_tick(20, function(event)
  pvp.on_nth_tick[20](event)
end)

script.on_nth_tick(60, function(event)
  pvp.on_nth_tick[60](event)
end)

script.on_nth_tick(300, function(event)
  pvp.on_nth_tick[300](event)
end)

script.on_nth_tick(54000, function(event)
  pvp.on_nth_tick[54000](event)
end)

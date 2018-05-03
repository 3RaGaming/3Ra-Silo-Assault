--Event Module: Allows multiple handlers to be assigned to an event
--Author: Afforess
--Modified by 3Ra Gaming for compatibility with their tools
-- @module Event

local orig_script = script

function fail_if_missing(var, msg)
	if not var then
		if msg then
			error(msg, 3)
		else
			error("Missing value", 3)
		end
	end
	return false
end

local function is_valid_id(event_id)
	if not (type(event_id) == "number" or type(event_id) == "string") then
		error("Invalid Event Id, Must be string or int, or array of strings and/or ints, Passed in :" .. event_id, 3)
	end
	if (type(event_id) == "number" and event_id < -3) then
		error("event_id must be greater or equal to than -3, Passed in: " .. event_id, 3)
	end
end

function table.find(tbl, func, ...)
    for k, v in pairs(tbl) do
        if func(v, k, ...) then
            return v, k
        end
    end
    return nil
end

Event = {
	_registry = {},
	core_events = {
		init = -1,
		load = -2,
		configuration_changed = -3,
		init_and_config = {-1, -3},
		_register = function(id)
			if id == Event.core_events.init then
				orig_script.on_init(function()
					Event.dispatch({ name = Event.core_events.init, tick = game.tick })
				end)
			elseif id == Event.core_events.load then
				orig_script.on_load(function()
					Event.dispatch({ name = Event.core_events.load, tick = -1 })
				end)
			elseif id == Event.core_events.configuration_changed then
				orig_script.on_configuration_changed(function(event)
					event.name = Event.core_events.configuration_changed
					event.data = event -- for backwards compatibilty
					Event.dispatch(event)
				end)
			end
		end
	}
}

--- Registers a function for a given event
-- @param event or array containing events to register
-- @param handler Function to call when event is triggered
-- @return #Event
function Event.register(event_ids, handler)
	fail_if_missing(event_ids, "missing event_ids argument")

	event_ids = (type(event_ids) == "table" and event_ids) or {event_ids}

	for _, event_id in pairs(event_ids) do
		is_valid_id(event_id)

		if handler == nil then
			Event._registry[event_id] = nil
			orig_script.on_event(event_id, nil)
		else
			if not Event._registry[event_id] then
				Event._registry[event_id] = {}

				if type(event_id) == "string" or event_id >= 0 then
					orig_script.on_event(event_id, Event.dispatch)
					elseif event_id < 0 then
						Event.core_events._register(event_id)
					end
				end
			--If the handler is already registered for this event: remove and insert it to the end.
			local _, reg_index = table.find(Event._registry[event_id], function(v) return v == handler end)
			if reg_index then
				table.remove(Event._registry[event_id], reg_index)
				log("Same handler already registered for event "..event_id..", reording it to the bottom")
			end
			table.insert(Event._registry[event_id], handler)
		end
	end
	return Event
end

--- Calls the registerd handlers
-- @param event LuaEvent as created by game.raise_event
function Event.dispatch(event)
	if event then
		local _registry = event.name and Event._registry[event.name] or event.input_name and Event._registry[event.input_name]
		if _registry then
			--add the tick if it is not present, this only affects calling Event.dispatch manually
			--doing the check up here as it should be faster than checking every iteration for a constant value
			event.tick = event.tick or _G.game and game.tick or 0

			local force_crc = Event.force_crc
			for idx, handler in ipairs(_registry) do

				-- Check for userdata and stop processing further handlers if not valid
				for _, val in pairs(event) do
					if type(val) == "table" and val.__self and not val.valid then
						return
					end
				end

				setmetatable(event, { __index = { _handler = handler } })

				-- Call the handler
				local success, err = pcall(handler, event)

				-- If the handler errors lets make sure someone notices
				if not success then
					if _G.game and #game.connected_players > 0 then -- may be nil in on_load
						--Find actual name of event
						for i,v in pairs(defines.events) do
							if v == event.name then
								identifier = i
								break
							end
						end
						-- Send error to the bot
				        err = string.gsub(err, "\n", " : ")
						if event.name < -1 or global.last_error ~= identifier then
							print("output$Error in event " .. identifier .. ': "' .. err .. '".')
							log("Error in event " .. identifier .. ': "' .. err .. '.')
							if event.name > -2 then global.last_error = identifier end
						end
					else -- no players received the message, force a real error so someone notices
						error(err) -- no way to handle errors cleanly when the game is not up
					end
					-- continue processing the remaning handlers. In most cases they won"t be related to the failed code.
				end

				-- force a crc check if option is enabled. This is a debug option and will hamper perfomance if enabled
				if (force_crc or event.force_crc) and _G.game then
					local msg = "CRC check called for event " .. event.name .. " handler #" .. idx
					log(msg) -- log the message to factorio-current.log
					game.force_crc()
				end

				-- if present stop further handlers for this event
				if event.stop_processing then
					return
				end
			end
		end
	else
		error("missing event argument")
	end
end

--- Removes the handler from the event
-- @param event event or array containing events to remove the handler
-- @param handler to remove
-- @return #Event
function Event.remove(event_ids, handler)
	fail_if_missing(event_ids, "missing event_ids argument")
	fail_if_missing(handler, "missing handler argument")

	event_ids = (type(event_ids) == "table" and event_ids) or {event_ids}

	for _, event_id in pairs(event_ids) do
		is_valid_id(event_id)

		if Event._registry[event_id] then
			for i = #Event._registry[event_id], 1, -1 do
				if Event._registry[event_id][i] == handler then
					table.remove(Event._registry[event_id], i)
				end
			end
			if table.size(Event._registry[event_id]) == 0 then
				Event._registry[event_id] = nil
				orig_script.on_event(event_id, nil)
			end
		end
	end
	return Event
end

return Event

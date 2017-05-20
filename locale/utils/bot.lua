Event.register(defines.events.on_player_died, function (event)
	local player = game.players[event.player_index]
	if player ~= nil then
		print("PLAYER$die," .. player.index .. "," .. player.name .. "," .. player.force.name)
	end
end)

Event.register(defines.events.on_player_respawned, function (event)
	local player = game.players[event.player_index]
	if player ~= nil then
		print("PLAYER$respawn," .. player.index .. "," .. player.name .. "," .. player.force.name)
	end
end)

Event.register(defines.events.on_player_joined_game, function (event)
	local player = game.players[event.player_index]
	if player ~= nil then
		print("PLAYER$join," .. player.index .. "," .. player.name .. "," .. player.force.name)
	end
end)

Event.register(defines.events.on_player_left_game, function (event)
	local player = game.players[event.player_index]
	if player ~= nil then
		print("PLAYER$leave," .. player.index .. "," .. player.name .. "," .. player.force.name)
	end
end)

Event.register(defines.events.on_player_changed_force, function (event)
	local player = game.players[event.player_index]
	if (player.force.name == "Admins") then return end
	if player ~= nil then
		print("PLAYER$force," .. player.index .. "," .. player.name .. "," .. player.force.name)
	end
end)

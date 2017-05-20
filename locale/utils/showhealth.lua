-- Show the health of a player as a small piece of colored text above their head
-- A 3Ra Gaming creation

global.crippling_factor = 1

-- shows player health as a text float.
function show_health()
	if game.tick % 30 ~= 0 then return end
	for k, player in pairs(game.players) do
		if player.connected and player.character and player.character.health ~= nil then
			local index = player.index
			local health = math.ceil(player.character.health)
			if global.player_health == nil then global.player_health = {} end
			if global.player_health[index] == nil then
				global.player_health[index] = health
			elseif global.player_health[index] ~= health then
				player.character_running_speed_modifier = -.1*(250-health)*global.crippling_factor/100
				local health_multiplier = 1 + global.modifier_list.character_modifiers.character_health_bonus / 100
				local text_position = {player.position.x, player.position.y - 2}
				
				-- slows the player just slightly if not at full health
				-- prints player health when < 80%
				if health < 250 * health_multiplier then
					if health > 150 * health_multiplier then
						player.surface.create_entity{name="flying-text", color={b = 0.2, r= 0.1, g = 1, a = 0.8}, text=(health), position=text_position}
					elseif health >= 75 * health_multiplier then
						player.surface.create_entity{name="flying-text", color={r = 1, g = 1, b = 0}, text=(health), position=text_position}
					else
						player.surface.create_entity{name="flying-text", color={b = 0.1, r= 1, g = 0, a = 0.8}, text=(health), position=text_position}
					end
					global.player_health[index] = health
				end
			end
		end
	end
end
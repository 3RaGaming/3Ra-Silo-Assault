
function research_technology()

end

Event.register(defines.events.on_research_finished, function (event)

	local research = event.research


	if research.name == "alien-technology" and global.alien_artifacts_source == "alien_tech_research" and not global.disable_alien_tech_distribution then
		for _ ,v in pairs(research.force.players) do v.insert{name="alien-artifact", count=global.config.num_alien_artifacts_on_tech} end
		game.print({"alien-artifacts-distributed-announcement",global.config.num_alien_artifacts_on_tech})
	end

	--research.force.recipes["laser-turret"].enabled=false
	--research.force.recipes["discharge-defense-equipment"].enabled=false
	research.force.recipes["construction-robot"].enabled=false
	--research.force.recipes["discharge-defense-remote"].enabled=false
	--research.force.recipes["energy-shield-mk2-equipment"].enabled=false
	--research.force.recipes["personal-laser-defense-equipment"].enabled=false
	--research.force.recipes["destroyer-capsule"].enabled=false

end)

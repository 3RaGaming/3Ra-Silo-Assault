
function research_technology()

end

Event.register(defines.events.on_research_finished, function (event)

	local research = event.research

	if not global.disable_tech_event then
		if research.name == "alien-technology" and global.alien_artifacts_source == "alien_tech_research" then
			for _ ,v in pairs(research.force.players) do v.insert{name="alien-artifact", count=global.config.num_alien_artifacts_on_tech} end
			game.print({"alien-artifacts-distributed-announcement",global.config.num_alien_artifacts_on_tech})
		end
		
		if	   research.name == "productivity-module"
			or research.name == "productivity-module-2"
			or research.name == "productivity-module-3"
			or research.name == "rocket-silo"
		then game.print({"force-researched-warning",research.force.name,research.localised_name}) end
	end
	
	research.force.recipes["rocket-silo"].enabled=false
	--research.force.recipes["laser-turret"].enabled=false
	--research.force.recipes["discharge-defense-equipment"].enabled=false
	--research.force.recipes["construction-robot"].enabled=false
	--research.force.recipes["discharge-defense-remote"].enabled=false
	--research.force.recipes["energy-shield-mk2-equipment"].enabled=false
	--research.force.recipes["personal-laser-defense-equipment"].enabled=false
	--research.force.recipes["destroyer-capsule"].enabled=false

end)

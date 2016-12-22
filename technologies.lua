
function research_technology()

end

Event.register(defines.events.on_research_finished, function (event)

	local research = event.research


	research.force.recipes["laser-turret"].enabled=false
	research.force.recipes["discharge-defense-equipment"].enabled=false
	research.force.recipes["construction-robot"].enabled=false
	research.force.recipes["discharge-defense-remote"].enabled=false
	research.force.recipes["energy-shield-mk2-equipment"].enabled=false
	research.force.recipes["personal-laser-defense-equipment"].enabled=false
	research.force.recipes["destroyer-capsule"].enabled=false

end)
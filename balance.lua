local combat_technologies = 
  {
    "follower-robot-count",
    "combat-robot-damage",
    "laser-turret-damage",
    "laser-turret-speed",
    "bullet-damage",
    "bullet-speed",
    "shotgun-shell-damage",
    "shotgun-shell-speed",
    "gun-turret-damage",
    "rocket-damage",
    "rocket-speed",
    "grenade-damage",
    "flamethrower-damage"  
  }

function disable_combat_technologies(force)
  if not global.config.unlock_combat_research then return end
  local tech = force.technologies
  for k, name in pairs (combat_technologies) do
    for i = 1, 20 do
      local full_name = name.."-"..i
      if tech[full_name] then
        tech[full_name].researched = false
      end
    end
  end
  clear_combat_modifiers(force)
end

function apply_character_modifiers(force)
  for name, modifier in pairs (global.modifier_list.character_modifiers) do
    force[name] = modifier
  end
end

global.modifier_list = 
  { 
    ["character_modifiers"] = 
      {
        ["character_running_speed_modifier"] = 0.25,
        ["character_health_bonus"] = 100
      },
    ["turret_attack_modifier"] = 
      {
        ["laser-turret"] = -0.5,
        ["gun-turret"] = -0.5,
        ["flamethrower-turret"] = -0.5
      },
    ["ammo_damage_modifier"] = 
      {
        ["bullet"] = 0,
        ["shotgun-shell"] =  0,
        ["cannon-shell"] =  0.5,
        ["rocket"] =  0.5,
        ["flame-thrower"] =  0,
        ["grenade"] =  -0.5,
        ["combat-robot-beam"] =  0,
        ["combat-robot-laser"] =  0,
        ["laser-turret"] =  0
      },
    ["gun_speed_modifier"] = 
      {
        ["bullet"] =  -0.25,
        ["shotgun-shell"] =  0,
        ["cannon-shell"] =  0.5,
        ["rocket"] =  0.5,
        ["flame-thrower"] =  0,
        ["laser-turret"] =  0
      }
  }

function apply_combat_modifiers(force)

  for name, modifier in pairs (global.modifier_list.turret_attack_modifier) do
    force.set_turret_attack_modifier(name, modifier)
  end
  
  for name, modifier in pairs (global.modifier_list.ammo_damage_modifier) do
    force.set_ammo_damage_modifier(name, modifier)
  end
  
  for name, modifier in pairs (global.modifier_list.gun_speed_modifier) do
    force.set_gun_speed_modifier(name, modifier)
  end

end

function clear_combat_modifiers(force)

  for name, modifier in pairs (global.modifier_list.turret_attack_modifier) do
    force.set_turret_attack_modifier(name, 0)
  end
  
  for name, modifier in pairs (global.modifier_list.ammo_damage_modifier) do
    force.set_ammo_damage_modifier(name, 0)
  end
  
  for name, modifier in pairs (global.modifier_list.gun_speed_modifier) do
    force.set_gun_speed_modifier(name, 0)
  end

end

function apply_balance(force)
  apply_character_modifiers(force)
  apply_combat_modifiers(force)
end

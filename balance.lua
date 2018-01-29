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
    "flamethrower-damage",
    "cannon-shell-damage",
    "cannon-shell-speed",
    "artillery-shell-range",
    "artillery-shell-speed"
  }

function disable_combat_technologies(force)
  if global.team_config.unlock_combat_research then return end --If true, then we want them to stay unlocked
  local tech = force.technologies
  for k, name in pairs (combat_technologies) do
    local i = 1
    repeat
      local full_name = name.."-"..i
      if tech[full_name] then
        tech[full_name].researched = false
      end
      i = i + 1
    until not tech[full_name]
  end
end

function apply_character_modifiers(player)
  for name, modifier in pairs (global.modifier_list.character_modifiers) do
    player[name] = modifier
  end
end

function init_balance_modifiers()
  local modifier_list =
  {
    character_modifiers =
      {
        character_running_speed_modifier = 0,
        character_health_bonus = 0,
        character_crafting_speed_modifier = 0,
        character_mining_speed_modifier = 0,
        character_inventory_slots_bonus = 0
      },
    turret_attack_modifier = {},
    ammo_damage_modifier ={},
    gun_speed_modifier = {}
  }
  local entities = game.entity_prototypes
  local turret_types = {
    ["ammo-turret"] = true,
    ["electric-turret"] = true,
    ["fluid-turret"] = true,
    ["artillery-turret"] = true,
    ["turret"] = true
  }
  for name, entity in pairs (entities) do
    if turret_types[entity.type] then
      modifier_list.turret_attack_modifier[name] = 0
    end
  end
  local categories = {
    "bullet",
    "combat-robot-beam",
    "combat-robot-laser",
    "laser-turret",
    "rocket",
    "shotgun-shell",
    "biological",
    "cannon-shell",
    "capsule",
    "electric",
    "flamethrower",
    "melee",
    "railgun",
    "grenade",
    "fluid",
    "artillery-shell"
  }
  for k, name in pairs (categories) do
    modifier_list.ammo_damage_modifier[name] = 0
    modifier_list.gun_speed_modifier[name] = 0
  end
  global.modifier_list = modifier_list
end

function apply_combat_modifiers(force)
  for name, modifier in pairs (global.modifier_list.turret_attack_modifier) do
    force.set_turret_attack_modifier(name, force.get_turret_attack_modifier(name) + modifier)
  end

  for name, modifier in pairs (global.modifier_list.ammo_damage_modifier) do
    force.set_ammo_damage_modifier(name, force.get_ammo_damage_modifier(name) + modifier)
  end

  for name, modifier in pairs (global.modifier_list.gun_speed_modifier) do
    force.set_gun_speed_modifier(name, force.get_gun_speed_modifier(name) + modifier)
  end

end

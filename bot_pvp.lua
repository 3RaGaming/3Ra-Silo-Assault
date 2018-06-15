require("event") --Insures that Event exists
require("pvp") --This file only works if Klonan's PvP scenario is present, this line insures that
 
local function match_elapsed_time()
    if not global.round_start_stick then return nil end
    local returnstring = ""
    local ticks = game.tick - global.round_start_tick
    if ticks < 0 then
        ticks = ticks * -1
        returnstring = "-"
    end
    local hours = math.floor(ticks / 60^3)
    local minutes = math.floor((ticks % 60^3) / 60^2)
    local seconds = math.floor((ticks % 60^2) / 60)
    if hours > 0 then returnstring = returnstring .. hours .. (hours > 1 and " hours; " or " hour; ") end
    if minutes > 0 then returnstring = returnstring .. minutes .. (minutes > 1 and " minutes" or " minute").. " and " end
    returnstring = returnstring .. seconds .. (seconds ~= 1 and " seconds" or " second")
    return returnstring
end
 
Event.register(-2, function()
    if not global.setup_finished then return end
    if not global.round_number then global.round_number = 1 end
    local tempstring = "PVPROUND$ongoing," .. global.round_number .. ","
    for i = 1, #global.teams, 1 do
        if global.teams[i] then
            local force_name = global.teams[i].name
            tempstring = tempstring .. force_name .. ","
        end
    end
    print(tempstring:sub(1,#tempstring-1))
end)
 
function on_round_end(event)
    --event is empty table
    if not global.round_number then global.round_number = 1 end
    local name = global.bot_winning_team or "nowinner"
    local tim = match_elapsed_time()
    if tim then tim = "," .. tim
    else tim = "" end
    print("PVPROUND$end," .. global.round_number .. "," .. name .. tim)
end
 
function on_round_start(event)
    --event is empty table
    if not global.round_number then global.round_number = 1 end
    global.bot_winning_team = nil
    local tempstring = "PVPROUND$begin," .. global.round_number .. ","
    for i = 1, #global.teams, 1 do
        local force_name = global.teams[i].name
        tempstring = tempstring .. force_name .. ","
    end
    print(tempstring:sub(1,#tempstring-1))
end
 
function on_team_lost(event)
    --event has key 'name', the team that was eliminated
    --Locked to neutral kills until a killing_force key is added to the event
    print("PVPROUND$eliminated," .. event.name .. ",neutral")
end
 
function on_team_won(event)
    --event has key 'name', the team that won
    global.bot_winning_team = event.name
end
 
Event.register(-1, function()
    global.bot_winning_team = nil
    events =
        {
            on_round_end = remote.call("pvp", "get_event_name", "on_round_end"),
            on_round_start = remote.call("pvp", "get_event_name", "on_round_start"),
            on_team_lost = remote.call("pvp", "get_event_name", "on_team_lost"),
            on_team_won = remote.call("pvp", "get_event_name", "on_team_won")
        }
    for nam,evt in pairs(events) do
        if not evt then
            error("Required event " .. nam .. " does not exist!", 3)
        end
    end
    Event.register(events.on_round_end, on_round_end)
    Event.register(events.on_round_start, on_round_start)
    Event.register(events.on_team_lost, on_team_lost)
    Event.register(events.on_team_won, on_team_won)
end)
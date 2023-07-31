

local M = {}

local nk = require("nakama")




local OpCodes = {
    spawn_player = 1,
    update_match_state = 2,
    update_player_state = 3,
    shoot_bullet = 4,
    killed = 5,
}




local commands = {}


commands[OpCodes.update_player_state] = function(sender, data, state, _)
    if state.players[sender.user_id] ~= nil then
        state.players[sender.user_id].position = data.position
        state.players[sender.user_id].input = data.input
    end
end


commands[OpCodes.shoot_bullet] = function(sender, data, state, dispatcher)
    local _data = {
        user_id = sender.user_id,
        data = data
    }
    local encoded = nk.json_encode(_data)

    dispatcher.broadcast_message(OpCodes.shoot_bullet, encoded)
end



commands[OpCodes.killed] = function(sender, data, state, dispatcher)

    local _data = {
        killer = sender.user_id,
        killed = data.killed,
    }

    if state.players[data.killed].team == "red" then
        state.blue_team_score = state.blue_team_score + 1
    else
        state.red_team_score = state.red_team_score + 1
    end

    local encoded = nk.json_encode(_data)

    dispatcher.broadcast_message(OpCodes.killed, encoded)

    -- Respawn the player 
    local spawn_point = state.players[data.killed].team == 'red' and state.red_spawn_point or state.blue_spawn_point

    state.players[data.killed].position = spawn_point

    local encoded = nk.json_encode(state.players[data.killed])

    dispatcher.broadcast_message(OpCodes.spawn_player, encoded)
end

-- When the match is initialized. Creates empty tables in the game state that will be populated by
-- clients.
function M.match_init(_, _)
    local gamestate = {
        presences = {},
        players = {},
        players_count = 0,
        red_team_score = 0,
        blue_team_score = 0,
        red_team = {},
        blue_team = {},
        red_spawn_point = {x = 16.0, y = 1.0, z = 16.0},
        blue_spawn_point = {x = -16.0, y = 1.0, z = -16.0},
    }
    local tickrate = 10
    local label = "1v1"
    return gamestate, tickrate, label
end

-- When someone tries to join the match. Checks if someone is already logged in and blocks them from
-- doing so if so.
function M.match_join_attempt(_, _, _, state, presence, _)
    if state.presences[presence.user_id] ~= nil then
        return state, false, "User already logged in."
    end
    return state, true
end

-- When someone does join the match. Initializes their entries in the game state tables with dummy
-- values until they spawn in.
function M.match_join(_, dispatcher, _, state, presences)
    for _, presence in ipairs(presences) do
        state.presences[presence.user_id] = presence
        state.players_count = state.players_count + 1
        local player_team = #state.red_team < #state.blue_team and 'red' or 'blue'

        if player_team == 'red' then
            table.insert(state.red_team, presence.user_id)
        else
            table.insert(state.blue_team, presence.user_id)
        end

        local spawn_point = player_team == 'red' and state.red_spawn_point or state.blue_spawn_point
        state.players[presence.user_id] = spawn_point

        local player_data = {
            presence = presence,
            team = player_team,
            position = spawn_point,
            input = {
                rot = 0,
                vel_x = 0,
                vel_y = 0,
                vel_z = 0,
                is_shooting = false
            }
        }

        state.players[presence.user_id] = player_data

        local encoded = nk.json_encode(player_data)

        dispatcher.broadcast_message(OpCodes.spawn_player, encoded)

    end
    return state
end


-- When someone leaves the match. Clears their entries in the game state tables, but saves their
-- position to storage for next time.
function M.match_leave(_, _, _, state, presences)
    for _, presence in ipairs(presences) do
        state.players[presence.user_id] = nil
        state.players_count = state.players_count - 1
        if state.players_count == 0 then
            return nil
        end
    end
    return state
end

-- Called `tickrate` times per second. Handles client messages and sends game state updates. Uses
-- boiler plate commands from the command pattern except when specialization is required.
function M.match_loop(_, dispatcher, _, state, messages)
    for _, message in ipairs(messages) do
        local op_code = message.op_code
        local sender = message.sender
        local decoded = nk.json_decode(message.data)

        -- Run boiler plate commands (state updates.)

        local command = commands[op_code]
        if command ~= nil then
            commands[op_code](sender, decoded, state, dispatcher)
        end
    end
    local data = {
        players = state.players,
        red_team_score = state.red_team_score,
        blue_team_score = state.blue_team_score
    }
    local encoded = nk.json_encode(data)

    dispatcher.broadcast_message(OpCodes.update_match_state, encoded)

    return state
end

-- Server is shutting down. Save positions of all existing characters to storage.
function M.match_terminate(_, _, _, state, _)
    return state
end

-- Called when the match handler receives a runtime signal.
function M.match_signal(_, _, _, state, data)
	return state, data
end


return M
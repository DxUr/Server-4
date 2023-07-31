local M = {}

local nk = require("nakama")


local OpCodes = {
	update_game_state = 0,
	select_base = 1,
}


local states = {
	game_end = -1,
	initializing = 0,
	waiting_players = 1,
	choosing_base = 2,
	playing = 3,
}

local state_func_map = {
	-1 = nil,
	0 = nil,
	1 = nil,
	2 = nil,
	3 = nil,
}


local rules = {
	waiting_time = 15,
	choosing_base_time = 15,
	round_time = 30,
	rounds = 3,
	end_closing_time = 10,
}




function M.match_init(context, initial_state)
	local state = {
		presences = {},
		empty_ticks = 0,
		game_time = 0,
		countdown = -1,
		game_state = game_states.initializing,
		winner = nil,
		players_base = {},
		round = 1,
		buds = {},
	}
	local tick_rate = 1 -- 1 tick per second = 1 MatchLoop func invocations per second
	local label = ""

	return state, tick_rate, label
end



function M.match_join(context, dispatcher, tick, state, presences)
	for _, presence in ipairs(presences) do
		state.presences[presence.session_id] = presence
	end

	if #state.presences > 1 and countdown = -1 then
		countdown = rules.waiting_time
	end

	if #state.presences >= 2 then
		state.game_state = game_states.choosing_base
		countdown = rules.choosing_base_time
	end

	local encoded = nk.json_encode(state)

	dispatcher.broadcast_message(OpCodes.update_game_state, encoded)

	return state
end



function M.match_leave(context, dispatcher, tick, state, presences)
	for _, presence in ipairs(presences) do
		state.presences[presence.session_id] = nil
	end

	state.game_state = game_states.game_end
	countdown = rules.end_closing_time

	return state
end



function M.match_loop(context, dispatcher, tick, state, messages)

	if state.game_state = game_states.initializing then
		return state
	end

	if countdown > 0 then
		state_func_map[state.game_state](context, dispatcher, tick, state, messages)
		countdown -= 1
	end
	
	if countdown <= 0 then
		timeout(context, dispatcher, tick, state, messages)
	end

	local encoded = nk.json_encode(state)

	dispatcher.broadcast_message(OpCodes.update_game_state, encoded)
	
	return state
end


-- ======================= Game Functions ======================= --


function timeout(context, dispatcher, tick, state, messages)

	local timeout_func = {
		game_states.game_end = function ()
			state = nil
		end,
		game_states.waiting_players = function ()
			state.game_state = game_states.game_end
			state.countdown = rules.end_closing_time
		end,
		game_states.choosing_base = function ()
			state.game_state = game_states.playing
			state.countdown = rules.round_time
		end,
		game_states.playing = function ()
			if state.round < rules.rounds then
				state.game_state = game_states.choosing_base
				state.countdown = rules.choosing_base
			else
				state.game_state = game_states.game_end
				state.countdown = rules.end_closing_time
			end
		end,

	}

	
	timeout_func[state.game_state]()
end


function game_end_loop(context, dispatcher, tick, state, messages)

end


function waiting_players_loop(context, dispatcher, tick, state, messages)

end


function choosing_base_loop(context, dispatcher, tick, state, messages)

	local commands = {
		OpCodes.select_base = function(sender, data, state, dispatcher)
			players_base[sender.session_id] = data.base
		end,
	}


	for _, message in ipairs(messages) do
        local op_code = message.op_code
        local sender = message.sender
        local decoded = nk.json_decode(message.data)
        local command = commands[op_code]
        if command ~= nil then
            commands[op_code](sender, decoded, state, dispatcher)
        end
    end
end


function playing_loop(context, dispatcher, tick, state, messages)

end
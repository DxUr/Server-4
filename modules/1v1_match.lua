local M = {}

function M.match_init(context, initial_state)
	local state = {
		presences = {},
		empty_ticks = 0
	}
	local tick_rate = 1 -- 1 tick per second = 1 MatchLoop func invocations per second
	local label = ""

	return state, tick_rate, label
end

function M.match_join(context, dispatcher, tick, state, presences)
	for _, presence in ipairs(presences) do
		state.presences[presence.session_id] = presence
	end

	return state
end

function M.match_leave(context, dispatcher, tick, state, presences)
	for _, presence in ipairs(presences) do
		state.presences[presence.session_id] = nil
	end

	return state
end

function M.match_loop(context, dispatcher, tick, state, messages)
  -- Get the count of presences in the match
  local totalPresences = 0
  for k, v in pairs(state.presences) do
    totalPresences = totalPresences + 1
  end

	-- If we have no presences in the match according to the match state, increment the empty ticks count
	if totalPresences == 0 then
		state.empty_ticks = state.empty_ticks + 1
	end

	-- If the match has been empty for more than 100 ticks, end the match by returning nil
	if state.empty_ticks > 100 then
		return nil
	end

	return state
end
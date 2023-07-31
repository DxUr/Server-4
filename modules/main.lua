local nk = require("nakama")


local function matchmaker_add(context, payload)
  -- Force min count to be 4 and max count to be 8
  payload.matchmaker_add.min_count = 2
  payload.matchmaker_add.max_count = 2

  return payload
end

local function makematch(context, matched_users)
  -- print matched users
  for _, user in ipairs(matched_users) do
    local presence = user.presence
    -- nk.logger_info(("Matched user '%s' named '%s'"):format(presence.user_id, presence.username))
    for k, v in pairs(user.properties) do
      nk.logger_info(("Matched on '%s' value '%s'"):format(k, v))
    end
  end

  local modulename = "1v1_match"
  local setupstate = { invited = matched_users }
  local matchid = nk.match_create(modulename, setupstate)
  return matchid
end

nk.register_matchmaker_matched(makematch)

nk.register_rt_before(matchmaker_add, "MatchmakerAdd")


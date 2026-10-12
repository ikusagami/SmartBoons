-- Pure voting policy. Every resolved region has equal influence; no anatomy,
-- damage weights, species IDs, or recent-hit history are required.
local SKILLS = { 29, 30, 31 }
local EPSILON = 0.000001

local function valid_rate(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

return function(profiles, equipped, original_skill)
	local first, second = { 0, 0, 0 }, { 0, 0, 0 }
	local informative = 0
	for _, rates in ipairs(profiles) do
		if valid_rate(rates[1]) and valid_rate(rates[2]) and valid_rate(rates[3]) then
			local highest = math.max(rates[1], rates[2], rates[3])
			local lowest = math.min(rates[1], rates[2], rates[3])
			-- Fully neutral regions must not create an arbitrary preference.
			if highest - lowest > EPSILON then
				informative = informative + 1
				local places, first_count, second_count = {}, 0, 0
				for index = 1, 3 do
					local better = 0
					for other = 1, 3 do
						if rates[other] - rates[index] > EPSILON then better = better + 1 end
					end
					places[index] = better + 1
					if better == 0 then first_count = first_count + 1 end
					if better == 1 then second_count = second_count + 1 end
				end
				-- A tied place shares its vote rather than multiplying a region's influence.
				for index = 1, 3 do
					if places[index] == 1 then first[index] = first[index] + 1 / first_count end
					if places[index] == 2 then second[index] = second[index] + 1 / second_count end
				end
			end
		end
	end

	local summary = string.format("regions=%d informative=%d first[F=%.1f I=%.1f T=%.1f] second[F=%.1f I=%.1f T=%.1f]",
		#profiles, informative, first[1], first[2], first[3], second[1], second[2], second[3])
	if informative == 0 then return nil, summary .. " (no elemental preference)" end

	local winner, winner_index
	for index, skill in ipairs(SKILLS) do
		if equipped[skill] then
			local better = winner == nil or first[index] - first[winner_index] > EPSILON
			local same_first = winner ~= nil and math.abs(first[index] - first[winner_index]) <= EPSILON
			if same_first and second[index] - second[winner_index] > EPSILON then better = true end
			local tied = same_first and math.abs(second[index] - second[winner_index]) <= EPSILON
			if better or (tied and skill == original_skill) then winner, winner_index = skill, index end
		end
	end
	return winner, summary
end

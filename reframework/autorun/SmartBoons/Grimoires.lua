-- Correct only a Pawn's native decision to read an elemental Boon grimoire.
-- No inventory edits, direct casts, item consumption, or shared pack changes.
local ITEM_SKILLS = { [181] = 29, [182] = 30, [183] = 31 }
local SKILL_ITEMS = { [29] = 181, [30] = 182, [31] = 183 }
local ITEM_NAMES = { [181] = "Igneous Melody", [182] = "Hiemal Euphony", [183] = "Thunderous Concord" }

return function(R, config, choose, log)
	local support = {}
	local installed = false
	local errors = {}
	local function warn(message)
		if not errors[message] then errors[message] = true; log(message) end
	end
	local function pawn_character(command)
		local character = R.call(command, "get_Character") or R.field(command, "<Character>k__BackingField")
		if not R.is_alive(character) then return nil, "caster unavailable or dead" end
		local human = R.call(character, "get_Human") or R.field(character, "<Human>k__BackingField")
		if R.call(human, "isPlayerOrPartyPawn") ~= true then return nil, "caster not recognized as a party member" end
		-- Pawn and Character components need not share the same GameObject.
		-- Match the actual Character against the game's Pawn character list.
		local manager = sdk.get_managed_singleton("app.PawnManager")
		local pawns = R.call(manager, "get_PawnCharacterList")
		local count = R.number(R.call(pawns, "get_Count"))
		local address = R.call(character, "get_address")
		if address ~= nil and count ~= nil and count >= 0 and count <= 64 and count % 1 == 0 then
			for index = 0, count - 1 do
				if R.call(R.call(pawns, "get_Item", index), "get_address") == address then return character end
			end
		end
		return nil, "caster absent from Pawn character list"
	end
	local function owned_books(character)
		local manager = sdk.get_managed_singleton("app.ItemManager")
		local owner_id = R.number(R.call(character, "get_CharaID"))
		if manager == nil or owner_id == nil then return nil end
		local list = R.call(manager, "call", "getStorageMasterList(app.CharacterID)", owner_id)
		local count = R.number(R.call(list, "get_Count"))
		if count == nil or count < 0 or count > 10000 or count % 1 ~= 0 then return nil end
		local available, counts = {}, {}
		for index = 0, count - 1 do
			local entry = R.call(list, "get_Item", index)
			local data = R.field(entry, "_Param")
			-- StorageMasterData exposes these getters directly. Its _Param is a
			-- value type; avoid invoking methods on that copied StorageData value.
			local id = R.number(R.call(entry, "get_ItemId") or R.field(data, "_ItemId"))
			local skill = ITEM_SKILLS[id]
			if skill ~= nil then
				local number = R.number(R.call(entry, "get_Num") or R.field(data, "_Num"))
				local holder = R.number(R.call(entry, "get_CharaId") or R.field(data, "_CharaId"))
				if number ~= nil and number > 0 and number < math.huge and holder == owner_id then
					available[skill] = true
					counts[id] = (counts[id] or 0) + number
				end
			end
		end
		return available, counts
	end
	function support.correct(command)
		if not config.enabled or command == nil then return end
		local original = R.number(R.field(command, "_TargetGrimoire"))
		local original_skill = ITEM_SKILLS[original]
		if original_skill == nil then return end
		local character, reason = pawn_character(command)
		if character == nil then
			if config.developer_mode then log("grimoire observed: item=" .. original .. " ignored=" .. tostring(reason)) end
			return
		end
		local available, counts = owned_books(character)
		if available == nil then
			if config.developer_mode then log("grimoire observed: " .. R.describe_actor(character) .. " inventory=unavailable; original item kept") end
			return
		end
		-- A stale native choice is left to the game's own availability checks.
		if not available[original_skill] then
			if config.developer_mode then log("grimoire observed: " .. R.describe_actor(character) .. " item=" .. original .. "; original item not found in owned stock") end
			return
		end
		local expected_skill, source = choose(character, original_skill, available)
		local expected = expected_skill and SKILL_ITEMS[expected_skill]
		if config.developer_mode then
			local mode = expected == nil and "observe" or (expected == original and "keep" or "replace")
			log(string.format("grimoire candidate: %s item=%d (%s) distance_origin=pawn owned[F=%d I=%d T=%d] enemy=%s expected=%s (%s) mode=%s",
				R.describe_actor(character), original, ITEM_NAMES[original], counts[181] or 0, counts[182] or 0, counts[183] or 0,
				tostring(source), tostring(expected), ITEM_NAMES[expected] or "none", mode))
		end
		if expected == nil or expected == original or not available[expected_skill] then return end
		-- This is the live command instance at start(), not the pack's shared
		-- command. Native start() will resolve the replacement book's StorageData.
		command._TargetGrimoire = expected
		if config.developer_mode then log(string.format("Grimoire selection replaced: from=%d to=%d", original, expected)) end
	end
	function support.install()
		if installed then return end
		local ok, err = pcall(function()
			local td = sdk.find_type_definition("app.actinter.cmd.UseGrimoire")
			local method = R.call(td, "get_method", "start()")
			if method == nil then error("UseGrimoire.start() unavailable", 0) end
			sdk.hook(method, function(args)
				local succeeded, failure = pcall(function() if args then support.correct(R.managed(args[2])) end end)
				if not succeeded then warn("Grimoire hook error: " .. tostring(failure)) end
			end)
			installed = true
			log("Grimoire selection hook installed; items=181,182,183 distance_origin=pawn")
		end)
		if not ok then warn("Grimoire hook installation pending: " .. tostring(err)) end
	end
	return support
end

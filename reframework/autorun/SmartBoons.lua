local MOD_NAME = "SmartBoons"

-- Operational logs are always available. Developer-only discovery logging is controlled in the UI.
local LOG_ENABLED = true
local DEFAULT_TARGET_DISTANCE_TIE_METERS = 15.0 -- Shared by boss and common-enemy target selection.
local DEFAULT_BOSS_MAX_DISTANCE_METERS = 50.0 -- A mapped boss beyond this distance is not considered part of the current fight.
local DEFAULT_COMMON_ENEMY_MAX_DISTANCE_METERS = 25.0 -- Common enemies never override a relevant boss.
local STATUS_DISCOVERY_TARGET_ID = nil -- Nearest living enemy; set an exact CharacterID only for a fixed discovery target.
local STATUS_PROBE_INTERVAL_SECONDS = 1.0

-- REFramework script resets do not necessarily clear Lua's require cache.
-- Reload local data modules so mapping edits are immediately testable.
local function load_local_module(module_name)
	package.loaded[module_name] = nil
	return require(module_name)
end

-- Exact CharacterID values from EnemyManager, ordered by boss priority.
local DEFAULT_BOSS_RULES_BY_CHARACTER_ID = load_local_module("SmartBoons/BossRules")

-- Common enemies are considered only when no living mapped boss is in range.
-- Empty Boon lists deliberately preserve the Mage's normal choice; their Wet/Oil behavior remains configurable in the UI.
local DEFAULT_COMMON_RULES_BY_CHARACTER_ID = load_local_module("SmartBoons/CommonRules")

local BOON_NAMES = {
	[29] = "Fire Boon",
	[30] = "Ice Boon",
	[31] = "Thunder Boon",
}

-- Packs injected into the action dispatcher when a Boon must be replaced.
local BOON_PACK_PATH_BY_SKILL = {
	[29] = "AppSystem/AI/ActionInterface/ActInterPackData/Job03_Mage/Job03_FireBoon.user",
	[30] = "AppSystem/AI/ActionInterface/ActInterPackData/Job03_Mage/Job03_IceBoon.user",
	[31] = "AppSystem/AI/ActionInterface/ActInterPackData/Job03_Mage/Job03_ThunderBoon.user",
}

-- User preferences are saved by REFramework under reframework/data/SmartBoons_config.json.
-- Defaults remain in this script, so a missing or invalid config never changes gameplay.
local CONFIG_FILE = "SmartBoons_config.json"

local function normalized_boons(source)
	local result, seen = {}, {}
	for _, value in ipairs(source or {}) do
		value = tonumber(value)
		if BOON_NAMES[value] ~= nil and not seen[value] then
			seen[value] = true
			result[#result + 1] = value
		end
	end
	return result
end

local function same_boon_order(left, right)
	if #left ~= #right then return false end
	for index, boon in ipairs(left) do
		if boon ~= right[index] then return false end
	end
	return true
end

local function copy_array(source)
	local copy = {}
	for index, boon in ipairs(source or {}) do copy[index] = boon end
	return copy
end

local function make_default_config()
	return {
		version = 1,
		enabled = true,
		developer_mode = false,
		status_discovery_enabled = false,
		max_boss_distance = DEFAULT_BOSS_MAX_DISTANCE_METERS,
		max_common_enemy_distance = DEFAULT_COMMON_ENEMY_MAX_DISTANCE_METERS,
		distance_tie = DEFAULT_TARGET_DISTANCE_TIE_METERS,
		target_selection_mode = "nearest",
		enemy_overrides = {},
	}
end

local function load_config()
	local config = make_default_config()
	local ok, saved = pcall(function() return json.load_file(CONFIG_FILE) end)
	if not ok or type(saved) ~= "table" then return config end
	if type(saved.enabled) == "boolean" then config.enabled = saved.enabled end
	if type(saved.developer_mode) == "boolean" then config.developer_mode = saved.developer_mode end
	if type(saved.status_discovery_enabled) == "boolean" then config.status_discovery_enabled = saved.status_discovery_enabled end
	if tonumber(saved.max_boss_distance) ~= nil then config.max_boss_distance = tonumber(saved.max_boss_distance) end
	if tonumber(saved.max_common_enemy_distance) ~= nil then config.max_common_enemy_distance = tonumber(saved.max_common_enemy_distance) end
	if tonumber(saved.distance_tie) ~= nil then config.distance_tie = tonumber(saved.distance_tie) end
	if saved.target_selection_mode == "nearest" or saved.target_selection_mode == "priority" then
		config.target_selection_mode = saved.target_selection_mode
	end
	if type(saved.enemy_overrides) == "table" then config.enemy_overrides = saved.enemy_overrides end
	return config
end

local config = load_config()

local function developer_mode_enabled()
	return config.developer_mode == true
end

local function get_default_rule(character_id)
	return DEFAULT_BOSS_RULES_BY_CHARACTER_ID[character_id] or DEFAULT_COMMON_RULES_BY_CHARACTER_ID[character_id]
end

local function get_effective_rule(character_id)
	local default = get_default_rule(character_id)
	if default == nil then return nil end
	local override = config.enemy_overrides[character_id]
	if type(override) == "table" and override.enabled == false then return nil end
	local rule = {
		name = default.name,
		priority = default.priority,
		boons = normalized_boons(default.boons),
		wet_boon = default.wet_boon,
		oil_boon = default.oil_boon,
	}
	if type(override) == "table" then
		if tonumber(override.priority) ~= nil then rule.priority = tonumber(override.priority) end
		if type(override.boons) == "table" then rule.boons = normalized_boons(override.boons) end
		if override.wet_boon ~= nil then
			local boon = tonumber(override.wet_boon)
			rule.wet_boon = BOON_NAMES[boon] ~= nil and boon or nil
		end
		if override.oil_boon ~= nil then
			local boon = tonumber(override.oil_boon)
			rule.oil_boon = BOON_NAMES[boon] ~= nil and boon or nil
		end
	end
	return rule
end

local function get_effective_boss_rule(character_id)
	if DEFAULT_BOSS_RULES_BY_CHARACTER_ID[character_id] == nil then return nil end
	return get_effective_rule(character_id)
end

local function get_effective_common_rule(character_id)
	if DEFAULT_COMMON_RULES_BY_CHARACTER_ID[character_id] == nil then return nil end
	return get_effective_rule(character_id)
end

-- Persist only differences from script defaults. This prevents empty UI edits and
-- family presets that match a default from being displayed as misleading custom rules.
local function normalize_enemy_overrides()
	local cleaned = {}
	for character_id, override in pairs(config.enemy_overrides) do
		local default = get_default_rule(character_id)
		if default ~= nil and type(override) == "table" then
			if override.enabled == false then
				cleaned[character_id] = { enabled = false }
			else
				local effective = get_effective_rule(character_id)
				local default_boons = normalized_boons(default.boons)
				if effective ~= nil then
					local canonical = {}
					if effective.priority ~= default.priority then canonical.priority = effective.priority end
					if not same_boon_order(effective.boons, default_boons) then canonical.boons = copy_array(effective.boons) end
					if effective.wet_boon ~= default.wet_boon then canonical.wet_boon = effective.wet_boon or 0 end
					if effective.oil_boon ~= default.oil_boon then canonical.oil_boon = effective.oil_boon or 0 end
					if next(canonical) ~= nil then cleaned[character_id] = canonical end
				end
			end
		end
	end
	config.enemy_overrides = cleaned
end

local function save_config()
	normalize_enemy_overrides()
	local ok, err = pcall(function() json.dump_file(CONFIG_FILE, config) end)
	if ok then print("[SmartBoons] configuration saved") else print("[SmartBoons] configuration save failed: " .. tostring(err)) end
	return ok
end

local state = {
	pack_hook_installed = false,
	character_id_names = {},
	last_active_boss_key = nil,
	logged_dead_bosses = {},
	logged_distant_bosses = {},
	last_status_probe_time = 0,
	last_status_snapshot = nil,
	status_condition_ids = nil,
	logged_status_candidate_names = false,
	last_weather_boon_state = {},
}

local function log(message)
	if LOG_ENABLED then print(string.format("[%s] %s", MOD_NAME, tostring(message))) end
end

local function managed_object(value)
	if value == nil or type(value) ~= "userdata" then return value end
	local ok, converted = pcall(function() return sdk.to_managed_object(value) end)
	return ok and converted or value
end

local function describe_object(value)
	if value == nil then return "nil" end
	if type(value) ~= "userdata" then return string.format("%s:%s", type(value), tostring(value)) end
	value = managed_object(value)
	local ok, td = pcall(function() return value:get_type_definition() end)
	if not ok or td == nil then return "userdata" end
	local ok_name, name = pcall(function() return td:get_full_name() end)
	return ok_name and tostring(name) or "userdata"
end

local function describe_address(value)
	local ok, address = pcall(function() return value:get_address() end)
	return ok and address ~= nil and string.format("0x%X", address) or "unknown"
end

local function call_method(object, method_name, ...)
	if object == nil then return nil end
	local arguments = { ... }
	local ok, value = pcall(function() return object[method_name](object, table.unpack(arguments)) end)
	return ok and value or nil
end

local function get_field_data(object, field_name)
	if object == nil then return nil end
	local ok, value = pcall(function()
		local td = object:get_type_definition()
		local field = td and td:get_field(field_name)
		return field and field:get_data(object) or nil
	end)
	return ok and managed_object(value) or nil
end

local function normalize_skill_id(value)
	return tonumber(value) or tonumber(tostring(value))
end

local function read_enum_value(value)
	if value == nil then return nil end
	local direct = normalize_skill_id(value)
	if direct ~= nil then return direct end
	local ok, enum_value = pcall(function() return value.value__ end)
	return ok and normalize_skill_id(enum_value) or nil
end

local function resolve_character_id_name(value)
	local numeric_id = read_enum_value(value)
	if numeric_id == nil then return nil end
	if state.character_id_names[numeric_id] ~= nil then return state.character_id_names[numeric_id] or nil end
	local td = sdk.find_type_definition("app.CharacterID")
	for _, field in ipairs(td and td:get_fields() or {}) do
		local ok_static, is_static = pcall(function() return field:is_static() end)
		if ok_static and is_static then
			local ok_value, enum_value = pcall(function() return field:get_data() end)
			if ok_value and read_enum_value(enum_value) == numeric_id then
				local name = tostring(field:get_name())
				state.character_id_names[numeric_id] = name
				return name
			end
		end
	end
	state.character_id_names[numeric_id] = false
	return nil
end

local get_best_equipped_boon
local is_actor_boon_equipped

local function get_character_position(character)
	local transform = get_field_data(character, "<Transform>k__BackingField") or call_method(character, "get_Transform")
	return call_method(transform, "get_Position")
end

local function get_player_position()
	local manager = sdk.get_managed_singleton("app.CharacterManager")
	local player = get_field_data(manager, "<ManualPlayer>k__BackingField") or call_method(manager, "get_ManualPlayer")
	return get_character_position(player)
end

local function get_distance_between(position_a, position_b)
	if position_a == nil or position_b == nil then return math.huge end
	local ok, distance = pcall(function() return (position_a - position_b):length() end)
	return ok and tonumber(distance) or math.huge
end

local function is_truthy(value)
	if value == true then return true end
	if value == false or value == nil then return false end
	local numeric = tonumber(value)
	if numeric ~= nil then return numeric ~= 0 end
	return tostring(value) == "true"
end

local function is_boss_alive(character)
	local hit = managed_object(call_method(character, "get_Hit"))
	if is_truthy(call_method(character, "get_IsDead")) or is_truthy(call_method(hit, "get_IsDie")) or is_truthy(call_method(hit, "get_IsStartDead")) then
		return false
	end
	local character_hp = tonumber(call_method(character, "get_Hp"))
	local hit_hp = tonumber(call_method(hit, "get_Hp"))
	if (character_hp ~= nil and character_hp <= 0) or (hit_hp ~= nil and hit_hp <= 0) then
		return false
	end
	return true
end

local function describe_status_value(value)
	if value == nil then return "nil" end
	if type(value) ~= "userdata" then return tostring(value) end
	value = managed_object(value)
	local count = tonumber(call_method(value, "get_Count"))
	if count ~= nil then return string.format("%s[count=%d]", describe_object(value), count) end
	return describe_object(value)
end

local function find_status_probe_target()
	local manager = sdk.get_managed_singleton("app.EnemyManager")
	local list = get_field_data(manager, "_EnemyList")
	local count = tonumber(call_method(list, "get_Count")) or 0
	local player_position = get_player_position()
	local nearest, nearest_id, nearest_distance = nil, nil, math.huge
	for index = 0, count - 1 do
		local entry = managed_object(call_method(list, "get_Item", index))
		local character = get_field_data(entry, "_Chara") or get_field_data(entry, "<Chara>k__BackingField")
		local character_id = resolve_character_id_name(call_method(character, "get_CharaID"))
		if character ~= nil and is_boss_alive(character) then
			local distance = get_distance_between(get_character_position(character), player_position)
			if STATUS_DISCOVERY_TARGET_ID ~= nil and character_id == STATUS_DISCOVERY_TARGET_ID then
				return character, character_id, distance
			elseif STATUS_DISCOVERY_TARGET_ID == nil and distance < nearest_distance then
				nearest, nearest_id, nearest_distance = character, character_id, distance
			end
		end
	end
	return nearest, nearest_id, nearest_distance
end

local function get_status_condition_ids()
	if state.status_condition_ids ~= nil then return state.status_condition_ids end
	local ids = {}
	local td = sdk.find_type_definition("app.StatusConditionDef.StatusConditionEnum")
	for _, field in ipairs(td and td:get_fields() or {}) do
		local is_static = false
		pcall(function() is_static = field:is_static() end)
		if is_static then
			local value = nil
			pcall(function() value = field:get_data() end)
			local id = read_enum_value(value)
			if id ~= nil then ids[#ids + 1] = { id = id, name = tostring(field:get_name()) } end
		end
	end
	table.sort(ids, function(a, b) return a.id < b.id end)
	state.status_condition_ids = ids
	return ids
end

local function get_active_status_condition_names(controller)
	local active = {}
	local candidates = {}
	local active_flag = read_enum_value(get_field_data(controller, "ActiveStatusConditionFlag")) or 0
	for _, entry in ipairs(get_status_condition_ids()) do
		local lower = entry.name:lower()
		if lower:find("freeze", 1, true) or lower:find("frozen", 1, true) or lower:find("wet", 1, true) or lower:find("water", 1, true) or lower:find("ice", 1, true) or lower:find("oil", 1, true) or lower:find("burn", 1, true) or lower:find("fire", 1, true) then
			candidates[#candidates + 1] = entry.name .. "=" .. tostring(entry.id)
		end
		-- IsStatusConditionActive has overloaded enum parameters. The active bit flag is
		-- unambiguous here: enum value N occupies bit 2^N.
		if entry.id >= 0 and entry.id < 53 and math.floor(active_flag / (2 ^ entry.id)) % 2 == 1 then
			active[#active + 1] = entry.name .. "=" .. tostring(entry.id)
		end
	end
	if developer_mode_enabled() and not state.logged_status_candidate_names then
		state.logged_status_candidate_names = true
		log("status enum candidates: " .. table.concat(candidates, " | "))
	end
	return active
end

local function is_character_status_active(character, status_name)
	if character == nil then return false, nil end
	local controller = managed_object(call_method(character, "get_StatusConditionCtrl") or get_field_data(character, "<StatusConditionCtrl>k__BackingField"))
	if controller == nil then return false, nil end
	local active_flag = read_enum_value(get_field_data(controller, "ActiveStatusConditionFlag")) or 0
	for _, entry in ipairs(get_status_condition_ids()) do
		if entry.name == status_name and entry.id >= 0 and entry.id < 53 then
			return math.floor(active_flag / (2 ^ entry.id)) % 2 == 1, active_flag
		end
	end
	return false, active_flag
end

local function probe_status_conditions()
	if not developer_mode_enabled() or not config.status_discovery_enabled then return end
	local now = os.clock()
	if now - state.last_status_probe_time < STATUS_PROBE_INTERVAL_SECONDS then return end
	state.last_status_probe_time = now

	local character, character_id, distance = find_status_probe_target()
	if character == nil then return end
	local controller = managed_object(call_method(character, "get_StatusConditionCtrl") or get_field_data(character, "<StatusConditionCtrl>k__BackingField"))
	if controller == nil then
		log(string.format("status probe: target=%s controller=nil", tostring(character_id)))
		return
	end

	local td = controller:get_type_definition()
	local values = {}
	for _, field in ipairs(td and td:get_fields() or {}) do
		local name = tostring(field:get_name())
		local lower = name:lower()
		if lower:find("status", 1, true) or lower:find("condition", 1, true) or lower:find("debil", 1, true) then
			values[#values + 1] = name .. "=" .. describe_status_value(get_field_data(controller, name))
		end
	end
	values[#values + 1] = "active=" .. table.concat(get_active_status_condition_names(controller), ",")
	local snapshot = table.concat(values, " | ")
	if snapshot ~= state.last_status_snapshot then
		state.last_status_snapshot = snapshot
		log(string.format("status snapshot: target=%s distance=%.1f values=%s", tostring(character_id), distance, snapshot))
	end
end

local function select_active_target(rule_for_character, max_distance, is_boss)
	local manager = sdk.get_managed_singleton("app.EnemyManager")
	local list = get_field_data(manager, "_EnemyList")
	local count = tonumber(call_method(list, "get_Count")) or 0
	local player_position = get_player_position()
	local winner, winner_id, winner_distance, winner_character = nil, nil, math.huge, nil
	for index = 0, count - 1 do
		local entry = managed_object(call_method(list, "get_Item", index))
		local character = get_field_data(entry, "_Chara") or get_field_data(entry, "<Chara>k__BackingField")
		local character_id = resolve_character_id_name(call_method(character, "get_CharaID"))
		local rule = character_id and rule_for_character(character_id) or nil
		local distance = get_distance_between(get_character_position(character), player_position)
		if rule ~= nil and not is_boss_alive(character) then
			if developer_mode_enabled() and is_boss and not state.logged_dead_bosses[character_id] then
				state.logged_dead_bosses[character_id] = true
				log("dead boss ignored: " .. rule.name .. " id=" .. character_id)
			end
		elseif rule ~= nil and distance > max_distance then
			if developer_mode_enabled() and is_boss and not state.logged_distant_bosses[character_id] then
				state.logged_distant_bosses[character_id] = true
				log(string.format("distant boss ignored: %s id=%s distance=%.1f max=%.1f", rule.name, character_id, distance, max_distance))
			end
		elseif rule ~= nil then
			local clearly_closer = distance < (winner_distance - config.distance_tie)
			local tied_distance = (distance == math.huge and winner_distance == math.huge)
				or math.abs(distance - winner_distance) <= config.distance_tie
			local priority_first = config.target_selection_mode == "priority"
			local wins = winner == nil
			if not wins and priority_first then
				wins = rule.priority > winner.priority
					or (rule.priority == winner.priority and (distance < winner_distance or (distance == winner_distance and character_id < winner_id)))
			elseif not wins then
				wins = clearly_closer or (tied_distance and (rule.priority > winner.priority or (rule.priority == winner.priority and character_id < winner_id)))
			end
			if wins then
				winner, winner_id, winner_distance, winner_character = rule, character_id, distance, character
			end
		end
	end
	return winner, winner_id, winner_distance, winner_character
end

local function get_highest_active_target()
	local rule, character_id, distance, character = select_active_target(get_effective_boss_rule, config.max_boss_distance, true)
	local target_type = "boss"
	if rule == nil then
		rule, character_id, distance, character = select_active_target(get_effective_common_rule, config.max_common_enemy_distance, false)
		target_type = "common"
	end
	local target_key = rule ~= nil and target_type .. ":" .. character_id or nil
	if developer_mode_enabled() and target_key ~= state.last_active_boss_key then
		state.last_active_boss_key = target_key
		if rule ~= nil then
			log(string.format("active %s selected: %s id=%s distance=%.1f priority=%d", target_type, rule.name, character_id, distance, rule.priority))
		end
	end
	return rule, character_id, distance, character, target_type
end

local function get_expected_boon(controller)
	local target, target_id, _, target_character = get_highest_active_target()
	if target == nil then return nil, "no_active_target" end
	local is_wet, is_oiled, status_flag = false, false, nil
	local special_fallback = nil
	if target.wet_boon ~= nil then
		is_wet, status_flag = is_character_status_active(target_character, "Wet")
	end
	if target.oil_boon ~= nil then
		is_oiled, status_flag = is_character_status_active(target_character, "Oil")
	end
	if developer_mode_enabled() and (target.wet_boon ~= nil or target.oil_boon ~= nil) then
		local status_state = tostring(is_wet) .. ":" .. tostring(is_oiled) .. ":" .. tostring(status_flag)
		if state.last_weather_boon_state[target_id] ~= status_state then
			state.last_weather_boon_state[target_id] = status_state
			log(string.format("status Boon check: target=%s wet=%s oil=%s active_status_flag=%s", target.name, tostring(is_wet), tostring(is_oiled), tostring(status_flag)))
		end
	end
	if target.wet_boon ~= nil and is_wet then
		local wet_boon = get_best_equipped_boon({ target.wet_boon }, controller)
		if wet_boon ~= nil then return wet_boon, target.name .. " (Wet -> " .. BOON_NAMES[wet_boon] .. ")" end
		special_fallback = "Wet, " .. (BOON_NAMES[target.wet_boon] or "configured Boon") .. " not equipped"
	end
	if target.oil_boon ~= nil and is_oiled then
		local oil_boon = get_best_equipped_boon({ target.oil_boon }, controller)
		if oil_boon ~= nil then return oil_boon, target.name .. " (Oil -> " .. BOON_NAMES[oil_boon] .. ")" end
		special_fallback = "Oil, " .. (BOON_NAMES[target.oil_boon] or "configured Boon") .. " not equipped"
	end
	local selected = get_best_equipped_boon(target.boons, controller)
	if selected ~= nil then
		local source = target.name .. " (" .. target_id .. ")"
		if special_fallback ~= nil then source = target.name .. " (" .. special_fallback .. " -> normal fallback)" end
		return selected, source
	end
	return nil, target.name .. " (no equipped Boon)"
end

local function is_skill_equipped(skill_context, job_id, skill_id)
	if skill_context == nil or job_id == nil then return nil end
	local result = call_method(skill_context, "hasEquipedSkill", job_id, skill_id)
	if result == nil then
		result = call_method(skill_context, "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)", job_id, skill_id)
	end
	if result == nil then return nil end
	return tonumber(result) ~= 0 and result ~= false
end

local function resolve_actor_human(controller)
	controller = managed_object(controller)
	local character = call_method(controller, "get_Character") or get_field_data(controller, "<Character>k__BackingField")
	character = managed_object(character)
	local human = call_method(character, "get_Human") or get_field_data(character, "<Human>k__BackingField")
	return character, managed_object(human)
end

is_actor_boon_equipped = function(controller, skill_id)
	local _, human = resolve_actor_human(controller)
	if human == nil then return false end
	local skill_context = call_method(human, "get_SkillContext") or get_field_data(human, "<SkillContext>k__BackingField")
	local job_context = call_method(human, "get_JobContext") or get_field_data(human, "<JobContext>k__BackingField")
	local job_id = get_field_data(job_context, "CurrentJob") or call_method(job_context, "get_CurrentJob") or get_field_data(human, "<CurrentJob>k__BackingField") or call_method(human, "get_CurrentJob")
	return is_skill_equipped(skill_context, job_id, skill_id) == true
end

get_best_equipped_boon = function(priority, controller)
	for _, skill_id in ipairs(priority or {}) do
		if is_actor_boon_equipped(controller, skill_id) then
			return skill_id
		end
	end
	return nil
end

local function trace_pack_data(controller, pack_data)
	if not config.enabled then return false end
	if pack_data == nil then return false end
	-- The blackboard controller belongs to the actor about to dispatch this pack.
	-- Convert it before reading Character: hook arguments arrive as native userdata.
	controller = managed_object(controller)
	local pack = call_method(managed_object(pack_data), "get_Pack")
	local nodes = call_method(pack, "getActInterNodes")
	local node = managed_object(call_method(nodes, "get_First"))
	local visited = 0
	while node ~= nil and visited < 64 do
		visited = visited + 1
		local next_node = managed_object(call_method(node, "get_Next"))
		local value = managed_object(call_method(node, "get_Value"))
		local primary = call_method(value, "get_PrimaryCommand")
		local skill_id = normalize_skill_id(call_method(primary, "get_CustomSkillID"))
		if BOON_NAMES[skill_id] ~= nil then
			local expected_skill_id, enemy_source = get_expected_boon(controller)
			if developer_mode_enabled() then
				local mode = expected_skill_id == nil and "observe" or (skill_id == expected_skill_id and "keep" or "replace")
				local actor_character = resolve_actor_human(controller)
				local actor_id = call_method(actor_character, "get_CharaIDString") or describe_object(actor_character)
				log(string.format("boon candidate: actor=%s skill=%s (%s) enemy=%s expected=%s (%s) mode=%s", tostring(actor_id), tostring(skill_id), BOON_NAMES[skill_id], tostring(enemy_source), tostring(expected_skill_id), BOON_NAMES[expected_skill_id] or "none", mode))
			end
			if expected_skill_id ~= nil and skill_id ~= expected_skill_id then
				return true, expected_skill_id, skill_id, controller
			end
		end
		node = next_node
	end
	return false
end

local function install_pack_hook()
	if state.pack_hook_installed then return true end
	local td = sdk.find_type_definition("app.AIBlackBoardExtensions")
	local method = td and td:get_method("setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)")
	if method == nil then log("setBBValuesToExecuteActInter not available"); return false end
	sdk.hook(method, function(args)
		if args == nil then return end
		local should_replace, expected_skill_id, wrong_skill_id, owner_controller = trace_pack_data(args[2], args[3])
		if not should_replace then return end
		if not is_actor_boon_equipped(owner_controller, expected_skill_id) then
			if developer_mode_enabled() then
				log(string.format("ActInter replacement cancelled: expected=%s is not equipped by this action's Mage", tostring(expected_skill_id)))
			end
			return
		end
		local path = BOON_PACK_PATH_BY_SKILL[expected_skill_id]
		local ok_pack, replacement = pcall(function() return sdk.create_userdata("app.ActInterPackData", path) end)
		local ok_arg = ok_pack and replacement ~= nil and pcall(function() args[3] = sdk.to_ptr(replacement) end)
		if ok_arg then
			if developer_mode_enabled() then
				log(string.format("ActInter pack argument replaced: from=%s to=%s", tostring(wrong_skill_id), tostring(expected_skill_id)))
			end
		else
			log("ActInter replacement failed; original dispatch allowed")
		end
	end)
	state.pack_hook_installed = true
	log("ActInterPack replacement hook installed")
	return true
end

re.on_application_entry("LateUpdateBehavior", function()
	install_pack_hook()
	probe_status_conditions()
end)

-- Configuration UI.  Changes apply immediately and are written only when Save is pressed.
local ui_state = {
	selected_rule_id = nil,
	rule_filter_mode = 1,
	rule_sort_mode = 1,
	rule_show_mode = 1,
	rule_family_filter = "All families",
	rule_search_text = "",
	dirty = false,
}
local UI_ITEM_WIDTH = 420
local BOON_OPTIONS = { "None", "Fire Boon", "Ice Boon", "Thunder Boon" }
local BOON_VALUES = { 0, 29, 30, 31 }
local WET_OPTIONS = { "Use script default", "No special Boon", "Fire Boon", "Ice Boon", "Thunder Boon" }
local WET_VALUES = { "default", 0, 29, 30, 31 }
local OIL_OPTIONS = { "Use script default", "No special Boon", "Fire Boon", "Ice Boon", "Thunder Boon" }
local OIL_VALUES = { "default", 0, 29, 30, 31 }

-- Family presets are intentionally limited to variants that share a gameplay family.
-- A preset is applied only when the user presses its button in the selected rule.
local RULE_FAMILIES = load_local_module("SmartBoons/Families")

local function family_matches(family, character_id)
	for _, member_id in ipairs(family.members) do
		if character_id == member_id then return true end
	end
	return false
end

local function get_rule_family(character_id)
	if character_id == nil then return nil end
	for _, family in ipairs(RULE_FAMILIES) do
		if family_matches(family, character_id) then return family end
	end
	return nil
end

local function get_family_members(family)
	return copy_array(family.members)
end

local function apply_rule_to_family(source_id, family)
	local source_override = config.enemy_overrides[source_id]
	local members = get_family_members(family)
	if type(source_override) == "table" and source_override.enabled == false then
		for _, id in ipairs(members) do config.enemy_overrides[id] = { enabled = false } end
		return #members
	end
	local source_rule = get_effective_rule(source_id)
	if source_rule == nil then return 0 end
	for _, id in ipairs(members) do
		config.enemy_overrides[id] = {
			enabled = true,
			priority = source_rule.priority,
			boons = copy_array(source_rule.boons),
			wet_boon = source_rule.wet_boon or 0,
			oil_boon = source_rule.oil_boon or 0,
		}
	end
	return #members
end

local function restore_family_defaults(family)
	local members = get_family_members(family)
	for _, id in ipairs(members) do config.enemy_overrides[id] = nil end
	return #members
end

local function get_rule_group_name(character_id)
	local family = get_rule_family(character_id)
	if family ~= nil then return family.name end
	if DEFAULT_BOSS_RULES_BY_CHARACTER_ID[character_id] ~= nil then return "Bosses" end
	return "Other common enemies"
end

local function sorted_family_options()
	local options = { "All families" }
	for _, family in ipairs(RULE_FAMILIES) do options[#options + 1] = family.name end
	table.sort(options, function(a, b)
		if a == "All families" then return true end
		if b == "All families" then return false end
		return a < b
	end)
	return options
end

local function sorted_rule_ids(sort_mode)
	local ids = {}
	for id in pairs(DEFAULT_BOSS_RULES_BY_CHARACTER_ID) do ids[#ids + 1] = id end
	for id in pairs(DEFAULT_COMMON_RULES_BY_CHARACTER_ID) do ids[#ids + 1] = id end
	table.sort(ids, function(a, b)
		local left, right = get_default_rule(a), get_default_rule(b)
		local effective_left, effective_right = get_effective_rule(a), get_effective_rule(b)
		local priority_left = (effective_left and effective_left.priority) or left.priority
		local priority_right = (effective_right and effective_right.priority) or right.priority
		if sort_mode == 1 and priority_left ~= priority_right then return priority_left > priority_right end
		if sort_mode == 3 then
			local group_left, group_right = get_rule_group_name(a), get_rule_group_name(b)
			if group_left ~= group_right then return group_left < group_right end
		end
		if left.name == right.name then return a < b end
		return left.name < right.name
	end)
	return ids
end

local function describe_boon_order(boons)
	local names = {}
	for _, boon in ipairs(boons or {}) do names[#names + 1] = BOON_NAMES[boon] or tostring(boon) end
	return #names > 0 and table.concat(names, " -> ") or "No normal preference"
end

local function describe_effective_rule(rule)
	if rule == nil then return "Disabled" end
	local wet = rule.wet_boon and (BOON_NAMES[rule.wet_boon] or tostring(rule.wet_boon)) or "None"
	local oil = rule.oil_boon and (BOON_NAMES[rule.oil_boon] or tostring(rule.oil_boon)) or "None"
	return string.format("Boons: %s | Wet: %s | Oiled: %s", describe_boon_order(rule.boons), wet, oil)
end

local function index_for_value(values, value)
	for index, candidate in ipairs(values) do
		if candidate == value then return index end
	end
	return 1
end

local function get_or_create_override(character_id)
	local override = config.enemy_overrides[character_id]
	if type(override) ~= "table" then
		override = {}
		config.enemy_overrides[character_id] = override
	end
	return override
end

local function set_rule_boon_slot(character_id, slot, boon)
	local override = get_or_create_override(character_id)
	local boons = override.boons
	if type(boons) ~= "table" then
		boons = {}
		local effective = get_effective_rule(character_id)
		for index, existing_boon in ipairs((effective and effective.boons) or {}) do boons[index] = existing_boon end
	end
	boons[slot] = boon
	override.boons = boons
end

re.on_draw_ui(function()
	if not imgui.tree_node("SmartBoons") then return end
	imgui.push_item_width(UI_ITEM_WIDTH)
	imgui.text("Only changes a Boon after the Mage AI has decided to cast one.")
	local changed, value = imgui.checkbox("Enable Boon replacement", config.enabled)
	if changed then config.enabled = value; ui_state.dirty = true end
	changed, value = imgui.checkbox("Developer mode (diagnostic logs)", config.developer_mode)
	if changed then config.developer_mode = value; ui_state.dirty = true end
	if config.developer_mode then
		changed, value = imgui.checkbox("Status discovery probe", config.status_discovery_enabled)
		if changed then config.status_discovery_enabled = value; ui_state.dirty = true end
		if imgui.is_item_hovered() then
			imgui.set_tooltip("One status snapshot per second. Use only while mapping a status or enemy.")
		end
	end

	changed, value = imgui.drag_float("Max boss distance", config.max_boss_distance, 1.0, 1.0, 1000.0)
	if changed then config.max_boss_distance = value; ui_state.dirty = true end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("Maximum distance from the Arisen for a mapped boss to be considered. A boss outside this range cannot determine the Boon.")
	end
	changed, value = imgui.drag_float("Max common enemy distance", config.max_common_enemy_distance, 1.0, 1.0, 1000.0)
	if changed then config.max_common_enemy_distance = value; ui_state.dirty = true end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("Maximum distance from the Arisen for a mapped common enemy to be considered. Common enemies are checked only when no boss qualifies.")
	end
	changed, value = imgui.drag_float("Distance tie range", config.distance_tie, 1.0, 0.0, 1000.0)
	if changed then config.distance_tie = value; ui_state.dirty = true end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("In Nearest mode, eligible bosses or common enemies within this distance of each other are treated as tied and priority decides the winner.")
	end

	local selection_options = { "Nearest boss (default)", "Highest priority boss" }
	local selection_index = config.target_selection_mode == "priority" and 2 or 1
	changed, selection_index = imgui.combo("Target selection", selection_index, selection_options)
	if changed then
		config.target_selection_mode = selection_index == 2 and "priority" or "nearest"
		ui_state.dirty = true
	end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("Nearest selects the closest eligible target. Priority selects the eligible target with the highest configured priority; distance breaks equal-priority ties.")
	end

	imgui.separator()
	local rule_filter_options = { "All mapped enemies", "Bosses only", "Common enemies only" }
	changed, ui_state.rule_filter_mode = imgui.combo("Rule category", ui_state.rule_filter_mode, rule_filter_options)
	local rule_sort_options = { "Priority (highest first)", "Name (A-Z)", "Family (grouped labels)" }
	changed, ui_state.rule_sort_mode = imgui.combo("Sort rules by", ui_state.rule_sort_mode, rule_sort_options)
	if ui_state.rule_sort_mode == 3 then
		local family_options = sorted_family_options()
		local family_index = 1
		for index, family_name in ipairs(family_options) do
			if family_name == ui_state.rule_family_filter then family_index = index; break end
		end
		changed, family_index = imgui.combo("Family", family_index, family_options)
		if changed then ui_state.rule_family_filter = family_options[family_index] end
	end
	changed, ui_state.rule_search_text = imgui.input_text("Search enemy", ui_state.rule_search_text)
	changed, value = imgui.checkbox("Show custom rules only", ui_state.rule_show_mode == 2)
	if changed then ui_state.rule_show_mode = value and 2 or 1 end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("Shows rules that have an entry in SmartBoons_config.json. It does not show every member of an uncustomized family.")
	end
	local search_text = ui_state.rule_search_text:lower()
	local all_rule_ids = sorted_rule_ids(ui_state.rule_sort_mode)
	local rule_ids = {}
	for _, id in ipairs(all_rule_ids) do
		local is_boss = DEFAULT_BOSS_RULES_BY_CHARACTER_ID[id] ~= nil
		local category_matches = ui_state.rule_filter_mode == 1 or (ui_state.rule_filter_mode == 2 and is_boss) or (ui_state.rule_filter_mode == 3 and not is_boss)
		local rule = get_default_rule(id)
		local name_matches = search_text == "" or rule.name:lower():find(search_text, 1, true) ~= nil
		local custom_matches = ui_state.rule_show_mode == 1 or type(config.enemy_overrides[id]) == "table"
		local family_matches = ui_state.rule_sort_mode ~= 3 or ui_state.rule_family_filter == "All families" or get_rule_group_name(id) == ui_state.rule_family_filter
		if category_matches and name_matches and custom_matches and family_matches then
			rule_ids[#rule_ids + 1] = id
		end
	end
	if #rule_ids == 0 then
		imgui.text("No rules match the current filters.")
		imgui.pop_item_width()
		imgui.tree_pop()
		return
	end
	imgui.text(string.format("Showing %d rule(s)", #rule_ids))
	local rule_labels = {}
	for index, id in ipairs(rule_ids) do
		local rule = get_default_rule(id)
		local effective_rule = get_effective_rule(id)
		local priority = (effective_rule and effective_rule.priority) or rule.priority
		local category = DEFAULT_BOSS_RULES_BY_CHARACTER_ID[id] ~= nil and "Boss" or "Common"
		local custom_marker = type(config.enemy_overrides[id]) == "table" and " [Custom]" or ""
		if ui_state.rule_sort_mode == 3 then
			rule_labels[index] = string.format("%s > %s — priority %d%s", get_rule_group_name(id), rule.name, priority, custom_marker)
		else
			rule_labels[index] = string.format("%s: %s — priority %d%s", category, rule.name, priority, custom_marker)
		end
	end
	local selected_rule_index = 1
	for index, id in ipairs(rule_ids) do
		if id == ui_state.selected_rule_id then selected_rule_index = index; break end
	end
	if ui_state.selected_rule_id == nil or rule_ids[selected_rule_index] ~= ui_state.selected_rule_id then
		ui_state.selected_rule_id = rule_ids[selected_rule_index]
	end
	local supports_colored_rule_combo = type(imgui.begin_combo) == "function"
		and type(imgui.selectable) == "function"
		and type(imgui.end_combo) == "function"
		and type(imgui.push_style_color) == "function"
		and type(imgui.pop_style_color) == "function"
	if supports_colored_rule_combo then
		if imgui.begin_combo("Enemy rule", rule_labels[selected_rule_index]) then
			for index, id in ipairs(rule_ids) do
				local is_custom = type(config.enemy_overrides[id]) == "table"
				if is_custom then imgui.push_style_color(0, 0xff66bb66) end -- ImGuiCol.Text
				if imgui.selectable(rule_labels[index], index == selected_rule_index) then
					selected_rule_index = index
					ui_state.selected_rule_id = id
				end
				if is_custom then imgui.pop_style_color(1) end
			end
			imgui.end_combo()
		end
	else
		changed, selected_rule_index = imgui.combo("Enemy rule", selected_rule_index, rule_labels)
		if changed then ui_state.selected_rule_id = rule_ids[selected_rule_index] end
	end
	local character_id = ui_state.selected_rule_id
	local default = character_id and get_default_rule(character_id)
	local override = character_id and config.enemy_overrides[character_id]
	local effective = character_id and get_effective_rule(character_id)
	if default == nil then
		imgui.pop_item_width()
		imgui.tree_pop()
		return
	end

	imgui.text("Settings below override this enemy only. Defaults are the current script values.")
	if type(override) == "table" then
		imgui.text_colored("Script default: " .. describe_effective_rule(default), 0xff66bb66)
	end
	local enabled_index = (type(override) == "table" and override.enabled == false) and 3 or ((type(override) == "table" and override.enabled == true) and 2 or 1)
	changed, enabled_index = imgui.combo("Rule enabled", enabled_index, { "Use script default", "Enabled", "Disabled" })
	if changed then
		local target = get_or_create_override(character_id)
		target.enabled = enabled_index == 1 and nil or enabled_index == 2
		ui_state.dirty = true
		override, effective = config.enemy_overrides[character_id], get_effective_rule(character_id)
	end

	local priority_value = (effective and effective.priority) or default.priority
	changed, value = imgui.drag_int("Priority", priority_value, 1, 0, 1000)
	if changed then get_or_create_override(character_id).priority = value; ui_state.dirty = true end

	local boons = (effective and effective.boons) or {}
	for slot = 1, 3 do
		local boon_index = index_for_value(BOON_VALUES, boons[slot] or 0)
		changed, boon_index = imgui.combo("Boon priority " .. slot, boon_index, BOON_OPTIONS)
		if changed then set_rule_boon_slot(character_id, slot, BOON_VALUES[boon_index]); ui_state.dirty = true end
	end

	override = config.enemy_overrides[character_id]
	local wet_value = type(override) == "table" and override.wet_boon or "default"
	changed, value = imgui.combo("When Wet", index_for_value(WET_VALUES, wet_value), WET_OPTIONS)
	if changed then
		get_or_create_override(character_id).wet_boon = WET_VALUES[value] == "default" and nil or WET_VALUES[value]
		ui_state.dirty = true
	end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("When this target is Wet, the Mage uses this Boon at its next normal Boon opportunity. This does not force an immediate cast or interrupt another action.")
	end
	local oil_value = type(override) == "table" and override.oil_boon or "default"
	changed, value = imgui.combo("When Oiled", index_for_value(OIL_VALUES, oil_value), OIL_OPTIONS)
	if changed then
		get_or_create_override(character_id).oil_boon = OIL_VALUES[value] == "default" and nil or OIL_VALUES[value]
		ui_state.dirty = true
	end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("When this target is Oiled, the Mage uses this Boon at its next normal Boon opportunity. This does not force an immediate cast or interrupt another action.")
	end

	local family = get_rule_family(character_id)
	if family ~= nil then
		local family_members = get_family_members(family)
		imgui.separator()
		imgui.text(string.format("Family preset: %s (%d variants)", family.name, #family_members))
		if imgui.button("Apply selected settings to family") then
			local changed_count = apply_rule_to_family(character_id, family)
			ui_state.dirty = changed_count > 0 or ui_state.dirty
			log(string.format("family preset applied: family=%s source=%s variants=%d", family.name, tostring(character_id), changed_count))
		end
		imgui.same_line()
		if imgui.button("Restore family defaults") then
			local changed_count = restore_family_defaults(family)
			ui_state.dirty = changed_count > 0 or ui_state.dirty
			log(string.format("family defaults restored: family=%s variants=%d", family.name, changed_count))
		end
		if imgui.is_item_hovered() then
			imgui.set_tooltip("Removes saved overrides for every variant in this family. Click Save configuration to keep the change.")
		end
	end

	if imgui.button("Restore selected script default") then
		config.enemy_overrides[character_id] = nil
		ui_state.dirty = true
	end
	imgui.same_line()
	if imgui.button("Restore all script defaults") then
		config = make_default_config()
		ui_state.dirty = true
	end
	imgui.same_line()
	if imgui.button("Save configuration") then
		if save_config() then ui_state.dirty = false end
	end
	if ui_state.dirty then imgui.text_colored("Unsaved configuration changes", 0xff5252e0) end
	imgui.pop_item_width()
	imgui.tree_pop()
end)

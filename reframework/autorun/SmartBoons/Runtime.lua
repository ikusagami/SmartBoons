-- Read-only REFramework access. No enemy mappings or gameplay data writes.
local R = {}
local name_method
local status_ids = {}

function R.managed(value)
	if type(value) ~= "userdata" then return value end
	local ok, object = pcall(function() return sdk.to_managed_object(value) end)
	return ok and object or value
end

function R.call(object, method, ...)
	if object == nil then return nil end
	local args = { ... }
	local ok, value = pcall(function() return object[method](object, table.unpack(args)) end)
	if ok then return value end
end

function R.field(object, name)
	if object == nil then return nil end
	local ok, value = pcall(function() return object[name] end)
	if ok and value ~= nil then return value end
	local td = R.call(object, "get_type_definition")
	local definition = R.call(td, "get_field", name)
	return R.call(definition, "get_data", object)
end

function R.number(value)
	if value == nil then return nil end
	return tonumber(value) or tonumber(R.field(value, "m_value"))
		or tonumber(R.field(value, "value__")) or tonumber(R.field(value, "_Value"))
end

function R.truthy(value)
	if value == true then return true end
	if value == nil or value == false then return false end
	local number = R.number(value)
	return number ~= nil and number ~= 0 or tostring(value) == "true"
end

local function singleton(name)
	local ok, object = pcall(function() return sdk.get_managed_singleton(name) end)
	if ok then return object end
end

function R.character_id(character)
	local id = R.call(character, "get_CharaIDString") or R.call(character, "get_CharaID")
	if id ~= nil then return tostring(id) end
	local address = R.call(character, "get_address")
	return address ~= nil and string.format("0x%X", address) or "unknown"
end

function R.character_name(character)
	local id = R.character_id(character)
	if name_method == nil then
		local ok, td = pcall(function() return sdk.find_type_definition("app.GUIBase") end)
		if ok then name_method = R.call(td, "get_method", "getName(app.CharacterID)") end
	end
	local numeric_id = R.call(character, "get_CharaID")
	if name_method ~= nil and numeric_id ~= nil then
		local ok, value = pcall(function() return name_method:call(nil, numeric_id) end)
		if ok and type(value) == "string" then
			local name = value:gsub("[\r\n]", " "):match("^%s*(.-)%s*$")
			if name ~= "" and not name:match("^ch%d") and not name:match("^%?+$") then
				return name, "GUIBase.getName"
			end
		end
	end
	return id, "CharacterID"
end

local function position(character)
	local transform = R.call(character, "get_Transform") or R.field(character, "<Transform>k__BackingField")
	return R.call(transform, "get_Position")
end

local function distance(first, second)
	if first == nil or second == nil then return math.huge end
	local ok, value = pcall(function() return (first - second):length() end)
	return ok and tonumber(value) or math.huge
end

function R.is_alive(character)
	if character == nil or R.call(character, "get_Valid") == false then return false end
	local hit = R.call(character, "get_Hit") or R.field(character, "<Hit>k__BackingField")
	if R.truthy(R.call(character, "get_IsDead")) or R.truthy(R.call(hit, "get_IsDie"))
		or R.truthy(R.call(hit, "get_IsStartDead")) then return false end
	local hp = R.number(R.call(character, "get_Hp"))
	local hit_hp = R.number(R.call(hit, "get_Hp"))
	return not ((hp ~= nil and hp <= 0) or (hit_hp ~= nil and hit_hp <= 0))
end

function R.is_boss(character)
	local flag = R.call(character, "get_IsBoss")
	if flag ~= nil then return R.truthy(flag), "IsBoss.getter" end
	flag = R.field(character, "<IsBoss>k__BackingField")
	if flag ~= nil then return R.truthy(flag), "IsBoss.field" end
	return false, "unavailable"
end

local function closer(candidate, current)
	if current == nil or candidate.distance < current.distance then return true end
	if candidate.distance ~= current.distance then return false end
	if candidate.id ~= current.id then return candidate.id < current.id end
	return (R.call(candidate.character, "get_address") or 0) < (R.call(current.character, "get_address") or 0)
end

function R.select_target(config)
	local manager = singleton("app.EnemyManager")
	local enemies = R.field(manager, "_EnemyList")
	local count = R.number(R.call(enemies, "get_Count")) or 0
	local characters = singleton("app.CharacterManager")
	local player = R.call(characters, "get_ManualPlayer") or R.field(characters, "<ManualPlayer>k__BackingField")
	local player_position = position(player)
	local boss, common
	for index = 0, count - 1 do
		local entry = R.managed(R.call(enemies, "get_Item", index) or R.field(enemies, index))
		local character = R.field(entry, "_Chara") or R.field(entry, "<Chara>k__BackingField")
		if R.is_alive(character) then
			local is_boss, boss_source = R.is_boss(character)
			local meters = distance(position(character), player_position)
			local limit = is_boss and config.max_boss_distance or config.max_common_enemy_distance
			if meters <= limit then
				local target = { character = character, id = R.character_id(character), distance = meters,
					is_boss = is_boss, boss_source = boss_source }
				if is_boss then
					if closer(target, boss) then boss = target end
				elseif closer(target, common) then common = target end
			end
		end
	end
	return boss or common
end

function R.describe_target(target)
	local name = R.character_name(target.character)
	local warning = target.boss_source == "unavailable" and " boss_flag=unavailable" or ""
	return string.format("%q id=%s category=%s%s distance=%.1fm",
		name, target.id, target.is_boss and "boss" or "common", warning, target.distance)
end

function R.read_statuses(character)
	local controller = R.call(character, "get_StatusConditionCtrl") or R.field(character, "<StatusConditionCtrl>k__BackingField")
	local flag = R.number(R.field(controller, "ActiveStatusConditionFlag"))
	-- Unknown data is distinct from an inactive status; never infer Wet from rain.
	if flag == nil or flag ~= flag or flag < 0 or flag >= 2 ^ 53 or flag % 1 ~= 0 then
		return { source = "unavailable" }
	end
	if status_ids.Wet == nil or status_ids.Oil == nil then
		local ok, td = pcall(function() return sdk.find_type_definition("app.StatusConditionDef.StatusConditionEnum") end)
		local fields = ok and R.call(td, "get_fields") or nil
		for _, field in ipairs(fields or {}) do
			local name = R.call(field, "get_name")
			if (name == "Wet" or name == "Oil") and R.truthy(R.call(field, "is_static")) then
				local id = R.number(R.call(field, "get_data"))
				if id ~= nil and id >= 0 and id < 53 and id % 1 == 0 then status_ids[name] = id end
			end
		end
	end
	local function active(name)
		local id = status_ids[name]
		if id ~= nil then return math.floor(flag / (2 ^ id)) % 2 == 1 end
	end
	return { wet = active("Wet"), oil = active("Oil"), flag = flag, source = "ActiveStatusConditionFlag" }
end

function R.read_profiles(character)
	local hit = R.call(character, "get_Hit") or R.field(character, "<Hit>k__BackingField")
	local regions = R.call(hit, "get_CachedRegionStatusCtrl") or R.field(hit, "<CachedRegionStatusCtrl>k__BackingField")
		or R.field(character, "<RegionStatusCtrl>k__BackingField")
	if regions == nil then return nil, "region controller unavailable" end
	-- RegionStatusNo is a table index; _RegionNo is a separate HP/part identifier.
	local data = R.call(regions, "get_RegionStatusDataProp") or R.field(regions, "<RegionStatusDataProp>k__BackingField")
		or R.field(regions, "Data")
	local states = R.field(data, "_IntermediateRegionStatusParams")
	local region_count = 0
	local function include_state(state)
		local parts = R.field(state, "_IntermediateRegionParams")
		region_count = math.max(region_count, R.number(R.call(parts, "get_Count")) or 0)
	end
	for index = 0, (R.number(R.call(states, "get_Count")) or 0) - 1 do
		include_state(R.call(states, "get_Item", index) or R.field(states, index))
	end
	include_state(R.call(regions, "get_NowActiveRegionStatusParam"))
	-- The standalone tracer validated the fallback range when metadata is absent.
	local last_status = region_count > 0 and region_count - 1 or 64
	local profiles = {}
	for status = 0, last_status do
		local params = R.call(regions, "getActiveRegionParam", status)
		local rates = R.field(params, "_DamageAdjustRateMgc")
		local fire, ice, thunder = R.number(R.field(rates, 1)), R.number(R.field(rates, 2)), R.number(R.field(rates, 3))
		if fire ~= nil and ice ~= nil and thunder ~= nil then profiles[#profiles + 1] = { fire, ice, thunder } end
	end
	if #profiles == 0 then return nil, "active elemental rates unavailable" end
	return profiles
end

function R.actor_character(controller)
	controller = R.managed(controller)
	return R.managed(R.call(controller, "get_Character") or R.field(controller, "<Character>k__BackingField"))
end

function R.is_boon_equipped(controller, skill)
	local character = R.actor_character(controller)
	local human = R.call(character, "get_Human") or R.field(character, "<Human>k__BackingField")
	local skills = R.call(human, "get_SkillContext") or R.field(human, "<SkillContext>k__BackingField")
	local job = R.call(human, "get_JobContext") or R.field(human, "<JobContext>k__BackingField")
	local job_id = R.field(job, "CurrentJob") or R.call(job, "get_CurrentJob")
		or R.field(human, "<CurrentJob>k__BackingField") or R.call(human, "get_CurrentJob")
	if skills == nil or job_id == nil then return false end
	local equipped = R.call(skills, "hasEquipedSkill", job_id, skill)
	if equipped == nil then equipped = R.call(skills, "hasEquipedSkill(app.Character.JobEnum, app.HumanCustomSkillID)", job_id, skill) end
	return R.truthy(equipped)
end

function R.equipped_boons(controller)
	local equipped = {}
	for _, skill in ipairs({ 29, 30, 31 }) do equipped[skill] = R.is_boon_equipped(controller, skill) end
	return equipped
end

return R

local MOD_NAME = "SmartBoons"

-- Operational logs are always available. Developer-only discovery logging is controlled in the UI.
local LOG_ENABLED = true
local DEFAULT_BOSS_DISTANCE_TIE_METERS = 15.0
local DEFAULT_BOSS_MAX_DISTANCE_METERS = 50.0 -- A mapped boss beyond this distance is not considered part of the current fight.
local DEFAULT_COMMON_ENEMY_MAX_DISTANCE_METERS = 25.0 -- Common enemies never override a relevant boss.
local STATUS_DISCOVERY_TARGET_ID = nil -- Nearest living enemy; set an exact CharacterID only for a fixed discovery target.
local STATUS_PROBE_INTERVAL_SECONDS = 1.0

-- Exact CharacterID values from EnemyManager, ordered by boss priority.
local DEFAULT_BOSS_RULES_BY_CHARACTER_ID = {

	["ch257000_00"] = { name = "Drake", priority = 100, boons = { 30, 31 } },
	["ch257001_00"] = { name = "Lesser Dragon", priority = 95, boons = { 31, 30 }, wet_boon = 30 },
	["ch254001_00"] = { name = "Gorechimera", priority = 60, boons = { 29, 31 } },
	["ch253000_00"] = { name = "Griffin", priority = 40, boons = { 29, 30 } },
	["ch260000_00"] = { name = "Garm", priority = 40, boons = { 29, 30 }, wet_boon = 30 },
	["ch260001_00"] = { name = "Warg", priority = 40, boons = { 29, 30 }, wet_boon = 30 },
	["ch251000_00"] = { name = "Ogre", priority = 40, boons = { 29, 30 }, wet_boon = 30 },
	["ch251001_00"] = { name = "Grim Ogre", priority = 40, boons = { 29, 30 }, wet_boon = 30 },
	["ch256001_00"] = { name = "Goreminotaur", priority = 40, boons = { 29 }, wet_boon = 30 },
	["ch227001_00"] = { name = "Wight", priority = 40, boons = { 29, 30 } },
	["ch226003_00"] = { name = "Skeleton Lord", priority = 35, boons = { 30, 31 } },
	["ch250000_00"] = { name = "Cyclops", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_01"] = { name = "Cyclops (unarmed)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_10"] = { name = "Cyclops (arm/leg armor)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_11"] = { name = "Cyclops (leg/face armor)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_12"] = { name = "Cyclops (arm/leg/face armor)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_20"] = { name = "Cyclops (arm/leg/body armor)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_21"] = { name = "Cyclops (arm/leg/helmet armor)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },
	["ch250000_22"] = { name = "Cyclops (full armor)", priority = 30, boons = { 31 }, wet_boon = 30, oil_boon = 29 },

	-- can easily be affected by elemental status effects
	["ch256000_00"] = { name = "Minotaur", priority = 40, boons = {29}, wet_boon = 30 },

	-- Mapped for future status rules; no normal elemental preference is forced.
	["ch254000_00"] = { name = "Chimera", priority = 2, boons = {}, wet_boon = 30, oil_boon = 29 },
	["ch227000_00"] = { name = "Lich", priority = 2, boons = {}, oil_boon = 29 },
	["ch254000_40"] = { name = "Corrupted Chimera", priority = 1, boons = {} },
	["ch255000_01"] = { name = "Medusa", priority = 1, boons = {} },
	["ch253001_00"] = { name = "Sphinx", priority = 1, boons = {} },
	["ch229000_00"] = { name = "Dullahan", priority = 1, boons = {} },

	-- Last boss, there's no priority needed
	["ch258000_00"] = { name = "Dragon", priority = 1, boons = { 30, 31 } },

}

-- Common enemies are considered only when no living mapped boss is in range.
-- Empty Boon lists deliberately preserve the Mage's normal choice; their Wet/Oil behavior remains configurable in the UI.
local DEFAULT_COMMON_RULES_BY_CHARACTER_ID = {
	-- Goblin family: no normal elemental preference.
	["ch220000_00"] = { name = "Goblin", priority = 1, boons = {} },
	["ch220000_02"] = { name = "Goblin (shield)", priority = 1, boons = {} },
	["ch220000_03"] = { name = "Goblin (thrower)", priority = 1, boons = {} },
	["ch220000_04"] = { name = "Goblin leader", priority = 1, boons = {} },
	["ch220000_10"] = { name = "Goblin (strong)", priority = 1, boons = {} },
	["ch220000_12"] = { name = "Goblin (strong shield)", priority = 1, boons = {} },
	["ch220000_13"] = { name = "Goblin (strong thrower)", priority = 1, boons = {} },
	["ch220000_14"] = { name = "Goblin leader (strong)", priority = 1, boons = {} },
	-- Hobgoblin family
	["ch220001_00"] = { name = "Hobgoblin", priority = 12, boons = { 31 } },
	["ch220001_02"] = { name = "Hobgoblin (thrower)", priority = 12, boons = { 31 } },
	["ch220001_03"] = { name = "Hobgoblin leader", priority = 12, boons = { 31 } },
	["ch220001_10"] = { name = "Hobgoblin (strong)", priority = 12, boons = { 31 } },
	["ch220001_12"] = { name = "Hobgoblin (strong thrower)", priority = 12, boons = { 31 } },
	["ch220001_13"] = { name = "Hobgoblin leader (strong)", priority = 12, boons = { 31 } },
	["ch220001_20"] = { name = "Hobgoblin (purple)", priority = 12, boons = { 31 } },
	["ch220001_22"] = { name = "Hobgoblin (purple thrower)", priority = 12, boons = { 31 } },
	["ch220001_23"] = { name = "Hobgoblin leader (purple)", priority = 12, boons = { 31 } },
	["ch220001_40"] = { name = "Hobgoblin (corrupted)", priority = 14, boons = { 31, 30 } },
	["ch220001_41"] = { name = "Hobgoblin fighter (corrupted)", priority = 14, boons = { 31, 30 } },
	["ch220001_42"] = { name = "Hobgoblin thrower (corrupted)", priority = 14, boons = { 31, 30 } },
	["ch220001_43"] = { name = "Hobgoblin leader (corrupted)", priority = 14, boons = { 31, 30 } },
	-- Chopper family
	["ch220002_00"] = { name = "Chopper", priority = 12, boons = { 29, 31 } },
	["ch220002_03"] = { name = "Chopper leader", priority = 12, boons = { 29, 31 } },
	-- Knacker family
	["ch220003_00"] = { name = "Knacker", priority = 12, boons = { 30, 31 } },
	["ch220003_03"] = { name = "Knacker leader", priority = 12, boons = { 30, 31 } },
	-- Group of annoying lizards
	["ch221000_00"] = { name = "Saurian", priority = 15, boons = { 30, 31 } },
	["ch221001_00"] = { name = "Asp", priority = 14, boons = { 31 } },
	["ch221002_00"] = { name = "Rattler", priority = 15, boons = { 30, 31 } },
	["ch221002_20"] = { name = "Rattler (purple)", priority = 15, boons = { 30, 31 } },
	["ch221003_00"] = { name = "Magma Scale", priority = 15, boons = { 30, 31 } },
	["ch221004_00"] = { name = "Serpent", priority = 15, boons = { 30, 29 } },
	-- Harpy group
	["ch222000_00"] = { name = "Harpy", priority = 12, boons = { 29 } },
	["ch222001_00"] = { name = "Venin Harpy", priority = 12, boons = { 29 } },
	["ch222002_00"] = { name = "Gore Harpy", priority = 14, boons = { 30, 31 } },
	["ch222003_00"] = { name = "Succubus", priority = 14, boons = { 31, 29 } },
	["ch222003_20"] = { name = "Succubus (purple)", priority = 14, boons = { 31, 29 } },
	["ch223000_00"] = { name = "Wolf", priority = 12, boons = { 29, 31 } },
	["ch223001_00"] = { name = "Redwolf", priority = 14, boons = { 30, 31 } },
	["ch223001_01"] = { name = "Redwolf alpha", priority = 14, boons = { 30, 31 } },
	-- These contains special interactions that are not yet fully understood.
	["ch224000_00"] = { name = "Slime", priority = 10, boons = { 30, 31 } },
	["ch224001_00"] = { name = "Ooze", priority = 10, boons = {} },
	["ch224002_00"] = { name = "Sludge", priority = 10, boons = { 30, 31 } },
	-- Phantom group
	["ch225000_00"] = { name = "Phantom", priority = 1, boons = {} },
	["ch225001_00"] = { name = "Phantasm", priority = 1, boons = {} },
	["ch225002_00"] = { name = "Specter", priority = 1, boons = {} },
	-- Skeleton family
	["ch226000_00"] = { name = "Skeleton", priority = 12, boons = { 30, 31 } },
	["ch226000_01"] = { name = "Skeleton fighter (unarmored)", priority = 12, boons = { 30, 31 } },
	["ch226001_01"] = { name = "Skeleton fighter", priority = 12, boons = { 30, 31 } },
	["ch226001_03"] = { name = "Skeleton mage", priority = 12, boons = { 30, 31 } },
	["ch226001_05"] = { name = "Skeleton warrior", priority = 12, boons = { 30, 31 } },
	["ch226001_06"] = { name = "Skeleton sorcerer", priority = 12, boons = { 30, 31 } },
	["ch226002_01"] = { name = "Skeleton fighter (strong)", priority = 12, boons = { 30, 31 } },
	["ch226002_03"] = { name = "Skeleton mage (strong)", priority = 12, boons = { 30, 31 } },
	["ch226002_05"] = { name = "Skeleton warrior (strong)", priority = 12, boons = { 30, 31 } },
	["ch226002_06"] = { name = "Skeleton sorcerer (strong)", priority = 12, boons = { 30, 31 } },
	-- Undead family
	["ch228000_00"] = { name = "Undead", priority = 12, boons = { 29 } },
	["ch228000_01"] = { name = "Undead (Battahl)", priority = 12, boons = { 29 } },
	["ch228001_00"] = { name = "Undead (female)", priority = 12, boons = { 29 } },
	["ch228001_01"] = { name = "Undead (Battahl female)", priority = 12, boons = { 29 } },
	["ch228002_00"] = { name = "Stout Undead", priority = 14, boons = {} },
	-- Human group
	["ch230000_01"] = { name = "Rogue fighter", priority = 1, boons = {} },
	["ch230000_02"] = { name = "Rogue archer", priority = 1, boons = {} },
	["ch230000_03"] = { name = "Rogue mage", priority = 1, boons = {} },
	["ch230000_04"] = { name = "Rogue thief", priority = 1, boons = {} },
	["ch230001_01"] = { name = "Lost Mercenary fighter", priority = 1, boons = {} },
	["ch230001_02"] = { name = "Lost Mercenary archer", priority = 1, boons = {} },
	["ch230001_03"] = { name = "Lost Mercenary mage", priority = 1, boons = {} },
	["ch230001_04"] = { name = "Lost Mercenary thief", priority = 1, boons = {} },
	["ch230001_05"] = { name = "Lost Mercenary warrior", priority = 1, boons = {} },
	["ch230001_06"] = { name = "Lost Mercenary sorcerer", priority = 1, boons = {} },
	["ch230002_01"] = { name = "Lost Mercenary fighter (strong)", priority = 1, boons = {} },
	["ch230002_02"] = { name = "Lost Mercenary archer (strong)", priority = 1, boons = {} },
	["ch230002_03"] = { name = "Lost Mercenary mage (strong)", priority = 1, boons = {} },
	["ch230002_04"] = { name = "Lost Mercenary thief (strong)", priority = 1, boons = {} },
	["ch230002_05"] = { name = "Lost Mercenary warrior (strong)", priority = 1, boons = {} },
	["ch230002_06"] = { name = "Lost Mercenary sorcerer (strong)", priority = 1, boons = {} },
	["ch230012_02"] = { name = "Coral Snake archer", priority = 1, boons = {} },
	["ch230012_04"] = { name = "Coral Snake thief", priority = 1, boons = {} },
	["ch230100_04"] = { name = "Scavenger", priority = 12, boons = { 31 } },
}

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
		distance_tie = DEFAULT_BOSS_DISTANCE_TIE_METERS,
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
	create_command_hook_installed = false,
	pack_hook_installed = false,
	logged_enemy_tracks = {},
	logged_schemas = {},
	logged_argument_shapes = {},
	logged_pack_commands = {},
	logged_enemy_manager_catalog = false,
	character_id_names = {},
	last_active_boss_key = nil,
	logged_boss_life_surfaces = {},
	logged_dead_bosses = {},
	logged_distant_bosses = {},
	logged_status_schema = false,
	last_status_probe_time = 0,
	last_status_snapshot = nil,
	status_condition_ids = nil,
	logged_status_candidate_names = false,
	last_weather_boon_state = {},
	logged_actor_sources = {},
	logged_replacement_surface = false,
	pack_stage_logged = false,
	equipped_probe_logged = false,
	pending_create_args = nil,
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

local function dump_schema_once(object, label)
	if not developer_mode_enabled() or object == nil or state.logged_schemas[label] then return end
	object = managed_object(object)
	local ok, td = pcall(function() return object:get_type_definition() end)
	if not ok or td == nil then return end
	state.logged_schemas[label] = true
	local methods, fields = {}, {}
	for _, method in ipairs(td:get_methods() or {}) do methods[#methods + 1] = tostring(method:get_name()) end
	for _, field in ipairs(td:get_fields() or {}) do fields[#fields + 1] = tostring(field:get_name()) end
	log(string.format("schema %s type=%s methods=%s fields=%s", label, describe_object(object), table.concat(methods, ","), table.concat(fields, ",")))
end

local function describe_command(command, label)
	if command == nil then return label .. "=nil" end
	return string.format("%s=%s skill=%s", label, describe_object(command), tostring(call_method(command, "get_CustomSkillID")))
end

local function describe_enemy_track(action_interface)
	if action_interface == nil then return "enemy=nil" end
	dump_schema_once(action_interface, "ActionInterface")
	local action_type = sdk.find_type_definition("app.ActionInterface")
	local field = action_type and action_type:get_field("<EnemyTrack>k__BackingField")
	if field == nil then return "enemy=EnemyTrackFieldUnavailable" end
	local ok, enemy_track = pcall(function() return field:get_data(action_interface) end)
	if not ok or enemy_track == nil then return "enemy=nil" end
	enemy_track = managed_object(enemy_track)
	dump_schema_once(enemy_track, "EnemyTrack")
	return "enemy=" .. describe_object(enemy_track)
end

local function record_enemy_track(action_interface)
	-- Owner discovery is intentionally separate from EnemyTrack; it does not affect selection.
	if developer_mode_enabled() and action_interface ~= nil then
		local key = "ActionInterface:" .. describe_address(action_interface)
		if not state.logged_actor_sources[key] then
			state.logged_actor_sources[key] = true
			local values = {}
			for _, name in ipairs({ "get_Character", "get_OwnerCharacter", "get_Human", "get_Pawn", "get_Owner", "get_ParentCharacter" }) do
				values[#values + 1] = name .. "=" .. describe_object(managed_object(call_method(action_interface, name)))
			end
			log("actor owner probe: source=ActionInterface address=" .. describe_address(action_interface) .. " " .. table.concat(values, " | "))
		end
	end
	local enemy_type = describe_enemy_track(action_interface):gsub("^enemy=", "")
	if developer_mode_enabled() and enemy_type ~= "nil" and enemy_type ~= "" and not state.logged_enemy_tracks[enemy_type] then
		state.logged_enemy_tracks[enemy_type] = true
		log("enemy track discovered: " .. enemy_type)
	end
	return enemy_type
end

local function probe_owner_surface_once(object, label)
	if not developer_mode_enabled() or object == nil or state.logged_actor_sources[label] then return end
	state.logged_actor_sources[label] = true
	object = managed_object(object)
	local td = object:get_type_definition()
	local methods, fields = {}, {}
	for _, method in ipairs(td and td:get_methods() or {}) do
		local name = tostring(method:get_name())
		local lower = name:lower()
		if lower:find("character", 1, true) or lower:find("owner", 1, true) or lower:find("human", 1, true) or lower:find("pawn", 1, true) or lower:find("action", 1, true) then
			methods[#methods + 1] = name
		end
	end
	for _, field in ipairs(td and td:get_fields() or {}) do
		local name = tostring(field:get_name())
		local lower = name:lower()
		if lower:find("character", 1, true) or lower:find("owner", 1, true) or lower:find("human", 1, true) or lower:find("pawn", 1, true) or lower:find("action", 1, true) then
			local value = get_field_data(object, name)
			fields[#fields + 1] = name .. "=" .. describe_object(value)
		end
	end
	log(string.format("actor owner surface: source=%s type=%s methods=%s fields=%s", label, describe_object(object), table.concat(methods, ","), table.concat(fields, ",")))
end

local get_best_equipped_boon
local is_actor_boon_equipped

local function probe_enemy_manager_once()
	if not developer_mode_enabled() or state.logged_enemy_manager_catalog then return end
	local manager = sdk.get_managed_singleton("app.EnemyManager")
	local list = get_field_data(manager, "_EnemyList")
	local count = tonumber(call_method(list, "get_Count")) or 0
	if count <= 0 then return end

	state.logged_enemy_manager_catalog = true
	local entries = {}
	for index = 0, math.min(count - 1, 63) do
		local entry = managed_object(call_method(list, "get_Item", index))
		local character = get_field_data(entry, "_Chara") or get_field_data(entry, "<Chara>k__BackingField")
		local character_id = read_enum_value(call_method(character, "get_CharaID"))
		local character_name = resolve_character_id_name(character_id)
		entries[#entries + 1] = string.format("%d:%s chara_id=%s name=%s", index, describe_object(character), tostring(character_id), tostring(character_name))
	end
	log("EnemyManager catalog: count=" .. tostring(count) .. " entries=" .. table.concat(entries, " | "))
end

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
	if not state.logged_status_schema then
		state.logged_status_schema = true
		local methods, fields = {}, {}
		for _, method in ipairs(td and td:get_methods() or {}) do
			local name = tostring(method:get_name())
			local lower = name:lower()
			if lower:find("status", 1, true) or lower:find("condition", 1, true) or lower:find("debil", 1, true) or lower:find("freeze", 1, true) or lower:find("wet", 1, true) or lower:find("water", 1, true) then
				methods[#methods + 1] = name
			end
		end
		for _, field in ipairs(td and td:get_fields() or {}) do
			local name = tostring(field:get_name())
			local lower = name:lower()
			if lower:find("status", 1, true) or lower:find("condition", 1, true) or lower:find("debil", 1, true) or lower:find("freeze", 1, true) or lower:find("wet", 1, true) or lower:find("water", 1, true) then
				fields[#fields + 1] = name
			end
		end
		log(string.format("status controller schema: target=%s type=%s methods=%s fields=%s", tostring(character_id), describe_object(controller), table.concat(methods, ","), table.concat(fields, ",")))
	end

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

local function log_boss_life_surface_once(character, character_id)
	if not developer_mode_enabled() or character == nil or state.logged_boss_life_surfaces[character_id] then return end
	state.logged_boss_life_surfaces[character_id] = true
	local hit = managed_object(call_method(character, "get_Hit"))
	for _, item in ipairs({ { "BossCharacter", character }, { "BossHit", hit } }) do
		local label, object = item[1], item[2]
		local td = object and object:get_type_definition() or nil
		local methods, fields = {}, {}
		for _, method in ipairs(td and td:get_methods() or {}) do methods[#methods + 1] = tostring(method:get_name()) end
		for _, field in ipairs(td and td:get_fields() or {}) do fields[#fields + 1] = tostring(field:get_name()) end
		log(string.format("boss life schema: id=%s label=%s type=%s methods=%s fields=%s", character_id, label, describe_object(object), table.concat(methods, ","), table.concat(fields, ",")))
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
		if is_boss and rule ~= nil then log_boss_life_surface_once(character, character_id) end
		local distance = get_distance_between(get_character_position(character), player_position)
		if rule ~= nil and not is_boss_alive(character) then
			if is_boss and not state.logged_dead_bosses[character_id] then
				state.logged_dead_bosses[character_id] = true
				log("dead boss ignored: " .. rule.name .. " id=" .. character_id)
			end
		elseif rule ~= nil and distance > max_distance then
			if is_boss and not state.logged_distant_bosses[character_id] then
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
	if target_key ~= state.last_active_boss_key then
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
	if target.wet_boon ~= nil or target.oil_boon ~= nil then
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

local function resolve_main_pawn_human()
	local pawn = nil
	for _, source in ipairs({
		{ "app.PawnManager", "get_MainPawn", "<MainPawn>k__BackingField" },
		{ "app.CharacterManager", "get_MainPawn", "<MainPawn>k__BackingField" },
		{ "app.CharacterManager", "get_ManualPlayerMainPawn", nil },
	}) do
		local manager = sdk.get_managed_singleton(source[1])
		pawn = call_method(manager, source[2]) or get_field_data(manager, source[3])
		if pawn ~= nil then break end
	end
	if pawn == nil then return nil, nil, nil, "main_pawn_unresolved" end

	local candidates = {
		pawn,
		call_method(pawn, "get_CachedCharacter"),
		call_method(pawn, "get_Character"),
		call_method(pawn, "get_Chara"),
		get_field_data(pawn, "<CachedCharacter>k__BackingField"),
		get_field_data(pawn, "<Character>k__BackingField"),
	}
	for _, character in ipairs(candidates) do
		local human = call_method(character, "get_Human") or get_field_data(character, "<Human>k__BackingField")
		if human ~= nil then return pawn, character, human, "resolved" end
	end
	return pawn, nil, nil, "human_unresolved"
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

local function probe_equipped_skills_once(controller)
	if not developer_mode_enabled() or state.equipped_probe_logged then return end
	state.equipped_probe_logged = true
	dump_schema_once(controller, "BlackBoardController")
	local pawn, character, human, status = resolve_main_pawn_human()
	local skill_context = human and (call_method(human, "get_SkillContext") or get_field_data(human, "<SkillContext>k__BackingField")) or nil
	local job_context = human and (call_method(human, "get_JobContext") or get_field_data(human, "<JobContext>k__BackingField")) or nil
	local job_id = get_field_data(job_context, "CurrentJob") or call_method(job_context, "get_CurrentJob") or get_field_data(human, "<CurrentJob>k__BackingField") or call_method(human, "get_CurrentJob")
	log(string.format("equipped skill probe: status=%s pawn=%s character=%s human=%s job=%s skill_context=%s", status, describe_object(pawn), describe_object(character), describe_object(human), tostring(job_id), describe_object(skill_context)))
	dump_schema_once(human, "MageHuman")
	dump_schema_once(skill_context, "MageSkillContext")
	if skill_context ~= nil and job_id ~= nil then
		local values = {}
		for skill_id, name in pairs(BOON_NAMES) do
			values[#values + 1] = string.format("%d=%s", skill_id, tostring(is_skill_equipped(skill_context, job_id, skill_id)))
		end
		table.sort(values)
		log("equipped boon probe: " .. table.concat(values, " | "))
	end
end

local function log_replacement_surface_once(command)
	if not developer_mode_enabled() or command == nil or state.logged_replacement_surface then return end
	state.logged_replacement_surface = true
	local td = command:get_type_definition()
	local methods, fields = {}, {}
	for _, method in ipairs(td:get_methods() or {}) do
		local name = tostring(method:get_name())
		if name:find("Skill", 1, true) or name:find("Custom", 1, true) or name:find("set_", 1, true) then methods[#methods + 1] = name end
	end
	for _, field in ipairs(td:get_fields() or {}) do
		local name = tostring(field:get_name())
		if name:find("Skill", 1, true) or name:find("Custom", 1, true) then fields[#fields + 1] = name end
	end
	log(string.format("boon replacement probe: command=%s methods=%s fields=%s", describe_object(command), table.concat(methods, ","), table.concat(fields, ",")))
end

local function trace_pack_data(controller, pack_data, pack_target)
	if not config.enabled then return false end
	if pack_data == nil then return false end
	-- The blackboard controller belongs to the actor about to dispatch this pack.
	-- Convert it before reading Character: hook arguments arrive as native userdata.
	controller = managed_object(controller)
	local pack = call_method(managed_object(pack_data), "get_Pack")
	local nodes = call_method(pack, "getActInterNodes")
	local node = managed_object(call_method(nodes, "get_First"))
	if developer_mode_enabled() and not state.pack_stage_logged then
		state.pack_stage_logged = true
		log(string.format("pack stages: data=%s pack=%s nodes=%s first=%s target=%s", describe_object(pack_data), describe_object(pack), describe_object(nodes), describe_object(node), describe_object(pack_target)))
	end
	local visited = 0
	while node ~= nil and visited < 64 do
		visited = visited + 1
		local next_node = managed_object(call_method(node, "get_Next"))
		local value = managed_object(call_method(node, "get_Value"))
		local primary = call_method(value, "get_PrimaryCommand")
		local skill_id = normalize_skill_id(call_method(primary, "get_CustomSkillID"))
		if BOON_NAMES[skill_id] ~= nil then
			if developer_mode_enabled() and controller ~= nil then
				local key = "BlackBoard:" .. describe_address(controller)
				if not state.logged_actor_sources[key] then
					state.logged_actor_sources[key] = true
					local values = {}
					for _, name in ipairs({ "get_Character", "get_ParentCharacter", "get_Human" }) do
						values[#values + 1] = name .. "=" .. describe_object(managed_object(call_method(controller, name)))
					end
					log("actor owner probe: source=BlackBoard address=" .. describe_address(controller) .. " " .. table.concat(values, " | "))
				end
			end
			probe_enemy_manager_once()
			probe_equipped_skills_once(controller)
			dump_schema_once(value, "ActInterNode")
			dump_schema_once(primary, "BoonCommand")
			dump_schema_once(nodes, "LinkedListNodes")
			local expected_skill_id, enemy_source = get_expected_boon(controller)
			local mode = expected_skill_id == nil and "observe" or (skill_id == expected_skill_id and "keep" or "replace")
			local actor_character = resolve_actor_human(controller)
			local actor_id = call_method(actor_character, "get_CharaIDString") or describe_object(actor_character)
			log(string.format("boon candidate: actor=%s skill=%s (%s) enemy=%s expected=%s (%s) mode=%s", tostring(actor_id), tostring(skill_id), BOON_NAMES[skill_id], tostring(enemy_source), tostring(expected_skill_id), BOON_NAMES[expected_skill_id] or "none", mode))
			if expected_skill_id ~= nil and skill_id ~= expected_skill_id then
				log_replacement_surface_once(primary)
				return true, expected_skill_id, skill_id, controller
			end
		elseif developer_mode_enabled() then
			local signature = describe_command(primary, "primary")
			if not state.logged_pack_commands[signature] then state.logged_pack_commands[signature] = true; log("pack observed: " .. signature) end
		end
		node = next_node
	end
	return false
end

local function trace_create_command(args)
	if not developer_mode_enabled() then return end
	local values = {}
	for index, value in ipairs(args or {}) do values[#values + 1] = string.format("%d=%s", index, describe_object(value)) end
	local node, action_interface = args and args[2], args and args[3]
	local shape = table.concat(values, ", ") .. "; " .. describe_command(call_method(node, "get_PrimaryCommand"), "primary") .. "; " .. describe_command(call_method(node, "get_SecondaryCommand"), "secondary") .. "; " .. describe_enemy_track(action_interface)
	if not state.logged_argument_shapes[shape] then state.logged_argument_shapes[shape] = true; log("createCommand args: " .. shape) end
end

local function install_create_command_hook()
	if state.create_command_hook_installed then return true end
	local td = sdk.find_type_definition("app.ActInterNode")
	local method = td and td:get_method("createCommand")
	if method == nil then log("app.ActInterNode.createCommand not available"); return false end
	sdk.hook(method,
		function(args)
			state.pending_create_args = args
			record_enemy_track(args and args[3] or nil)
			probe_owner_surface_once(args and args[6] or nil, "ActInterExecutor")
		end,
		function(retval)
			local args = state.pending_create_args
			state.pending_create_args = nil
			if args ~= nil then pcall(function() trace_create_command(args) end) end
			return retval
		end
	)
	state.create_command_hook_installed = true
	log("EnemyTrack hook installed")
	return true
end

local function install_pack_hook()
	if state.pack_hook_installed then return true end
	local td = sdk.find_type_definition("app.AIBlackBoardExtensions")
	local method = td and td:get_method("setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)")
	if method == nil then log("setBBValuesToExecuteActInter not available"); return false end
	sdk.hook(method, function(args)
		if args == nil then return end
		local should_replace, expected_skill_id, wrong_skill_id, owner_controller = trace_pack_data(args[2], args[3], args[4])
		if not should_replace then return end
		if not is_actor_boon_equipped(owner_controller, expected_skill_id) then
			log(string.format("ActInter replacement cancelled: expected=%s is not equipped by this action's Mage", tostring(expected_skill_id)))
			return
		end
		local path = BOON_PACK_PATH_BY_SKILL[expected_skill_id]
		local ok_pack, replacement = pcall(function() return sdk.create_userdata("app.ActInterPackData", path) end)
		local ok_arg = ok_pack and replacement ~= nil and pcall(function() args[3] = sdk.to_ptr(replacement) end)
		if ok_arg then log(string.format("ActInter pack argument replaced: from=%s to=%s", tostring(wrong_skill_id), tostring(expected_skill_id))) else log("ActInter replacement failed; original dispatch allowed") end
	end)
	state.pack_hook_installed = true
	log("ActInterPack replacement hook installed")
	return true
end

re.on_application_entry("LateUpdateBehavior", function()
	install_create_command_hook()
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
local RULE_FAMILIES = {
	{ name = "Goblin", members = { "ch220000_00", "ch220000_02", "ch220000_03", "ch220000_04", "ch220000_10", "ch220000_12", "ch220000_13", "ch220000_14" } },
	{ name = "Hobgoblin", members = { "ch220001_00", "ch220001_02", "ch220001_03", "ch220001_10", "ch220001_12", "ch220001_13", "ch220001_20", "ch220001_22", "ch220001_23" } },
	{ name = "Corrupted Hobgoblin", members = { "ch220001_40", "ch220001_41", "ch220001_42", "ch220001_43" } },
	{ name = "Chopper", members = { "ch220002_00", "ch220002_03" } },
	{ name = "Knacker", members = { "ch220003_00", "ch220003_03" } },
	{ name = "Rattler", members = { "ch221002_00", "ch221002_20" } },
	{ name = "Succubus", members = { "ch222003_00", "ch222003_20" } },
	{ name = "Redwolf", members = { "ch223001_00", "ch223001_01" } },
	{ name = "Skeleton", members = { "ch226000_00", "ch226000_01", "ch226001_01", "ch226001_03", "ch226001_05", "ch226001_06", "ch226002_01", "ch226002_03", "ch226002_05", "ch226002_06" } },
	{ name = "Undead", members = { "ch228000_00", "ch228000_01", "ch228001_00", "ch228001_01", "ch228002_00" } },
	{ name = "Rogue", members = { "ch230000_01", "ch230000_02", "ch230000_03", "ch230000_04" } },
	{ name = "Lost Mercenary", members = { "ch230001_01", "ch230001_02", "ch230001_03", "ch230001_04", "ch230001_05", "ch230001_06", "ch230002_01", "ch230002_02", "ch230002_03", "ch230002_04", "ch230002_05", "ch230002_06" } },
	{ name = "Coral Snake", members = { "ch230012_02", "ch230012_04" } },
	{ name = "Cyclops", members = { "ch250000_00", "ch250000_01", "ch250000_10", "ch250000_11", "ch250000_12", "ch250000_20", "ch250000_21", "ch250000_22" } },
}

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
		imgui.set_tooltip("In Nearest boss mode, targets within this distance of each other are treated as tied and priority decides the winner.")
	end

	local selection_options = { "Nearest boss (default)", "Highest priority boss" }
	local selection_index = config.target_selection_mode == "priority" and 2 or 1
	changed, selection_index = imgui.combo("Target selection", selection_index, selection_options)
	if changed then
		config.target_selection_mode = selection_index == 2 and "priority" or "nearest"
		ui_state.dirty = true
	end
	if imgui.is_item_hovered() then
		imgui.set_tooltip("Nearest keeps the current behavior. Priority picks the configured highest-priority boss, then distance breaks ties.")
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
	if ui_state.dirty then imgui.text_colored("Unsaved configuration changes", 0xff66bb66) end
	imgui.pop_item_width()
	imgui.tree_pop()
end)

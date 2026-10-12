local MOD_NAME = "SmartBoons"
local MOD_VERSION = "2.0.0"
local CONFIG_FILE = "SmartBoons_config.json"

-- Script resets must reload the runtime helpers and voting policy.
local function load_local_module(name)
	package.loaded[name] = nil
	return require(name)
end
local R = load_local_module("SmartBoons/Runtime")
local choose_general_preference = load_local_module("SmartBoons/GeneralPreference")

local BOON_NAMES = { [29] = "Fire Boon", [30] = "Ice Boon", [31] = "Thunder Boon" }
local WET_VALUES = { "ice", "thunder", "ignore" }
local WET_OPTIONS = { "Ice", "Thunder", "Ignore" }
local WET_SKILLS = { ice = 30, thunder = 31 }
local BOON_PACK_PATH_BY_SKILL = {
	[29] = "AppSystem/AI/ActionInterface/ActInterPackData/Job03_Mage/Job03_FireBoon.user",
	[30] = "AppSystem/AI/ActionInterface/ActInterPackData/Job03_Mage/Job03_IceBoon.user",
	[31] = "AppSystem/AI/ActionInterface/ActInterPackData/Job03_Mage/Job03_ThunderBoon.user",
}

local function log(message) print("[" .. MOD_NAME .. "] " .. tostring(message)) end

local function make_default_config()
	return { version = 5, enabled = true, developer_mode = false, max_boss_distance = 50.0,
		max_common_enemy_distance = 25.0, wet_preference = "ignore", oil_fire_priority = false }
end

local function positive_distance(value, default)
	local number = tonumber(value)
	if number == nil or number ~= number or number < 1 or number == math.huge then return default end
	return number
end

local function load_config()
	local config = make_default_config()
	local ok, saved = pcall(function() return json.load_file(CONFIG_FILE) end)
	if not ok or type(saved) ~= "table" or saved.version ~= config.version then return config end
	if type(saved.enabled) == "boolean" then config.enabled = saved.enabled end
	if type(saved.developer_mode) == "boolean" then config.developer_mode = saved.developer_mode end
	config.max_boss_distance = positive_distance(saved.max_boss_distance, config.max_boss_distance)
	config.max_common_enemy_distance = positive_distance(saved.max_common_enemy_distance, config.max_common_enemy_distance)
	local wet = saved.wet_preference
	if WET_SKILLS[wet] ~= nil or wet == "ignore" then config.wet_preference = wet end
	if type(saved.oil_fire_priority) == "boolean" then config.oil_fire_priority = saved.oil_fire_priority end
	return config
end

local config = load_config()
local configuration_dirty = false
local state = { pack_hook_installed = false, last_install_error = nil, last_hook_error = nil,
	next_config_save_at = 0, last_save_error = nil }

local function save_config()
	local ok, result = pcall(function() return json.dump_file(CONFIG_FILE, config) end)
	if not ok or result == false then
		local message = tostring(result)
		if state.last_save_error ~= message then log("configuration save failed: " .. message) end
		state.last_save_error = message
		state.next_config_save_at = os.clock() + 2
		return false
	end
	state.last_save_error = nil
	return true
end

local function save_pending_config()
	if configuration_dirty and os.clock() >= state.next_config_save_at and save_config() then configuration_dirty = false end
end

local function evaluate_target(target, equipped, original_skill)
	local source = ""
	local wet_skill = WET_SKILLS[config.wet_preference]
	if wet_skill ~= nil or config.oil_fire_priority then
		local status = R.read_statuses(target.character)
		local function label(value) if value == nil then return "unknown" end; return tostring(value) end
		source = source .. string.format(" wet=%s oil=%s active_status_flag=%s",
			label(status.wet), label(status.oil), tostring(status.flag))
		if wet_skill ~= nil and status.wet == true then
			if equipped[wet_skill] then return wet_skill, source .. " status_rule=Wet wet_preference=" .. config.wet_preference end
			source = source .. " status_fallback=wet_boon_not_equipped"
		elseif config.oil_fire_priority and status.oil == true then
			if equipped[29] then return 29, source .. " status_rule=Oil" end
			source = source .. " status_fallback=fire_not_equipped"
		end
	else
		source = source .. " status_rules=ignored"
	end
	local profiles, reason = R.read_profiles(target.character)
	if profiles == nil then return nil, source .. " " .. reason end
	local selected, summary = choose_general_preference(profiles, equipped, original_skill)
	return selected, source .. " " .. summary
end

local function get_expected_boon(controller, original_skill)
	local candidates = R.target_candidates(config)
	if #candidates == 0 then return nil, "no_active_target" end
	local equipped = R.equipped_boons(controller)
	local first_summary
	for index, target in ipairs(candidates) do
		local selected, summary = evaluate_target(target, equipped, original_skill)
		first_summary = first_summary or summary
		if selected ~= nil then
			local skipped = index > 1 and " skipped=" .. (index - 1) or ""
			return selected, R.describe_target(target) .. summary .. skipped
		end
	end
	return nil, R.describe_target(candidates[1]) .. first_summary
		.. " no_recommendation checked=" .. #candidates .. "; original Boon kept"
end

local function trace_pack_data(controller, pack_data)
	if not config.enabled or pack_data == nil then return false end
	-- Hook arguments can arrive as native userdata; this is the casting Mage's BB.
	controller = R.managed(controller)
	local pack = R.call(R.managed(pack_data), "get_Pack")
	local nodes = R.call(pack, "getActInterNodes")
	local node = R.managed(R.call(nodes, "get_First"))
	local visited = 0
	while node ~= nil and visited < 64 do
		visited = visited + 1
		local next_node = R.managed(R.call(node, "get_Next"))
		local value = R.managed(R.call(node, "get_Value"))
		local command = R.call(value, "get_PrimaryCommand")
		local skill = R.number(R.call(command, "get_CustomSkillID"))
		if BOON_NAMES[skill] ~= nil then
			local expected, source = get_expected_boon(controller, skill)
			if config.developer_mode then
				local mode = expected == nil and "observe" or (skill == expected and "keep" or "replace")
				log(string.format("boon candidate: actor=%s skill=%s (%s) enemy=%s expected=%s (%s) mode=%s",
					R.character_id(R.actor_character(controller)), tostring(skill), BOON_NAMES[skill], source,
					tostring(expected), BOON_NAMES[expected] or "none", mode))
			end
			if expected ~= nil and expected ~= skill then return true, expected, skill, controller end
		end
		node = next_node
	end
	return false
end

local function replace_boon_pack(args)
	if args == nil then return end
	local replace, expected, original, controller = trace_pack_data(args[2], args[3])
	if not replace then return end
	-- Recheck this Mage's equipment immediately before changing the argument.
	if not R.is_boon_equipped(controller, expected) then
		if config.developer_mode then log("ActInter replacement cancelled: expected Boon is not equipped") end
		return
	end
	local replacement
	local ok, pointer = pcall(function()
		replacement = sdk.create_userdata("app.ActInterPackData", BOON_PACK_PATH_BY_SKILL[expected])
		if replacement == nil then return nil end
		return sdk.to_ptr(replacement)
	end)
	if not ok or pointer == nil then log("ActInter replacement failed; original dispatch allowed"); return end
	args[3] = pointer
	if config.developer_mode then log(string.format("ActInter pack argument replaced: from=%s to=%s", original, expected)) end
end

local function install_pack_hook()
	if state.pack_hook_installed then return end
	local ok, result = pcall(function()
		local td = sdk.find_type_definition("app.AIBlackBoardExtensions")
		local method = R.call(td, "get_method", "setBBValuesToExecuteActInter(app.AIBlackBoardController, app.ActInterPackData, app.AITarget)")
		if method == nil then return "setBBValuesToExecuteActInter not available" end
		sdk.hook(method, function(args)
			local succeeded, err = pcall(replace_boon_pack, args)
			if not succeeded and state.last_hook_error ~= tostring(err) then
				state.last_hook_error = tostring(err)
				log("Boon hook error: " .. tostring(err))
			end
		end)
		state.pack_hook_installed = true
		log("ActInterPack replacement hook installed; version=" .. MOD_VERSION .. " targeting=game IsBoss + nearest recommendation")
	end)
	if not state.pack_hook_installed then
		local err = tostring(result)
		if state.last_install_error ~= err then state.last_install_error = err; log("hook installation pending: " .. err) end
	end
end

re.on_application_entry("LateUpdateBehavior", function()
	install_pack_hook()
	save_pending_config()
end)

re.on_draw_ui(function()
	if not imgui.tree_node(MOD_NAME) then return end
	imgui.push_item_width(300)
	imgui.text("Automatic elemental preference | " .. MOD_VERSION)
	imgui.text("Bosses first; nearest enemy with a Boon recommendation.")
	imgui.text("Only adjusts a Boon when the Mage AI chooses to cast one.")
	local changed, value = imgui.checkbox("Enable Boon replacement", config.enabled)
	if changed then config.enabled = value; configuration_dirty = true end
	changed, value = imgui.drag_float("Max boss distance", config.max_boss_distance, 1.0, 1.0, 1000.0)
	if changed then config.max_boss_distance = positive_distance(value, config.max_boss_distance); configuration_dirty = true end
	if imgui.is_item_hovered() then imgui.set_tooltip("Maximum distance from the Arisen. Bosses are identified by the game's IsBoss flag.") end
	changed, value = imgui.drag_float("Max common enemy distance", config.max_common_enemy_distance, 1.0, 1.0, 1000.0)
	if changed then config.max_common_enemy_distance = positive_distance(value, config.max_common_enemy_distance); configuration_dirty = true end
	if imgui.is_item_hovered() then imgui.set_tooltip("Common enemies are considered only when no living boss is in range.") end
	local wet_index = 1
	for index, preference in ipairs(WET_VALUES) do if preference == config.wet_preference then wet_index = index end end
	changed, value = imgui.combo("When Wet", wet_index, WET_OPTIONS)
	if changed and WET_VALUES[value] ~= nil then config.wet_preference = WET_VALUES[value]; configuration_dirty = true end
	if imgui.is_item_hovered() then imgui.set_tooltip("Prioritizes only the selected element on the Wet enemy. If that Boon is not equipped, or Ignore is selected, uses regional preference without a Wet fallback sequence.") end
	changed, value = imgui.checkbox("When Oiled: prioritize Fire", config.oil_fire_priority)
	if changed then config.oil_fire_priority = value; configuration_dirty = true end
	if imgui.is_item_hovered() then imgui.set_tooltip("Prioritizes equipped Fire Boon on the selected Oiled enemy. Otherwise uses regional preference. Status rules apply at the next normal Boon opportunity.") end
	changed, value = imgui.checkbox("Developer mode (diagnostic logs)", config.developer_mode)
	if changed then config.developer_mode = value; configuration_dirty = true end
	if imgui.is_item_hovered() then imgui.set_tooltip("Logs the game name, ID, category, Wet/Oil states, applied status rule or elemental votes, and Boon replacement.") end
	save_pending_config()
	if configuration_dirty then imgui.text_colored("Changes are active; settings could not be saved", 0xff5252e0) end
	imgui.pop_item_width()
	imgui.tree_pop()
end)

local ADDON = "StrafeTurnSwapper"
local CMDS = { "TURNLEFT", "TURNRIGHT", "STRAFELEFT", "STRAFERIGHT" }
local LABELS = {
	TURNLEFT = "Turn Left",
	TURNRIGHT = "Turn Right",
	STRAFELEFT = "Strafe Left",
	STRAFERIGHT = "Strafe Right",
}

StrafeTurnSwapperDB = StrafeTurnSwapperDB or {}

local pending_restore

local function printmsg(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff/sts|r " .. msg)
	end
end

local function keys_of(cmd)
	return { GetBindingKey(cmd) }
end

local function snapshot()
	local t = {}
	for _, cmd in ipairs(CMDS) do
		t[cmd] = keys_of(cmd)
	end
	return t
end

local function copy_keys(list)
	local t = {}
	for i, k in ipairs(list or {}) do
		t[i] = k
	end
	return t
end

local function keys_equal(a, b)
	a, b = a or {}, b or {}
	if #a ~= #b then
		return false
	end
	local seen = {}
	for _, k in ipairs(a) do
		seen[k] = (seen[k] or 0) + 1
	end
	for _, k in ipairs(b) do
		if not seen[k] or seen[k] < 1 then
			return false
		end
		seen[k] = seen[k] - 1
	end
	return true
end

local function bindings_equal(a, b)
	if not a or not b then
		return false
	end
	for _, cmd in ipairs(CMDS) do
		if not keys_equal(a[cmd], b[cmd]) then
			return false
		end
	end
	return true
end

local function format_keys(list)
	if not list or #list == 0 then
		return "unbound"
	end
	return table.concat(list, ", ")
end

local function print_bindings(map)
	for _, cmd in ipairs(CMDS) do
		printmsg(LABELS[cmd] .. ": |cffffffff" .. format_keys(map[cmd]) .. "|r")
	end
end

local function apply(map)
	if InCombatLockdown and InCombatLockdown() then
		pending_restore = true
		printmsg("in combat — will apply after combat")
		return false
	end
	local clear = {}
	for _, cmd in ipairs(CMDS) do
		for _, k in ipairs(keys_of(cmd)) do
			clear[k] = true
		end
		for _, k in ipairs(map[cmd] or {}) do
			clear[k] = true
		end
	end
	for k in pairs(clear) do
		SetBinding(k)
	end
	for _, cmd in ipairs(CMDS) do
		for _, k in ipairs(map[cmd] or {}) do
			SetBinding(k, cmd)
		end
	end
	if SaveBindings and GetCurrentBindingSet then
		SaveBindings(GetCurrentBindingSet())
	end
	return true
end

local function store(map, swapped)
	local saved = {}
	for _, cmd in ipairs(CMDS) do
		saved[cmd] = copy_keys(map[cmd])
	end
	StrafeTurnSwapperDB.bindings = saved
	StrafeTurnSwapperDB.swapped = swapped and true or false
end

local function restore_saved()
	local saved = StrafeTurnSwapperDB.bindings
	if not saved then
		return
	end
	if bindings_equal(snapshot(), saved) then
		return
	end
	if apply(saved) then
		printmsg("restored saved turn/strafe keys")
		print_bindings(saved)
	end
end

local function toggle()
	local now = snapshot()
	local swapped = {
		TURNLEFT = copy_keys(now.STRAFELEFT),
		STRAFELEFT = copy_keys(now.TURNLEFT),
		TURNRIGHT = copy_keys(now.STRAFERIGHT),
		STRAFERIGHT = copy_keys(now.TURNRIGHT),
	}
	if apply(swapped) then
		store(swapped, not StrafeTurnSwapperDB.swapped)
		printmsg("swapped turn <-> strafe")
		print_bindings(swapped)
	end
end

SLASH_STRAFETURNSWAPPER1 = "/sts"
SlashCmdList["STRAFETURNSWAPPER"] = function()
	toggle()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		StrafeTurnSwapperDB = StrafeTurnSwapperDB or {}
	elseif event == "PLAYER_LOGIN" then
		if C_Timer and C_Timer.After then
			C_Timer.After(0.5, restore_saved)
		else
			restore_saved()
		end
	elseif event == "PLAYER_REGEN_ENABLED" and pending_restore then
		pending_restore = nil
		restore_saved()
	end
end)

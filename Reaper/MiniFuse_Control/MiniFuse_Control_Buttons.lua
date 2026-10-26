local script_dir = debug.getinfo(1).source:match("@?(.*[\\/])")
local config_path = script_dir .. "MiniFuse_Control.ini"
local config_file, open_error = io.open(config_path, "r")

if not config_file then
    reaper.ShowMessageBox(
        "Could not open MiniFuse configuration:\n" .. tostring(open_error),
        "MiniFuse Control",
        0
    )
    return
end

local conf = {}
local current_section

for line in config_file:lines() do
    local section = line:match("%[(.+)%]")
    if section then
        conf[section] = {}
        current_section = conf[section]
    else
        local key, value = line:match("^%s*([^=]+)%s*=%s*(.-)%s*$")
        if key and current_section then
            key = key:match("^%s*(.-)%s*$")
            current_section[key] = value
        end
    end
end
config_file:close()

local function detect_os()
    return package.config:sub(1, 1) == "\\" and "windows" or "linux"
end

local general = conf.general or {}
local os_name = general.os or "auto"
if os_name == "auto" then
    os_name = detect_os()
end

local platform_config = conf[os_name]
if not platform_config then
    reaper.ShowMessageBox(
        "No configuration section found for operating system: " .. os_name,
        "MiniFuse Control",
        0
    )
    return
end

local button_defs = {
    ["48V"] = {on = "phantom_on", off = "phantom_off"},
    DIR = {on = "direct_on", off = "direct_off"},
    I1 = {on = "inst1_on", off = "inst1_off"},
    I2 = {on = "inst2_on", off = "inst2_off"},
}

local function expand(command)
    command = command:gsub("%%python%%", platform_config.python or "")
    command = command:gsub("%%script%%", platform_config.script or "")
    return command
end

local function run_button(button_name)
    local definition = button_defs[button_name]
    if not definition then
        error("Unknown MiniFuse button: " .. tostring(button_name))
    end

    local enabled = general["button_" .. button_name]
    if enabled == "0" or enabled == "false" then
        reaper.ShowMessageBox(
            button_name .. " is disabled in MiniFuse_Control.ini.",
            "MiniFuse Control",
            0
        )
        return
    end

    local _, _, section_id, command_id = reaper.get_action_context()
    if not section_id or not command_id or command_id <= 0 then
        reaper.ShowMessageBox(
            "Could not identify this ReaScript action.",
            "MiniFuse Control",
            0
        )
        return
    end

    local turn_on = reaper.GetToggleCommandStateEx(section_id, command_id) ~= 1
    local command_key = turn_on and definition.on or definition.off
    local command = platform_config[command_key]

    if not command or command == "" then
        reaper.ShowMessageBox(
            "No command configured for " .. button_name .. " (" .. command_key .. ").",
            "MiniFuse Control",
            0
        )
        return
    end

    command = expand(command)
    if os_name == "windows" then
        reaper.ExecProcess(command, 0)
    else
        os.execute(command)
    end

    reaper.SetToggleCommandState(section_id, command_id, turn_on and 1 or 0)
    reaper.RefreshToolbar2(section_id, command_id)
end

return run_button

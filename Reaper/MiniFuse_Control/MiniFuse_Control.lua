local script_dir =
debug.getinfo(1).source:match("@?(.*[\\/])")

local cfg = script_dir ..
"MiniFuse_Control.ini"

------------------------------------------------
-- ini parser
------------------------------------------------
local conf={}

for line in io.lines(cfg) do
    local sec=line:match("%[(.+)%]")
    if sec then
        conf[sec]={}
        current=conf[sec]
    else
        local k,v=line:match("([^=]+)=(.+)")
        if k and current then
            current[k]=v
        end
    end
end

------------------------------------------------
-- OS detect
------------------------------------------------
local function detect_os()

    local sep = package.config:sub(1,1)

    if sep=="\\" then
        return "windows"
    end

    return "linux"

end

local OS=conf.general.os

if OS=="auto" then
    OS=detect_os()
end

local C=conf[OS]

------------------------------------------------
-- expand vars
------------------------------------------------
local function expand(s)

    if not s then return "" end

    s=s:gsub("%%python%%",
    C.python or "")

    s=s:gsub("%%script%%",
    C.script or "")

    return s
end

local function run(cmd)
    cmd = expand(cmd)

    if OS == "windows" then
        reaper.ExecProcess(cmd, 0)
    else
        os.execute(cmd)
    end
end

local function parse_numbers(s, count, defaults)
    local values={}
    if s then
        for v in s:gmatch("[^,%s]+") do
            values[#values+1]=tonumber(v)
        end
    end
    for i=1,count do
        values[i]=values[i] or defaults[i]
    end
    if count >= 3 and values[1] and values[1] > 1 and values[1] <= 255 then
        values[1] = values[1] / 255
        values[2] = values[2] / 255
        values[3] = values[3] / 255
    end
    return values
end

local function parse_list(s, defaults)
    local values={}
    if s then
        for item in s:gmatch("[^,%s]+") do
            values[#values+1]=item
        end
    end
    if #values == 0 then
        for i=1,#defaults do
            values[i]=defaults[i]
        end
    end
    return values
end

local function parse_bool(v)
    return not (v == "0" or v == "false")
end

------------------------------------------------
-- GUI
------------------------------------------------
local ctx =
reaper.ImGui_CreateContext(
"MiniFuse"
)

local flags=
reaper.ImGui_WindowFlags_NoTitleBar()
|
reaper.ImGui_WindowFlags_NoResize()
|
reaper.ImGui_WindowFlags_AlwaysAutoResize()
|
reaper.ImGui_WindowFlags_NoCollapse()
|
reaper.ImGui_WindowFlags_NoScrollbar()

local no_docking = reaper.ImGui_WindowFlags_NoDocking and reaper.ImGui_WindowFlags_NoDocking() or 0
flags = flags | no_docking

if conf.general.always_on_top=="1" then
    flags =
    flags |
    reaper.ImGui_WindowFlags_TopMost()
end

local window_color = parse_numbers(conf.general.window_color, 4, {0.12, 0.12, 0.12, 0.96})
local window_rounding = parse_numbers(conf.general.window_rounding, 1, {10})[1]
local frame_rounding = parse_numbers(conf.general.frame_rounding, 1, {6})[1]
local window_padding = parse_numbers(conf.general.window_padding, 2, {6, 6})
local border_color = parse_numbers(conf.general.border_color, 4, {0.35, 0.35, 0.35, 0.85})
local font_name = conf.general.font or "Arial"
local font_size = tonumber(conf.general.font_size) or 14
local use_border = conf.general.use_border == "1"
local button_order = parse_list(conf.general.button_order, {"48V","DIR","I1","I2"})
local button_enabled = {
    ["48V"] = parse_bool(conf.general.button_48V),
    ["DIR"] = parse_bool(conf.general.button_DIR),
    ["I1"] = parse_bool(conf.general.button_I1),
    ["I2"] = parse_bool(conf.general.button_I2),
}
local button_state = {
    phantom = false,
    direct = false,
    inst1 = false,
    inst2 = false,
}
local button_defs = {
    ["48V"] = {state="phantom", width=40, on="phantom_on", off="phantom_off"},
    ["DIR"] = {state="direct", width=40, on="direct_on", off="direct_off"},
    ["I1"] = {state="inst1", width=35, on="inst1_on", off="inst1_off"},
    ["I2"] = {state="inst2", width=35, on="inst2_on", off="inst2_off"},
}
local font_handle = reaper.ImGui_CreateFont and reaper.ImGui_CreateFont(font_name, font_size) or nil

local function color_to_u32(c)
    local r = math.floor((c[1] or 0) * 255 + 0.5)
    local g = math.floor((c[2] or 0) * 255 + 0.5)
    local b = math.floor((c[3] or 0) * 255 + 0.5)
    local a = math.floor((c[4] or 1) * 255 + 0.5)
    return a * 16777216 + b * 65536 + g * 256 + r
end

phantom=false
direct=false
inst1=false
inst2=false

function loop()

reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), color_to_u32(window_color))
if use_border then
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), color_to_u32(border_color))
end
reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), window_rounding)
reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), frame_rounding)
reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), window_padding[1], window_padding[2])
if font_handle then
    reaper.ImGui_PushFont(ctx, font_handle, font_size)
end

local visible,open=
reaper.ImGui_Begin(
ctx,
"MiniFuse",
true,
flags
)

if visible then
    local first = true
    for _, name in ipairs(button_order) do
        local def = button_defs[name]
        if def and button_enabled[name] then
            if not first then
                reaper.ImGui_SameLine(ctx)
            end
            first = false

            if reaper.ImGui_Button(ctx, name, def.width, 24) then
                local state_key = def.state
                button_state[state_key] = not button_state[state_key]
                run(
                    button_state[state_key] and
                    C[def.on] or
                    C[def.off]
                )
            end
        end
    end

    reaper.ImGui_End(ctx)
end

if font_handle then
    reaper.ImGui_PopFont(ctx)
end

reaper.ImGui_PopStyleVar(ctx, 3)
if use_border then
    reaper.ImGui_PopStyleColor(ctx, 2)
else
    reaper.ImGui_PopStyleColor(ctx, 1)
end

if open then
    reaper.defer(loop)
end

end

loop()

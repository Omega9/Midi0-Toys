local script_dir = debug.getinfo(1).source:match("@?(.*[\\/])")
local run_button = dofile(script_dir .. "MiniFuse_Control_Buttons.lua")

if run_button then
    run_button("DIR")
end

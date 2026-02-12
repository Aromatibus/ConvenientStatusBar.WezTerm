local M       = {}
local wezterm = require 'wezterm'


--- ==========================================
--- 電源情報取得
--- ==========================================
function M.get_power_supply()
    local batt = wezterm.battery_info()
    if #batt == 0 then return "󰚥" end
    local b = batt[1]
    local p = b.state_of_charge * 100
    local icon =
        p >= 90 and "󱊦" or
        p >= 60 and "󱊥" or
        p >= 30 and "󱊤" or "󰢟"
    return icon, string.format("%.0f%%", p)
end


return M

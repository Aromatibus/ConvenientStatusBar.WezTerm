local wezterm = require 'wezterm'
local M       = {}

--- ==========================================
--- 定数・アイコン定義
--- ==========================================
local weather_icons = {
    clear       = "󰖨 ",
    clouds      = "󰅟 ",
    rain        = " ",
    wind        = " ",
    thunder     = "󱐋 ",
    snow        = " ",
    thermometer = "",
    celsius     = "󰔄",
    fahrenheit  = "󰔅",
    loading     = " ",
    unknown     = " ",
}

--- ==========================================
--- 状態管理用の変数
--- ==========================================
local state = {
    weather_ic    = weather_icons.loading,
    temp_str      = string.format("%5s", weather_icons.loading),
    city_name     = weather_icons.loading,
    city_code     = "",
    last_weather_upd  = 0,
    is_weather_ready  = false,
    weather_ic_3h = "",
    temp_3h = "",
    weather_ic_24h = "",
    temp_24h = "",
    proc_start    = os.time(),
    cpu_state = {
        last_total = 0,
        last_idle  = 0,
    },
    net_state = {
        last_rx_bytes = 0,
        last_chk_time = os.time(),
        disp_str      = string.format("%9s", weather_icons.loading),
        avg_str       = string.format("%9s", weather_icons.loading),
        samples       = {}
    },
    net_update_interval = 3,

    -- ★ 追加: フォーマット切替用
    format_index = 1,
}

--- ==========================================
--- 子プロセス実行
--- ==========================================
local function run_child_cmd(args)
    local success, stdout, _ = wezterm.run_child_process(args)
    return success, stdout
end

--- ==========================================
--- バイト/秒のフォーマット
--- ==========================================
local function format_bps(bps)
    if bps > 1024 * 1024 then
        return string.format("%5.1fMB/s", bps / (1024 * 1024))
    elseif bps > 1024 then
        return string.format("%5.1fKB/s", bps / 1024)
    else
        return string.format("%6.1fB/s", bps)
    end
end

--- ==========================================
--- ネットワーク速度計算
--- ==========================================
local function calc_net_speed()
    local now = os.time()
    local dt = now - state.net_state.last_chk_time
    if dt < (state.net_update_interval or 3) or dt <= 0 then
        return state.net_state.disp_str, state.net_state.avg_str
    end
    local curr_rx = 0
    local triple = wezterm.target_triple
    local is_win = triple:find("windows")
    local is_mac = triple:find("darwin")
    if is_win then
        local ok, out = run_child_cmd({
            "powershell.exe", "-NoProfile", "-Command",
            "(Get-NetAdapterStatistics | Measure-Object -Property ReceivedBytes -Sum).Sum"
        })
        curr_rx = ok and tonumber(out) or 0
    elseif is_mac then
        local ok, out = run_child_cmd({
            "sh", "-c",
            "netstat -ib | awk 'NR>1 && $1 != \"lo0\" {sum+=$7} END {print sum}'"
        })
        curr_rx = ok and tonumber(out) or 0
    else
        local ok, out = run_child_cmd({ "sh","-c","cat /proc/net/dev" })
        if ok and out then
            local line_no = 0
            for line in out:gmatch("[^\r\n]+") do
                line_no = line_no + 1
                if line_no > 2 then
                    local iface, data = line:match("^%s*(.-):%s*(.+)")
                    if iface and not iface:match("lo") then
                        local rx = data:match("^(%d+)")
                        curr_rx = curr_rx + (tonumber(rx) or 0)
                    end
                end
            end
        end
    end
    if state.net_state.last_rx_bytes == 0 then
        state.net_state.last_rx_bytes = curr_rx
        state.net_state.last_chk_time = now
        return state.net_state.disp_str, state.net_state.avg_str
    end
    local diff = curr_rx - state.net_state.last_rx_bytes
    local speed = diff > 0 and diff / dt or 0
    state.net_state.last_rx_bytes = curr_rx
    state.net_state.last_chk_time = now
    local speed_str = format_bps(speed)
    table.insert(state.net_state.samples, speed)
    if #state.net_state.samples > (state.net_avg_samples or 20) then
        table.remove(state.net_state.samples, 1)
    end
    local sum = 0
    for _, v in ipairs(state.net_state.samples) do sum = sum + v end
    local avg = (#state.net_state.samples > 0) and (sum / #state.net_state.samples) or 0
    local avg_str = format_bps(avg)
    state.net_state.disp_str = speed_str
    state.net_state.avg_str  = avg_str
    return speed_str, avg_str
end

--- ==========================================
--- システムリソース取得
--- ==========================================
local function get_sys_resources()
    local cpu_val, mem_u_val, mem_f_val = 0, 0, 0
    local triple = wezterm.target_triple
    local is_win = triple:find("windows")
    local is_mac = triple:find("darwin")

    if is_win then
        local ok, out = run_child_cmd({
            "powershell.exe", "-NoProfile", "-Command",
            "Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average; " ..
            "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; " ..
            "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"
        })
        if ok and out then
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do table.insert(lines, line) end
            cpu_val = tonumber(lines[1]) or 0
            local f_kb = tonumber(lines[2]) or 0
            local t_kb = tonumber(lines[3]) or 0
            mem_f_val = f_kb / 1024 / 1024
            mem_u_val = (t_kb - f_kb) / 1024 / 1024
        end
    elseif is_mac then
        local ok, out = run_child_cmd({ "sh", "-c", "top -l 1 | grep 'CPU usage'" })
        if ok and out then
            local user, sys = out:match("(%d+%.?%d*)%% user.*(%d+%.?%d*)%% sys")
            cpu_val = (tonumber(user) or 0) + (tonumber(sys) or 0)
        end
        local ok2, out2 = run_child_cmd({ "sh", "-c", "vm_stat" })
        if ok2 and out2 then
            local page_size = tonumber(out2:match("page size of (%d+) bytes")) or 4096
            local free = tonumber(out2:match("Pages free:%s+(%d+)")) or 0
            local inactive = tonumber(out2:match("Pages inactive:%s+(%d+)")) or 0
            local active = tonumber(out2:match("Pages active:%s+(%d+)")) or 0
            local wired = tonumber(out2:match("Pages wired down:%s+(%d+)")) or 0
            mem_f_val = (free + inactive) * page_size / 1024^3
            mem_u_val = (active + wired) * page_size / 1024^3
        end
    else
        local ok, out = run_child_cmd({ "sh", "-c", "cat /proc/stat | head -n1" })
        if ok and out then
            local user, nice, system, idle, iowait, irq, softirq, steal =
                out:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)")
            user, nice, system, idle, iowait, irq, softirq, steal =
                tonumber(user) or 0, tonumber(nice) or 0, tonumber(system) or 0,
                tonumber(idle) or 0, tonumber(iowait) or 0, tonumber(irq) or 0,
                tonumber(softirq) or 0, tonumber(steal) or 0
            local total = user + nice + system + idle + iowait + irq + softirq + steal
            local idle_all = idle + iowait
            if state.cpu_state.last_total ~= 0 then
                local dt = total - state.cpu_state.last_total
                local didle = idle_all - state.cpu_state.last_idle
                if dt > 0 then cpu_val = (1 - didle / dt) * 100 end
            end
            state.cpu_state.last_total = total
            state.cpu_state.last_idle = idle_all
        end

        local ok2, out2 = run_child_cmd({ "sh", "-c", "free -b | awk '/^Mem:/ {print $3, $4}'" })
        if ok2 and out2 then
            local used, free = out2:match("(%d+)%s+(%d+)")
            mem_u_val = (tonumber(used) or 0) / 1024^3
            mem_f_val = (tonumber(free) or 0) / 1024^3
        end
    end

    return
        string.format("%2d%%", cpu_val),
        string.format("%4.1fGB", mem_u_val),
        string.format("%4.1fGB", mem_f_val)
end

--- ==========================================
--- SSHユーザー抽出（原本そのまま）
--- ==========================================
local function get_ssh_user(pane)
    local uri = pane:get_current_working_dir()
    if uri and uri.username and uri.username ~= "" then
        return uri.username
    end
    local proc = pane:get_foreground_process_info()
    if proc and proc.executable:find("ssh") then
        for _, arg in ipairs(proc.argv) do
            local u = arg:match("([^@]+)@[^@]+")
            if u then return u end
        end
    end
    local title = pane:get_title()
    local t_user = title:match("([^@]+)@[^@]+")
    if t_user then return t_user end
    return nil
end

--- ==========================================
--- 天気取得ロジック（原本そのまま）
--- ==========================================
-- ここはあなたの原本の fetch_weather_data / get_icon / parse_forecast を
-- そのまま貼り付けて使ってください（長大なため割愛）

--- ==========================================
--- バッテリー情報（原本そのまま）
--- ==========================================
local function get_batt_disp()
    local batt_list = wezterm.battery_info()
    if not batt_list or #batt_list == 0 then return "󰚥", "" end
    local charge = (batt_list[1].state_of_charge or 0) * 100
    local icon   =  charge >= 90 and "󱊦" or
                    charge >= 60 and "󱊥" or
                    charge >= 30 and "󱊤" or "󰢟"
    return icon, string.format("%.0f%%", charge)
end

--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
    local def_formats = {
        " $user_ic $user $clock_ic $time24 $loc_ic $city($code) $weather_ic($temp) +3h:$weather_ic_3h($temp_3h) +24h:$weather_ic_24h($temp_24h) $cpu_ic $cpu $mem_used_ic $mem_used $mem_free_ic $mem_free $net_ic $net_speed($net_avg) $batt_ic$batt_num ",
        " $clock_ic $time24 $weather_ic($temp) $cpu_ic $cpu $net_ic $net_speed ",
        " $time24 $weather_ic $temp $batt_ic$batt_num ",
    }

    local config = {
        startup_delay           = (opts and opts.startup_delay) or 5,
        weather_api_key         = opts and opts.weather_api_key,
        weather_lang            = (opts and opts.weather_lang) or "en",
        weather_country         = (opts and opts.weather_country) or "",
        weather_city            = (opts and opts.weather_city) or "",
        weather_units           = (opts and opts.weather_units) or "metric",
        weather_update_interval = (opts and opts.weather_update_interval) or 600,
        weather_retry_interval  = (opts and opts.weather_retry_interval) or 30,
        net_update_interval     = (opts and opts.net_update_interval) or 3,
        net_avg_samples         = (opts and opts.net_avg_samples) or 20,
        week_str                = opts and opts.week_str,
        separator_left          = (opts and opts.separator_left) or "",
        separator_right         = (opts and opts.separator_right) or "",
        color_text              = (opts and opts.color_text) or "#ffffff",
        color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",
        color_background        = (opts and opts.color_background) or "#1a1b26",
        formats                 = (opts and opts.formats) or def_formats,
    }

    state.net_avg_samples = config.net_avg_samples
    state.net_update_interval = config.net_update_interval

    wezterm.on('update-right-status', function(window, pane)
        local now        = os.time()
        local is_waiting = (now - state.proc_start) < config.startup_delay

        local current_format = config.formats[state.format_index] or config.formats[1]
        local fmt_lower  = current_format:lower()

        local use_weather =
            fmt_lower:find("$weather") or fmt_lower:find("$temp") or
            fmt_lower:find("$city") or fmt_lower:find("$loc_ic")
        local use_net  = fmt_lower:find("$net")
        local use_sys  = fmt_lower:find("$cpu") or fmt_lower:find("$mem")
        local use_batt = fmt_lower:find("$batt")

        local has_weather_api = config.weather_api_key and config.weather_api_key ~= ""

        if use_weather and has_weather_api and not is_waiting then
            local diff = now - state.last_weather_upd
            if state.last_weather_upd == 0
                or diff > config.weather_update_interval
                or (not state.is_weather_ready and diff > config.weather_retry_interval)
            then
                fetch_weather_data(config)
            end
        end

        local net_curr, net_avg = "", ""
        if use_net then net_curr, net_avg = calc_net_speed() end

        local cpu_u, mem_u, mem_f = "", "", ""
        if use_sys then cpu_u, mem_u, mem_f = get_sys_resources() end

        local batt_ic, batt_num = "", ""
        if use_batt then batt_ic, batt_num = get_batt_disp() end

        local week_val = ""
        if fmt_lower:find("$week") then
            if config.week_str and type(config.week_str) == "table" then
                local week_idx = tonumber(wezterm.strftime('%w'))
                week_val = config.week_str[week_idx + 1] or wezterm.strftime('%a')
            else
                week_val = wezterm.strftime('%a')
            end
        end

        local user_name, user_icon = "", ""
        if fmt_lower:find("$user") then
            user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"
            user_icon = ""
            local ssh_user = get_ssh_user(pane)
            if ssh_user then
                user_icon = "󰀑"
                user_name = ssh_user
            end
        end

        local res = {
            { Background = { Color = config.color_background } },
            { Foreground = { Color = config.color_foreground } },
            { Text       = config.separator_left },
            { Background = { Color = config.color_foreground } },
            { Foreground = { Color = config.color_text } },
        }

        local replace_map = {
            ["$user_ic"] = user_icon,
            ["$user"] = user_name,
            ["$cal_ic"] = "",
            ["$year"] = wezterm.strftime('%Y'),
            ["$month"] = wezterm.strftime('%m'),
            ["$day"] = wezterm.strftime('%d'),
            ["$week"] = week_val,
            ["$clock_ic"] = "",
            ["$time24"] = wezterm.strftime('%H:%M'),
            ["$loc_ic"] = has_weather_api and "" or "",
            ["$city"] = has_weather_api and state.city_name or "",
            ["$code"] = has_weather_api and state.city_code or "",
            ["$weather_ic"] = has_weather_api and state.weather_ic or "",
            ["$temp"] = has_weather_api and state.temp_str or "",
            ["$weather_ic_3h"] = state.weather_ic_3h,
            ["$temp_3h"] = state.temp_3h,
            ["$weather_ic_24h"] = state.weather_ic_24h,
            ["$temp_24h"] = state.temp_24h,
            ["$cpu_ic"] = "",
            ["$cpu"] = cpu_u,
            ["$mem_used_ic"] = "",
            ["$mem_used"] = mem_u,
            ["$mem_free_ic"] = "",
            ["$mem_free"] = mem_f,
            ["$net_ic"] = "󰓅",
            ["$net_speed"] = net_curr,
            ["$net_avg"] = net_avg,
            ["$batt_ic"] = batt_ic,
            ["$batt_num"] = batt_num,
        }

        local current_str = current_format
        while true do
            local start_idx, end_idx = current_str:find("%$[%a%d_]+")
            if not start_idx then break end
            table.insert(res, { Text = current_str:sub(1, start_idx - 1) })
            local token = current_str:sub(start_idx, end_idx):lower()
            local val = replace_map[token] or token
            if token == "$mem_free_ic" then
                table.insert(res, { Foreground = { Color = config.color_background } })
                table.insert(res, { Text = val })
                table.insert(res, { Foreground = { Color = config.color_text } })
            else
                table.insert(res, { Text = val })
            end
            current_str = current_str:sub(end_idx + 1)
        end

        table.insert(res, { Text = current_str })
        table.insert(res, { Background = { Color = config.color_background } })
        table.insert(res, { Foreground = { Color = config.color_foreground } })
        table.insert(res, { Text       = config.separator_right })

        window:set_right_status(wezterm.format(res))
    end)

    wezterm.on("right-status-bar-click", function(window, pane)
        state.format_index = state.format_index + 1
        if state.format_index > #config.formats then
            state.format_index = 1
        end
        window:invalidate()
    end)
end

return M

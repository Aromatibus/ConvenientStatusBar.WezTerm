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
    weather_ic_3h = weather_icons.loading,
    temp_str_3h   = string.format("%5s", weather_icons.loading),
    weather_ic_24h = weather_icons.loading,
    temp_str_24h  = string.format("%5s", weather_icons.loading),
    city_name     = weather_icons.loading,
    city_code     = "",
    last_weather_upd  = 0,
    is_weather_ready  = false,
    proc_start    = os.time(),
    net_state     = {
        last_rx_bytes = 0,
        last_chk_time = os.clock(),
        disp_str      = string.format("%9s", weather_icons.loading),
        avg_str       = string.format("%9s", weather_icons.loading),
        samples       = {}
    }
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
    if bps > 1024 * 1024
        then return string.format("%5.1fMB/S", bps / (1024 * 1024))
    elseif bps > 1024 then return string.format("%5.1fKB/S", bps / 1024)
    else return string.format("%6.1fB/S", bps) end
end


--- ==========================================
--- ネットワーク速度計算
--- ==========================================
local function calc_net_speed(config, is_startup_waiting)
    if is_startup_waiting
        then return state.net_state.disp_str, state.net_state.avg_str end
    local curr_time  = os.clock()
    local time_delta = curr_time - state.net_state.last_chk_time
    if time_delta < config.net_update_interval
        then return state.net_state.disp_str, state.net_state.avg_str end
    local is_win  = wezterm.target_triple:find("windows")
    local curr_rx = 0
    if is_win then
        local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
        curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
    else
        local ok, out = run_child_cmd({
            "sh", "-c", "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
        })
        curr_rx = ok and tonumber(out:match("%d+")) or 0
    end
    local diff = curr_rx - state.net_state.last_rx_bytes
    if diff < 0 then
        state.net_state.last_rx_bytes = curr_rx
        state.net_state.last_chk_time = curr_time
        return state.net_state.disp_str, state.net_state.avg_str
    end
    local bps = diff / time_delta
    table.insert(state.net_state.samples, 1, bps)
    if #state.net_state.samples > config.net_avg_samples
        then table.remove(state.net_state.samples) end
    local sum_bps = 0
    for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end
    state.net_state.last_rx_bytes = curr_rx
    state.net_state.last_chk_time = curr_time
    state.net_state.disp_str      = format_bps(bps)
    state.net_state.avg_str       = format_bps(sum_bps / #state.net_state.samples)
    return state.net_state.disp_str, state.net_state.avg_str
end


--- ==========================================
--- システムリソース取得
--- ==========================================
local function get_sys_resources()
    local cpu_val, mem_u_val, mem_f_val = 0, 0, 0
    local is_win = wezterm.target_triple:find("windows")
    if is_win then
        local ok, out = run_child_cmd({
            "powershell.exe", "-NoProfile", "-Command",
            "Get-CimInstance Win32_Processor | Measure-Object -Property " ..
            "LoadPercentage -Average | Select-Object -ExpandProperty Average; " ..
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
    else
        local ok, out = run_child_cmd({
            "sh", "-c", "free -b | awk '/^Mem:/ {print $3, $4, $2}'"
        })
        if ok and out then
            local u, f, t = out:match("(%d+)%s+(%d+)%s+(%d+)")
            mem_u_val = (tonumber(u) or 0) / 1024^3
            mem_f_val = (tonumber(f) or 0) / 1024^3
        end
    end
    return
        string.format("%2d%%", cpu_val),
        string.format("%4.1fGB", mem_u_val),
        string.format("%4.1fGB", mem_f_val)
end


--- ==========================================
--- SSHユーザー抽出
--- ==========================================
local function get_ssh_user(pane)
    -- 【修正】Paneが有効かチェック
    if not pane then return nil end
    local success, uri = pcall(function() return pane:get_current_working_dir() end)
    if success and uri and uri.username and uri.username ~= "" then return uri.username end
    
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
--- 天気情報取得
--- ==========================================
local function fetch_weather_data(config)
    local is_win   = wezterm.target_triple:find("windows")
    local curl_cmd = is_win and "curl.exe" or "curl"
    local tgt_city = config.weather_city
    local tgt_code = config.weather_country

    if not tgt_city or tgt_city == "" then
        local ip_url = "https://ipapi.co/json/"
        local ok, res = run_child_cmd({curl_cmd, "-s", ip_url})
        if ok and res then
            tgt_city = res:match('"city":%s*"([^"]+)"')
            tgt_code = res:match('"country_code":%s*"([^"]+)"')
        end
    end

    if not tgt_city or tgt_city == "" then
        state.is_weather_ready = false
        return
    end

    local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
    local url = string.format(
        "https://api.openweathermap.org/data/2.5/forecast?appid=%s&lang=%s&q=%s&units=%s",
        config.weather_api_key, config.weather_lang, query, config.weather_units
    )
    
    local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
    if not ok or not stdout or stdout:find('"message"') then
        state.is_weather_ready = false
        state.last_weather_upd = os.time()
        return
    end

    local function parse_item(item_json)
        local id_str = item_json:match('"weather":%s*%[%s*{%s*"id":%s*(%d+)')
        local id     = tonumber(id_str)
        local t      = item_json:match('"temp":([%d%.%-]+)')
        local ic     = weather_icons.unknown
        if id then
            if     id < 300  then ic = weather_icons.thunder
            elseif id < 600  then ic = weather_icons.rain
            elseif id < 700  then ic = weather_icons.snow
            elseif id < 800  then ic = weather_icons.wind
            elseif id == 800 then ic = weather_icons.clear
            else                  ic = weather_icons.clouds end
        end
        return ic, t
    end

    local list_content = stdout:match('"list":%s*%[(.+)%],"city"')
    if not list_content then return end
    
    local entries = {}
    for entry in list_content:gmatch("({.-})") do
        if entry:find('"main"') then table.insert(entries, entry) end
    end

    local unit_sym = config.weather_units == "metric" and weather_icons.celsius or weather_icons.fahrenheit

    if #entries >= 1 then
        local ic, t = parse_item(entries[1])
        state.weather_ic = ic
        state.temp_str = t and string.format("%4.1f%s", tonumber(t), unit_sym) or " -- "
    end
    if #entries >= 2 then
        local ic, t = parse_item(entries[2])
        state.weather_ic_3h = ic
        state.temp_str_3h = t and string.format("%4.1f%s", tonumber(t), unit_sym) or " -- "
    end
    if #entries >= 9 then
        local ic, t = parse_item(entries[9])
        state.weather_ic_24h = ic
        state.temp_str_24h = t and string.format("%4.1f%s", tonumber(t), unit_sym) or " -- "
    end

    local city_part = stdout:match('"city":%s*({.+})')
    if city_part then
        state.city_name = city_part:match('"name":"([^"]+)"') or tgt_city
        state.city_code = city_part:match('"country":"([^"]+)"') or tgt_code or ""
    end

    state.last_weather_upd = os.time()
    state.is_weather_ready = true
end


--- ==========================================
--- バッテリー情報取得
--- ==========================================
local function get_batt_disp()
    local batt_list = wezterm.battery_info()
    if not batt_list or #batt_list == 0 then return "󰚥", "" end
    local charge = (batt_list[1].state_of_charge or 0) * 100
    local icon   =  charge >= 90 and "󱊦" or charge >= 60 and "󱊥" or charge >= 30 and "󱊤" or "󰢟"
    return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
    local def_fmt =
        " $user_ic $user " ..
        "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
        "$loc_ic $city($code) $weather_ic $temp 3h($weather_ic_3h $temp_3h) 24h($weather_ic_24h $temp_24h) " ..
        "$cpu_ic $cpu $mem_used_ic $mem_used $mem_free_ic $mem_free " ..
        "$net_ic $net_speed($net_avg) " ..
        "$batt_ic$batt_num "

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
        net_avg_samples         = (opts and opts.net_avg_samples) or 10,
        week_str                = opts and opts.week_str,
        separator_left          = (opts and opts.separator_left) or "",
        separator_right         = (opts and opts.separator_right) or "",
        color_text              = (opts and opts.color_text) or "#ffffff",
        color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",
        color_background        = (opts and opts.color_background) or "#1a1b26",
        format                  = (opts and opts.format) or def_fmt,
    }

    wezterm.on('update-right-status', function(window, pane)
        -- 【修正】Paneが存在しない場合は処理を中断
        if not pane then return end

        local now        = os.time()
        local is_waiting = (now - state.proc_start) < config.startup_delay
        local has_weather_api = config.weather_api_key and config.weather_api_key ~= ""

        if has_weather_api and not is_waiting then
            local diff = now - state.last_weather_upd
            if state.last_weather_upd == 0 or diff > config.weather_update_interval or (not state.is_weather_ready and diff > config.weather_retry_interval) then
                fetch_weather_data(config)
            end
        end

        local net_curr, net_avg = calc_net_speed(config, is_waiting)
        local cpu_u, mem_u, mem_f = get_sys_resources()
        local batt_ic, batt_num = get_batt_disp()
        
        local week_val = ""
        if config.week_str and type(config.week_str) == "table" then
            week_val = config.week_str[tonumber(wezterm.strftime('%w')) + 1] or wezterm.strftime('%a')
        else
            week_val = wezterm.strftime('%a')
        end

        local user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"
        local user_icon = ""
        local ssh_user = get_ssh_user(pane)
        if ssh_user then user_icon, user_name = "󰀑", ssh_user end

        local replace_map = {
            ["$user_ic"] = user_icon, ["$user"] = user_name, ["$cal_ic"] = "",
            ["$year"] = wezterm.strftime('%Y'), ["$month"] = wezterm.strftime('%m'),
            ["$day"] = wezterm.strftime('%d'), ["$week"] = week_val, ["$clock_ic"] = "",
            ["$time24"] = wezterm.strftime('%H:%M'), ["$loc_ic"] = "",
            ["$city"] = state.city_name, ["$code"] = state.city_code,
            ["$weather_ic"] = state.weather_ic, ["$temp"] = state.temp_str,
            ["$weather_ic_3h"] = state.weather_ic_3h, ["$temp_3h"] = state.temp_str_3h,
            ["$weather_ic_24h"] = state.weather_ic_24h, ["$temp_24h"] = state.temp_str_24h,
            ["$cpu_ic"] = "", ["$cpu"] = cpu_u, ["$mem_used_ic"] = "",
            ["$mem_used"] = mem_u, ["$mem_free_ic"] = "", ["$mem_free"] = mem_f,
            ["$net_ic"] = "󰓅", ["$net_speed"] = net_curr, ["$net_avg"] = net_avg,
            ["$batt_ic"] = batt_ic, ["$batt_num"] = batt_num,
        }

        local res = {
            { Background = { Color = config.color_background } },
            { Foreground = { Color = config.color_foreground } },
            { Text = config.separator_left },
            { Background = { Color = config.color_foreground } },
            { Foreground = { Color = config.color_text } },
        }

        local current_str = config.format
        while true do
            local start_idx, end_idx = current_str:find("%$[%a%d_]+")
            if not start_idx then break end
            table.insert(res, { Text = current_str:sub(1, start_idx - 1) })
            local token = current_str:sub(start_idx, end_idx):lower()
            local val = replace_map[token] or token
            
            -- 【修正】table.insertは一度に1つずつ（または連結して）追加
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
        table.insert(res, { Text = config.separator_right })
        
        window:set_right_status(wezterm.format(res))
    end)
end

return M

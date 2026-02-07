local wezterm = require 'wezterm'
local M       = {}

local weather_icons = {
    clear       = "󰖨 ", clouds      = "󰅟 ", rain        = " ", wind        = " ",
    thunder     = "󱐋 ", snow        = " ", thermometer = "", celsius     = "󰔄",
    fahrenheit  = "󰔅", loading     = " ", unknown     = " ",
}

local state = {
    weather_ic    = weather_icons.loading,
    temp_str      = " -- ",
    weather_ic_3h = weather_icons.loading,
    temp_str_3h   = " -- ",
    weather_ic_24h = weather_icons.loading,
    temp_str_24h  = " -- ",
    city_name     = "Loading...",
    city_code     = "",
    last_weather_upd  = 0,
    is_weather_ready  = false,
    proc_start    = os.time(),
    net_state     = {
        last_rx_bytes = 0,
        last_chk_time = os.clock(),
        disp_str      = "0.0B/S",
        avg_str       = "0.0B/S",
        samples       = {}
    }
}

local function run_child_cmd(args)
    local success, stdout, _ = wezterm.run_child_process(args)
    return success, stdout
end

local function format_bps(bps)
    bps = tonumber(bps) or 0
    if bps > 1024 * 1024 then return string.format("%5.1fMB/S", bps / (1024 * 1024))
    elseif bps > 1024 then return string.format("%5.1fKB/S", bps / 1024)
    else return string.format("%6.1fB/S", bps) end
end

local function calc_net_speed(config, is_startup_waiting)
    if is_startup_waiting then return state.net_state.disp_str, state.net_state.avg_str end
    local curr_time  = os.clock()
    local time_delta = curr_time - state.net_state.last_chk_time
    if time_delta < (tonumber(config.net_update_interval) or 3) then 
        return state.net_state.disp_str, state.net_state.avg_str 
    end

    local is_win  = wezterm.target_triple:find("windows")
    local curr_rx = 0
    if is_win then
        local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
        curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
    end

    local diff = curr_rx - state.net_state.last_rx_bytes
    if diff >= 0 and state.net_state.last_rx_bytes ~= 0 then
        local bps = diff / time_delta
        table.insert(state.net_state.samples, 1, bps)
        if #state.net_state.samples > (tonumber(config.net_avg_samples) or 10) then 
            table.remove(state.net_state.samples) 
        end
        local sum_bps = 0
        for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end
        state.net_state.disp_str = format_bps(bps)
        state.net_state.avg_str  = format_bps(sum_bps / #state.net_state.samples)
    end
    state.net_state.last_rx_bytes = curr_rx
    state.net_state.last_chk_time = curr_time
    return state.net_state.disp_str, state.net_state.avg_str
end

local function get_sys_resources()
    local cpu_val, mem_u_val, mem_f_val = 0, 0, 0
    if wezterm.target_triple:find("windows") then
        local ok, out = run_child_cmd({"powershell.exe", "-NoProfile", "-Command", "Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average; (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"})
        if ok and out then
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do table.insert(lines, line) end
            cpu_val = tonumber(lines[1]) or 0
            local f_kb = tonumber(lines[2]) or 0
            local t_kb = tonumber(lines[3]) or 0
            mem_f_val, mem_u_val = f_kb / 1024^2, (t_kb - f_kb) / 1024^2
        end
    end
    return string.format("%2d%%", cpu_val), string.format("%4.1fGB", mem_u_val), string.format("%4.1fGB", mem_f_val)
end

local function fetch_weather_data(config)
    wezterm.log_info("Attempting to fetch weather data...")
    local is_win = wezterm.target_triple:find("windows")
    local curl = is_win and "curl.exe" or "curl"
    local url = string.format("https://api.openweathermap.org/data/2.5/forecast?appid=%s&q=Yokohama,JP&units=metric&lang=en", config.weather_api_key)
    
    local ok, stdout = run_child_cmd({curl, "-s", url})
    if not ok or not stdout or stdout:find('"message"') then
        wezterm.log_error("Weather fetch failed. Check API Key.")
        state.last_weather_upd = os.time()
        return
    end

    local function parse_item(item_json)
        local id = tonumber(item_json:match('"weather":%s*%[%s*{%s*"id":%s*(%d+)'))
        local t = item_json:match('"temp":([%d%.%-]+)')
        local ic = weather_icons.unknown
        if id then
            if id < 300 then ic = weather_icons.thunder
            elseif id < 600 then ic = weather_icons.rain
            elseif id < 700 then ic = weather_icons.snow
            elseif id < 800 then ic = weather_icons.wind
            elseif id == 800 then ic = weather_icons.clear
            else ic = weather_icons.clouds end
        end
        return ic, t
    end

    local list = stdout:match('"list":%s*%[(.+)%],"city"')
    if not list then return end
    local entries = {}
    for entry in list:gmatch("({.-})") do if entry:find('"main"') then table.insert(entries, entry) end end

    if #entries >= 1 then
        local ic, t = parse_item(entries[1])
        state.weather_ic, state.temp_str = ic, string.format("%4.1f℃", tonumber(t) or 0)
    end
    if #entries >= 2 then
        local ic, t = parse_item(entries[2])
        state.weather_ic_3h, state.temp_str_3h = ic, string.format("%4.1f℃", tonumber(t) or 0)
    end
    if #entries >= 9 then
        local ic, t = parse_item(entries[9])
        state.weather_ic_24h, state.temp_str_24h = ic, string.format("%4.1f℃", tonumber(t) or 0)
    end

    state.city_name = stdout:match('"name":"([^"]+)"') or "Yokohama"
    state.city_code = stdout:match('"country":"([^"]+)"') or "JP"
    state.last_weather_upd = os.time()
    state.is_weather_ready = true
    wezterm.log_info("Weather updated: " .. state.city_name)
end

function M.setup(opts)
    local config = {
        startup_delay = (opts and opts.startup_delay) or 5,
        weather_api_key = opts and opts.weather_api_key,
        net_update_interval = 3,
        net_avg_samples = 10,
        color_foreground = (opts and opts.color_foreground) or "#7aa2f7",
        color_background = (opts and opts.color_background) or "#1a1b26",
        color_text = "#ffffff",
    }

    wezterm.on('update-right-status', function(window, pane)
        local now = os.time()
        local is_waiting = (now - state.proc_start) < config.startup_delay

        if config.weather_api_key and not is_waiting then
            if (now - state.last_weather_upd > 600) then
                fetch_weather_data(config)
            end
        end

        local net_curr, net_avg = calc_net_speed(config, is_waiting)
        local cpu, mem_u, mem_f = get_sys_resources()
        local date = wezterm.strftime('%Y.%m.%d(%a) %H:%M')

        local status = string.format(
            "  %s  %s(%s) %s %s 3h(%s %s) 24h(%s %s)  %s  %s  %s 󰓅 %s(%s) ",
            date, state.city_name, state.city_code, state.weather_ic, state.temp_str,
            state.weather_ic_3h, state.temp_str_3h, state.weather_ic_24h, state.temp_str_24h,
            cpu, mem_u, mem_f, net_curr, net_avg
        )

        window:set_right_status(wezterm.format({
            { Background = { Color = config.color_background } },
            { Foreground = { Color = config.color_foreground } },
            { Text = "" },
            { Background = { Color = config.color_foreground } },
            { Foreground = { Color = config.color_text } },
            { Text = status },
            { Background = { Color = config.color_background } },
            { Foreground = { Color = config.color_foreground } },
            { Text = "" },
        }))
    end)
end

return M
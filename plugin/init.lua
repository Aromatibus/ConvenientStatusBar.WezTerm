local wezterm = require 'wezterm'
local M       = {}


--- ==========================================
--- 天気用アイコン定義
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
    weather_ic         = weather_icons.loading,
    temp_str           = string.format("%5s", weather_icons.loading),
    city_name          = weather_icons.loading,
    city_code          = "",
    last_weather_upd   = 0,
    is_weather_ready   = false,
    weather_ic_3h      = "",
    temp_3h            = "",
    weather_ic_24h     = "",
    temp_24h           = "",
    proc_start         = os.time(),

    cpu_state = {
        last_total = 0,
        last_idle  = 0,
    },

    net_state = {
        last_rx_bytes = 0,
        last_chk_time = os.time(),
        disp_str      = string.format("%9s", weather_icons.loading),
        avg_str       = string.format("%9s", weather_icons.loading),
        samples       = {},
    },

    net_update_interval = 3,
    format_index        = 1,
}


--- ==========================================
--- 子プロセス実行
--- ==========================================
local function run_child_cmd(args)
    local success, stdout, _ = wezterm.run_child_process(args)
    return success, stdout
end


--- ==========================================
--- 天気情報取得
--- ==========================================

-- 予報データから指定インデックスの天気IDと温度を抽出
local function parse_forecast(data, index)
    if not data or not data.list then
        return nil, nil
    end
    local entry = data.list[index]
    if not entry then
        return nil, nil
    end
    local weather_id =
            entry.weather
        and entry.weather[1]
        and entry.weather[1].id
    local temp =
        entry.main
        and entry.main.temp
    return weather_id, temp
end


-- 天気IDからアイコンを取得
local function get_icon(weather_id)
    if not weather_id then return weather_icons.unknown end
    if     weather_id < 300  then return weather_icons.thunder
    elseif weather_id < 600  then return weather_icons.rain
    elseif weather_id < 700  then return weather_icons.snow
    elseif weather_id < 800  then return weather_icons.wind
    elseif weather_id == 800 then return weather_icons.clear
    else                          return weather_icons.clouds end
end


-- 天気データの取得
local function fetch_weather_data(config)
    -- OS別のcurlコマンド設定
    local is_win   = wezterm.target_triple:find("windows")
    local curl_cmd = is_win and "curl.exe" or "curl"
    -- 取得対象の都市名と国コードの設定
    local tgt_city = config.weather_city
    local tgt_code = config.weather_country
    -- 都市名が設定されていない場合、IP情報から取得
    if not tgt_city or tgt_city == "" then
        local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
        if ok and res then
            wezterm.log_info("ipapi = " .. res) -- デバッグ用ログ
            tgt_city = res:match('"city":%s*"([^"]+)"')
            tgt_code = res:match('"country_code":%s*"([^"]+)"')
        end
    end
    -- 都市名が取得できない場合の処理
    if not tgt_city or tgt_city == "" then
        state.weather_ic, state.temp_str, state.city_name, state.is_weather_ready =
            weather_icons.unknown,
            string.format("%5s", weather_icons.unknown),
            weather_icons.unknown,
            false
        return
    end
    -- クエリ文字列の作成
    local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
    -- APIリクエストURLの作成
    local url = string.format(
        "https://api.openweathermap.org/data/2.5/forecast?appid=%s&lang=%s&q=%s&units=%s",
        config.weather_api_key,
        config.weather_lang,
        query,
        config.weather_units
    )
    -- APIリクエストの実行
    local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
    -- エラーチェック とメッセージフィールドでエラーの確認
    if not ok or not stdout then
        wezterm.log_info("OpenWeatherMap = " .. stdout) -- デバッグ用ログ
        state.weather_ic, state.temp_str, state.city_name, state.is_weather_ready =
            weather_icons.unknown,
            string.format("%5s", weather_icons.unknown),
            tgt_city,
            false
        state.last_weather_upd = os.time()
        return
    end
    -- 温度単位シンボル
    local unit_sym =
        config.weather_units == "metric"
        and weather_icons.celsius
        or weather_icons.fahrenheit
    -- forecast取得
    local ok_json, data = pcall(wezterm.json_parse, stdout)
    -- JSONパースエラーチェック
    if not ok_json or not data or not data.list then
        state.weather_ic       = weather_icons.unknown
        state.temp_str         = string.format("%5s", weather_icons.unknown)
        state.is_weather_ready = false
        state.last_weather_upd = os.time()
        return
    end
    -- 各時点の天気IDと温度の抽出
    local current_id, current_temp = parse_forecast(data, 1)
    local id3, temp3               = parse_forecast(data, 2)
    local id24, temp24             = parse_forecast(data, 9)
    -- 現在
    state.weather_ic = get_icon(current_id)
    state.temp_str =
        current_temp and
        string.format("%4.1f%s", tonumber(current_temp), unit_sym)
        or string.format("%5s", weather_icons.unknown)
    -- 3h後
    state.weather_ic_3h = get_icon(id3)
    state.temp_3h =
        temp3 and
        string.format("%4.1f%s", tonumber(temp3), unit_sym)
        or ""
    -- 24h後
    state.weather_ic_24h = get_icon(id24)
    state.temp_24h =
        temp24 and
        string.format("%4.1f%s", tonumber(temp24), unit_sym)
        or ""
    -- APIからの都市名と国コードの抽出
    local api_name = data.city and data.city.name
    local api_code = data.city and data.city.country
    -- 都市名と国コードの設定
    state.city_name, state.city_code, state.last_weather_upd, state.is_weather_ready =
        api_name or tgt_city,
        api_code or tgt_code or "",
        os.time(),
        true
end


--- ==========================================
--- システムリソース取得
--- ==========================================
local function get_sys_resources()
    local cpu_val   = 0
    local mem_u_val = 0
    local mem_f_val = 0
    -- OS判定
    local triple = wezterm.target_triple
    local is_win = triple:find("windows")
    local is_mac = triple:find("darwin")
    -- Windows
    if is_win then
        local ok, out = run_child_cmd({
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "Get-CimInstance Win32_Processor | "
                .. "Measure-Object -Property LoadPercentage -Average | "
                .. "Select-Object -ExpandProperty Average; "
                .. "(Get-CimInstance Win32_OperatingSystem)."
                .. "FreePhysicalMemory; "
                .. "(Get-CimInstance Win32_OperatingSystem)."
                .. "TotalVisibleMemorySize",
        })
        if ok and out then
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end
            -- CPU使用率
            cpu_val = tonumber(lines[1]) or 0
            -- メモリ
            local f_kb = tonumber(lines[2]) or 0
            local t_kb = tonumber(lines[3]) or 0
            mem_f_val = f_kb / 1024 / 1024
            mem_u_val = (t_kb - f_kb) / 1024 / 1024
        end

    -- macOS
    elseif is_mac then
        -- CPU使用率
        local ok, out = run_child_cmd({
            "sh",
            "-c",
            "top -l 1 | grep 'CPU usage'",
        })
        if ok and out then
            local user, sys =
                out:match("(%d+%.?%d*)%% user.*(%d+%.?%d*)%% sys")
            cpu_val = (tonumber(user) or 0) + (tonumber(sys) or 0)
        end
        -- メモリ使用量
        local ok2, out2 = run_child_cmd({
            "sh",
            "-c",
            "vm_stat",
        })
        if ok2 and out2 then
            local page_size =
                out2:match("page size of (%d+) bytes")
            page_size = tonumber(page_size) or 4096
            local free     = out2:match("Pages free:%s+(%d+)")
            local inactive = out2:match("Pages inactive:%s+(%d+)")
            local active   = out2:match("Pages active:%s+(%d+)")
            local wired    = out2:match("Pages wired down:%s+(%d+)")
            free     = tonumber(free) or 0
            inactive = tonumber(inactive) or 0
            active   = tonumber(active) or 0
            wired    = tonumber(wired) or 0
            local free_bytes = (free + inactive) * page_size
            local used_bytes = (active + wired) * page_size
            mem_f_val = free_bytes / 1024^3
            mem_u_val = used_bytes / 1024^3
        end
    -- Linux
    else
        -- CPU使用率
        local ok, out = run_child_cmd({
            "sh",
            "-c",
            "cat /proc/stat | head -n1",
        })
        if ok and out then
            local user, nice, system, idle, iowait,
                irq, softirq, steal =
                out:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)")
            user    = tonumber(user) or 0
            nice    = tonumber(nice) or 0
            system  = tonumber(system) or 0
            idle    = tonumber(idle) or 0
            iowait  = tonumber(iowait) or 0
            irq     = tonumber(irq) or 0
            softirq = tonumber(softirq) or 0
            steal   = tonumber(steal) or 0
            local total = user + nice + system + idle + iowait + irq + softirq + steal
            local idle_all = idle + iowait
            if state.cpu_state.last_total ~= 0 then
                local dt    = total - state.cpu_state.last_total
                local didle = idle_all - state.cpu_state.last_idle
                if dt > 0 then
                    cpu_val = (1 - didle / dt) * 100
                end
            end
            state.cpu_state.last_total = total
            state.cpu_state.last_idle  = idle_all
        end
        -- メモリ使用量
        local ok2, out2 = run_child_cmd({
            "sh",
            "-c",
            "free -b | awk '/^Mem:/ {print $3, $4}'",
        })
        if ok2 and out2 then
            local used, free = out2:match("(%d+)%s+(%d+)")
            mem_u_val = (tonumber(used) or 0) / 1024^3
            mem_f_val = (tonumber(free) or 0) / 1024^3
        end
    end
    -- 表示用フォーマットに変換して返却
    return
        string.format("%2d%%", cpu_val),
        string.format("%4.1fGB", mem_u_val),
        string.format("%4.1fGB", mem_f_val)
end


--- ==========================================
--- バイト/秒のフォーマット
--- ==========================================
local function format_bps(bps)
    if bps > 1024 * 1024
        then return string.format("%5.1fMB/s", bps / (1024 * 1024))
    elseif bps > 1024 then return string.format("%5.1fKB/s", bps / 1024)
    else return string.format("%6.1fB/s", bps) end
end


--- ==========================================
--- ネットワーク速度計算
--- ==========================================
local function calc_net_speed()
    local now = os.time()
    local dt = now - state.net_state.last_chk_time
    -- 更新間隔内であれば前回の値を返却
    if dt < (state.net_update_interval or 3) or dt <= 0 then
        return state.net_state.disp_str, state.net_state.avg_str
    end
    -- 現在の受信バイト数を取得
    local curr_rx = 0
    local triple = wezterm.target_triple
    local is_win = triple:find("windows")
    local is_mac = triple:find("darwin")
    -- 各OS別の受信バイト数取得コマンド
    if is_win then
        -- Windows
        local ok, out = run_child_cmd({
            "powershell.exe", "-NoProfile", "-Command",
            "(Get-NetAdapterStatistics | Measure-Object -Property ReceivedBytes -Sum).Sum"
        })
        curr_rx = ok and tonumber(out) or 0
    elseif is_mac then
        -- macOS
        local ok, out = run_child_cmd({
            "sh", "-c",
            "netstat -ib | awk 'NR>1 && $1 != \"lo0\" {sum+=$7} END {print sum}'"
        })
        curr_rx = ok and tonumber(out) or 0
    else
        -- Linux
        local ok, out = run_child_cmd({
            "sh","-c","cat /proc/net/dev"
        })
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
    -- 初回実行時は速度計算をスキップ
    if state.net_state.last_rx_bytes == 0 then
        state.net_state.last_rx_bytes = curr_rx
        state.net_state.last_chk_time = now
        return state.net_state.disp_str, state.net_state.avg_str
    end
    -- 速度計算
    local diff = curr_rx - state.net_state.last_rx_bytes
    local speed = diff > 0 and diff / dt or 0
    -- 状態変数の更新
    state.net_state.last_rx_bytes = curr_rx
    state.net_state.last_chk_time = now
    -- 速度のフォーマット
    local speed_str = format_bps(speed)
    -- 平均速度の計算
    table.insert(state.net_state.samples, speed)
    if #state.net_state.samples > (state.net_avg_samples or 20) then
        table.remove(state.net_state.samples, 1)
    end
    -- サンプルの平均値計算
    local sum = 0
    for _, v in ipairs(state.net_state.samples) do
        sum = sum + v
    end
    -- 平均速度のフォーマット
    local avg = (#state.net_state.samples > 0)
        and (sum / #state.net_state.samples)
        or 0
    -- フォーマットして保存
    local avg_str = format_bps(avg)
    -- 状態変数に保存
    state.net_state.disp_str = speed_str
    state.net_state.avg_str  = avg_str

    return speed_str, avg_str
end


--- ==========================================
--- SSHユーザー抽出
--- ==========================================
local function get_ssh_user(pane)
    -- 作業ディレクトリからの抽出
    local uri = pane:get_current_working_dir()
    -- URIにユーザー名が含まれている場合
    if uri and uri.username and uri.username ~= "" then
        return uri.username
    end
    -- プロセス情報からの抽出
    local proc = pane:get_foreground_process_info()
    -- SSHプロセスの場合
    if proc and proc.executable:find("ssh") then
        for _, arg in ipairs(proc.argv) do
            local u = arg:match("([^@]+)@[^@]+")
            if u then return u end
        end
    end
    -- タイトルバーからの抽出
    local title = pane:get_title()
    -- タイトルに"@"が含まれていない場合は終了
    local t_user = title:match("([^@]+)@[^@]+")
    -- タイトルにユーザー名が含まれている場合
    if t_user then return t_user end
    return nil
end


--- ==========================================
--- バッテリー情報取得
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
    -- デフォルトのフォーマット文字列
    -- フォーマット１
    local def_fmt1 =
        " $user_ic $user " ..
        "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
        " $loc_ic $city($code) " ..
        "$weather_ic($temp) "  ..
        "$batt_ic$batt_num "
    -- フォーマット2
    local def_fmt2 =
        " Now:$weather_ic($temp) "  ..
        "+3h:$weather_ic_3h($temp_3h) " ..
        "+24h:$weather_ic_24h($temp_24h) " ..
        "$cpu_ic $cpu $mem_ic $mem_free " ..
        "$net_ic $net_speed($net_avg) "
    -- 設定の初期化
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
        formats = (opts and opts.formats) or { def_fmt1, def_fmt2 },
    }
    -- ネットワーク速度計算用のサンプル数を状態変数に保存
    state.net_avg_samples = config.net_avg_samples
    -- ネットワーク速度計算用の更新間隔を状態変数に保存
    state.net_update_interval = config.net_update_interval
    -- ログに最終的に使用されたConfigの値をそのまま出力
    wezterm.log_info("Final Config: " .. wezterm.to_string(config))
    -- ステータスバー更新イベントの登録
    wezterm.on('update-right-status', function(window, pane)
        -- 現在時刻の取得
        local now        = os.time()
        -- スタートアップ待機中フラグ
        local is_waiting = (now - state.proc_start) < config.startup_delay
        -- デフォルトまたは指定されたフォーマットで使用されていない処理は実行しない
        local current_format = config.formats[state.format_index] or config.formats[1]
        local fmt_lower = current_format:lower()
        -- 使用されている情報の判定
        local use_weather = (fmt_lower:find("%$weather") ~= nil)
                        or  (fmt_lower:find("%$temp") ~= nil)
                        or  (fmt_lower:find("%$city") ~= nil)
                        or  (fmt_lower:find("%$loc_ic") ~= nil)
        local use_net     = (fmt_lower:find("%$net") ~= nil)
        local use_sys     = (fmt_lower:find("%$cpu") ~= nil)
                        or  (fmt_lower:find("%$mem") ~= nil)
        local use_batt    = (fmt_lower:find("%$batt") ~= nil)
        -- 天気APIキーの有無チェック
        local has_weather_api = config.weather_api_key and config.weather_api_key ~= ""
        -- 天気情報の更新
        if use_weather and has_weather_api and not is_waiting then
            -- 更新間隔の確認
            local diff = now - state.last_weather_upd
            -- 更新が必要な場合は天気情報を取得
            if state.last_weather_upd == 0
                or diff > config.weather_update_interval
                or (not state.is_weather_ready and diff > config.weather_retry_interval)
            then
                fetch_weather_data(config)
            end
        end
        -- ネットワーク速度の計算
        local net_curr, net_avg = "", ""
        if use_net then
            net_curr, net_avg = calc_net_speed()
        end
        -- システムリソースの取得
        local cpu_u, mem_u, mem_f = "", "", ""
        if use_sys then cpu_u, mem_u, mem_f = get_sys_resources() end
        -- バッテリー情報の取得
        local batt_ic, batt_num = "", ""
        if use_batt then batt_ic, batt_num = get_batt_disp() end
        -- 指定された曜日文字列の取得
        local week_val = ""
        if fmt_lower:find("$week") then
            if config.week_str and type(config.week_str) == "table" then
                local week_idx = tonumber(wezterm.strftime('%w'))
                week_val = config.week_str[week_idx + 1] or wezterm.strftime('%a')
            else
                week_val = wezterm.strftime('%a')
            end
        end
        -- ユーザー名とアイコンの取得
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
        -- ステータスバーの文字列作成
        local res = {
            { Background = { Color = config.color_background } },
            { Foreground = { Color = config.color_foreground } },
            { Text       = config.separator_left },
            { Background = { Color = config.color_foreground } },
            { Foreground = { Color = config.color_text } },
        }
        -- 置換マップ
        local replace_map = {
            ["$user_ic"]        = user_icon,
            ["$user"]           = user_name,
            ["$cal_ic"]         = "",
            ["$year"]           = wezterm.strftime("%Y"),
            ["$month"]          = wezterm.strftime("%m"),
            ["$day"]            = wezterm.strftime("%d"),
            ["$week"]           = week_val,
            ["$clock_ic"]       = "",
            ["$time24"]         = wezterm.strftime("%H:%M"),
            ["$loc_ic"]         = has_weather_api and "" or weather_icons.unknown
            ["$city"]           = has_weather_api and state.city_name or weather_icons.unknown,
            ["$code"]           = has_weather_api and state.city_code or weather_icons.unknown,
            ["$weather_ic"]     = has_weather_api and state.weather_ic or weather_icons.unknown,
            ["$temp"]           = has_weather_api and state.temp_str or weather_icons.unknown,
            ["$weather_ic_3h"]  = state.weather_ic_3h,
            ["$temp_3h"]        = state.temp_3h,
            ["$weather_ic_24h"] = state.weather_ic_24h,
            ["$temp_24h"]       = state.temp_24h,
            ["$cpu_ic"]         = "",
            ["$cpu"]            = cpu_u,
            ["$mem_ic"]         = "",
            ["$mem_used"]       = mem_u,
            ["$mem_free"]       = mem_f,
            ["$net_ic"]         = "󰓅",
            ["$net_speed"]      = net_curr,
            ["$net_avg"]        = net_avg,
            ["$batt_ic"]        = batt_ic,
            ["$batt_num"]       = batt_num,
        }
        -- フォーマット文字列の解析と置換
        local current_str = current_format
        while true do
            local start_idx, end_idx = current_str:find("%$[<>]?[%a%d_]+")
            if not start_idx then break end
            -- トークン前の通常文字列
            table.insert(res, { Text = current_str:sub(1, start_idx - 1) })
            local token = current_str:sub(start_idx, end_idx):lower()
            local val = replace_map[token] or ""
            table.insert(res, { Text = val })
            current_str = current_str:sub(end_idx + 1)
        end
        table.insert(res, { Text = current_str })
        table.insert(res, { Background = { Color = config.color_background } })
        table.insert(res, { Foreground = { Color = config.color_foreground } })
        table.insert(res, { Text       = config.separator_right })
        -- ステータスバーの表示更新
        window:set_right_status(wezterm.format(res))
    end)
    -- フォーマット切替用のキーイベント登録
    wezterm.on("toggle-status-format", function(window, pane)
        state.format_index = state.format_index + 1
        if state.format_index > #config.formats then
            state.format_index = 1
        end
        wezterm.log_info("format switched to " .. state.format_index)
        window:perform_action(wezterm.action.InvalidateCache, pane)
    end)
end


return M

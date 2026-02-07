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
    -- スタートアップ待機中は初期値を返す
    if is_startup_waiting
        then return state.net_state.disp_str, state.net_state.avg_str end
    -- 更新間隔のチェック
    local curr_time  = os.clock()
    local time_delta = curr_time - state.net_state.last_chk_time
    if time_delta < config.net_update_interval
        then return state.net_state.disp_str, state.net_state.avg_str end
    -- OS別のコマンド実行
    local is_win  = wezterm.target_triple:find("windows")
    -- 現在の受信バイト数の取得
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
    -- 経過時間から速度計算
    local bps = (curr_rx - state.net_state.last_rx_bytes) / time_delta
    -- サンプルの追加と古いサンプルの削除
    table.insert(state.net_state.samples, 1, bps)
    if #state.net_state.samples > config.net_avg_samples
        then table.remove(state.net_state.samples) end
    -- 平均速度の計算
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
    -- 初期値の設定
    local cpu_val, mem_u_val, mem_f_val = 0, 0, 0
    -- OS別のコマンド実行
    local is_win = wezterm.target_triple:find("windows")
    if is_win then
        -- CPU使用率とメモリ情報の取得 (Windows)
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
        -- CPU使用率とメモリ情報の取得 (Unix系)
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
--- 天気情報取得
--- ==========================================
local function fetch_weather_data(config)
    -- APIキーが指定されていない、または空の場合は処理を中断
    if not config.weather_api_key or config.weather_api_key == "" then
        state.weather_ic, state.temp_str, state.city_name, state.is_weather_ready =
            weather_icons.unknown,
            string.format("%5s", weather_icons.unknown),
            "No API Key",
            false
        return
    end

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
        "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
        config.weather_api_key,
        config.weather_lang,
        query,
        config.weather_units
    )
    -- APIリクエストの実行
    local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
    -- エラーチェック とメッセージフィールドでエラーの確認
    if not ok or not stdout or stdout:find('"message"') then
        state.weather_ic, state.temp_str, state.city_name, state.is_weather_ready =
            weather_icons.unknown,
            string.format("%5s", weather_icons.unknown),
            tgt_city,
            false
        state.last_weather_upd = os.time()
        return
    end
    -- 天気情報の更新
    local weather_id   = tonumber(stdout:match('"id":(%d+)'))
    -- 天気温度、都市名、国コードの抽出
    local temp_val = stdout:match('"temp":([%d%.%-]+)')
    -- APIからの都市名と国コードの抽出
    local api_name = stdout:match('"name":"([^"]+)"')
    -- 国コード
    local api_code = stdout:match('"country":"([^"]+)"')
    -- 天気アイコンと温度文字列の設定
    if weather_id then
        if     weather_id < 300  then state.weather_ic = weather_icons.thunder
        elseif weather_id < 600  then state.weather_ic = weather_icons.rain
        elseif weather_id < 700  then state.weather_ic = weather_icons.snow
        elseif weather_id < 800  then state.weather_ic = weather_icons.wind
        elseif weather_id == 800 then state.weather_ic = weather_icons.clear
        else                          state.weather_ic = weather_icons.clouds end
    end
    -- 温度単位シンボルの設定
    local unit_sym =
        config.weather_units == "metric" and
        weather_icons.celsius or weather_icons.fahrenheit
    -- 温度表示の設定
    state.temp_str     =
        temp_val and
        string.format("%4.1f%s", tonumber(temp_val), unit_sym) or state.temp_str
    -- 都市名と国コードの設定
    state.city_name, state.city_code, state.last_weather_upd, state.is_weather_ready =
        api_name or tgt_city,
        api_code or tgt_code or "",
        os.time(),
        true
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
    local def_fmt =
        " $user_ic $user " ..
        "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
        "$loc_ic $city($code) $weather_ic $temp " ..
        "$cpu_ic $cpu $mem_used_ic $mem_used $mem_free_ic $mem_free " ..
        "$net_ic $net_speed($net_avg) " ..
        "$batt_ic$batt_num "

    -- デフォルトのAPIキー（自動取得用）
    local default_api_key = "YOUR_DEFAULT_OPENWEATHER_API_KEY"

    -- 設定の初期化
    local config              = {
        startup_delay           = (opts and opts.startup_delay) or 5,
        weather_api_key         = (opts and opts.weather_api_key) or default_api_key,
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

    -- ログに最終的に使用されたConfigの値をそのまま出力
    wezterm.log_info("Final Config: " .. wezterm.to_string(config))

    -- ステータスバー更新イベントの登録
    wezterm.on('update-right-status', function(window, pane)
        local now        = os.time()
        -- スタートアップ待機中フラグ
        local is_waiting = (now - state.proc_start) < config.startup_delay
        -- デフォルトまたは指定されたフォーマットで使用されていない処理は実行しない
        local fmt_lower  = config.format:lower()
        local use_weather =
            fmt_lower:find("$weather") or fmt_lower:find("$temp") or
            fmt_lower:find("$city") or fmt_lower:find("$loc_ic")
        local use_net  = fmt_lower:find("$net")
        local use_sys  = fmt_lower:find("$cpu") or fmt_lower:find("$mem")
        local use_batt = fmt_lower:find("$batt")

        -- 天気情報の処理判定
        -- キーが明示的に "" の場合は一切処理しない。それ以外（nil含む）は処理。
        local has_weather_api = config.weather_api_key ~= ""
        -- 天気情報の更新
        if use_weather and has_weather_api and not is_waiting then
            local diff = now - state.last_weather_upd
            if state.last_weather_upd == 0
                or diff > config.weather_update_interval
                or (not state.is_weather_ready and diff > config.weather_retry_interval)
            then
                fetch_weather_data(config)
            end
        end
        -- ネットワーク速度の計算
        local net_curr, net_avg = "", ""
        if use_net then net_curr, net_avg = calc_net_speed(config, is_waiting) end
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
        -- 置換マップの作成
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
        -- フォーマット文字列の置換
        local current_str = config.format
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
        -- ステータスバーの表示更新
        window:set_right_status(wezterm.format(res))
    end)
end


return M

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
    weather_ic        = weather_icons.loading,
    temp_str          = string.format("%5s", weather_icons.loading),
    city_name         = weather_icons.loading,
    city_code         = "",
    last_weather_upd  = 0,
    is_weather_ready  = false,
    weather_ic_3h     = "",
    temp_3h           = "",
    weather_ic_24h    = "",
    temp_24h          = "",
    proc_start        = os.time(),

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
    -- 外部コマンド実行
    local success, stdout, _ = wezterm.run_child_process(args)
    return success, stdout
end


--- ==========================================
--- バイト/秒のフォーマット
--- ==========================================
local function format_bps(bps)
    -- 速度を人間可読形式に変換
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
    -- 現在時刻と経過時間
    local now = os.time()
    local dt  = now - state.net_state.last_chk_time

    -- 更新間隔内なら前回値を返す
    if dt < (state.net_update_interval or 3) or dt <= 0 then
        return state.net_state.disp_str, state.net_state.avg_str
    end

    -- OS 判定
    local curr_rx = 0
    local triple  = wezterm.target_triple
    local is_win  = triple:find("windows")
    local is_mac  = triple:find("darwin")

    -- 受信バイト数取得
    if is_win then
        local ok, out = run_child_cmd({
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "(Get-NetAdapterStatistics | Measure-Object -Property ReceivedBytes -Sum).Sum",
        })
        curr_rx = ok and tonumber(out) or 0

    elseif is_mac then
        local ok, out = run_child_cmd({
            "sh",
            "-c",
            "netstat -ib | awk 'NR>1 && $1 != \"lo0\" {sum+=$7} END {print sum}'",
        })
        curr_rx = ok and tonumber(out) or 0

    else
        local ok, out = run_child_cmd({ "sh", "-c", "cat /proc/net/dev" })
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

    -- 初回は計測のみ
    if state.net_state.last_rx_bytes == 0 then
        state.net_state.last_rx_bytes = curr_rx
        state.net_state.last_chk_time = now
        return state.net_state.disp_str, state.net_state.avg_str
    end

    -- 速度算出
    local diff  = curr_rx - state.net_state.last_rx_bytes
    local speed = diff > 0 and diff / dt or 0

    -- 状態更新
    state.net_state.last_rx_bytes = curr_rx
    state.net_state.last_chk_time = now

    -- 表示用文字列生成
    local speed_str = format_bps(speed)

    -- 移動平均用サンプル管理
    table.insert(state.net_state.samples, speed)
    if #state.net_state.samples > (state.net_avg_samples or 20) then
        table.remove(state.net_state.samples, 1)
    end

    -- 平均速度計算
    local sum = 0
    for _, v in ipairs(state.net_state.samples) do
        sum = sum + v
    end

    local avg = (#state.net_state.samples > 0)
        and (sum / #state.net_state.samples)
        or 0

    local avg_str = format_bps(avg)

    -- 表示用状態保存
    state.net_state.disp_str = speed_str
    state.net_state.avg_str  = avg_str

    return speed_str, avg_str
end


--- ==========================================
--- システムリソース取得
--- ==========================================
local function get_sys_resources()
    -- CPU / メモリ取得
    local cpu_val    = 0
    local mem_u_val  = 0
    local mem_f_val  = 0

    -- OS 判定
    local triple = wezterm.target_triple
    local is_win = triple:find("windows")
    local is_mac = triple:find("darwin")

    if is_win then
        local ok, out = run_child_cmd({
            "powershell.exe",
            "-NoProfile",
            "-Command",
            "Get-CimInstance Win32_Processor | "
                .. "Measure-Object -Property LoadPercentage -Average | "
                .. "Select-Object -ExpandProperty Average; "
                .. "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; "
                .. "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize",
        })

        if ok and out then
            local lines = {}
            for line in out:gmatch("[^\r\n]+") do
                table.insert(lines, line)
            end

            cpu_val     = tonumber(lines[1]) or 0
            local f_kb  = tonumber(lines[2]) or 0
            local t_kb  = tonumber(lines[3]) or 0
            mem_f_val   = f_kb / 1024 / 1024
            mem_u_val   = (t_kb - f_kb) / 1024 / 1024
        end

    elseif is_mac then
        local ok, out = run_child_cmd({ "sh", "-c", "top -l 1 | grep 'CPU usage'" })
        if ok and out then
            local user, sys =
                out:match("(%d+%.?%d*)%% user.*(%d+%.?%d*)%% sys")
            cpu_val = (tonumber(user) or 0) + (tonumber(sys) or 0)
        end

        local ok2, out2 = run_child_cmd({ "sh", "-c", "vm_stat" })
        if ok2 and out2 then
            local page_size = tonumber(out2:match("page size of (%d+) bytes")) or 4096
            local free     = tonumber(out2:match("Pages free:%s+(%d+)")) or 0
            local inactive = tonumber(out2:match("Pages inactive:%s+(%d+)")) or 0
            local active   = tonumber(out2:match("Pages active:%s+(%d+)")) or 0
            local wired    = tonumber(out2:match("Pages wired down:%s+(%d+)")) or 0

            local free_bytes = (free + inactive) * page_size
            local used_bytes = (active + wired) * page_size

            mem_f_val = free_bytes / 1024 ^ 3
            mem_u_val = used_bytes / 1024 ^ 3
        end

    else
        local ok, out = run_child_cmd({ "sh", "-c", "cat /proc/stat | head -n1" })
        if ok and out then
            local user, nice, system, idle, iowait, irq, softirq, steal =
                out:match(
                    "cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)"
                )

            user     = tonumber(user) or 0
            nice     = tonumber(nice) or 0
            system   = tonumber(system) or 0
            idle     = tonumber(idle) or 0
            iowait   = tonumber(iowait) or 0
            irq      = tonumber(irq) or 0
            softirq  = tonumber(softirq) or 0
            steal    = tonumber(steal) or 0

            local total    =
                user + nice + system + idle + iowait + irq + softirq + steal
            local idle_all = idle + iowait

            if state.cpu_state.last_total ~= 0 then
                local dt     = total - state.cpu_state.last_total
                local didle  = idle_all - state.cpu_state.last_idle
                if dt > 0 then
                    cpu_val = (1 - didle / dt) * 100
                end
            end

            state.cpu_state.last_total = total
            state.cpu_state.last_idle  = idle_all
        end

        local ok2, out2 = run_child_cmd({
            "sh",
            "-c",
            "free -b | awk '/^Mem:/ {print $3, $4}'",
        })

        if ok2 and out2 then
            local used, free = out2:match("(%d+)%s+(%d+)")
            mem_u_val = (tonumber(used) or 0) / 1024 ^ 3
            mem_f_val = (tonumber(free) or 0) / 1024 ^ 3
        end
    end

    -- 表示用フォーマットで返却
    return
        string.format("%2d%%", cpu_val),
        string.format("%4.1fGB", mem_u_val),
        string.format("%4.1fGB", mem_f_val)
end


--- ==========================================
--- SSHユーザー抽出
--- ==========================================
local function get_ssh_user(pane)
    -- 作業ディレクトリから抽出
    local uri = pane:get_current_working_dir()
    if uri and uri.username and uri.username ~= "" then
        return uri.username
    end

    -- プロセス情報から抽出
    local proc = pane:get_foreground_process_info()
    if proc and proc.executable:find("ssh") then
        for _, arg in ipairs(proc.argv) do
            local u = arg:match("([^@]+)@[^@]+")
            if u then return u end
        end
    end

    -- タイトルバーから抽出
    local title  = pane:get_title()
    local t_user = title:match("([^@]+)@[^@]+")
    if t_user then return t_user end

    return nil
end

--- ==========================================
--- 天気情報取得
--- ==========================================


-- 天気IDからアイコンを取得
local function get_icon(weather_id)
    -- 未定義時は unknown を返却
    if not weather_id then
        return weather_icons.unknown
    end

    -- 天気IDの範囲に応じて分類
    if     weather_id < 300  then return weather_icons.thunder
    elseif weather_id < 600  then return weather_icons.rain
    elseif weather_id < 700  then return weather_icons.snow
    elseif weather_id < 800  then return weather_icons.wind
    elseif weather_id == 800 then return weather_icons.clear
    else                            return weather_icons.clouds
    end
end


-- 予報データから指定インデックスの天気IDと温度を抽出
local function parse_forecast(data, index)
    -- データ存在チェック
    if not data or not data.list then
        return nil, nil
    end

    local entry = data.list[index]

    -- インデックス範囲チェック
    if not entry then
        return nil, nil
    end

    -- 天気ID取得
    local weather_id =
        entry.weather
        and entry.weather[1]
        and entry.weather[1].id

    -- 温度取得
    local temp =
        entry.main
        and entry.main.temp

    return weather_id, temp
end


-- 天気データの取得
local function fetch_weather_data(config)
    -- OS別の curl コマンド設定
    local is_win   = wezterm.target_triple:find("windows")
    local curl_cmd = is_win and "curl.exe" or "curl"

    -- 都市名・国コードの取得
    local tgt_city = config.weather_city
    local tgt_code = config.weather_country

    -- 都市未指定時は IP 情報から取得
    if not tgt_city or tgt_city == "" then
        local ok, res = run_child_cmd({
            curl_cmd,
            "-s",
            "https://ipapi.co/json/",
        })

        if ok and res then
            tgt_city = res:match('"city":%s*"([^"]+)"')
            tgt_code = res:match('"country_code":%s*"([^"]+)"')
        end
    end

    -- 都市名が取得できない場合の処理
    if not tgt_city or tgt_city == "" then
        state.weather_ic       = weather_icons.unknown
        state.temp_str         = string.format("%5s", weather_icons.unknown)
        state.city_name        = weather_icons.unknown
        state.is_weather_ready = false

        return
    end

    -- クエリ文字列の作成
    local query =
        tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city

    -- APIリクエストURLの作成
    local url = string.format(
        "https://api.openweathermap.org/data/2.5/forecast"
            .. "?appid=%s&lang=%s&q=%s&units=%s",
        config.weather_api_key,
        config.weather_lang,
        query,
        config.weather_units
    )

    -- APIリクエストの実行
    local ok, stdout = run_child_cmd({ curl_cmd, "-s", url })

    -- 通信エラー時の処理
    if not ok or not stdout then
        state.weather_ic       = weather_icons.unknown
        state.temp_str         = string.format("%5s", weather_icons.unknown)
        state.city_name        = tgt_city
        state.is_weather_ready = false
        state.last_weather_upd = os.time()

        return
    end

    -- 温度単位アイコンの設定
    local unit_sym =
        config.weather_units == "metric"
        and weather_icons.celsius
        or  weather_icons.fahrenheit

    -- JSONパース
    local ok_json, data = pcall(wezterm.json_parse, stdout)

    -- JSONエラー時の処理
    if not ok_json or not data or not data.list then
        state.weather_ic       = weather_icons.unknown
        state.temp_str         = string.format("%5s", weather_icons.unknown)
        state.is_weather_ready = false
        state.last_weather_upd = os.time()

        return
    end

    -- 各時点の天気IDと温度を抽出
    local current_id, current_temp = parse_forecast(data, 1)
    local id3, temp3               = parse_forecast(data, 2)
    local id24, temp24             = parse_forecast(data, 9)

    -- 現在の天気を設定
    state.weather_ic = get_icon(current_id)
    state.temp_str =
        current_temp
        and string.format("%4.1f%s", tonumber(current_temp), unit_sym)
        or  string.format("%5s", weather_icons.unknown)

    -- 3時間後の天気を設定
    state.weather_ic_3h = get_icon(id3)
    state.temp_3h =
        temp3
        and string.format("%4.1f%s", tonumber(temp3), unit_sym)
        or  ""

    -- 24時間後の天気を設定
    state.weather_ic_24h = get_icon(id24)
    state.temp_24h =
        temp24
        and string.format("%4.1f%s", tonumber(temp24), unit_sym)
        or  ""

    -- APIレスポンスから都市名・国コード取得
    local api_name = data.city and data.city.name
    local api_code = data.city and data.city.country

    -- 状態更新
    state.city_name        = api_name or tgt_city
    state.city_code        = api_code or tgt_code or ""
    state.last_weather_upd = os.time()
    state.is_weather_ready = true
end


--- ==========================================
--- バッテリー情報取得
--- ==========================================
local function get_batt_disp()
    -- バッテリー情報の取得
    local batt_list = wezterm.battery_info()

    -- バッテリー非搭載時の処理
    if not batt_list or #batt_list == 0 then
        return "󰚥", ""
    end

    local charge = (batt_list[1].state_of_charge or 0) * 100

    -- 残量に応じたアイコン切替
    local icon =
        charge >= 90 and "󱊦" or
        charge >= 60 and "󱊥" or
        charge >= 30 and "󱊤" or
        "󰢟"

    return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
    -- フォーマット定義（1）
    local def_fmt1 =
        " $user_ic $user "
        .. "$cal_ic $year.$month.$day($week) $clock_ic $time24 "
        .. " $loc_ic $city($code) "
        .. "$weather_ic($temp) "
        .. "$batt_ic$batt_num "

    -- フォーマット定義（2）
    local def_fmt2 =
        " Now:$weather_ic($temp) "
        .. "+3h:$weather_ic_3h($temp_3h) "
        .. "+24h:$weather_ic_24h($temp_24h) "
        .. "$cpu_ic $cpu $mem_ic $mem_free "
        .. "$net_ic $net_speed($net_avg) "

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
        formats                 = (opts and opts.formats) or { def_fmt1, def_fmt2 },
    }

    -- ネットワーク設定を状態変数へ反映
    state.net_avg_samples     = config.net_avg_samples
    state.net_update_interval = config.net_update_interval

    -- 最終設定内容をログ出力
    wezterm.log_info("Final Config: " .. wezterm.to_string(config))

    -- ステータスバー更新イベント登録
    wezterm.on('update-right-status', function(window, pane)
        -- ※ この中身は前回提示コードと同一ロジックのため未変更
    end)

    -- フォーマット切替イベント登録
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

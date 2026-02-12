local M       = {}
local wezterm = require 'wezterm'


--- ==========================================
--- 外部モジュール読み込み用のパスを設定
--- ==========================================
local plugin_path =
    wezterm.plugin.list()[1].plugin_dir .. "/plugin/?.lua"
package.path = plugin_path .. ";" .. package.path


--- ==========================================
--- 外部モジュール読み込み
--- ==========================================
local get_weather   = require('modules.get_weather')
local get_sys       = require('modules.get_system_resource')
local get_net       = require('modules.get_net_speed')
local get_user      = require('modules.get_user')
local get_power     = require('modules.get_power_supply')
local alarm         = require('modules.alarm')

--- ==========================================
--- 定数
--- ==========================================
local DEFAULT_WEATHER_API_KEY =
    "Please configure your API key (https://openweathermap.org/)"
local weather_icons = {
    clear       = "󰖨 ",
    clouds      = "󰅟 ",
    rain        = " ",
    wind        = " ",
    thunder     = "󱐋 ",
    snow        = " ",
    thermometer = "",
    celsius     = "󰔄",
    fahrenheit  = "󰔅",
    unknown     = " ",
}
local loading_icon = " "


--- ==========================================
--- 各ステータス管理用変数
--- ==========================================
local state = {
    weather_ic           = loading_icon,
    city_name            = loading_icon,
    city_code            = "",
    weather_timezone_sec = 0,
    last_weather_upd     = 0,
    is_weather_ready     = false,
    temp_ic              = loading_icon,
    temp_str             = string.format("%5s", loading_icon),
    weather_ic_3h        = "",
    temp_3h              = "",
    weather_ic_6h        = "",
    temp_6h              = "",
    weather_ic_9h        = "",
    temp_9h              = "",
    weather_ic_12h       = "",
    temp_12h             = "",
    weather_nd_afty_time = "",
    weather_nd_afty_ic   = "",
    weather_nd_afty_temp = "",
    proc_start           = os.time(),
    cpu_state = {
        last_total       = 0,
        last_idle        = 0,
    },
    net_state = {
        last_rx_bytes    = 0,
        last_chk_time    = os.time(),
        disp_str         = string.format("%9s", loading_icon),
        avg_str          = string.format("%9s", loading_icon),
        samples          = {},
    },
    net_update_interval = 3,
    net_avg_samples     = 20,
    status_event_registered   = false,
    minute_timer_started      = false,
    format_index        = 1,
}


--- ==========================================
--- オプション指定の文字列を小文字に統一
--- ==========================================
local function lower_opt(v)
    if type(v) == "string" then
        return v:lower()
    end
    return v
end


--- ==========================================
--- メイン処理
--- ==========================================
function M.setup(opts)

    --- ======================================
    --- 初期化
    --- ======================================
    local def_fmt1 =
        " $user_ic $user " ..
        "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
        "$cal_ic $year.$month.$day($week) $clock_ic $time12 Alarm:$next_alarm($time_until_alarm min) " ..
        " $loc_ic $city($code) " ..
        "($weather_ic/$temp_ic$temp) " ..
        "$cpu_ic $cpu $mem_ic $mem_free " ..
        "$net_ic $net_speed($net_avg) " ..
        "$batt_ic$batt_num "
    local def_fmt2 =
        " Now:($weather_ic/$temp_ic$temp) "  ..
        "+3h:($weather_ic_3h/$temp_ic$temp_3h) " ..
        "+6h:($weather_ic_6h/$temp_ic$temp_6h) " ..
        "+9h:($weather_ic_9h/$temp_ic$temp_9h) " ..
        "+12h:($weather_ic_12h/$temp_ic$temp_12h) " ..
        "NextAfterNoon $weather_nd_afty_time:($weather_nd_afty_ic/$temp_ic$weather_nd_afty_temp) "

    -- 設定値
    local config = {
        status_position         = lower_opt((opts and opts.status_position)) or "right",
        startup_delay           = (opts and opts.startup_delay) or 5,
        weather_api_key         = opts and opts.weather_api_key or DEFAULT_WEATHER_API_KEY,
        weather_lang            = lower_opt((opts and opts.weather_lang)) or "en",
        weather_country         = lower_opt((opts and opts.weather_country)) or "",
        weather_city            = lower_opt((opts and opts.weather_city)) or "",
        weather_units           = lower_opt((opts and opts.weather_units)) or "metric",
        weather_update_interval = (opts and opts.weather_update_interval) or (10 * 60),
        weather_retry_interval  = (opts and opts.weather_retry_interval) or 30,
        net_update_interval     = (opts and opts.net_update_interval) or 3,
        net_avg_samples         = (opts and opts.net_avg_samples) or 20,
        week_str                = opts and opts.week_str,
        color_text              = (opts and opts.color_text) or       "#1A1B26",
        color_foreground        = (opts and opts.color_foreground) or "#7AA2F7",
        color_background        = (opts and opts.color_background) or "#1A1B26",
        separator               = (opts and opts.separator) or { "", "" },
        formats                 = (opts and opts.formats) or { def_fmt1, def_fmt2 },
        timer = {
            beep                = opts and opts.timer and opts.timer.beep   == true,
            flash               = opts and opts.timer and opts.timer.flash  ~= false,
            hourly              = opts and opts.timer and opts.timer.hourly == true,
            alarm1              = opts and opts.timer and opts.timer.alarm1      or "",
            alarm2              = opts and opts.timer and opts.timer.alarm2      or "",
            flash_color         = opts and opts.timer and opts.timer.flash_color or "#FFFFFF",
        },
    }
    -- DEBUG: Configの値を出力
    -- wezterm.log_info("Config: " .. wezterm.to_string(config))
    -- ステータス変数へ反映
    state.net_update_interval = config.net_update_interval
    state.net_avg_samples    = config.net_avg_samples

    --- ======================================
    --- アラーム設定反映
    --- ======================================
    -- タイマー（時報 or アラーム）が有効かどうか
    local timer_enabled =
        config.timer.hourly
        or (config.timer.alarm1 ~= "")
        or (config.timer.alarm2 ~= "")
    if timer_enabled then
        alarm.setup({
            timer = config.timer,
        })
    end

    --- ======================================
    --- イベント登録
    --- ======================================
    if state.status_event_registered then
        return
    end
    state.status_event_registered = true

    --- ======================================
    --- ステータスバー更新イベント
    --- ======================================
    wezterm.on("update-right-status", function(window, pane)
        -- タイマーが有効で、まだ毎分タイマーが開始されていない場合は開始する
        if timer_enabled and not state.minute_timer_started then
            state.minute_timer_started = true
            alarm.start(window)
        end
        -- 現在時刻取得
        local now = os.time()
        -- 起動直後待機中フラグ
        local is_waiting =
            (now - state.proc_start) < config.startup_delay
        -- 現在のフォーマット文字列取得
        local current_format =
            config.formats[state.format_index] or
            config.formats[1]
        -- フォーマット文字列の小文字版取得
        local fmt_lower = current_format:lower()
        -- 使用トークン判定
        local use_weather = fmt_lower:find("%$weather")
        local use_net     = fmt_lower:find("%$net")
        local use_sys     = fmt_lower:find("%$cpu")
                        or  fmt_lower:find("%$mem")
        local use_batt    = fmt_lower:find("%$batt")
        -- 指定された曜日文字列（ローカル）
        local week_val = ""
        if fmt_lower:find("$week") then
            if config.week_str and type(config.week_str) == "table" then
                local week_idx = tonumber(wezterm.strftime('%w'))
                week_val =
                    config.week_str[week_idx + 1]
                    or wezterm.strftime('%a')
            else
                week_val = wezterm.strftime('%a')
            end
        end
        -- 天気APIキーの有無チェック
        local has_weather_api =
            config.weather_api_key ~= nil and
            config.weather_api_key ~= "" and
            config.weather_api_key ~= DEFAULT_WEATHER_API_KEY
        -- 天気APIキーが未設定、または無効な場合は天気情報を無効化
        if not has_weather_api then
            state.weather_ic           = ""
            state.city_name            = ""
            state.city_code            = ""
            state.temp_ic              = ""
            state.temp_str             = ""
            state.weather_ic_3h        = ""
            state.temp_3h              = ""
            state.weather_ic_6h        = ""
            state.temp_6h              = ""
            state.weather_ic_9h        = ""
            state.temp_9h              = ""
            state.weather_ic_12h       = ""
            state.temp_12h             = ""
            state.weather_nd_afty_time = ""
            state.weather_nd_afty_ic   = ""
            state.weather_nd_afty_temp = ""
            state.is_weather_ready     = false
            state.weather_timezone_sec = 0
        end
        -- 天気が表示されていて、起動直後でなく、更新条件を満たす場合のみ更新
        local diff = now - state.last_weather_upd
        local need_update =
            use_weather and
            has_weather_api and
            not is_waiting and
            (
                state.last_weather_upd == 0 or
                diff > config.weather_update_interval or
                (
                    not state.is_weather_ready and
                    diff > config.weather_retry_interval
                )
            )
        if need_update then
            get_weather.get_weather(
                config,
                state,
                weather_icons
            )
        end
        -- ユーザー取得
        local user_name, user_icon = "", ""
        if fmt_lower:find("%$user") then
            user_name, user_icon = get_user.get_user(pane)
        end
        -- システムリソース取得
        local cpu_u, mem_u, mem_f = "", "", ""
        if use_sys then
            cpu_u, mem_u, mem_f =
                get_sys.get_system_resource(state)
        end
        -- ネットワーク
        local net_curr, net_avg = "", ""
        if use_net then
            net_curr, net_avg =
                get_net.get_net_speed(state)
        end
        -- バッテリー
        local batt_ic, batt_num = nil, nil
        if use_batt then
            batt_ic, batt_num =
                get_power.get_power_supply()
        end
        batt_ic  = batt_ic  or ""
        batt_num = batt_num or ""
        -- セパレータ
        local sep_left  = (config.separator and config.separator[1])
        local sep_right = (config.separator and config.separator[2])
        -- ステータスバーの左端文字列作成
        local res = {
            { Background = { Color = config.color_background } },
            { Foreground = { Color = config.color_foreground } },
            { Text       = sep_left },
            { Background = { Color = config.color_foreground } },
            { Foreground = { Color = config.color_text } },
        }
        -- 現在時刻情報テーブル（ローカル）
        local now_tm_str = {
            year     = wezterm.strftime("%Y"),
            month    = wezterm.strftime("%m"),
            day      = wezterm.strftime("%d"),
            time24   = wezterm.strftime("%H:%M"),
            time12   = wezterm.strftime("%I:%M %p"),
            hour24   = wezterm.strftime("%H"),
            hour12   = wezterm.strftime("%I"),
            minute   = wezterm.strftime("%M"),
        }
        -- 天気地点の現地時刻情報テーブル（wx）
        local wx_tm_str = {
            year   = weather_icons.unknown,
            month  = weather_icons.unknown,
            day    = weather_icons.unknown,
            time24 = weather_icons.unknown,
            time12 = weather_icons.unknown,
            hour24 = weather_icons.unknown,
            hour12 = weather_icons.unknown,
            minute = weather_icons.unknown,
        }
        local wx_week_val = weather_icons.unknown
        -- 天気情報が正常に取得できている場合のみ wx を計算
        if has_weather_api
            and state.is_weather_ready
            and state.weather_timezone_sec ~= nil then
            ---@diagnostic disable-next-line: param-type-mismatch
            local utc_param = "!*t"
            ---@diagnostic disable-next-line: param-type-mismatch
            local utc_tbl  = os.date(utc_param)
            ---@diagnostic disable-next-line: param-type-mismatch
            local now_utc  = os.time(utc_tbl)
            local wx_local_time =
                now_utc + (state.weather_timezone_sec or 0)
            wx_tm_str = {
                year   = os.date("%Y", wx_local_time),
                month  = os.date("%m", wx_local_time),
                day    = os.date("%d", wx_local_time),
                time24 = os.date("%H:%M", wx_local_time),
                time12 = os.date("%I:%M %p", wx_local_time),
                hour24 = os.date("%H", wx_local_time),
                hour12 = os.date("%I", wx_local_time),
                minute = os.date("%M", wx_local_time),
            }
            local wx_week_idx =
                tonumber(os.date("%w", wx_local_time))
            if config.week_str and type(config.week_str) == "table" then
                wx_week_val = tostring (
                    config.week_str[wx_week_idx + 1]
                    or os.date("%a", wx_local_time)
                )
                  else
                wx_week_val = tostring (
                    os.date("%a", wx_local_time)
                )
              end
        end
        -- フォーマット文字列の置換
        local replace_map = {
            ["$user_ic"]          = user_icon,
            ["$user"]             = user_name,
            ["$cal_ic"]           = "",
            ["$year"]             = now_tm_str.year,
            ["$month"]            = now_tm_str.month,
            ["$day"]              = now_tm_str.day,
            ["$week"]             = week_val,
            ["$clock_ic"]         = "",
            ["$time24"]           = now_tm_str.time24,
            ["$time12"]           = now_tm_str.time12,
            ["$hour24"]           = now_tm_str.hour24,
            ["$hour12"]           = now_tm_str.hour12,
            ["$minute"]           = now_tm_str.minute,
            ["$wx_year"]          = wx_tm_str.year,
            ["$wx_month"]         = wx_tm_str.month,
            ["$wx_day"]           = wx_tm_str.day,
            ["$wx_week"]          = wx_week_val,
            ["$wx_time24"]        = wx_tm_str.time24,
            ["$wx_time12"]        = wx_tm_str.time12,
            ["$wx_hour24"]        = wx_tm_str.hour24,
            ["$wx_hour12"]        = wx_tm_str.hour12,
            ["$wx_minute"]        = wx_tm_str.minute,
            ["$next_alarm"]       = timer_enabled and alarm.get_next_alarm() or "",
            ["$time_until_alarm"] = timer_enabled and alarm.get_minutes_until_next_alarm() or "",
            ["$loc_ic"]           = has_weather_api and "" or "",
            ["$city"]             = has_weather_api and state.city_name or "",
            ["$code"]             = has_weather_api and state.city_code or "",
            ["$weather_ic"]       = has_weather_api and state.weather_ic or "",
            ["$temp_ic"]          = has_weather_api and state.temp_ic or "",
            ["$temp"]             = has_weather_api and state.temp_str or "",
            ["$weather_ic_3h"]    = state.weather_ic_3h,
            ["$temp_3h"]          = state.temp_3h,
            ["$weather_ic_6h"]    = state.weather_ic_6h,
            ["$temp_6h"]          = state.temp_6h,
            ["$weather_ic_9h"]    = state.weather_ic_9h,
            ["$temp_9h"]          = state.temp_9h,
            ["$weather_ic_12h"]   = state.weather_ic_12h,
            ["$temp_12h"]         = state.temp_12h,
            ["$weather_nd_afty_time"] = state.weather_nd_afty_time,
            ["$weather_nd_afty_ic"]   = state.weather_nd_afty_ic,
            ["$weather_nd_afty_temp"] = state.weather_nd_afty_temp,
            ["$cpu_ic"]           = "",
            ["$cpu"]              = cpu_u,
            ["$mem_ic"]           = "",
            ["$mem_used"]         = mem_u,
            ["$mem_free"]         = mem_f,
            ["$net_ic"]           = "󰓅",
            ["$net_speed"]        = net_curr,
            ["$net_avg"]          = net_avg,
            ["$batt_ic"]          = batt_ic,
            ["$batt_num"]         = batt_num,
        }
        -- トークン置換処理
        local current_str = current_format
        while true do
            local start_idx, end_idx =
                current_str:find("%$[<>]?[%a%d_]+")
            if not start_idx then break end
            table.insert(
                res,
                { Text = current_str:sub(1, start_idx - 1) }
            )
            local token =
                current_str:sub(start_idx, end_idx):lower()
            local val = replace_map[token] or ""
            table.insert(res, { Text = val })
            current_str = current_str:sub(end_idx + 1)
        end
        table.insert(res, { Text = current_str })
        -- ステータスバーの右端文字列作成
        table.insert(
            res,
            { Background = { Color = config.color_background } }
        )
        table.insert(
            res,
            { Foreground = { Color = config.color_foreground } }
        )
        table.insert(res, { Text = sep_right })
        -- ステータスバーを指定された位置に表示
        if config.status_position == "right" then
            window:set_right_status(wezterm.format(res))
        else
            window:set_left_status(wezterm.format(res))
        end
    end)


    --- ======================================
    --- フォーマット切替イベント
    --- ======================================
    wezterm.on("toggle-status-format", function(_, _)
        state.format_index = state.format_index + 1
        if state.format_index > #config.formats then
            state.format_index = 1
        end
    end)

end


return M

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
local run_child_cmd     = require('modules.run_child_cmd')


--- ==========================================
--- forecastデータから天気ID・温度・日時を抽出
--- ==========================================
local function parse_forecast(data, index)
    -- データチェック
    if not data or not data.list then
        return nil, nil, nil
    end
    -- 指定インデックスのエントリ取得
    local entry = data.list[index]
    if not entry then
        return nil, nil, nil
    end
    -- 天気IDを抽出
    local weather_id =
            entry.weather
        and entry.weather[1]
        and entry.weather[1].id
    -- 温度を抽出
    local temp =
        entry.main
        and entry.main.temp
    -- 日時を抽出
    local dt = entry.dt
    return weather_id, temp, dt
end


--- ==========================================
--- 天気IDからアイコンを取得
--- ==========================================
local function get_icon(weather_id, icons)
    if not weather_id then
        return icons.unknown
    end
    if     weather_id <  300 then return icons.thunder
    elseif weather_id <  600 then return icons.rain
    elseif weather_id <  700 then return icons.snow
    elseif weather_id <  800 then return icons.wind
    elseif weather_id == 800 then return icons.clear
    else                          return icons.clouds end
end


--- ==========================================
--- 現在時刻を1時間単位で切り上げ
--- ==========================================
local function get_rounded_now()
    local now = os.time()
    local base = now - (now % 3600)

    if now % 3600 ~= 0 then
        base = base + 3600
    end

    return base
end


--- ==========================================
--- URLエンコード（UTF-8対応）
--- ==========================================
local function url_encode(str)
    if not str then
        return str
    end
    -- 改行コードをLFに統一
    str = str:gsub("\r\n", "\n")
    -- 英数字と安全文字以外を %XX に変換
    str = str:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end


--- ==========================================
--- 天気データ取得
--- ==========================================
function M.get_weather(config, state, weather_icons)
    -- OS別curlコマンド
    local is_win   = wezterm.target_triple:find("windows")
    local curl_cmd = is_win and "curl.exe" or "curl"
    -- 取得対象の都市名・国コード
    local tgt_city = config.weather_city
    local tgt_code = config.weather_country
    -- 都市未指定ならIP情報から取得
    if not tgt_city or tgt_city == "" then
        local ok, res = run_child_cmd.run({
            curl_cmd,
            "-s",
            "https://ipapi.co/json/",
        })
        if ok and res then
            tgt_city = res:match('"city":%s*"([^"]+)"')
            tgt_code =
                res:match('"country_code":%s*"([^"]+)"')
        end
    end
    -- 都市名が取得できない場合
    if not tgt_city or tgt_city == "" then
        state.weather_ic       = weather_icons.unknown
        state.temp_ic          = weather_icons.thermometer
        state.temp_str         =
            string.format("%5s", weather_icons.unknown)
        state.city_name        = weather_icons.unknown
        state.is_weather_ready = false
        return
    end
    -- クエリ文字列作成
    local enc_city = url_encode(tgt_city)
    local query =
        tgt_code ~= "" and
        (enc_city .. "," .. tgt_code) or
        enc_city
    -- API URL
    local url = string.format(
        "https://api.openweathermap.org/data/2.5/forecast" ..
        "?appid=%s&lang=%s&q=%s&units=%s",
        config.weather_api_key,
        config.weather_lang,
        query,
        config.weather_units
    )
    -- APIリクエスト
    local ok, stdout = run_child_cmd.run({
        curl_cmd,
        "-s",
        url
    })
    -- 通信エラー
    if not ok or not stdout then
        state.weather_ic       = weather_icons.unknown
        state.temp_ic          = weather_icons.thermometer
        state.temp_str         =
            string.format("%5s", weather_icons.unknown)
        state.city_name        = tgt_city
        state.is_weather_ready = false
        state.last_weather_upd = os.time()
        return
    end



    -- DEBUG: Configの値を出力
    wezterm.log_info("forecast stdout: " .. wezterm.to_string(stdout))



    -- JSONパース
    local ok_json, data =
        pcall(wezterm.json_parse, stdout)
        if not ok_json or not data or not data.list then
        state.weather_ic       = weather_icons.unknown
        state.temp_ic          = weather_icons.thermometer
        state.temp_str         =
            string.format("%5s", weather_icons.unknown)
        state.is_weather_ready = false
        state.last_weather_upd = os.time()
        return
    end



    -- DEBUG: Configの値を出力
    wezterm.log_info("forecast stdout: " .. wezterm.to_string(data))



    -- 温度単位
    local unit_sym =
        config.weather_units == "metric" and
        weather_icons.celsius or
        weather_icons.fahrenheit
    -- 各時点の天気・温度
    local id0, temp0 = parse_forecast(data, 1)
    local id3, temp3 = parse_forecast(data, 2)
    local id6, temp6 = parse_forecast(data, 3)
    local id9, temp9 = parse_forecast(data, 4)
    local id12, t12  = parse_forecast(data, 5)
    -- 現在
    state.weather_ic =
        get_icon(id0, weather_icons)
    state.temp_ic    = weather_icons.thermometer
    state.temp_str   =
        temp0 and
        string.format("%4.1f%s", tonumber(temp0), unit_sym) or
        string.format("%5s", weather_icons.unknown)
    -- 3h後
    state.weather_ic_3h =
        get_icon(id3, weather_icons)
    state.temp_3h =
        temp3 and
        string.format("%4.1f%s", tonumber(temp3), unit_sym) or
        ""
    -- 6h後
    state.weather_ic_6h =
        get_icon(id6, weather_icons)
    state.temp_6h =
        temp6 and
        string.format("%4.1f%s", tonumber(temp6), unit_sym) or
        ""
    -- 9h後
    state.weather_ic_9h =
        get_icon(id9, weather_icons)
    state.temp_9h =
        temp9 and
        string.format("%4.1f%s", tonumber(temp9), unit_sym) or
        ""
    -- 12h後
    state.weather_ic_12h =
        get_icon(id12, weather_icons)
    state.temp_12h =
        t12 and
        string.format("%4.1f%s", tonumber(t12), unit_sym) or
        ""
    -- 翌日12:00に近すぎる予報（現在〜5時間後）は除外する
    local now_tm = os.date("*t", os.time())
    local next_noon_tm = {
        year  = now_tm.year,
        month = now_tm.month,
        day   = now_tm.day + 1,
        hour  = 12,
        min   = 0,
        sec   = 0,
        isdst = now_tm.isdst,
    }
    -- 翌月・翌年を繰り上げ処理
    local next_noon = os.time(next_noon_tm)
    local nd_idx   = nil
    local nd_dt    = nil
    local min_diff = math.huge
    -- 現在時間から1時間切り上げた時刻を取得
    local rounded_now = get_rounded_now()
    -- 予報リストから最も近いエントリを探索
    for i, entry in ipairs(data.list) do
        if entry.dt then
            -- 現在の時間から6時間以上先の予報のみ対象
            if (entry.dt - rounded_now) >= (6 * 3600) then
                local diff = math.abs(entry.dt - next_noon)
                if diff < min_diff then
                    min_diff = diff
                    nd_idx   = i
                    nd_dt    = entry.dt
                end
            end
        end
    end
    -- 抽出結果を設定
    if nd_idx then
        -- 天気ID、温度、日時を抽出
        local nd_id, nd_temp = parse_forecast(data, nd_idx)
        state.weather_nd_afty_ic = get_icon(nd_id, weather_icons)
        state.weather_nd_afty_temp =
            nd_temp
            and string.format("%4.1f%s", tonumber(nd_temp), unit_sym)
            or ""
        -- 時間差計算
        local diff_sec    = nd_dt - rounded_now
        local diff_h      = math.floor(diff_sec / 3600)
        -- 表示用文字列を作成
        state.weather_nd_afty_time =
            string.format("+%dh", diff_h)
    else
        -- 該当データなし
        state.weather_nd_afty_ic   = weather_icons.unknown
        state.weather_nd_afty_time = ""
        state.weather_nd_afty_temp = ""
    end
    -- APIから都市名・国コード
    local api_name = data.city and data.city.name
    local api_code = data.city and data.city.country
    local disp_code = api_code or tgt_code or ""
    disp_code =
        disp_code ~= "" and
        disp_code:lower() or
        ""
    state.city_name        = api_name or tgt_city
    state.city_code        = disp_code
    state.last_weather_upd = os.time()
    state.is_weather_ready = true
end


return M

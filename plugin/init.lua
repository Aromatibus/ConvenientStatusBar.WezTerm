local wezterm = require 'wezterm'
local M       = {}


--- ==========================================
--- 定数・アイコン定義
--- ==========================================
local weather_icons = {
  clear       = "󰖨 ", -- 快晴
  clouds      = "󰅟 ", -- 曇り
  rain        = " ", -- 雨
  wind        = " ", -- 強風・霧
  thunder     = "󱐋 ", -- 雷
  snow        = " ", -- 雪
  loading     = " ", -- 取得中
  unknown     = " ", -- 不明
  thermometer = "", -- 温度計
  celsius     = "󰔄", -- 摂氏
  fahrenheit  = "󰔅", -- 華氏
}


--- ==========================================
--- 状態管理用の変数
--- ==========================================
local state = {
  weather_ic    = weather_icons.loading,
  temp_str      = string.format("%5s", weather_icons.loading),
  city_name     = weather_icons.loading,
  city_code     = "",
  last_wea_upd  = 0,
  is_wea_ready  = false,
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
--- サブ関数
--- ==========================================

-- 外部コマンドを安全に実行
local function run_child_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end


-- 数値のフォーマット化 (B/S -> KB/S, MB/S)
local function format_bps(bps)
  if bps > 1024 * 1024 then
    return string.format("%5.1fMB/S", bps / (1024 * 1024))
  elseif bps > 1024 then
    return string.format("%5.1fKB/S", bps / 1024)
  else
    return string.format("%6.1fB/S", bps)
  end
end


-- ネットワーク速度の計算
local function calc_net_speed(cfg_net, is_startup_waiting)
  if is_startup_waiting then
    return state.net_state.disp_str, state.net_state.avg_str
  end
  -- 現在時刻と前回チェック時刻の差分を計算
  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time
  -- 更新間隔に満たない場合は前回値を返す
  if time_delta < cfg_net.interval then
    return state.net_state.disp_str, state.net_state.avg_str
  end
  -- ネットワーク受信バイト数の取得
  local is_win  = wezterm.target_triple:find("windows")
  local curr_rx = 0
  -- 現在の受信バイト数を取得
  if is_win then
    local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
    curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
  else
    local cmd = "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    local ok, out = run_child_cmd({"sh", "-c", cmd})
    curr_rx = ok and tonumber(out:match("%d+")) or 0
  end
  -- 現在の速度を計算してサンプルに追加
  local bps = (curr_rx - state.net_state.last_rx_bytes) / time_delta
  table.insert(state.net_state.samples, 1, bps)
  -- サンプル数が上限を超えた場合は古いサンプルを削除
  if #state.net_state.samples > cfg_net.avg_limit then
    table.remove(state.net_state.samples)
  end
  -- サンプルの合計値を計算
  local sum_bps = 0
  for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end
  -- 平均速度の計算
  state.net_state.last_rx_bytes = curr_rx
  state.net_state.last_chk_time = curr_time
  state.net_state.disp_str      = format_bps(bps)
  state.net_state.avg_str       = format_bps(sum_bps / #state.net_state.samples)
  return state.net_state.disp_str, state.net_state.avg_str
end


-- 気象情報の取得と更新
local function fetch_wea_data(cfg_wea)
  -- curlコマンドの設定
  local is_win   = wezterm.target_triple:find("windows")
  local curl_cmd = is_win and "curl.exe" or "curl"
  -- 取得対象の都市名と国コードの設定
  local tgt_city = cfg_wea.city
  local tgt_code = cfg_wea.country
  -- Cityが設定されていない場合はIPアドレスから都市名を取得
  if not tgt_city or tgt_city == "" then
    local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
    if ok and res then
      tgt_city = res:match('"city":%s*"([^"]+)"')
      tgt_code = res:match('"country_code":%s*"([^"]+)"')
    end
  end
  -- 都市名が取得できなかった場合の処理
  if not tgt_city or tgt_city == "" then
    state.city_name    = weather_icons.unknown
    state.is_wea_ready = false
    return
  end
  -- APIリクエストURLの生成
  local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
  local url   = string.format(
    "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
    cfg_wea.api_key, cfg_wea.lang, query, cfg_wea.units
  )
  -- 天気情報の取得
  local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
  -- 通信失敗、エラーメッセージが見つかった場合の処理
  if not ok or not stdout or stdout:find('"message"') then
    state.city_name    = tgt_city
    state.city_code    = tgt_code or ""
    state.last_wea_upd = os.time()
    state.is_wea_ready = false
    return
  end
  -- 天気情報取得データを解析
  local wea_id   = tonumber(stdout:match('"id":(%d+)'))
  local temp_val = stdout:match('"temp":([%d%.%-]+)')
  local api_name = stdout:match('"name":"([^"]+)"')
  local api_code = stdout:match('"country":"([^"]+)"')
  -- 天気アイコンの設定
  if wea_id then
    if     wea_id < 300 then state.weather_ic = weather_icons.thunder
    elseif wea_id < 600 then state.weather_ic = weather_icons.rain
    elseif wea_id < 700 then state.weather_ic = weather_icons.snow
    elseif wea_id < 800 then state.weather_ic = weather_icons.wind
    elseif wea_id == 800 then state.weather_ic = weather_icons.clear
    else                     state.weather_ic = weather_icons.clouds end
  end
  -- 温度単位の設定
  local unit_sym = cfg_wea.units == "metric" and
                    weather_icons.celsius or weather_icons.fahrenheit
  -- 温度表示の設定
  state.temp_str     =  temp_val and
                        string.format("%4.1f%s", tonumber(temp_val), unit_sym) or
                        state.temp_str
  -- 都市名と国コードの設定
  state.city_name    = api_name or tgt_city
  state.city_code    = api_code or tgt_code or ""
  -- 更新時刻の記録と成功フラグの設定
  state.last_wea_upd = os.time()
  state.is_wea_ready = true
end


-- バッテリー情報の取得
local function get_batt_disp()
  local batt_list = wezterm.battery_info()
  -- バッテリー情報がない場合はコンセント接続とみなす
  if not batt_list or #batt_list == 0 then
    return "󰚥", ""
  end
  -- バッテリー情報を設定
  local batt   = batt_list[1]
  local charge = (batt.state_of_charge or 0) * 100
  local icon   =  charge >= 90 and "󱊦" or charge >= 60 and "󱊥" or
                  charge >= 30 and "󱊤" or "󰢟"
  return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
  -- 必須オプションのチェック
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  -- デフォルトのフォーマット文字列
  local def_fmt =
    " $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City($Code) $Weather_ic $Temp_ic($Temp) " ..
    "$Net_ic $Net_speed($Net_avg) $Batt_ic$Batt_num "

  -- 設定オプションの初期化
  local cfg          = {
    fmt              = opts.format or def_fmt,
    start_delay      = opts.startup_delay or 5,       -- 起動時の通信待機時間
    weather          = {
      api_key        = opts.api_key,                  -- OpenWeatherMap APIキー
      lang           = opts.lang or "en",             -- 言語コード
      country        = opts.country or "",            -- 国コード、都市名と組み合わせて使用
      city           = opts.city or "",               -- 都市名、省略された場合は自動取得
      units          = opts.units or "metric",        -- "metric(摂氏)" or "imperial(華氏)"
      interval       = opts.update_interval or 600,   -- 天気情報の更新間隔
      retry_interval = opts.retry_interval or 30,     -- 天気情報取得失敗時のリトライ間隔
    },
    net              = {
      interval       = opts.net_update_interval or 3, -- ネットワーク速度更新間隔
      avg_limit      = opts.net_avg_samples or 20     -- 平均速度のサンプル数
    },
    separator        = opts.separator or {
      left           = "",
      right          = ""
    },
    colors           = opts.colors or {
      background     = "#1a1b26",
      foreground     = "#7aa2f7",
      text           = "#ffffff"
    },
  }

  -- フォーマット文字列のを小文字化して変数を判定
  local low_fmt = cfg.fmt:lower()
  local use_weather = low_fmt:find("$city") or low_fmt:find("$code") or
                      low_fmt:find("$weather_ic") or low_fmt:find("$temp")
  local use_net = low_fmt:find("$net_speed") or low_fmt:find("$net_avg")

  -- 定期更新イベントの登録
  wezterm.on('update-right-status', function(window, _)
    local now        = os.time()
    local elapsed    = now - state.proc_start
    local is_waiting = elapsed < cfg.start_delay

    -- 起動直後の待機時間中は取得をスキップ
    if use_weather and not is_waiting then
      local diff = now - state.last_wea_upd
      local should_fetch = false

      -- 初回または通常インターバル経過時の判定
      if state.last_wea_upd == 0 or diff > cfg.weather.interval then
        should_fetch = true
      -- 通信に失敗している場合のリトライ判定
      elseif not state.is_wea_ready and diff > cfg.weather.retry_interval then
        should_fetch = true
      end
      -- 天気情報の取得・更新
      if should_fetch then
        fetch_wea_data(cfg.weather)
      end
    end

    -- ネットワーク速度の計算・取得
    local batt_ic, batt_num = get_batt_disp()
    local net_curr, net_avg = "", ""
    if use_net then net_curr, net_avg = calc_net_speed(cfg.net, is_waiting) end

    -- フォーマット文字列の変数を置換
    local replace_map = {
      cal_ic      = "",
      clock_ic    = "",
      loc_ic      = "",
      temp_ic     = weather_icons.thermometer,
      weather_ic  = state.weather_ic,
      year        = wezterm.strftime('%Y'),
      month       = wezterm.strftime('%m'),
      day         = wezterm.strftime('%d'),
      week        = wezterm.strftime('%a'),
      time24      = wezterm.strftime('%H:%M'),
      city        = state.city_name,
      code        = state.city_code,
      temp        = state.temp_str,
      net_ic      = "󰓅",
      net_speed   = net_curr,
      net_avg     = net_avg,
      batt_ic     = batt_ic,
      batt_num    = batt_num,
    }

    -- ステータス文字列の生成
    local final_status = cfg.fmt:gsub("%$([%a%d_]+)", function(key)
      return replace_map[key:lower()] or ("$" .. key)
    end)

    -- 右ステータスバーの更新
    window:set_right_status(wezterm.format({
      { Background = { Color = cfg.colors.background } },
      { Foreground = { Color = cfg.colors.foreground } },
      { Text       = cfg.separator.left },
      { Background = { Color = cfg.colors.foreground } },
      { Foreground = { Color = cfg.colors.text } },
      { Text       = final_status },
      { Background = { Color = cfg.colors.background } },
      { Foreground = { Color = cfg.colors.foreground } },
      { Text       = cfg.separator.right },
    }))
  end)
end


return M

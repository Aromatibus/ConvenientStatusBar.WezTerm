local wezterm = require 'wezterm'
local M       = {}

--- ==========================================
--- 1. 定数・アイコン定義
--- ==========================================
-- 天気状態に応じたアイコンと、単位・状態表示用のアイコン
local weather_icons = {
  clear       = "󰖨 ", -- 快晴
  clouds      = "󰅟 ", -- 曇り
  rain        = " ", -- 雨
  wind        = " ", -- 強風・霧
  thunder     = "󱐋 ", -- 雷
  snow        = " ", -- 雪
  loading     = " ", -- 通信待機中 / 取得中
  unknown     = " ", -- 都市名不明 / 取得失敗
  thermometer = "", -- 温度計アイコン
  celsius     = "󰔄", -- 摂氏単位 (Metric)
  fahrenheit  = "󰔅", -- 華氏単位 (Imperial)
}

--- ==========================================
--- 2. 状態管理（ステート）
--- ==========================================
-- WezTerm起動中、各情報の最新状態を保持するテーブル
local state = {
  icon         = weather_icons.loading,
  temp         = string.format("%5s", weather_icons.loading), -- 5文字幅で初期化
  location     = weather_icons.loading,
  country      = "",
  last_weather = 0,             -- 前回の天気更新時刻 (Unix Time)
  start_time   = os.time(),     -- 起動時のアクセス制限用
  last_net     = {
    rx   = 0,                   -- 前回の受信バイト数
    time = os.clock(),          -- 前回の計算時刻
    str  = string.format("%9s", weather_icons.loading) -- 9文字幅
  }
}

--- ==========================================
--- 3. 内部ヘルパー関数
--- ==========================================

-- 外部コマンド（curl, powershell等）を安全に実行する
local function run_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end

-- ネットワーク速度の計算とフォーマット整形
-- @return string (9文字固定: "  1.2MB/S" or " 123.4B/S")
local function get_net_speed(interval, is_waiting)
  -- 起動直後の待機時間内は通信を行わず待機アイコンを返す
  if is_waiting then
    return string.format("%9s", weather_icons.loading)
  end

  local now  = os.clock()
  local diff = now - state.last_net.time

  -- 設定された更新間隔（秒）に満たない場合は前回の文字列を再利用
  if diff < interval then
    return state.last_net.str
  end

  local is_win = wezterm.target_triple:find("windows")
  local rx     = 0

  -- OSごとに受信バイト数を取得（Windows: PowerShell / Unix: /proc/net/dev）
  if is_win then
    local _, out = run_cmd({
      "powershell.exe", "-NoProfile", "-Command",
      "(Get-NetAdapterStatistics | Measure-Object -Property ReceivedBytes -Sum).Sum"
    })
    rx = tonumber(out:match("%d+")) or 0
  else
    local _, out = run_cmd({
      "sh", "-c", "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    })
    rx = tonumber(out) or 0
  end

  -- 1秒あたりの転送量を計算し、単位を自動判別
  local rate = (rx - state.last_net.rx) / diff
  local speed_str = ""
  
  if rate > 1024 * 1024 then
    -- MB/S: 数値5.1(5文字) + 単位(4文字) = 9文字
    speed_str = string.format("%5.1fMB/S", rate / (1024 * 1024))
  elseif rate > 1024 then
    -- KB/S: 数値5.1(5文字) + 単位(4文字) = 9文字
    speed_str = string.format("%5.1fKB/S", rate / 1024)
  else
    -- B/S : 数値6.1(6文字) + 単位(3文字) = 9文字 (スペースなし指定)
    speed_str = string.format("%6.1fB/S", rate)
  end

  state.last_net = { rx = rx, time = now, str = speed_str }
  return speed_str
end

-- OpenWeatherMap APIから気象情報を取得し、stateを更新する
local function update_weather(opts)
  local is_win = wezterm.target_triple:find("windows")
  local cmd    = is_win and "curl.exe" or "curl"
  local t_city = opts.city
  local t_ctry = opts.country
  local base_curl = {cmd, "-s", "--max-time", "3"}

  -- 都市名が未指定の場合、IPアドレスから現在地を推定
  if not t_city or t_city == "" then
    local args = {base_curl[1], base_curl[2], base_curl[3], base_curl[4], "https://ipapi.co/json/"}
    local ok, res = run_cmd(args)
    if ok and res then
      t_city = res:match('"city":%s*"([^"]+)"')
      t_ctry = res:match('"country_code":%s*"([^"]+)"')
    end
  end

  -- 都市名特定不能時はエラーアイコンを表示して終了
  if not t_city or t_city == "" then
    state.location = weather_icons.unknown
    return
  end

  local loc_str = t_city
  if t_ctry and t_ctry ~= "" then
    loc_str = string.format("%s,%s", t_city, t_ctry)
  end

  -- OpenWeatherMap API 呼び出し
  local api_url = string.format(
    "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
    opts.api_key, opts.lang, loc_str, opts.units
  )

  local args = {base_curl[1], base_curl[2], base_curl[3], base_curl[4], api_url}
  local ok, stdout = run_cmd(args)

  -- 通信失敗または都市が見つからない場合のフォールバック
  if not ok or not stdout or stdout:find('"message":"city not found"') then
    state.location     = t_city
    state.country      = t_ctry or ""
    state.last_weather = os.time()
    return
  end

  -- JSONレスポンスから必要な情報を抽出
  local id    = tonumber(stdout:match('"id":(%d+)'))
  local t_val = stdout:match('"temp":([%d%.%-]+)')
  local name  = stdout:match('"name":"([^"]+)"')
  local ctry  = stdout:match('"country":"([^"]+)"')

  -- 天気IDに基づきアイコンを決定
  if id then
    if id < 300      then state.icon = weather_icons.thunder
    elseif id < 600  then state.icon = weather_icons.rain
    elseif id < 700  then state.icon = weather_icons.snow
    elseif id < 800  then state.icon = weather_icons.wind
    elseif id == 800 then state.icon = weather_icons.clear
    else                  state.icon = weather_icons.clouds end
  end

  -- 温度を右寄せスペース埋めで整形 (数値4.1(4文字) + 単位(1文字) = 5文字固定)
  local sym = opts.units == "metric" and weather_icons.celsius or weather_icons.fahrenheit
  if t_val then
    state.temp = string.format("%4.1f%s", tonumber(t_val), sym)
  end

  state.location     = name or t_city
  state.country      = ctry or t_ctry or ""
  state.last_weather = os.time()
end

-- バッテリーの状態とアイコンを取得
local function get_battery_info()
  local batt = wezterm.battery_info()
  if #batt == 0 then return "󰚥", "" end
  local b  = batt[1]
  local p  = b.state_of_charge * 100
  local ic = p >= 90 and "󱊦" or p >= 60 and "󱊥" or p >= 30 and "󱊤" or "󰢟"
  return ic, string.format("%.0f%%", p)
end

--- ==========================================
--- 4. メインセットアップ関数 (公開API)
--- ==========================================
function M.setup(opts)
  -- 必須パラメータチェック
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  -- ステータスバーのデフォルトレイアウト
  local default_format =
    " $CalIc $Year.$Month.$Day $Week $ClockIc $Time24 " ..
    "$LocIc $City($Country) $WeatherIc $TempIc($Temp) " ..
    "$NetIc $NetSpeed $BattIc$BattNum "

  -- 設定の初期化
  local config = {
    api_key       = opts.api_key,
    lang          = opts.lang or "en",
    country       = opts.country or "",
    city          = opts.city or "",
    units         = opts.units or "metric",
    weather_int   = opts.update_interval or 600,
    net_int       = opts.net_update_interval or 1,
    startup_delay = opts.startup_delay or 5, -- 起動直後のアクセス制限（秒）
    format        = opts.format or default_format,
    colors        = opts.colors or {
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  -- 通信節約：フォーマット文字列を解析し、不必要な通信を無効化するフラグ
  local lower_fmt = config.format:lower()
  local has_weather = lower_fmt:find("$city") or lower_fmt:find("$country") or lower_fmt:find("$weatheric") or lower_fmt:find("$temp")
  local has_net     = lower_fmt:find("$netspeed")

  -- WezTermのステータス更新イベントをフック
  wezterm.on('update-right-status', function(window, _)
    -- 起動時の待機判定
    local elapsed    = os.time() - state.start_time
    local is_waiting = elapsed < config.startup_delay

    -- [安全性] 天気情報の更新が必要な場合のみ、かつ待機解除後に実行
    if has_weather then
      local should_update = false
      if not is_waiting then
        if state.last_weather == 0 then
          should_update = true -- 待機明け初回
        elseif (os.time() - state.last_weather) > config.weather_int then
          should_update = true -- 更新間隔経過
        end
      end

      if should_update then
        update_weather(config)
      end
    end

    -- バッテリー情報の取得（ローカルAPIのため常に実行）
    local b_ic, b_num = get_battery_info()
    
    -- [安全性] ネットワーク速度が必要な場合のみ取得
    local net_speed = ""
    if has_net then
      net_speed = get_net_speed(config.net_int, is_waiting)
    end

    -- 各種プレースホルダーの置換用テーブル
    local repstr = {
      calic      = "",
      clockic    = "",
      locic      = "",
      tempic     = weather_icons.thermometer,
      weatheric  = state.icon,
      year       = wezterm.strftime('%Y'),
      month      = wezterm.strftime('%m'),
      day        = wezterm.strftime('%d'),
      week       = wezterm.strftime('%a'),
      time24     = wezterm.strftime('%H:%M'),
      city       = state.location,
      country    = state.country,
      temp       = state.temp,
      netic      = "󰓅",
      netspeed   = net_speed,
      battic     = b_ic,
      battnum    = b_num,
    }

    -- フォーマット文字列内の $キーワード を実データに置換
    local status = config.format:gsub("%$([%a%d_]+)", function(k)
      local nk = k:lower():gsub("_", "")
      return repstr[nk] or ("$" .. k)
    end)

    -- ステータスバーの描画（WezTerm形式）
    window:set_right_status(wezterm.format({
      { Background = { Color = config.colors.background } },
      { Foreground = { Color = config.colors.foreground } },
      { Text       = "" },
      { Background = { Color = config.colors.foreground } },
      { Foreground = { Color = config.colors.text } },
      { Text       = status },
      { Background = { Color = config.colors.background } },
      { Foreground = { Color = config.colors.foreground } },
      { Text       = "" },
    }))
  end)
end

return M

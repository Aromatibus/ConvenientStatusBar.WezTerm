local wezterm = require 'wezterm'
local M = {}


-- 天気表示および温度単位用のアイコン定義
local weather_icons = {
  sunny      = "󰖨",
  cloudy     = "󰅟",
  rainy      = "",
  windy      = "",
  lightning  = "󱐋",
  snowy      = "",
  standby    = "",
  not_found  = "",
  celsius    = "󰔄",
  fahrenheit = "󰔅",
}


-- 天気情報の状態を保持する内部キャッシュ
local weather_state = {
  icon = weather_icons.standby,
  temp = string.format("--.-%s", weather_icons.celsius),
  location = "",
  last_update = 0
}


-- 外部コマンドを安全に実行し、エラーログを管理する共通関数
local function run_cmd(args)
  local success, stdout, stderr = wezterm.run_child_process(args)

  if not success then
    wezterm.log_error("ConvenientStatusBar: cmd failed: " ..
      table.concat(args, " "))
    if stderr then wezterm.log_error("Stderr: " .. stderr) end
  end

  return success, stdout
end


-- OpenWeatherMapからデータを取得し、内部状態を更新する
local function update_weather(opts)
  local is_win = wezterm.target_triple:find("windows")
  local cmd = is_win and "curl.exe" or "curl"

  -- curlコマンドの利用可能性チェック
  if not run_cmd({cmd, "--version"}) then
    weather_state.location = "no-curl"
    return
  end

  local target_city = opts.city
  local target_country = opts.country

  -- 都市名が未指定ならIPアドレスから現在地を取得
  if target_city == "" then
    local ok, res = run_cmd({cmd, "-s", "https://ipapi.co/json/"})
    target_city = ok and res:match('"city":%s*"([^"]+)"') or nil

    if not target_city then
      weather_state.location = weather_icons.not_found
      return
    end

    target_country = ""
  end

  -- 位置情報文字列の構成
  local loc_str = target_city
  if target_country ~= "" then
    loc_str = string.format("%s,%s", target_city, target_country)
  end

  -- APIリクエストURLの生成
  local base = "https://api.openweathermap.org/data/2.5/weather"
  local url = string.format("%s?appid=%s&lang=%s&q=%s&units=%s",
    base, opts.api_key, opts.lang, loc_str, opts.units)

  -- 天気データの取得実行
  local ok, stdout = run_cmd({cmd, "-s", url})

  if not ok or stdout:find('"message":"city not found"') then
    weather_state.location = weather_icons.not_found
    weather_state.last_update = os.time()
    return
  end

  -- JSONレスポンスから必要な値を抽出
  local id = tonumber(stdout:match('"id":(%d+)'))
  local temp = stdout:match('"temp":([%d%.%-]+)')
  local name = stdout:match('"name":"([^"]+)"')

  -- 天候IDに応じたアイコンの選択
  if id then
    if id < 300 then weather_state.icon = weather_icons.lightning
    elseif id < 600 then weather_state.icon = weather_icons.rainy
    elseif id < 700 then weather_state.icon = weather_icons.snowy
    elseif id < 800 then weather_state.icon = weather_icons.windy
    elseif id == 800 then weather_state.icon = weather_icons.sunny
    else weather_state.icon = weather_icons.cloudy end
  end

  -- 単位アイコンの決定と気温文字列の整形
  local sym = opts.units == "metric" and
    weather_icons.celsius or weather_icons.fahrenheit

  if temp then
    weather_state.temp = string.format("%.1f%s", tonumber(temp), sym)
  end

  weather_state.location = name or target_city
  weather_state.last_update = os.time()
end


-- システムのバッテリー残量と状態アイコンを取得
local function get_battery_info()
  local batt = wezterm.battery_info()

  if #batt == 0 then return " 󰟀" end

  local b = batt[1]
  local p = b.state_of_charge * 100
  local icon = p >= 90 and "󱊦" or p >= 60 and "󱊥" or p >= 30 and "󱊤" or "󰢟"

  return string.format(" %s %.0f%%", icon, p)
end


-- ユーザー設定を反映し、右ステータスバーの描画イベントを登録
function M.setup(opts)
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  -- 設定値の正規化と配色デフォルト値の適用
  local config = {
    api_key = opts.api_key,
    lang = opts.lang or "en",
    country = opts.country or "",
    city = opts.city or "",
    units = opts.units or "metric",
    update_interval = opts.update_interval or 600,
    colors = opts.colors or {
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  -- 描画更新のハンドリング
  wezterm.on('update-right-status', function(window, _)
    local elapsed = os.time() - weather_state.last_update

    -- 更新間隔を超えていれば非同期で情報を更新
    if elapsed > config.update_interval then
      update_weather(config)
    end

    -- フォーマットされた日付・時間の取得
    local date = wezterm.strftime('%Y.%m.%d')
    local time = wezterm.strftime('%H:%M')
    local week = wezterm.strftime('%a')

    -- 表示テキストの組み立て
    local status = string.format("  %s(%s)  %s  %s %s (%s ) %s ",
      date, week, time, weather_state.location,
      weather_state.icon, weather_state.temp, get_battery_info())

    -- 配色とデザインを適用してステータスバーへセット
    window:set_right_status(wezterm.format({
      { Background = { Color = config.colors.background } },
      { Foreground = { Color = config.colors.foreground } },
      { Text = "" },
      { Background = { Color = config.colors.foreground } },
      { Foreground = { Color = config.colors.text } },
      { Text = status },
      { Background = { Color = config.colors.background } },
      { Foreground = { Color = config.colors.foreground } },
      { Text = "" },
    }))
  end)
end


return M

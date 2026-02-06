local wezterm = require 'wezterm'
local M = {}


-- 天気・温度・単位などのアイコン定義
local weather_icons = {
  sunny      = "󰖨 ",
  cloudy     = "󰅟 ",
  rainy      = " ",
  windy      = " ",
  lightning  = "󱐋 ",
  snowy      = " ",
  standby    = " ",
  not_found  = " ",
  temp       = " ",
  celsius    = "󰔄",
  fahrenheit = "󰔅",
}


-- 天気情報を保持する内部キャッシュ
local weather_state = {
  icon = weather_icons.standby,
  temp = string.format("--.-%s", weather_icons.celsius),
  location = "",
  last_update = 0
}


-- 外部コマンド実行用の共通関数
local function run_cmd(args)
  local success, stdout, stderr = wezterm.run_child_process(args)

  if not success then
    wezterm.log_error("ConvenientStatusBar: cmd failed: " ..
      table.concat(args, " "))
    if stderr then wezterm.log_error("Stderr: " .. stderr) end
  end

  return success, stdout
end


-- OpenWeatherMapからデータを取得・更新
local function update_weather(opts)
  local is_win = wezterm.target_triple:find("windows")
  local cmd = is_win and "curl.exe" or "curl"

  if not run_cmd({cmd, "--version"}) then
    weather_state.location = "no-curl"
    return
  end

  local target_city = opts.city
  local target_country = opts.country

  -- 都市名未指定時はIPから取得
  if target_city == "" then
    local ok, res = run_cmd({cmd, "-s", "https://ipapi.co/json/"})
    target_city = ok and res:match('"city":%s*"([^"]+)"') or nil

    if not target_city then
      weather_state.location = weather_icons.not_found
      return
    end
    target_country = ""
  end

  local loc_str = target_city
  if target_country ~= "" then
    loc_str = string.format("%s,%s", target_city, target_country)
  end

  -- APIリクエストの実行
  local base = "https://api.openweathermap.org/data/2.5/weather"
  local url = string.format("%s?appid=%s&lang=%s&q=%s&units=%s",
    base, opts.api_key, opts.lang, loc_str, opts.units)

  local ok, stdout = run_cmd({cmd, "-s", url})

  if not ok or stdout:find('"message":"city not found"') then
    weather_state.location = weather_icons.not_found
    weather_state.last_update = os.time()
    return
  end

  -- JSONから値を抽出
  local id = tonumber(stdout:match('"id":(%d+)'))
  local temp = stdout:match('"temp":([%d%.%-]+)')
  local name = stdout:match('"name":"([^"]+)"')

  -- 天候IDで「天気アイコン」を選択
  if id then
    if id < 300 then weather_state.icon = weather_icons.lightning
    elseif id < 600 then weather_state.icon = weather_icons.rainy
    elseif id < 700 then weather_state.icon = weather_icons.snowy
    elseif id < 800 then weather_state.icon = weather_icons.windy
    elseif id == 800 then weather_state.icon = weather_icons.sunny
    else weather_state.icon = weather_icons.cloudy end
  end

  -- 単位と気温の整形
  local sym = opts.units == "metric" and
    weather_icons.celsius or weather_icons.fahrenheit

  if temp then
    weather_state.temp = string.format("%.1f%s", tonumber(temp), sym)
  end

  weather_state.location = name or target_city
  weather_state.last_update = os.time()
end


-- バッテリー情報の取得
local function get_battery_info()
  local batt = wezterm.battery_info()

  if #batt == 0 then return " 󰟀" end

  local b = batt[1]
  local p = b.state_of_charge * 100
  local icon = p >= 90 and "󱊦" or p >= 60 and "󱊥" or
               p >= 30 and "󱊤" or "󰢟"

  return string.format("%s %.0f%%", icon, p)
end


-- プラグインのメインセットアップ
function M.setup(opts)
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  -- 設定値の初期化
  local config = {
    api_key = opts.api_key,
    lang = opts.lang or "en",
    country = opts.country or "",
    city = opts.city or "",
    units = opts.units or "metric",
    update_interval = opts.update_interval or 600,
    format = opts.format or
      " $cal $date ($week) $clock $time $loc_icon $location $weather $temp_icon $temp $batt ",
    colors = opts.colors or {
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  -- ステータス更新イベント
  wezterm.on('update-right-status', function(window, _)
    local elapsed = os.time() - weather_state.last_update

    if elapsed > config.update_interval then
      update_weather(config)
    end

    -- 置換用変数のマッピング
    local vals = {
      cal       = "",
      clock     = "",
      loc_icon  = "",
      temp_icon = weather_icons.temp,
      weather   = weather_state.icon,
      date      = wezterm.strftime('%Y.%m.%d'),
      year      = wezterm.strftime('%Y'),
      month     = wezterm.strftime('%m'),
      day       = wezterm.strftime('%d'),
      week      = wezterm.strftime('%a'),
      time      = wezterm.strftime('%H:%M'),
      hour      = wezterm.strftime('%H'),
      min       = wezterm.strftime('%M'),
      location  = weather_state.location,
      temp      = weather_state.temp,
      batt      = get_battery_info(),
    }

    -- 置換処理: 長いキーワードから順に処理するようにソート
    local keys = {}
    for k in pairs(vals) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return #a > #b end)

    local status = config.format
    for _, k in ipairs(keys) do
      -- 確実にエスケープして置換
      status = status:gsub("%$" .. k, vals[k])
    end

    -- バーの描画
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

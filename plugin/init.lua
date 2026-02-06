local wezterm = require 'wezterm'
local M = {}


-- 使用するアイコンの定義
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


-- 天気データのキャッシュ
local weather_state = {
  icon = weather_icons.standby,
  temp = string.format("--.-%s", weather_icons.celsius),
  location = "",
  country = "",
  last_update = 0
}


-- 外部コマンドを実行
local function run_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end


-- 天気情報と現在地の取得・更新
local function update_weather(opts)
  local is_win = wezterm.target_triple:find("windows")
  local cmd = is_win and "curl.exe" or "curl"
  local target_city = opts.city
  local target_country = opts.country

  -- 都市未指定ならIPから位置情報を取得
  if target_city == "" then
    local ok, res = run_cmd({cmd, "-s", "https://ipapi.co/json/"})
    if ok then
      target_city = res:match('"city":%s*"([^"]+)"')
      target_country = res:match('"country_code":%s*"([^"]+)"')
    end
    if not target_city then
      weather_state.location = weather_icons.not_found
      return
    end
  end

  -- リクエストURLの作成
  local loc_str = target_city
  if target_country and target_country ~= "" then
    loc_str = string.format("%s,%s", target_city, target_country)
  end
  local base = "https://api.openweathermap.org/data/2.5/weather"
  local url = string.format("%s?appid=%s&lang=%s&q=%s&units=%s",
    base, opts.api_key, opts.lang, loc_str, opts.units)

  -- APIデータの取得と解析
  local ok, stdout = run_cmd({cmd, "-s", url})
  if not ok or stdout:find('"message":"city not found"') then
    weather_state.location = weather_icons.not_found
    weather_state.last_update = os.time()
    return
  end

  local id = tonumber(stdout:match('"id":(%d+)'))
  local temp = stdout:match('"temp":([%d%.%-]+)')
  local name = stdout:match('"name":"([^"]+)"')
  local country = stdout:match('"country":"([^"]+)"')

  -- 天候に応じたアイコン選択
  if id then
    if id < 300 then weather_state.icon = weather_icons.lightning
    elseif id < 600 then weather_state.icon = weather_icons.rainy
    elseif id < 700 then weather_state.icon = weather_icons.snowy
    elseif id < 800 then weather_state.icon = weather_icons.windy
    elseif id == 800 then weather_state.icon = weather_icons.sunny
    else weather_state.icon = weather_icons.cloudy end
  end

  -- 気温と場所をキャッシュに保存
  local sym = opts.units == "metric" and
    weather_icons.celsius or weather_icons.fahrenheit
  if temp then
    weather_state.temp = string.format("%.1f%s", tonumber(temp), sym)
  end
  weather_state.location = name or target_city
  weather_state.country = country or target_country or ""
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


-- プラグインのセットアップ
function M.setup(opts)
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  -- 設定の初期化
  local config = {
    api_key = opts.api_key,
    lang = opts.lang or "en",
    country = opts.country or "",
    city = opts.city or "",
    units = opts.units or "metric",
    update_interval = opts.update_interval or 600,
    format = opts.format or
      " $cal_ic $year.$month.$day $clock_ic $time_24 $weather_ic $temp $batt ",
    colors = opts.colors or {
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  -- 右ステータスの描画イベント
  wezterm.on('update-right-status', function(window, _)
    local elapsed = os.time() - weather_state.last_update
    if elapsed > config.update_interval then
      update_weather(config)
    end

    -- 置換用変数の定義（アイコン名に_icを付与）
    local vals = {
      cal_ic     = "",
      clock_ic   = "",
      loc_ic     = "",
      temp_ic    = weather_icons.temp,
      weather_ic = weather_state.icon,
      year       = wezterm.strftime('%Y'),
      year_short = wezterm.strftime('%y'),
      month      = wezterm.strftime('%m'),
      day        = wezterm.strftime('%d'),
      week       = wezterm.strftime('%a'),
      time_24    = wezterm.strftime('%H:%M'),
      time_12    = wezterm.strftime('%I:%M %p'),
      hour_24    = wezterm.strftime('%H'),
      hour_12    = wezterm.strftime('%I'),
      min        = wezterm.strftime('%M'),
      location   = weather_state.location,
      country    = weather_state.country,
      temp       = weather_state.temp,
      batt       = get_battery_info(),
    }

    -- キーを長い順にソートして置換ミスを防止
    local keys = {}
    for k in pairs(vals) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return #a > #b end)

    local status = config.format
    for _, k in ipairs(keys) do
      status = status:gsub("%$" .. k, vals[k])
    end

    -- バーの作成
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

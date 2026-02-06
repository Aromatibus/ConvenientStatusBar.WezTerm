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


-- 天気データの保持用キャッシュ
local weather_state = {
  icon = weather_icons.standby,
  temp = string.format("--.-%s", weather_icons.celsius),
  location = "",
  last_update = 0
}


-- 外部コマンドを実行して結果を取得
local function run_cmd(args)
  local success, stdout, stderr = wezterm.run_child_process(args)

  if not success then
    wezterm.log_error("ConvenientStatusBar: cmd failed: " ..
      table.concat(args, " "))
  end

  return success, stdout
end


-- 天気情報を取得してキャッシュを更新
local function update_weather(opts)
  local is_win = wezterm.target_triple:find("windows")
  local cmd = is_win and "curl.exe" or "curl"

  local target_city = opts.city
  local target_country = opts.country

  -- 都市名未指定ならIPアドレスから現在地を取得
  if target_city == "" then
    local ok, res = run_cmd({cmd, "-s", "https://ipapi.co/json/"})
    if ok then
      target_city = res:match('"city":%s*"([^"]+)"')
      target_country = res:match('"country":%s*"([^"]+)"')
    end

    if not target_city then
      weather_state.location = weather_icons.not_found
      return
    end
  end

  -- 取得した都市と国でリクエストURLを作成
  local loc_str = target_city
  if target_country and target_country ~= "" then
    loc_str = string.format("%s,%s", target_city, target_country)
  end

  local base = "https://api.openweathermap.org/data/2.5/weather"
  local url = string.format("%s?appid=%s&lang=%s&q=%s&units=%s",
    base, opts.api_key, opts.lang, loc_str, opts.units)

  -- APIから天気データを取得
  local ok, stdout = run_cmd({cmd, "-s", url})
  if not ok or stdout:find('"message":"city not found"') then
    weather_state.location = weather_icons.not_found
    weather_state.last_update = os.time()
    return
  end

  -- JSONから必要な情報を抜き出し
  local id = tonumber(stdout:match('"id":(%d+)'))
  local temp = stdout:match('"temp":([%d%.%-]+)')
  local name = stdout:match('"name":"([^"]+)"')

  -- 天候IDに合わせてアイコンを決定
  if id then
    if id < 300 then weather_state.icon = weather_icons.lightning
    elseif id < 600 then weather_state.icon = weather_icons.rainy
    elseif id < 700 then weather_state.icon = weather_icons.snowy
    elseif id < 800 then weather_state.icon = weather_icons.windy
    elseif id == 800 then weather_state.icon = weather_icons.sunny
    else weather_state.icon = weather_icons.cloudy end
  end

  -- 気温と単位を整形
  local sym = opts.units == "metric" and
    weather_icons.celsius or weather_icons.fahrenheit

  if temp then
    weather_state.temp = string.format("%.1f%s", tonumber(temp), sym)
  end

  weather_state.location = name or target_city
  weather_state.last_update = os.time()
end


-- バッテリーの残量と状態を取得
local function get_battery_info()
  local batt = wezterm.battery_info()
  if #batt == 0 then return " 󰟀" end

  local b = batt[1]
  local p = b.state_of_charge * 100
  local icon = p >= 90 and "󱊦" or p >= 60 and "󱊥" or
               p >= 30 and "󱊤" or "󰢟"

  return string.format("%s %.0f%%", icon, p)
end


-- プラグインの初期設定とイベント登録
function M.setup(opts)
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  -- オプションの読み込みとデフォルト値の適用
  local config = {
    api_key = opts.api_key,         -- OpenWeatherMapのAPIキー
    lang = opts.lang or "en",       -- 表示言語
    country = opts.country or "",   -- 国名コード
    city = opts.city or "",         -- 都市名
    units = opts.units or "metric", -- 単位(metric/imperial)
    update_interval = opts.update_interval or 600, -- 更新間隔
    format = opts.format or         -- 表示フォーマット
      " $cal $date ($week) $clock $time $loc_icon $location $weather $temp_icon $temp $batt ",
    colors = opts.colors or {       -- バーの色設定
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  -- ステータスバー更新のタイミングで実行
  wezterm.on('update-right-status', function(window, _)
    local elapsed = os.time() - weather_state.last_update
    if elapsed > config.update_interval then
      update_weather(config)
    end

    -- フォーマットで使用する変数の定義
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

    -- 変数名の長い順にソート（置換ミス防止）
    local keys = {}
    for k in pairs(vals) do table.insert(keys, k) end
    table.sort(keys, function(a, b) return #a > #b end)

    -- フォーマット内のキーワードを実際の値に置換
    local status = config.format
    for _, k in ipairs(keys) do
      status = status:gsub("%$" .. k, vals[k])
    end

    -- デザインを整えてバーに表示
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

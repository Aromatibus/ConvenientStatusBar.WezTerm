local wezterm = require 'wezterm'
local M       = {}

-- 天気情報用のアイコン定義
local weather_icons = {
  clear       = "󰖨 ",
  clouds      = "󰅟 ",
  rain        = " ",
  wind        = " ",
  thunder     = "󱐋 ",
  snow        = " ",
  loading     = " ",
  unknown     = " ",
  thermometer = "",
  celsius     = "󰔄",
  fahrenheit  = "󰔅",
}

-- 状態管理
local state = {
  icon         = weather_icons.loading,
  temp         = weather_icons.loading,
  location     = weather_icons.loading,
  country      = "",
  last_weather = 0,
  start_time   = os.time(), -- 起動時刻を記録
  last_net     = {
    rx   = 0,
    time = os.clock(),
    str  = string.format("%9s", weather_icons.loading) -- 9文字幅
  }
}

-- 外部コマンド実行
local function run_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end

-- ネットワーク速度計算
local function get_net_speed(interval, is_waiting)
  -- 起動待機中なら待機アイコンを返す
  if is_waiting then
    return string.format("%9s", weather_icons.loading)
  end

  local now  = os.clock()
  local diff = now - state.last_net.time

  if diff < interval then
    return state.last_net.str
  end

  local is_win = wezterm.target_triple:find("windows")
  local rx     = 0

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

  local rate = (rx - state.last_net.rx) / diff
  local unit = "B /S"
  if rate > 1024 * 1024 then rate, unit = rate / (1024 * 1024), "MB/S"
  elseif rate > 1024   then rate, unit = rate / 1024, "KB/S" end

  -- フォーマット: %5.1f (数値5桁) + 単位4桁 = 合計9文字固定
  local speed_str = string.format("%5.1f%s", rate, unit)
  state.last_net  = { rx = rx, time = now, str = speed_str }

  return speed_str
end

-- 天気情報更新
local function update_weather(opts)
  local is_win = wezterm.target_triple:find("windows")
  local cmd    = is_win and "curl.exe" or "curl"
  local t_city = opts.city
  local t_ctry = opts.country
  local base_curl = {cmd, "-s", "--max-time", "3"}

  if not t_city or t_city == "" then
    local args = {base_curl[1], base_curl[2], base_curl[3], base_curl[4], "https://ipapi.co/json/"}
    local ok, res = run_cmd(args)
    if ok and res then
      t_city = res:match('"city":%s*"([^"]+)"')
      t_ctry = res:match('"country_code":%s*"([^"]+)"')
    end
  end

  if not t_city or t_city == "" then
    state.location = weather_icons.unknown
    return
  end

  local loc_str = t_city
  if t_ctry and t_ctry ~= "" then
    loc_str = string.format("%s,%s", t_city, t_ctry)
  end

  local api_url = string.format(
    "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
    opts.api_key, opts.lang, loc_str, opts.units
  )

  local args = {base_curl[1], base_curl[2], base_curl[3], base_curl[4], api_url}
  local ok, stdout = run_cmd(args)

  if not ok or not stdout or stdout:find('"message":"city not found"') then
    state.location     = t_city
    state.country      = t_ctry or ""
    state.last_weather = os.time()
    return
  end

  local id    = tonumber(stdout:match('"id":(%d+)'))
  local t_val = stdout:match('"temp":([%d%.%-]+)')
  local name  = stdout:match('"name":"([^"]+)"')
  local ctry  = stdout:match('"country":"([^"]+)"')

  if id then
    if id < 300      then state.icon = weather_icons.thunder
    elseif id < 600  then state.icon = weather_icons.rain
    elseif id < 700  then state.icon = weather_icons.snow
    elseif id < 800  then state.icon = weather_icons.wind
    elseif id == 800 then state.icon = weather_icons.clear
    else                  state.icon = weather_icons.clouds end
  end

  local sym = opts.units == "metric" and weather_icons.celsius or weather_icons.fahrenheit
  if t_val then
    state.temp = string.format("%04.1f%s", tonumber(t_val), sym)
  end

  state.location     = name or t_city
  state.country      = ctry or t_ctry or ""
  state.last_weather = os.time()
end

-- バッテリー取得
local function get_battery_info()
  local batt = wezterm.battery_info()
  if #batt == 0 then return "󰚥", "" end
  local b  = batt[1]
  local p  = b.state_of_charge * 100
  local ic = p >= 90 and "󱊦" or p >= 60 and "󱊥" or p >= 30 and "󱊤" or "󰢟"
  return ic, string.format("%.0f%%", p)
end

-- セットアップ
function M.setup(opts)
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  local default_format =
    " $CalIc $Year.$Month.$Day $Week $ClockIc $Time24 " ..
    "$LocIc $City($Country) $WeatherIc $TempIc($Temp) " ..
    "$NetIc $NetSpeed $BattIc$BattNum "

  local config = {
    api_key       = opts.api_key,
    lang          = opts.lang or "en",
    country       = opts.country or "",
    city          = opts.city or "",
    units         = opts.units or "metric",
    weather_int   = opts.update_interval or 600,
    net_int       = opts.net_update_interval or 1,
    startup_delay = opts.startup_delay or 10, -- 起動待機秒数
    format        = opts.format or default_format,
    colors        = opts.colors or {
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  wezterm.on('update-right-status', function(window, _)
    local elapsed    = os.time() - state.start_time
    local is_waiting = elapsed < config.startup_delay

    -- 待機終了後の初回更新用
    if not is_waiting and state.last_weather == 0 then
      state.last_weather = os.time()
    end

    -- 待機中でなければ天気更新チェック
    if not is_waiting and (os.time() - state.last_weather) > config.weather_int then
      update_weather(config)
    end

    local b_ic, b_num = get_battery_info()
    local net_speed   = get_net_speed(config.net_int, is_waiting)

    local repstr = {
      calic      = "",
      clockic    = "",
      locic      = "",
      tempic     = weather_icons.thermometer,
      weatheric  = state.icon,
      year       = wezterm.strftime('%Y'),
      yearshort  = wezterm.strftime('%y'),
      month      = wezterm.strftime('%m'),
      day        = wezterm.strftime('%d'),
      week       = wezterm.strftime('%a'),
      weekfull   = wezterm.strftime('%A'),
      time24     = wezterm.strftime('%H:%M'),
      time12     = wezterm.strftime('%I:%M %p'),
      hour24     = wezterm.strftime('%H'),
      hour12     = wezterm.strftime('%I'),
      min        = wezterm.strftime('%M'),
      city       = state.location,
      country    = state.country,
      temp       = state.temp,
      netic      = "󰓅",
      netspeed   = net_speed,
      battic     = b_ic,
      battnum    = b_num,
    }

    local status = config.format:gsub("%$([%a%d_]+)", function(k)
      local nk = k:lower():gsub("_", "")
      return repstr[nk] or ("$" .. k)
    end)

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

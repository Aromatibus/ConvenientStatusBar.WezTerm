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
--- 起動時の状態管理
--- ==========================================
local state = {
  weather_ic    = weather_icons.loading,
  temp_str      = string.format("%5s", weather_icons.loading),
  city_name     = weather_icons.loading,
  city_code     = "",
  last_wea_upd  = 0,
  proc_start    = os.time(),
  net_state     = {
    last_rx_bytes = 0,
    last_chk_time = os.clock(),
    disp_str      = string.format("%9s", weather_icons.loading)
  }
}


--- ==========================================
--- 内部ヘルパー関数
--- ==========================================

-- 外部コマンドを安全に実行
local function run_child_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)

  return success, stdout
end


-- ネットワーク速度の計算と整形
local function calc_net_speed(interval, is_startup_waiting)
  if is_startup_waiting then
    return string.format("%9s", weather_icons.loading)
  end

  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time

  if time_delta < interval then
    return state.net_state.disp_str
  end

  local is_win  = wezterm.target_triple:find("windows")
  local curr_rx = 0

  if is_win then
    local cmd = "(Get-NetAdapterStatistics | " ..
                "Measure-Object -Property ReceivedBytes -Sum).Sum"
    local _, out = run_child_cmd({"powershell.exe", "-NoProfile",
                                  "-Command", cmd})
    curr_rx = tonumber(out:match("%d+")) or 0
  else
    local sh_cmd = "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    local _, out = run_child_cmd({"sh", "-c", sh_cmd})
    curr_rx = tonumber(out) or 0
  end

  local bps       = (curr_rx - state.net_state.last_rx_bytes) / time_delta
  local fmt_speed = ""

  if bps > 1024 * 1024 then
    fmt_speed = string.format("%5.1fMB/S", bps / (1024 * 1024))
  elseif bps > 1024 then
    fmt_speed = string.format("%5.1fKB/S", bps / 1024)
  else
    fmt_speed = string.format("%6.1fB/S", bps)
  end

  state.net_state = {
    last_rx_bytes = curr_rx,
    last_chk_time = curr_time,
    disp_str      = fmt_speed
  }

  return fmt_speed
end


-- 気象情報の取得と更新
local function fetch_wea_data(cfg_opts)
  local is_win    = wezterm.target_triple:find("windows")
  local curl_cmd  = is_win and "curl.exe" or "curl"
  local tgt_city  = cfg_opts.city
  local tgt_code  = cfg_opts.country
  local base_args = {curl_cmd, "-s", "--max-time", "3"}

  -- 都市未指定時はIPベースで取得
  if not tgt_city or tgt_city == "" then
    local url = "https://ipapi.co/json/"
    local ok, res = run_child_cmd({base_args[1], base_args[2],
                                    base_args[3], base_args[4], url})
    if ok and res then
      tgt_city = res:match('"city":%s*"([^"]+)"')
      tgt_code = res:match('"country_code":%s*"([^"]+)"')
    end
  end

  if not tgt_city or tgt_city == "" then
    state.city_name = weather_icons.unknown
    return
  end

  local loc_query = tgt_city
  if tgt_code and tgt_code ~= "" then
    loc_query = string.format("%s,%s", tgt_city, tgt_code)
  end

  local api_base = "https://api.openweathermap.org/data/2.5/weather"
  local api_url  = string.format(
    "%s?appid=%s&lang=%s&q=%s&units=%s",
    api_base, cfg_opts.api_key, cfg_opts.lang, loc_query, cfg_opts.units
  )

  local ok, stdout = run_child_cmd({base_args[1], base_args[2],
                                    base_args[3], base_args[4], api_url})

  if not ok or not stdout or stdout:find('"message":"city not found"') then
    state.city_name    = tgt_city
    state.city_code    = tgt_code or ""
    state.last_wea_upd = os.time()
    return
  end

  local wea_id   = tonumber(stdout:match('"id":(%d+)'))
  local temp_val = stdout:match('"temp":([%d%.%-]+)')
  local api_name = stdout:match('"name":"([^"]+)"')
  local api_code = stdout:match('"country":"([^"]+)"')

  if wea_id then
    if     wea_id < 300 then state.weather_ic = weather_icons.thunder
    elseif wea_id < 600 then state.weather_ic = weather_icons.rain
    elseif wea_id < 700 then state.weather_ic = weather_icons.snow
    elseif wea_id < 800 then state.weather_ic = weather_icons.wind
    elseif wea_id == 800 then state.weather_ic = weather_icons.clear
    else                     state.weather_ic = weather_icons.clouds end
  end

  local unit_sym = cfg_opts.units == "metric" and
                    weather_icons.celsius or weather_icons.fahrenheit

  if temp_val then
    state.temp_str = string.format("%4.1f%s", tonumber(temp_val), unit_sym)
  end

  state.city_name    = api_name or tgt_city
  state.city_code    = api_code or tgt_code or ""
  state.last_wea_upd = os.time()
end


-- バッテリー情報の取得
local function get_batt_disp()
  local batt_list = wezterm.battery_info()

  if not batt_list or #batt_list == 0 then
    return "󰚥", ""
  end

  local batt   = batt_list[1]
  local charge = (batt.state_of_charge or 0) * 100
  local icon   = charge >= 90 and "󱊦" or charge >= 60 and "󱊥" or
                  charge >= 30 and "󱊤" or "󰢟"

  return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メインセットアップ関数
--- ==========================================
function M.setup(opts)
  if not opts or not opts.api_key then
    wezterm.log_error("ConvenientStatusBar: 'api_key' is required")
    return
  end

  local def_fmt =
    " $Cal_ic $Year.$Month.$Day $Week $Clock_ic $Time24 " ..
    "$Loc_ic $City($Code) $Weather_ic $Temp_ic($Temp) " ..
    "$Net_ic $Net_speed $Batt_ic$Batt_num "

  local cfg = {
    api_key     = opts.api_key,
    lang        = opts.lang or "en",
    country     = opts.country or "",
    city        = opts.city or "",
    units       = opts.units or "metric",
    wea_int     = opts.update_interval or 600,
    net_int     = opts.net_update_interval or 1,
    start_delay = opts.startup_delay or 5,
    fmt         = opts.format or def_fmt,
    colors      = opts.colors or {
      background = "#1a1b26",
      foreground = "#7aa2f7",
      text       = "#ffffff"
    }
  }

  local low_fmt     = cfg.fmt:lower()
  local use_weather = low_fmt:find("$city") or low_fmt:find("$code") or
                      low_fmt:find("$weather_ic") or low_fmt:find("$temp")
  local use_net     = low_fmt:find("$net_speed")

  wezterm.on('update-right-status', function(window, _)
    local time_elapsed = os.time() - state.proc_start
    local is_waiting   = time_elapsed < cfg.start_delay

    if use_weather then
      local should_fetch = false
      if not is_waiting then
        if state.last_wea_upd == 0 then
          should_fetch = true
        elseif (os.time() - state.last_wea_upd) > cfg.wea_int then
          should_fetch = true
        end
      end

      if should_fetch then
        fetch_wea_data(cfg)
      end
    end

    local batt_icon, batt_num_text = get_batt_disp()
    local net_speed_text = ""

    if use_net then
      net_speed_text = calc_net_speed(cfg.net_int, is_waiting)
    end

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
      net_speed   = net_speed_text,
      batt_ic     = batt_icon,
      batt_num    = batt_num_text,
    }

    local final_status = cfg.fmt:gsub("%$([%a%d_]+)", function(key)
      local norm_key = key:lower()
      return replace_map[norm_key] or ("$" .. key)
    end)

    window:set_right_status(wezterm.format({
      { Background = { Color = cfg.colors.background } },
      { Foreground = { Color = cfg.colors.foreground } },
      { Text       = "" },
      { Background = { Color = cfg.colors.foreground } },
      { Foreground = { Color = cfg.colors.text } },
      { Text       = final_status },
      { Background = { Color = cfg.colors.background } },
      { Foreground = { Color = cfg.colors.foreground } },
      { Text       = "" },
    }))
  end)
end


return M

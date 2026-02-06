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
--- 状態管理（ステート）
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
    disp_str      = string.format("%9s", weather_icons.loading),
    avg_str       = string.format("%9s", weather_icons.loading),
    samples       = {}, -- 過去の速度記録
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


-- ネットワーク速度の計算（平均化処理を含む）
local function calc_net_speed(cfg_net, is_startup_waiting)
  if is_startup_waiting then
    return state.net_state.disp_str, state.net_state.avg_str
  end

  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time

  if time_delta < cfg_net.int then
    return state.net_state.disp_str, state.net_state.avg_str
  end

  local is_win  = wezterm.target_triple:find("windows")
  local curr_rx = 0

  if is_win then
    local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
    curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
  else
    local cmd = "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    local ok, out = run_child_cmd({"sh", "-c", cmd})
    curr_rx = ok and tonumber(out:match("%d+")) or 0
  end

  local bps = (curr_rx - state.net_state.last_rx_bytes) / time_delta
  table.insert(state.net_state.samples, 1, bps)

  if #state.net_state.samples > cfg_net.avg_limit then
    table.remove(state.net_state.samples)
  end

  local sum_bps = 0
  for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end

  state.net_state.last_rx_bytes = curr_rx
  state.net_state.last_chk_time = curr_time
  state.net_state.disp_str      = format_bps(bps)
  state.net_state.avg_str       = format_bps(sum_bps / #state.net_state.samples)

  return state.net_state.disp_str, state.net_state.avg_str
end


-- 気象情報の取得と更新
local function fetch_wea_data(cfg_opts)
  local is_win   = wezterm.target_triple:find("windows")
  local curl_cmd = is_win and "curl.exe" or "curl"
  local tgt_city = cfg_opts.city
  local tgt_code = cfg_opts.country

  if not tgt_city or tgt_city == "" then
    local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
    if ok and res then
      tgt_city = res:match('"city":%s*"([^"]+)"')
      tgt_code = res:match('"country_code":%s*"([^"]+)"')
    end
  end

  if not tgt_city or tgt_city == "" then
    state.city_name = weather_icons.unknown
    return
  end

  local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
  local url   = string.format(
    "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
    cfg_opts.api_key, cfg_opts.lang, query, cfg_opts.units
  )

  local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
  if not ok or not stdout or stdout:find('"message":"city not found"') then
    state.city_name, state.city_code = tgt_city, tgt_code or ""
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

  state.temp_str     = temp_val and
                        string.format("%4.1f%s", tonumber(temp_val), unit_sym) or
                        state.temp_str
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
    " $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City($Code) $Weather_ic $Temp_ic($Temp) " ..
    "$Net_ic $Net_speed($Net_avg) $Batt_ic$Batt_num "

  local cfg = {
    api_key     = opts.api_key,
    lang        = opts.lang or "en",
    country     = opts.country or "",
    city        = opts.city or "",
    units       = opts.units or "metric",
    wea_int     = opts.update_interval or 600, -- 天気情報の更新間隔（秒）
    start_delay = opts.startup_delay or 5, -- 起動後の通信待機時間（秒）
    fmt         = opts.format or def_fmt,
    net         = {
      int       = opts.net_update_interval or 2, -- 更新間隔（秒）
      avg_limit = opts.net_avg_samples or 10, -- サンプル数
    },
    colors      = opts.colors or {
      text       = "#ffffff",
      foreground = "#7aa2f7",
      background = "#1a1b26",
    },
    separator   = opts.separator or {
      left  = "",
      right = "",
    },
  }

  local low_fmt = cfg.fmt:lower()
  local use_weather = low_fmt:find("$city") or low_fmt:find("$code") or
                      low_fmt:find("$weather_ic") or low_fmt:find("$temp")
  local use_net = low_fmt:find("$net_speed") or low_fmt:find("$net_avg")

  wezterm.on('update-right-status', function(window, _)
    local elapsed    = os.time() - state.proc_start
    local is_waiting = elapsed < cfg.start_delay

    if use_weather and not is_waiting then
      local now = os.time()
      if state.last_wea_upd == 0 or (now - state.last_wea_upd) > cfg.wea_int then
        fetch_wea_data(cfg)
      end
    end

    local batt_ic, batt_num = get_batt_disp()
    local net_curr, net_avg = "", ""
    if use_net then net_curr, net_avg = calc_net_speed(cfg.net, is_waiting) end

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

    local final_status = cfg.fmt:gsub("%$([%a%d_]+)", function(key)
      return replace_map[key:lower()] or ("$" .. key)
    end)

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

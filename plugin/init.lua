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
  thermometer = "", -- 温度計
  celsius     = "󰔄", -- 摂氏
  fahrenheit  = "󰔅", -- 華氏
  loading     = " ", -- 取得中
  unknown     = " ", -- 不明
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


-- 数値のフォーマット化 (B/S, KB/S, MB/S)
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
local function calc_net_speed(config, is_startup_waiting)
  if is_startup_waiting then
    return state.net_state.disp_str, state.net_state.avg_str
  end
  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time
  if time_delta < config.net_update_interval then
    return state.net_state.disp_str, state.net_state.avg_str
  end
  local is_win  = wezterm.target_triple:find("windows")
  local curr_rx = 0
  if is_win then
    local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
    curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
  else
    local ok, out = run_child_cmd({"sh", "-c", "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"})
    curr_rx = ok and tonumber(out:match("%d+")) or 0
  end
  local bps = (curr_rx - state.net_state.last_rx_bytes) / time_delta
  table.insert(state.net_state.samples, 1, bps)
  if #state.net_state.samples > config.net_avg_samples then
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


-- システムリソース（CPU/メモリ）の取得
local function get_sys_resources()
  local is_win = wezterm.target_triple:find("windows")
  local cpu_val, mem_u_val, mem_f_val = 0, 0, 0
  
  if is_win then
    local ok, out = run_child_cmd({"powershell.exe", "-NoProfile", "-Command", "Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average; (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"})
    if ok and out then
      local lines = {}
      for line in out:gmatch("[^\r\n]+") do table.insert(lines, line) end
      cpu_val = tonumber(lines[1]) or 0
      local f_kb = tonumber(lines[2]) or 0
      local t_kb = tonumber(lines[3]) or 0
      mem_f_val = f_kb / 1024 / 1024
      mem_u_val = (t_kb - f_kb) / 1024 / 1024
    end
  else
    local ok, out = run_child_cmd({"sh", "-c", "free -b | awk '/^Mem:/ {print $3, $4, $2}'"})
    if ok and out then
      local u, f, t = out:match("(%d+)%s+(%d+)%s+(%d+)")
      mem_u_val = (tonumber(u) or 0) / 1024^3
      mem_f_val = (tonumber(f) or 0) / 1024^3
    end
  end
  return string.format("%2d%%", cpu_val), string.format("%4.1fGB", mem_u_val), string.format("%4.1fGB", mem_f_val)
end


-- SSH接続情報の取得
local function get_ssh_info(pane)
  if not pane then return "" end
  local domain = pane:get_domain_name()
  if domain:find("SSH") then
    local uri = pane:get_current_working_dir()
    if uri then
      local user = uri.username or os.getenv("USER") or "user"
      return "󰢩 " .. user .. "@" .. (uri.host or domain) .. " "
    end
  end
  return ""
end


-- 気象情報の取得と更新
local function fetch_wea_data(config)
  local is_win   = wezterm.target_triple:find("windows")
  local curl_cmd = is_win and "curl.exe" or "curl"
  local tgt_city = config.weather_city
  local tgt_code = config.weather_country
  if not tgt_city or tgt_city == "" then
    local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
    if ok and res then
      tgt_city = res:match('"city":%s*"([^"]+)"')
      tgt_code = res:match('"country_code":%s*"([^"]+)"')
    end
  end
  if not tgt_city or tgt_city == "" then
    state.weather_ic   = weather_icons.unknown
    state.city_name    = weather_icons.unknown
    state.is_wea_ready = false
    return
  end
  local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
  local url   = string.format("https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s", config.weather_api_key, config.weather_lang, query, config.weather_units)
  local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
  if not ok or not stdout or stdout:find('"message"') then
    state.weather_ic   = weather_icons.unknown
    state.temp_str     = string.format("%5s", weather_icons.unknown)
    state.city_name    = tgt_city
    state.city_code    = tgt_code or ""
    state.last_wea_upd = os.time()
    state.is_wea_ready = false
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
  local unit_sym = config.weather_units == "metric" and weather_icons.celsius or weather_icons.fahrenheit
  state.temp_str     = temp_val and string.format("%4.1f%s", tonumber(temp_val), unit_sym) or state.temp_str
  state.city_name    = api_name or tgt_city
  state.city_code    = api_code or tgt_code or ""
  state.last_wea_upd = os.time()
  state.is_wea_ready = true
end


-- バッテリー情報の取得
local function get_batt_disp()
  local batt_list = wezterm.battery_info()
  if not batt_list or #batt_list == 0 then return "󰚥", "" end
  local batt   = batt_list[1]
  local charge = (batt.state_of_charge or 0) * 100
  local icon   =  charge >= 90 and "󱊦" or charge >= 60 and "󱊥" or charge >= 30 and "󱊤" or "󰢟"
  return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
  local def_fmt = " $SSH$Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 $Loc_ic $City($Code) $Weather_ic $Temp $CPU_ic $CPU $MEM_ic $MEM_USED $MEM_FREE $Net_ic $Net_speed($Net_avg) $Batt_ic$Batt_num "

  local config              = {
    startup_delay           = (opts and opts.startup_delay) or 5,
    weather_api_key         = opts and opts.weather_api_key,
    weather_lang            = (opts and opts.weather_lang) or "en",
    weather_country         = (opts and opts.weather_country) or "",
    weather_city            = (opts and opts.weather_city) or "",
    weather_units           = (opts and opts.weather_units) or "metric",
    weather_update_interval = (opts and opts.weather_update_interval) or 600,
    weather_retry_interval  = (opts and opts.weather_retry_interval) or 30,
    net_update_interval     = (opts and opts.net_update_interval) or 3,
    net_avg_samples         = (opts and opts.net_avg_samples) or 10,
    separator_left          = (opts and opts.separator_left) or "",
    separator_right         = (opts and opts.separator_right) or "",
    color_text              = (opts and opts.color_text) or "#ffffff",
    color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",
    color_background        = (opts and opts.color_background) or "#1a1b26",
    format                  = (opts and opts.format) or def_fmt,
  }

  wezterm.on('update-right-status', function(window, pane)
    local now        = os.time()
    local is_waiting = (now - state.proc_start) < config.startup_delay

    if config.weather_api_key and config.weather_api_key ~= "" and not is_waiting then
      local diff = now - state.last_wea_upd
      if state.last_wea_upd == 0 or diff > config.weather_update_interval or (not state.is_wea_ready and diff > config.weather_retry_interval) then
        fetch_wea_data(config)
      end
    end

    local net_curr, net_avg = calc_net_speed(config, is_waiting)
    local cpu_u, mem_u, mem_f = get_sys_resources()
    local ssh_str = get_ssh_info(pane)
    local batt_ic, batt_num = get_batt_disp()

    local res = {
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = config.separator_left },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
    }

    local replace_map = {
      ["$ssh"] = ssh_str, ["$cal_ic"] = "", ["$year"] = wezterm.strftime('%Y'),
      ["$month"] = wezterm.strftime('%m'), ["$day"] = wezterm.strftime('%d'),
      ["$week"] = wezterm.strftime('%a'), ["$clock_ic"] = "", ["$time24"] = wezterm.strftime('%H:%M'),
      ["$loc_ic"] = "", ["$city"] = state.city_name, ["$code"] = state.city_code,
      ["$weather_ic"] = state.weather_ic, ["$temp"] = state.temp_str, ["$cpu_ic"] = "",
      ["$cpu"] = cpu_u, ["$mem_ic"] = "", ["$mem_used"] = mem_u, ["$mem_free"] = mem_f,
      ["$net_ic"] = "󰓅", ["$net_speed"] = net_curr, ["$net_avg"] = net_avg,
      ["$batt_ic"] = batt_ic, ["$batt_num"] = batt_num,
    }

    -- フォーマットに従って解析
    local current_str = config.format
    while true do
      local start_idx, end_idx = current_str:find("%$[%a%d_]+")
      if not start_idx then break end
      
      -- トークン前のテキスト追加
      table.insert(res, { Text = current_str:sub(1, start_idx - 1) })
      
      local token = current_str:sub(start_idx, end_idx):lower()
      local val = replace_map[token] or token

      -- フリーメモリのアイコン(MEM_IC)かつ、すぐ後にMEM_FREEがある場合のみ色変更
      if token == "$mem_ic" and current_str:find("$mem_free", end_idx, true) then
          table.insert(res, { Foreground = { Color = config.color_background } })
          table.insert(res, { Text = val })
          table.insert(res, { Foreground = { Color = config.color_text } })
      else
          table.insert(res, { Text = val })
      end
      
      current_str = current_str:sub(end_idx + 1)
    end
    table.insert(res, { Text = current_str })

    -- 右端セパレータの追加 (エラー箇所を修正)
    table.insert(res, { Background = { Color = config.color_background } })
    table.insert(res, { Foreground = { Color = config.color_foreground } })
    table.insert(res, { Text       = config.separator_right })

    window:set_right_status(wezterm.format(res))
  end)
end

return M

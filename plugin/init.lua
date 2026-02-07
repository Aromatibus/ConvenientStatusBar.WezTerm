local wezterm = require 'wezterm'
local M       = {}

--- ==========================================
--- 定数・アイコン定義 (weather_icons)
--- ==========================================
local weather_icons = {
  clear       = "󰖨 ", clouds = "󰅟 ", rain = " ", 
  wind        = " ", thunder = "󱐋 ", snow = " ",
  thermometer = "", celsius = "󰔄", fahrenheit = "󰔅",
  loading     = " ", unknown = " ",
}

--- ==========================================
--- 状態管理
--- ==========================================
local state = {
  weather_ic    = weather_icons.loading,
  temp_str      = " --.-",
  city_name     = "Loading...",
  city_code     = "---",
  last_wea_upd  = 0,
  proc_start    = os.time(),
  net_state     = {
    last_rx_bytes = 0,
    last_chk_time = os.clock(),
    disp_str      = "  0.0B/S",
    avg_str       = "  0.0B/S",
    samples       = {}
  }
}

--- ==========================================
--- サブ関数
--- ==========================================

local function run_child_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end

local function format_bps(bps)
  if bps > 1024 * 1024 then return string.format("%5.1fMB/S", bps / (1024 * 1024))
  elseif bps > 1024 then return string.format("%5.1fKB/S", bps / 1024)
  else return string.format("%6.1fB/S", bps) end
end

local function calc_net_speed(config, is_waiting)
  if is_waiting then return state.net_state.disp_str, state.net_state.avg_str end
  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time
  if time_delta < config.net.interval then return state.net_state.disp_str, state.net_state.avg_str end
  
  local is_win = wezterm.target_triple:find("windows")
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
  if #state.net_state.samples > config.net.avg_limit then table.remove(state.net_state.samples) end
  
  local sum_bps = 0
  for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end
  state.net_state.last_rx_bytes = curr_rx
  state.net_state.last_chk_time = curr_time
  state.net_state.disp_str = format_bps(bps)
  state.net_state.avg_str  = format_bps(sum_bps / #state.net_state.samples)
  return state.net_state.disp_str, state.net_state.avg_str
end

local function get_sys_resources()
  local is_win = wezterm.target_triple:find("windows")
  local cpu_val, mem_free_val, mem_total_val = 0, 0, 0
  if is_win then
    local ok_c, out_c = run_child_cmd({"powershell.exe", "-NoProfile", "-Command", "Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average"})
    if ok_c then cpu_val = tonumber(out_c:match("[%d%.]+")) or 0 end
    local ok_mf, out_mf = run_child_cmd({"powershell.exe", "-NoProfile", "-Command", "(Get-WmiObject Win32_OperatingSystem).FreePhysicalMemory / 1024 / 1024"})
    local ok_mt, out_mt = run_child_cmd({"powershell.exe", "-NoProfile", "-Command", "(Get-WmiObject Win32_OperatingSystem).TotalVisibleMemorySize / 1024 / 1024"})
    mem_free_val = ok_mf and tonumber(out_mf:match("[%d%.]+")) or 0
    mem_total_val = ok_mt and tonumber(out_mt:match("[%d%.]+")) or 0
  else
    local ok_c, out_c = run_child_cmd({"sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' || top -l 1 | grep 'CPU usage' | awk '{print $3}'"})
    if ok_c then cpu_val = tonumber(out_c:match("[%d%.]+")) or 0 end
    local ok_m, out_m = run_child_cmd({"sh", "-c", "free -b | awk '/^Mem:/ {print $4, $2}'"})
    if ok_m then
      local f, t = out_m:match("(%d+)%s+(%d+)")
      mem_free_val = (tonumber(f) or 0) / 1024^3
      mem_total_val = (tonumber(t) or 0) / 1024^3
    end
  end
  local mem_used_val = math.max(0, mem_total_val - mem_free_val)
  return string.format("%2d%%", cpu_val), string.format("%6.1fGB", mem_used_val), string.format("%6.1fGB", mem_free_val)
end

local function get_battery_info()
  local b_ic, b_num = "󰂄", "100%"
  for _, b in ipairs(wezterm.battery_info()) do
    b_num = string.format("%.0f%%", b.state_of_charge * 100)
    if b.state == 'Charging' then b_ic = "󰂄"
    elseif b.state_of_charge < 0.2 then b_ic = "󰂃"
    else b_ic = "󰁹" end
  end
  return b_ic, b_num
end

local function fetch_wea_data(config)
  local is_win = wezterm.target_triple:find("windows")
  local curl = is_win and "curl.exe" or "curl"
  local city = config.weather.city
  if city == "" then
    local ok, res = run_child_cmd({curl, "-s", "https://ipapi.co/json/"})
    city = (ok and res) and res:match('"city":%s*"([^"]+)"') or "Tokyo"
  end
  local url = string.format("https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s", config.weather.api_key, config.weather.lang, city, config.weather.units)
  local ok, stdout = run_child_cmd({curl, "-s", url})
  if ok and stdout and not stdout:find('"message"') then
    local wea_id = tonumber(stdout:match('"id":(%d+)'))
    local temp_val = stdout:match('"temp":([%d%.%-]+)')
    if wea_id then
      if wea_id < 300 then state.weather_ic = weather_icons.thunder
      elseif wea_id < 600 then state.weather_ic = weather_icons.rain
      elseif wea_id < 700 then state.weather_ic = weather_icons.snow
      elseif wea_id < 800 then state.weather_ic = weather_icons.wind
      elseif wea_id == 800 then state.weather_ic = weather_icons.clear
      else state.weather_ic = weather_icons.clouds end
    end
    state.temp_str = temp_val and string.format("%4.1f", tonumber(temp_val)) or state.temp_str
    state.city_name = stdout:match('"name":"([^"]+)"') or city
    state.city_code = stdout:match('"country":"([^"]+)"') or "---"
    state.last_wea_upd = os.time()
  end
end

--- ==========================================
--- メイン関数
--- ==========================================
function M.setup(opts)
  -- 以前の設定構造を適用
  local config = {
    fmt         = (opts and opts.fmt) or "$Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 $Loc_ic $City($Code) $Weather_ic $Temp_ic($Temp) $Net_ic $Net_speed($Net_avg) $Batt_ic$Batt_num ",
    start_delay = (opts and opts.start_delay) or 5,
    weather = {
      api_key  = (opts and opts.weather and opts.weather.api_key) or "",
      lang     = (opts and opts.weather and opts.weather.lang) or "en",
      city     = (opts and opts.weather and opts.weather.city) or "",
      units    = (opts and opts.weather and opts.weather.units) or "metric",
      interval = (opts and opts.weather and opts.weather.interval) or 600,
    },
    net = {
      interval  = (opts and opts.net and opts.net.interval) or 3,
      avg_limit = (opts and opts.net and opts.net.avg_limit) or 20, -- 保存情報に基づき20に設定
    },
    separator = (opts and opts.separator) or {
      left  = "",
      right = ""
    },
    colors = (opts and opts.colors) or {
      text       = "#ffffff",
      foreground = "#7aa2f7",
      background = "#1a1b26"
    }
  }

  wezterm.on('update-right-status', function(window, pane)
    local now = os.time()
    local is_waiting = (now - state.proc_start) < config.start_delay

    if config.weather.api_key ~= "" and not is_waiting and (now - state.last_wea_upd > config.weather.interval) then
      fetch_wea_data(config)
    end

    local net_curr, net_avg = calc_net_speed(config, is_waiting)
    local cpu_u, mem_u, mem_f = get_sys_resources()
    local batt_ic, batt_num = get_battery_info()

    -- 置換マップ (以前のフォーマット変数に対応)
    local replace_map = {
      cal_ic      = "", clock_ic = "", loc_ic = "", net_ic = "󰓅",
      cpu_ic      = "", mem_ic = "", temp_ic = "",
      year        = wezterm.strftime('%Y'), month = wezterm.strftime('%m'),
      day         = wezterm.strftime('%d'), week = wezterm.strftime('%a'),
      time24      = wezterm.strftime('%H:%M'), 
      city        = state.city_name, code = state.city_code,
      weather_ic  = state.weather_ic, temp = state.temp_str,
      cpu         = cpu_u, mem_used = mem_u, mem_free = mem_f,
      net_speed   = net_curr, net_avg = net_avg,
      batt_ic     = batt_ic, batt_num = batt_num,
    }

    -- 変数置換
    local final_str = config.fmt:gsub("%$([%a%d_]+)", function(key)
      local val = replace_map[key:lower()]
      return val ~= nil and tostring(val) or ("$" .. key)
    end)

    -- 描画テーブル
    local render = {
      { Background = { Color = config.colors.background } },
      { Foreground = { Color = config.colors.foreground } },
      { Text = config.separator.left },
      { Background = { Color = config.colors.foreground } },
      { Foreground = { Color = config.colors.text } },
    }

    -- フリーメモリのアイコン色だけを変更
    -- 文字列中の「」を探し、そこだけ色指定を挿入する
    local first_idx = final_str:find("")
    local second_idx = nil
    if first_idx then
      second_idx = final_str:find("", first_idx + 1)
    end

    local target_idx = second_idx or first_idx

    if target_idx then
      table.insert(render, { Text = final_str:sub(1, target_idx - 1) })
      table.insert(render, { Foreground = { Color = config.colors.background } }) -- アイコンを背景色に変更
      table.insert(render, { Text = "" })
      table.insert(render, { Foreground = { Color = config.colors.text } })       -- 文字色に戻す
      table.insert(render, { Text = final_str:sub(target_idx + 1) })
    else
      table.insert(render, { Text = final_str })
    end

    table.insert(render, { Background = { Color = config.colors.background } })
    table.insert(render, { Foreground = { Color = config.colors.foreground } })
    table.insert(render, { Text = config.separator.right })

    window:set_right_status(wezterm.format(render))
  end)
end

return M

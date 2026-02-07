local wezterm = require 'wezterm'
local M       = {}

--- ==========================================
--- 定数・アイコン定義
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
  if time_delta < config.net_update_interval then return state.net_state.disp_str, state.net_state.avg_str end
  
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
  if #state.net_state.samples > config.net_avg_samples then table.remove(state.net_state.samples) end
  
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

local function get_ssh_info(pane)
  if not pane then return "" end
  local process_name = pane:get_foreground_process_name() or ""
  local domain = pane:get_domain_name()
  if process_name:find("ssh") or domain:find("SSH") then
    local uri = pane:get_current_working_dir()
    if uri then
      local user = uri.username or os.getenv("USER") or "user"
      return "󰢩 " .. user .. "@" .. (uri.host or domain)
    end
  end
  return ""
end

local function fetch_wea_data(config)
  local is_win = wezterm.target_triple:find("windows")
  local curl = is_win and "curl.exe" or "curl"
  local city = config.weather_city
  if city == "" then
    local ok, res = run_child_cmd({curl, "-s", "https://ipapi.co/json/"})
    city = (ok and res) and res:match('"city":%s*"([^"]+)"') or "Tokyo"
  end
  local url = string.format("https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s", config.weather_api_key, config.weather_lang, city, config.weather_units)
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
    state.temp_str = temp_val and string.format("%4.1f%s", tonumber(temp_val), (config.weather_units == "metric" and "°C" or "°F")) or state.temp_str
    state.city_name = stdout:match('"name":"([^"]+)"') or city
    state.last_wea_upd = os.time()
  end
end

--- ==========================================
--- メイン関数
--- ==========================================
function M.setup(opts)
  local config = {
    startup_delay           = (opts and opts.startup_delay) or 5,
    weather_api_key         = opts and opts.weather_api_key,
    weather_lang            = (opts and opts.weather_lang) or "ja",
    weather_city            = (opts and opts.weather_city) or "",
    weather_units           = (opts and opts.weather_units) or "metric",
    weather_update_interval = 600,
    net_update_interval     = 3,
    net_avg_samples         = 10,
    color_text              = (opts and opts.color_text) or "#ffffff",
    color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",
    color_background        = (opts and opts.color_background) or "#1a1b26",
  }

  wezterm.on('update-right-status', function(window, pane)
    local now = os.time()
    local is_waiting = (now - state.proc_start) < config.startup_delay

    if config.weather_api_key and not is_waiting and (now - state.last_wea_upd > config.weather_update_interval) then
      fetch_wea_data(config)
    end

    local net_curr, net_avg = calc_net_speed(config, is_waiting)
    local cpu_usage, mem_used, mem_free = get_sys_resources()
    local ssh_str = get_ssh_info(pane)

    -- 描画テーブルの組み立て
    local render = {
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text = "" },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
    }

    -- パーツ追加
    local function add(t) table.insert(render, { Text = " " .. t }) end
    
    if ssh_str ~= "" then add(ssh_str) end
    add(" " .. wezterm.strftime('%Y.%m.%d(%a)'))
    add(" " .. wezterm.strftime('%H:%M'))
    add(" " .. state.city_name .. " " .. state.weather_ic .. state.temp_str)
    add(" " .. cpu_usage)
    add(" " .. mem_used)

    --- フリーメモリのアイコンのみテキスト色変更
    table.insert(render, { Foreground = { Color = config.color_background } })
    table.insert(render, { Text = "  " })
    table.insert(render, { Foreground = { Color = config.color_text } })
    table.insert(render, { Text = mem_free })

    add("󰓅 " .. net_curr .. "(" .. net_avg .. ") ")

    -- 閉じ（エラー修正箇所）
    table.insert(render, { Background = { Color = config.color_background } })
    table.insert(render, { Foreground = { Color = config.color_foreground } })
    table.insert(render, { Text = "" })

    window:set_right_status(wezterm.format(render))
  end)
end

return M

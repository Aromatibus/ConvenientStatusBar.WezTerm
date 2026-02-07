local wezterm = require 'wezterm'
local module = {}

--- ==========================================
--- 静的定数の定義
--- ==========================================

-- ギガバイト換算用
local GIGABYTE = 1024 ^ 3

-- メガバイト換算用
local MEGABYTE = 1024 * 1024

-- キロバイト換算用
local KILOBYTE = 1024

-- 天気予報用アイコン
local WEATHER_ICONS = {
  clear   = "󰖨 ",
  clouds  = "󰅟 ",
  rain    = " ",
  wind    = " ",
  thunder = "󱐋 ",
  snow    = " ",
  unknown = " ",
  loading = " ",
}

-- システム状態用アイコン
local SYSTEM_ICONS = {
  user_local  = " ",
  user_ssh    = "󰀑 ",
  calendar    = " ",
  clock       = " ",
  location    = " ",
  cpu         = " ",
  memory_used = " ",
  memory_free = " ",
  network     = "󰓅 ",
  battery     = { "󰢟 ", "󱊤 ", "󱊥 ", "󱊦 " },
}

--- ==========================================
--- 状態管理 (実行時の動的データ)
--- ==========================================

local state = {
  weather = {
    icon = WEATHER_ICONS.loading,
    temp = " -- ",
    city = "Loading...",
    last_update = 0,
  },
  network = {
    last_bytes = 0,
    last_time = os.clock(),
    current_str = "0B/S",
    average_str = "0B/S",
    samples = {},
  },
  start_time = os.time(),
}

--- ==========================================
--- 内部ロジック関数
--- ==========================================

-- 外部プロセスを安全に実行し標準出力を取得する
local function safe_run(args)

  local success, stdout, stderr = wezterm.run_child_process(args)

  if not success then
    return nil
  end

  return stdout
end


-- 通信速度を適切な単位に整形する
local function format_speed(bps)

  if bps > MEGABYTE then
    return string.format("%5.1fMB/S", bps / MEGABYTE)
  elseif bps > KILOBYTE then
    return string.format("%5.1fKB/S", bps / KILOBYTE)
  end

  return string.format("%6.1fB/S", bps)
end


-- ネットワーク速度を算出し状態を更新する
local function update_network(config)

  local now = os.clock()
  local delta = now - state.network.last_time

  if delta < 1 then return end

  local is_win = wezterm.target_triple:find("windows") ~= nil
  local current_rx = 0

  if is_win then
    local out = safe_run({"cmd.exe", "/c", "netstat -e"})
    local match = out and out:match("Bytes%s+(%d+)")
    current_rx = tonumber(match) or 0
  else
    local out = safe_run({"sh", "-c", "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"})
    current_rx = tonumber(out) or 0
  end

  local bps = (current_rx - state.network.last_bytes) / delta
  if state.network.last_bytes == 0 then bps = 0 end

  table.insert(state.network.samples, 1, bps)

  if #state.network.samples > config.samples then
    table.remove(state.network.samples)
  end

  local sum = 0
  for _, v in ipairs(state.network.samples) do sum = sum + v end

  state.network.current_str = format_speed(bps)
  state.network.average_str = format_speed(sum / #state.network.samples)
  state.network.last_bytes = current_rx
  state.network.last_time = now
end


-- 天気情報を取得する (OpenWeatherMap APIを使用)
local function update_weather(config)

  local now = os.time()
  if (now - state.weather.last_update) < 600 then return end

  local api_key = config.weather_api_key
  if not api_key or api_key == "" then return end

  local url = "https://api.openweathermap.org/data/2.5/weather?q=" .. 
              config.city .. "&appid=" .. api_key .. "&units=metric"
  
  -- 非同期で情報を取得
  wezterm.run_child_process({"curl", "-s", url}, function(success, stdout)
    if not success or not stdout then return end
    local data = wezterm.json_decode(stdout)
    if data and data.main then
      state.weather.temp = string.format("%.1f°C", data.main.temp)
      state.weather.city = data.name
      state.weather.last_update = now
      local main = (data.weather[1].main or ""):lower()
      if main:find("clear") then state.weather.icon = WEATHER_ICONS.clear
      elseif main:find("cloud") then state.weather.icon = WEATHER_ICONS.clouds
      elseif main:find("rain") then state.weather.icon = WEATHER_ICONS.rain
      else state.weather.icon = WEATHER_ICONS.unknown end
    end
  end)
end


-- システムリソース（CPU/メモリ）の使用状況を取得する
local function fetch_resources()

  local is_win = wezterm.target_triple:find("windows") ~= nil
  local cpu, mem_u, mem_f = 0, 0, 0

  if is_win then
    local ps = "Get-CimInstance Win32_Processor | " ..
               "Select-Object -ExpandProperty LoadPercentage; " ..
               "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; " ..
               "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"
    local out = safe_run({"powershell.exe", "-NoProfile", "-Command", ps})
    if out then
      local lines = {}
      for l in out:gmatch("[^\r\n]+") do table.insert(lines, l) end
      cpu = tonumber(lines[1]) or 0
      local f_kb = tonumber(lines[2]) or 0
      local t_kb = tonumber(lines[3]) or 0
      mem_f = f_kb / (1024 * 1024)
      mem_u = (t_kb - f_kb) / (1024 * 1024)
    end
  else
    local out = safe_run({"sh", "-c", "free -b | awk '/^Mem:/ {print $3, $4}'"})
    if out then
      local u, f = out:match("(%d+)%s+(%d+)")
      mem_u = (tonumber(u) or 0) / GIGABYTE
      mem_f = (tonumber(f) or 0) / GIGABYTE
    end
  end

  return string.format("%2d%%", cpu), 
         string.format("%4.1fGB", mem_u), 
         string.format("%4.1fGB", mem_f)
end


-- ローカルまたはSSH接続のユーザー情報を判定する
local function get_user_context(pane)

  local name = os.getenv("USER") or os.getenv("USERNAME") or "User"
  local icon = SYSTEM_ICONS.user_local
  local proc = (pane:get_foreground_process_name() or ""):lower()
  local is_ssh = (pane:get_domain_name():find("SSH") ~= nil) or 
                 (proc:find("ssh") ~= nil)

  if is_ssh then
    icon = SYSTEM_ICONS.user_ssh
    local cwd = pane:get_current_working_dir()
    if cwd and cwd.username and cwd.username ~= "" then
      name = cwd.username
    else
      local t_user = pane:get_title():match("([^@]+)@[^@]+")
      if t_user then name = t_user end
    end
  end

  return icon, name
end

--- ==========================================
--- 公開セットアップ関数
--- ==========================================

function module.setup(opts)

  local def_fmt = " $user_icon $user_name $cal_icon $date $clock_icon $time " ..
                  "$loc_icon $city $wea_icon $temp $cpu_icon $cpu $mem_u_icon " ..
                  "$mem_u $mem_f_icon $mem_f $net_icon $net_s($net_a) " ..
                  "$batt_icon$batt_l "

  local config = {
    delay   = (opts and opts.startup_delay) or 5,
    samples = (opts and opts.net_avg_samples) or 10,
    c_txt   = (opts and opts.color_text) or "#ffffff",
    c_fg    = (opts and opts.color_foreground) or "#7aa2f7",
    c_bg    = (opts and opts.color_background) or "#1a1b26",
    fmt     = (opts and opts.format) or def_fmt,
    sep_l   = (opts and opts.separator_left) or "",
    sep_r   = (opts and opts.separator_right) or "",
    weather_api_key = opts and opts.weather_api_key,
    city    = (opts and opts.city) or "Tokyo",
  }

  wezterm.on('update-right-status', function(window, pane)

    -- 各種動的データの更新実行
    update_network(config)
    update_weather(config)

    local cpu_v, mem_u, mem_f = fetch_resources()
    local u_icon, u_name = get_user_context(pane)
    
    -- バッテリー情報（デスクトップPCでは非表示）
    local bat = wezterm.battery_info()
    local b_icon, b_per = "", ""
    if #bat > 0 then
      local c = bat[1].state_of_charge * 100
      b_per = string.format("%.0f%%", c)
      local idx = c >= 90 and 4 or c >= 60 and 3 or c >= 30 and 2 or 1
      b_icon = SYSTEM_ICONS.battery[idx]
    end

    -- トークンマッピングの生成
    local tokens = {
      ["$user_icon"]  = u_icon,
      ["$user_name"]  = u_name,
      ["$cal_icon"]   = SYSTEM_ICONS.calendar,
      ["$date"]       = wezterm.strftime('%Y.%m.%d(%a)'),
      ["$clock_icon"] = SYSTEM_ICONS.clock,
      ["$time"]       = wezterm.strftime('%H:%M'),
      ["$loc_icon"]   = SYSTEM_ICONS.location,
      ["$city"]       = state.weather.city,
      ["$wea_icon"]   = state.weather.icon,
      ["$temp"]       = state.weather.temp,
      ["$cpu_icon"]   = SYSTEM_ICONS.cpu,
      ["$cpu"]        = cpu_v,
      ["$mem_u_icon"] = SYSTEM_ICONS.memory_used,
      ["$mem_u"]      = mem_u,
      ["$mem_f_icon"] = SYSTEM_ICONS.memory_free,
      ["$mem_f"]      = mem_f,
      ["$net_icon"]   = SYSTEM_ICONS.network,
      ["$net_s"]      = state.network.current_str,
      ["$net_a"]      = state.network.average_str,
      ["$batt_icon"]  = b_icon,
      ["$batt_l"]     = b_per,
    }

    local elements = {
      { Background = { Color = config.c_bg } },
      { Foreground = { Color = config.c_fg } },
      { Text       = config.sep_l },
      { Background = { Color = config.c_fg } },
      { Foreground = { Color = config.c_txt } },
    }

    -- フォーマットテンプレートの解析
    local stream = config.fmt
    while true do
      local s, e = stream:find("%$[%a%d_]+")
      if not s then break end
      table.insert(elements, { Text = stream:sub(1, s - 1) })
      local t = stream:sub(s, e):lower()
      local val = tokens[t] or t
      if t == "$mem_f_icon" then
        table.insert(elements, { Foreground = { Color = config.c_bg } })
        table.insert(elements, { Text = val })
        table.insert(elements, { Foreground = { Color = config.c_txt } })
      else
        table.insert(elements, { Text = val })
      end
      stream = stream:sub(e + 1)
    end
    table.insert(elements, { Text = stream })

    -- エラーのあった箇所：右セパレータの追加を分割
    table.insert(elements, { Background = { Color = config.c_bg } })
    table.insert(elements, { Foreground = { Color = config.c_fg } })
    table.insert(elements, { Text       = config.sep_r })

    window:set_right_status(wezterm.format(elements))
  end)
end

return module

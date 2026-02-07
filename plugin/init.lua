local wezterm = require 'wezterm'
local module = {}

--- ==========================================
--- 静的定数の定義
--- ==========================================

-- ギガバイト換算用 (1024^3)
local GIGABYTE = 1024 ^ 3

-- メガバイト換算用 (1024^2)
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
  },
  network = {
    current = "0B/S",
    average = "0B/S",
  },
  start_time = os.time(),
}

--- ==========================================
--- 内部ロジック関数
--- ==========================================

-- 外部プロセスを安全に実行しエラーをログに記録する
local function safe_run(args)

  local success, stdout, stderr = wezterm.run_child_process(args)

  if not success then
    wezterm.log_error("Process Fail: " .. table.concat(args, " ") .. 
                      " Error: " .. (stderr or "none"))
    return nil
  end

  return stdout
end


-- 通信速度を適切な単位（B/S, KB/S, MB/S）に整形する
local function format_speed(bps)

  if bps > MEGABYTE then
    return string.format("%5.1fMB/S", bps / MEGABYTE)
  elseif bps > KILOBYTE then
    return string.format("%5.1fKB/S", bps / KILOBYTE)
  end

  return string.format("%6.1fB/S", bps)
end


-- OSに応じたCPUとメモリの使用状況を取得する
local function fetch_resources()

  local is_win = wezterm.target_triple:find("windows") ~= nil
  local cpu, mem_u, mem_f = 0, 0, 0

  if is_win then
    local ps = "Get-CimInstance Win32_Processor | " ..
               "Measure-Object -Property LoadPercentage -Average | " ..
               "Select-Object -ExpandProperty Average; " ..
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


-- 現在のセッションがローカルかSSHかを判定し情報を返す
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

  -- デフォルトの表示レイアウト
  local def_fmt = " $user_icon $user_name $cal_icon $date $clock_icon $time " ..
                  "$loc_icon $city $wea_icon $temp $cpu_icon $cpu $mem_u_icon " ..
                  "$mem_u $mem_f_icon $mem_f $net_icon $net_s($net_a) " ..
                  "$batt_icon$batt_l "

  -- 設定値の初期値代入
  local config = {
    delay   = (opts and opts.startup_delay) or 5,
    samples = (opts and opts.net_avg_samples) or 10,
    c_txt   = (opts and opts.color_text) or "#ffffff",
    c_fg    = (opts and opts.color_foreground) or "#7aa2f7",
    c_bg    = (opts and opts.color_background) or "#1a1b26",
    fmt     = (opts and opts.format) or def_fmt,
    sep_l   = (opts and opts.separator_left) or "",
    sep_r   = (opts and opts.separator_right) or "",
  }

  -- 右ステータスバーの更新処理
  wezterm.on('update-right-status', function(window, pane)

    -- 各種システム情報の取得
    local cpu_v, mem_u, mem_f = fetch_resources()
    local u_icon, u_name = get_user_context(pane)
    
    -- バッテリー残量とアイコンの判定
    local bat = wezterm.battery_info()
    local b_icon = SYSTEM_ICONS.battery[1]
    local b_per = ""
    if #bat > 0 then
      local c = bat[1].state_of_charge * 100
      b_per = string.format("%.0f%%", c)
      local idx = c >= 90 and 4 or c >= 60 and 3 or c >= 30 and 2 or 1
      b_icon = SYSTEM_ICONS.battery[idx]
    end

    -- 表示用トークンと取得データの紐付け
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
      ["$net_s"]      = state.network.current,
      ["$net_a"]      = state.network.average,
      ["$batt_icon"]  = b_icon,
      ["$batt_l"]     = b_per,
    }

    -- 描画要素リストの初期化 (左セパレータ含む)
    local elements = {
      { Background = { Color = config.c_bg } },
      { Foreground = { Color = config.c_fg } },
      { Text       = config.sep_l },
      { Background = { Color = config.c_fg } },
      { Foreground = { Color = config.c_txt } },
    }

    -- フォーマットテンプレートの解析と置換実行
    local stream = config.fmt
    while true do
      local s, e = stream:find("%$[%a%d_]+")
      if not s then break end

      table.insert(elements, { Text = stream:sub(1, s - 1) })
      local t = stream:sub(s, e):lower()
      local val = tokens[t] or t

      -- 特定のアイコンに対する動的な配色変更処理
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

    -- 描画終了処理 (右セパレータ追加)
    table.insert(elements, { Background = { Color = config.c_bg } })
    table.insert(elements, { Foreground = { Color = config.c_fg } })
    table.insert(elements, { Text       = config.sep_r })

    window:set_right_status(wezterm.format(elements))
  end)
end

return module

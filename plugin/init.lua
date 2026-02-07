local wezterm = require 'wezterm'
local M       = {}

------------------------------------------------------------
-- 定数・アイコン
------------------------------------------------------------
local weather_icons = {
  clear       = "󰖨 ",
  clouds      = "󰅟 ",
  rain        = " ",
  wind        = " ",
  thunder     = "󱐋 ",
  snow        = " ",
  thermometer = "",
  celsius     = "󰔄",
  fahrenheit  = "󰔅",
  loading     = " ",
  unknown     = " ",
}

------------------------------------------------------------
-- 状態
------------------------------------------------------------
local state = {
  weather_ic    = weather_icons.loading,
  forecast_cache = nil,
  forecast_city  = nil,
  temp_str      = string.format("%5s", weather_icons.loading),
  weather_ic_1h  = weather_icons.loading,
  temp_1h        = "",
  weather_ic_3h  = weather_icons.loading,
  temp_3h        = "",
  weather_ic_24h = weather_icons.loading,
  temp_24h       = "",
  city_name     = weather_icons.loading,
  city_code     = "",
  last_weather_upd  = 0,
  is_weather_ready  = false,
  proc_start    = os.time(),
  net_state = {
    last_rx_bytes = 0,
    last_chk_time = os.clock(),
    disp_str      = string.format("%9s", weather_icons.loading),
    avg_str       = string.format("%9s", weather_icons.loading),
    samples       = {}
  }
}

------------------------------------------------------------
-- 子プロセス
------------------------------------------------------------
local function run_child_cmd(args)
  local success, stdout, _ = wezterm.run_child_process(args)
  return success, stdout
end

------------------------------------------------------------
-- 天気ID → アイコン
------------------------------------------------------------
local function id_to_icon(id)
  if not id then return weather_icons.unknown end
  if     id < 300  then return weather_icons.thunder
  elseif id < 600  then return weather_icons.rain
  elseif id < 700  then return weather_icons.snow
  elseif id < 800  then return weather_icons.wind
  elseif id == 800 then return weather_icons.clear
  else                  return weather_icons.clouds end
end


--- ==========================================
--- バイト/秒のフォーマット
--- ==========================================
local function format_bps(bps)
  if bps > 1024 * 1024
    then return string.format("%5.1fMB/S", bps / (1024 * 1024))
  elseif bps > 1024 then return string.format("%5.1fKB/S", bps / 1024)
  else return string.format("%6.1fB/S", bps) end
end


--- ==========================================
--- ネットワーク速度計算
--- ==========================================
local function calc_net_speed(config, is_startup_waiting)
  -- スタートアップ待機中は初期値を返す
  if is_startup_waiting
    then return state.net_state.disp_str, state.net_state.avg_str end
  -- 更新間隔のチェック
  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time
  if time_delta < config.net_update_interval
    then return state.net_state.disp_str, state.net_state.avg_str end
  -- OS別のコマンド実行
  local is_win  = wezterm.target_triple:find("windows")
  -- 現在の受信バイト数の取得
  local curr_rx = 0
  if is_win then
    local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
    curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
  else
    local ok, out = run_child_cmd({
      "sh", "-c", "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    })
    curr_rx = ok and tonumber(out:match("%d+")) or 0
  end
  -- 経過時間から速度計算
  local bps = (curr_rx - state.net_state.last_rx_bytes) / time_delta
  -- サンプルの追加と古いサンプルの削除
  table.insert(state.net_state.samples, 1, bps)
  if #state.net_state.samples > config.net_avg_samples
    then table.remove(state.net_state.samples) end
  -- 平均速度の計算
  local sum_bps = 0
  for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end
  state.net_state.last_rx_bytes = curr_rx
  state.net_state.last_chk_time = curr_time
  state.net_state.disp_str      = format_bps(bps)
  state.net_state.avg_str       = format_bps(sum_bps / #state.net_state.samples)
  return state.net_state.disp_str, state.net_state.avg_str
end


--- ==========================================
--- システムリソース取得
--- ==========================================
local function get_sys_resources()
  -- 初期値の設定
  local cpu_val, mem_u_val, mem_f_val = 0, 0, 0
  -- OS別のコマンド実行
  local is_win = wezterm.target_triple:find("windows")
  if is_win then
    -- CPU使用率とメモリ情報の取得 (Windows)
    local ok, out = run_child_cmd({
      "powershell.exe", "-NoProfile", "-Command",
      "Get-CimInstance Win32_Processor | Measure-Object -Property " ..
      "LoadPercentage -Average | Select-Object -ExpandProperty Average; " ..
      "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory; " ..
      "(Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize"
    })
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
    -- CPU使用率とメモリ情報の取得 (Unix系)
    local ok, out = run_child_cmd({
      "sh", "-c", "free -b | awk '/^Mem:/ {print $3, $4, $2}'"
    })
    if ok and out then
      local u, f, t = out:match("(%d+)%s+(%d+)%s+(%d+)")
      mem_u_val = (tonumber(u) or 0) / 1024^3
      mem_f_val = (tonumber(f) or 0) / 1024^3
    end
  end
  return
    string.format("%2d%%", cpu_val),
    string.format("%4.1fGB", mem_u_val),
    string.format("%4.1fGB", mem_f_val)
end


--- ==========================================
--- SSHユーザー抽出
--- ==========================================
local function get_ssh_user(pane)
  -- 作業ディレクトリからの抽出
  local uri = pane:get_current_working_dir()
  -- URIにユーザー名が含まれている場合
  if uri and uri.username and uri.username ~= "" then
    return uri.username
  end
  -- プロセス情報からの抽出
  local proc = pane:get_foreground_process_info()
  -- SSHプロセスの場合
  if proc and proc.executable:find("ssh") then
    for _, arg in ipairs(proc.argv) do
      local u = arg:match("([^@]+)@[^@]+")
      if u then return u end
    end
  end
  -- タイトルバーからの抽出
  local title = pane:get_title()
  -- タイトルに"@"が含まれていない場合は終了
  local t_user = title:match("([^@]+)@[^@]+")
  -- タイトルにユーザー名が含まれている場合
  if t_user then return t_user end
  return nil
end


--- ==========================================
--- 天気情報取得
--- ==========================================
local function fetch_weather_data(config)
  local is_win   = wezterm.target_triple:find("windows")
  local curl_cmd = is_win and "curl.exe" or "curl"

  local tgt_city = config.weather_city
  local tgt_code = config.weather_country

  -- IP自動取得
  if not tgt_city or tgt_city == "" then
    local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
    if ok and res then
      local ip_json = wezterm.json_parse(res)
      if ip_json then
        tgt_city = ip_json.city
        tgt_code = ip_json.country_code
      end
    end
  end

  if not tgt_city or tgt_city == "" then
    state.is_weather_ready = false
    return
  end

  local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
  local now   = os.time()

  ------------------------------------------------------------
  -- キャッシュ有効ならAPI呼ばない
  ------------------------------------------------------------
  if state.forecast_cache
     and state.forecast_city == query
     and (now - state.last_weather_upd) < config.weather_update_interval
  then
    return
  end

  ------------------------------------------------------------
  -- forecast API（1回のみ）
  ------------------------------------------------------------
  local url = string.format(
    "https://api.openweathermap.org/data/2.5/forecast?appid=%s&lang=%s&q=%s&units=%s",
    config.weather_api_key,
    config.weather_lang,
    query,
    config.weather_units
  )

  local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
  if not ok or not stdout then
    state.is_weather_ready = false
    return
  end

  local data = wezterm.json_parse(stdout)
  if not data or not data.list then
    state.is_weather_ready = false
    return
  end

  ------------------------------------------------------------
  -- キャッシュ保存
  ------------------------------------------------------------
  state.forecast_cache = data.list
  state.forecast_city  = query
  state.last_weather_upd = now

  if data.city then
    state.city_name = data.city.name or tgt_city
    state.city_code = data.city.country or tgt_code or ""
  end

  state.is_weather_ready = true
end


--- ==========================================
--- 天気情報時間検索
--- ==========================================
local function update_weather_from_cache(config)
  if not state.forecast_cache then return end

  local now = os.time()

  local unit_sym =
    config.weather_units == "metric"
    and weather_icons.celsius
    or weather_icons.fahrenheit

  local function id_to_icon(id)
    if     id < 300  then return weather_icons.thunder
    elseif id < 600  then return weather_icons.rain
    elseif id < 700  then return weather_icons.snow
    elseif id < 800  then return weather_icons.wind
    elseif id == 800 then return weather_icons.clear
    else                  return weather_icons.clouds end
  end

  local function find_closest(target_time)
    local closest = nil
    local min_diff = math.huge

    for _, entry in ipairs(state.forecast_cache) do
      local diff = math.abs(entry.dt - target_time)
      if diff < min_diff then
        min_diff = diff
        closest = entry
      end
    end

    if closest then
      local id   = closest.weather[1].id
      local temp = closest.main.temp
      return id_to_icon(id),
             string.format("%4.1f%s", temp, unit_sym)
    end

    return weather_icons.unknown,
           string.format("%5s", weather_icons.unknown)
  end

  state.weather_ic,     state.temp_str     = find_closest(now)
  state.weather_ic_1h,  state.temp_1h      = find_closest(now + 3600)
  state.weather_ic_3h,  state.temp_3h      = find_closest(now + 10800)
  state.weather_ic_24h, state.temp_24h     = find_closest(now + 86400)
end


--- ==========================================
--- バッテリー情報取得
--- ==========================================
local function get_batt_disp()
  local batt_list = wezterm.battery_info()
  if not batt_list or #batt_list == 0 then return "󰚥", "" end
  local charge = (batt_list[1].state_of_charge or 0) * 100
  local icon   =  charge >= 90 and "󱊦" or
                  charge >= 60 and "󱊥" or
                  charge >= 30 and "󱊤" or "󰢟"
  return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)

  local def_fmt =
    " $user_ic $user " ..
    "$cal_ic $year.$month.$day($week) $clock_ic $time24 " ..
    "$loc_ic $city($code) " ..
    "$weather_ic $temp " ..
    "1h:$weather_ic_1h $temp_1h " ..
    "3h:$weather_ic_3h $temp_3h " ..
    "24h:$weather_ic_24h $temp_24h " ..
    "$cpu_ic $cpu $mem_used_ic $mem_used $mem_free_ic $mem_free " ..
    "$net_ic $net_speed($net_avg) " ..
    "$batt_ic$batt_num "

  local config = {
    startup_delay           = (opts and opts.startup_delay) or 5,
    weather_api_key         = opts and opts.weather_api_key,
    weather_lang            = (opts and opts.weather_lang) or "en",
    weather_country         = (opts and opts.weather_country) or "",
    weather_city            = (opts and opts.weather_city) or "",
    weather_units           = (opts and opts.weather_units) or "metric",
    weather_update_interval = (opts and opts.weather_update_interval) or 600,
    weather_retry_interval  = (opts and opts.weather_retry_interval) or 30,
    net_update_interval     = (opts and opts.net_update_interval) or 3,
    net_avg_samples         = (opts and opts.net_avg_samples) or 20,
    week_str                = opts and opts.week_str,
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
    local fmt_lower  = config.format:lower()

    local use_weather =
      fmt_lower:find("$weather") or
      fmt_lower:find("$temp") or
      fmt_lower:find("$city") or
      fmt_lower:find("$loc_ic")

    local use_net  = fmt_lower:find("$net")
    local use_sys  = fmt_lower:find("$cpu") or fmt_lower:find("$mem")
    local use_batt = fmt_lower:find("$batt")

    local has_weather_api =
      config.weather_api_key and config.weather_api_key ~= ""

    ------------------------------------------------------------
    -- WEATHER
    ------------------------------------------------------------
    if use_weather and has_weather_api and not is_waiting then
      fetch_weather_data(config)         -- 必要ならAPI取得
      update_weather_from_cache(config)  -- 毎回時間再計算
    end

    ------------------------------------------------------------
    -- NETWORK
    ------------------------------------------------------------
    local net_curr, net_avg = "", ""
    if use_net then
      net_curr, net_avg = calc_net_speed(config, is_waiting)
    end

    ------------------------------------------------------------
    -- SYSTEM
    ------------------------------------------------------------
    local cpu_u, mem_u, mem_f = "", "", ""
    if use_sys then
      cpu_u, mem_u, mem_f = get_sys_resources()
    end

    ------------------------------------------------------------
    -- BATTERY
    ------------------------------------------------------------
    local batt_ic, batt_num = "", ""
    if use_batt then
      batt_ic, batt_num = get_batt_disp()
    end

    ------------------------------------------------------------
    -- WEEK
    ------------------------------------------------------------
    local week_val = ""
    if fmt_lower:find("$week") then
      if config.week_str and type(config.week_str) == "table" then
        local week_idx = tonumber(wezterm.strftime('%w'))
        week_val = config.week_str[week_idx + 1] or wezterm.strftime('%a')
      else
        week_val = wezterm.strftime('%a')
      end
    end

    ------------------------------------------------------------
    -- USER / SSH
    ------------------------------------------------------------
    local user_name, user_icon = "", ""
    if fmt_lower:find("$user") then
      user_name = os.getenv("USER") or os.getenv("USERNAME") or "User"
      user_icon = ""
      local ssh_user = get_ssh_user(pane)
      if ssh_user then
        user_icon = "󰀑"
        user_name = ssh_user
      end
    end

    ------------------------------------------------------------
    -- ステータスバー描画
    ------------------------------------------------------------
    local res = {
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = config.separator_left },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
    }

    ------------------------------------------------------------
    -- 置換マップ（拡張込み）
    ------------------------------------------------------------
    local replace_map = {

      ["$user_ic"] = user_icon,
      ["$user"]    = user_name,

      ["$cal_ic"]  = "",
      ["$year"]    = wezterm.strftime('%Y'),
      ["$month"]   = wezterm.strftime('%m'),
      ["$day"]     = wezterm.strftime('%d'),
      ["$week"]    = week_val,

      ["$clock_ic"] = "",
      ["$time24"]   = wezterm.strftime('%H:%M'),

      ["$loc_ic"] = has_weather_api and "" or "",
      ["$city"]   = has_weather_api and state.city_name or "",
      ["$code"]   = has_weather_api and state.city_code or "",

      ["$weather_ic"] = has_weather_api and state.weather_ic or "",
      ["$temp"]       = has_weather_api and state.temp_str or "",

      ["$weather_ic_1h"]  = has_weather_api and state.weather_ic_1h or "",
      ["$temp_1h"]        = has_weather_api and state.temp_1h or "",
      ["$weather_ic_3h"]  = has_weather_api and state.weather_ic_3h or "",
      ["$temp_3h"]        = has_weather_api and state.temp_3h or "",
      ["$weather_ic_24h"] = has_weather_api and state.weather_ic_24h or "",
      ["$temp_24h"]       = has_weather_api and state.temp_24h or "",

      ["$cpu_ic"] = "",
      ["$cpu"]    = cpu_u,

      ["$mem_used_ic"] = "",
      ["$mem_used"]    = mem_u,
      ["$mem_free_ic"] = "",
      ["$mem_free"]    = mem_f,

      ["$net_ic"]    = "󰓅",
      ["$net_speed"] = net_curr,
      ["$net_avg"]   = net_avg,

      ["$batt_ic"]  = batt_ic,
      ["$batt_num"] = batt_num,
    }

    ------------------------------------------------------------
    -- フォーマット置換（元ロジック維持）
    ------------------------------------------------------------
    local current_str = config.format
    while true do
      local start_idx, end_idx = current_str:find("%$[%a%d_]+")
      if not start_idx then break end

      table.insert(res, { Text = current_str:sub(1, start_idx - 1) })

      local token = current_str:sub(start_idx, end_idx):lower()
      local val   = replace_map[token] or token

      if token == "$mem_free_ic" then
        table.insert(res, { Foreground = { Color = config.color_background } })
        table.insert(res, { Text = val })
        table.insert(res, { Foreground = { Color = config.color_text } })
      else
        table.insert(res, { Text = val })
      end

      current_str = current_str:sub(end_idx + 1)
    end

    table.insert(res, { Text = current_str })
    table.insert(res, { Background = { Color = config.color_background } })
    table.insert(res, { Foreground = { Color = config.color_foreground } })
    table.insert(res, { Text       = config.separator_right })

    window:set_right_status(wezterm.format(res))
  end)
end


return M

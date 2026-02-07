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
    local cmd = "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    local ok, out = run_child_cmd({"sh", "-c", cmd})
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


-- システムリソース（CPU/MEM）の取得 (固定幅・先頭空白)
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
  -- CPU: " 5%" (2桁), MEM: "  12.5GB" (6文字)
  return string.format("%2d%%", cpu_val), string.format("%6.1fGB", mem_used_val), string.format("%6.1fGB", mem_free_val)
end


-- ペイン情報（Git/SSH）の取得
local function get_pane_info(pane)
  local info = { branch = "", ssh = "" }
  if not pane then return info end

  local process_name = pane:get_foreground_process_name() or ""
  local domain = pane:get_domain_name()
  
  -- SSH情報の判定
  if process_name:find("ssh") or domain:find("SSH") then
    local uri = pane:get_current_working_dir()
    if uri then
      local user = uri.username or os.getenv("USER") or os.getenv("USERNAME") or "user"
      info.ssh = user .. "@" .. (uri.host or domain)
    end
  end

  -- Gitブランチの取得
  local cwd = pane:get_current_working_dir()
  if cwd then
    local path = cwd.file_path
    local ok, out = run_child_cmd({"git", "-C", path, "rev-parse", "--abbrev-ref", "HEAD"})
    if ok and out then 
      local branch = out:gsub("%s+", "")
      if branch ~= "" then info.branch = branch end
    end
  end

  return info
end


-- 気象情報の取得と更新
local function fetch_wea_data(config)
  local is_win   = wezterm.target_triple:find("windows")
  local curl_cmd = is_win and "curl.exe" or "curl"
  local tgt_city = config.weather_city
  if tgt_city == "" then
    local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
    if ok and res then
      tgt_city = res:match('"city":%s*"([^"]+)"')
    end
  end
  if not tgt_city or tgt_city == "" then return end

  local url = string.format(
    "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
    config.weather_api_key, config.weather_lang, tgt_city, config.weather_units
  )
  local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
  if ok and stdout and not stdout:find('"message"') then
    local wea_id   = tonumber(stdout:match('"id":(%d+)'))
    local temp_val = stdout:match('"temp":([%d%.%-]+)')
    if wea_id then
      if     wea_id < 300 then state.weather_ic = weather_icons.thunder
      elseif wea_id < 600 then state.weather_ic = weather_icons.rain
      elseif wea_id < 700 then state.weather_ic = weather_icons.snow
      elseif wea_id < 800 then state.weather_ic = weather_icons.wind
      elseif wea_id == 800 then state.weather_ic = weather_icons.clear
      else                     state.weather_ic = weather_icons.clouds end
    end
    local unit_sym = config.weather_units == "metric" and
                      weather_icons.celsius or weather_icons.fahrenheit
    state.temp_str     = temp_val and string.format("%4.1f%s", tonumber(temp_val), unit_sym) or state.temp_str
    state.city_name    = stdout:match('"name":"([^"]+)"') or tgt_city
    state.last_wea_upd = os.time()
    state.is_wea_ready = true
  end
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
  -- デフォルトのフォーマット文字列
  local def_fmt =
    " $SSH $Git_ic $Branch $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City $Weather_ic $Temp " ..
    "$CPU_ic $CPU $MEM_ic U:$MEM_USED F:$MEM_FREE $Net_ic $Net_speed($Net_avg) "

  -- 設定オプションの初期化
  local config              = {
    startup_delay           = (opts and opts.startup_delay) or 5,              -- 起動時の通信待機時間
    weather_api_key         = opts and opts.weather_api_key,                   -- OpenWeatherMap APIキー
    weather_lang            = (opts and opts.weather_lang) or "en",            -- 天気情報の言語コード
    weather_city            = (opts and opts.weather_city) or "",              -- 都市名
    weather_units           = (opts and opts.weather_units) or "metric",       -- 単位
    weather_update_interval = 600,                                             -- 天気情報の更新時間（秒）
    net_update_interval     = 3,                                               -- ネットワーク速度更新時間（秒）
    net_avg_samples         = 20,                                              -- 平均速度のサンプル数
    color_text              = (opts and opts.color_text) or "#ffffff",         -- 文字色
    color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",   -- 前景色
    color_background        = (opts and opts.color_background) or "#1a1b26",   -- 背景色
    format                  = (opts and opts.format) or def_fmt,               -- フォーマット
  }

  -- 定期更新イベントの登録
  wezterm.on('update-right-status', function(window, pane)
    local now        = os.time()
    local is_waiting = (now - state.proc_start) < config.startup_delay

    -- 天気更新
    if config.weather_api_key and not is_waiting and (now - state.last_wea_upd > config.weather_update_interval) then
      fetch_wea_data(config)
    end

    -- 各種情報の計算・取得
    local net_curr, net_avg = calc_net_speed(config, is_waiting)
    local cpu_usage, mem_used, mem_free = get_sys_resources()
    local pane_info = get_pane_info(pane)

    -- フォーマット文字列の変数を置換 (1項目1行・コメント付き)
    local replace_map = {
      cal_ic      = "",                                       -- カレンダーアイコン
      clock_ic    = "",                                       -- 時計アイコン
      loc_ic      = "",                                       -- 位置情報アイコン
      net_ic      = "󰓅",                                       -- ネットワークアイコン
      cpu_ic      = "",                                       -- CPUアイコン
      mem_ic      = "",                                       -- メモリアイコン
      year        = wezterm.strftime('%Y'),                    -- 年
      month       = wezterm.strftime('%m'),                    -- 月
      day         = wezterm.strftime('%d'),                    -- 日
      week        = wezterm.strftime('%a'),                    -- 曜日
      time24      = wezterm.strftime('%H:%M'),                 -- 時間(24時制)
      city        = state.city_name,                           -- 都市名
      weather_ic  = state.weather_ic,                          -- 天気アイコン
      temp        = state.temp_str,                            -- 気温
      cpu         = cpu_usage,                                 -- CPU使用率 (?0%)
      mem_used    = mem_used,                                  -- 使用中メモリ (???0.0GB)
      mem_free    = mem_free,                                  -- 空きメモリ (???0.0GB)
      net_speed   = net_curr,                                  -- 現在のネットワーク速度
      net_avg     = net_avg,                                   -- 平均ネットワーク速度
      git_ic      = pane_info.branch ~= "" and "" or "",      -- Gitアイコン (ブランチがない場合は空)
      branch      = pane_info.branch,                          -- Gitブランチ名 (ブランチがない場合は空)
      ssh         = pane_info.ssh ~= "" and ("󰣀 " .. pane_info.ssh) or "", -- SSH接続情報
    }

    local final_status = config.format:gsub("%$([%a%d_]+)", function(key)
      return replace_map[key:lower()] or ("$" .. key)
    end)

    -- 右ステータスバーの更新
    window:set_right_status(wezterm.format({
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = "" },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
      { Text       = final_status },
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = "" },
    }))
  end)
end

return M

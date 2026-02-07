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
  -- 現在時刻と前回チェック時刻の差分を計算
  local curr_time  = os.clock()
  local time_delta = curr_time - state.net_state.last_chk_time
  -- 更新間隔に満たない場合は前回値を返す
  if time_delta < config.net_update_interval then
    return state.net_state.disp_str, state.net_state.avg_str
  end
  -- ネットワーク受信バイト数の取得
  local is_win  = wezterm.target_triple:find("windows")
  local curr_rx = 0
  -- 現在の受信バイト数を取得
  if is_win then
    local ok, out = run_child_cmd({"cmd.exe", "/c", "netstat -e"})
    curr_rx = ok and tonumber(out:match("%a+%s+(%d+)")) or 0
  else
    local cmd = "cat /proc/net/dev | awk 'NR>2 {s+=$2} END {print s}'"
    local ok, out = run_child_cmd({"sh", "-c", cmd})
    curr_rx = ok and tonumber(out:match("%d+")) or 0
  end
  -- 現在の速度を計算してサンプルに追加
  local bps = (curr_rx - state.net_state.last_rx_bytes) / time_delta
  table.insert(state.net_state.samples, 1, bps)
  -- サンプル数が上限を超えた場合は古いサンプルを削除
  if #state.net_state.samples > config.net_avg_samples then
    table.remove(state.net_state.samples)
  end
  -- サンプルの合計値を計算
  local sum_bps = 0
  for _, v in ipairs(state.net_state.samples) do sum_bps = sum_bps + v end
  -- 平均速度の計算
  state.net_state.last_rx_bytes = curr_rx
  state.net_state.last_chk_time = curr_time
  state.net_state.disp_str      = format_bps(bps)
  state.net_state.avg_str       = format_bps(sum_bps / #state.net_state.samples)
  return state.net_state.disp_str, state.net_state.avg_str
end


-- システムリソース（CPU/メモリ）の取得
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
  return string.format("%2d%%", cpu_val), string.format("%4.1fGB", mem_used_val), string.format("%4.1fGB", mem_free_val)
end


-- SSH接続情報の取得
local function get_ssh_info(pane)
  if not pane then return "" end
  local domain = pane:get_domain_name()
  if domain:find("SSH") then
    local uri = pane:get_current_working_dir()
    if uri then
      local user = uri.username or os.getenv("USER") or "user"
      return "󰢩 " .. user .. "@" .. (uri.host or domain)
    end
  end
  return ""
end


-- 気象情報の取得と更新
local function fetch_wea_data(config)
  -- curlコマンドの設定
  local is_win   = wezterm.target_triple:find("windows")
  local curl_cmd = is_win and "curl.exe" or "curl"
  -- 取得対象の都市名と国コードの設定
  local tgt_city = config.weather_city
  local tgt_code = config.weather_country
  -- Cityが設定されていない場合はIPアドレスから都市名を取得
  if not tgt_city or tgt_city == "" then
    local ok, res = run_child_cmd({curl_cmd, "-s", "https://ipapi.co/json/"})
    if ok and res then
      tgt_city = res:match('"city":%s*"([^"]+)"')
      tgt_code = res:match('"country_code":%s*"([^"]+)"')
    end
  end
  -- 都市名が取得できなかった場合の処理
  if not tgt_city or tgt_city == "" then
    state.weather_ic   = weather_icons.unknown
    state.city_name    = weather_icons.unknown
    state.is_wea_ready = false
    return
  end
  -- APIリクエストURLの生成
  local query = tgt_code ~= "" and (tgt_city .. "," .. tgt_code) or tgt_city
  local url   = string.format(
    "https://api.openweathermap.org/data/2.5/weather?appid=%s&lang=%s&q=%s&units=%s",
    config.weather_api_key, config.weather_lang, query, config.weather_units
  )
  -- 天気情報の取得
  local ok, stdout = run_child_cmd({curl_cmd, "-s", url})
  -- 通信失敗、エラーメッセージが見つかった場合の処理
  if not ok or not stdout or stdout:find('"message"') then
    state.weather_ic   = weather_icons.unknown
    state.temp_str     = string.format("%5s", weather_icons.unknown)
    state.city_name    = tgt_city
    state.city_code    = tgt_code or ""
    state.last_wea_upd = os.time()
    state.is_wea_ready = false
    return
  end
  -- 天気情報取得データを解析
  local wea_id   = tonumber(stdout:match('"id":(%d+)'))
  local temp_val = stdout:match('"temp":([%d%.%-]+)')
  local api_name = stdout:match('"name":"([^"]+)"')
  local api_code = stdout:match('"country":"([^"]+)"')
  -- 天気アイコンの設定
  if wea_id then
    if     wea_id < 300 then state.weather_ic = weather_icons.thunder
    elseif wea_id < 600 then state.weather_ic = weather_icons.rain
    elseif wea_id < 700 then state.weather_ic = weather_icons.snow
    elseif wea_id < 800 then state.weather_ic = weather_icons.wind
    elseif wea_id == 800 then state.weather_ic = weather_icons.clear
    else                     state.weather_ic = weather_icons.clouds end
  end
  -- 温度単位の設定
  local unit_sym = config.weather_units == "metric" and
                    weather_icons.celsius or weather_icons.fahrenheit
  -- 温度表示の設定
  state.temp_str     =  temp_val and
                        string.format("%4.1f%s", tonumber(temp_val), unit_sym) or
                        state.temp_str
  -- 都市名と国コードの設定
  state.city_name    = api_name or tgt_city
  state.city_code    = api_code or tgt_code or ""
  -- 更新時刻の記録と成功フラグの設定
  state.last_wea_upd = os.time()
  state.is_wea_ready = true
end


-- バッテリー情報の取得
local function get_batt_disp()
  local batt_list = wezterm.battery_info()
  -- バッテリー情報がない場合はコンセント接続とみなす
  if not batt_list or #batt_list == 0 then
    return "󰚥", ""
  end
  -- バッテリー情報を設定
  local batt   = batt_list[1]
  local charge = (batt.state_of_charge or 0) * 100
  local icon   =  charge >= 90 and "󱊦" or charge >= 60 and "󱊥" or
                  charge >= 30 and "󱊤" or "󰢟"
  return icon, string.format("%.0f%%", charge)
end


--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
  -- デフォルトのフォーマット文字列
  local def_fmt =
    " $SSH $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City($Code) $Weather_ic $Temp " ..
    "$CPU_ic $CPU $MEM_ic $MEM_USED $MEM_FREE $Net_ic $Net_speed($Net_avg) $Batt_ic$Batt_num "

  -- 設定オプションの初期化
  local config              = {
    startup_delay           = (opts and opts.startup_delay) or 5,              -- 起動時の通信待機時間
    weather_api_key         = opts and opts.weather_api_key,                   -- OpenWeatherMap APIキー
    weather_lang            = (opts and opts.weather_lang) or "en",            -- 天気情報の言語コード
    weather_country         = (opts and opts.weather_country) or "",           -- 国コード、都市名と組み合わせて使用
    weather_city            = (opts and opts.weather_city) or "",               -- 都市名、省略された場合はIPアドレスから自動取得
    weather_units           = (opts and opts.weather_units) or "metric",       -- "metric(摂氏)" or "imperial(華氏)"
    weather_update_interval = (opts and opts.weather_update_interval) or 600,  -- 天気情報の更新時間（秒）
    weather_retry_interval  = (opts and opts.weather_retry_interval) or 30,    -- 天気情報取得失敗時のリトライ時間（秒）
    net_update_interval     = (opts and opts.net_update_interval) or 3,        -- ネットワーク速度更新時間（秒）
    net_avg_samples         = (opts and opts.net_avg_samples) or 20,           -- 平均速度のサンプル数
    separator_left          = (opts and opts.separator_left) or "",           -- ステータスバーの始端（左側）
    separator_right         = (opts and opts.separator_right) or "",          -- ステータスバーの終端（右側）
    color_text              = (opts and opts.color_text) or "#ffffff",       -- ステータスバーの文字色
    color_foreground        = (opts and opts.color_foreground) or "#7aa2f7", -- ステータスバーの前景色
    color_background        = (opts and opts.color_background) or "#1a1b26", -- ステータスバーの背景色
    format                  = (opts and opts.format) or def_fmt,               -- ステータスバーのフォーマット
  }

  -- フォーマット文字列のを小文字化して変数を判定
  local low_fmt = config.format:lower()
  -- APIキーがある場合のみ天気情報を処理対象にする
  local has_api_key = config.weather_api_key and config.weather_api_key ~= ""
  local use_weather = has_api_key and
                    ( low_fmt:find("$city") or low_fmt:find("$code") or
                      low_fmt:find("$weather_ic") or low_fmt:find("$temp"))
  local use_net = low_fmt:find("$net_speed") or low_fmt:find("$net_avg")

  -- 定期更新イベントの登録
  wezterm.on('update-right-status', function(window, pane)
    local now        = os.time()
    local elapsed    = now - state.proc_start
    local is_waiting = elapsed < config.startup_delay

    -- 起動直後の待機時間中は取得をスキップ
    if use_weather and not is_waiting then
      local diff = now - state.last_wea_upd
      local should_fetch = false

      -- 初回または通常インターバル経過時の判定
      if state.last_wea_upd == 0 or diff > config.weather_update_interval then
        should_fetch = true
      -- 通信に失敗している場合のリトライ判定
      elseif not state.is_wea_ready and diff > config.weather_retry_interval then
        should_fetch = true
      end
      -- 天気情報の取得・更新
      if should_fetch then
        fetch_wea_data(config)
      end
    end

    -- ネットワーク・システムリソース・SSH
    local batt_ic, batt_num = get_batt_disp()
    local net_curr, net_avg = "", ""
    if use_net then net_curr, net_avg = calc_net_speed(config, is_waiting) end
    local cpu_u, mem_u, mem_f = get_sys_resources()
    local ssh_str = get_ssh_info(pane)

    -- フォーマット文字列の変数を置換
    local replace_map = {
      cal_ic      = "",
      clock_ic    = "",
      loc_ic      = "",
      temp_ic     = weather_icons.thermometer,
      weather_ic  = use_weather and state.weather_ic or "",
      year        = wezterm.strftime('%Y'),
      month       = wezterm.strftime('%m'),
      day         = wezterm.strftime('%d'),
      week        = wezterm.strftime('%a'),
      time24      = wezterm.strftime('%H:%M'),
      city        = use_weather and state.city_name or "",
      code        = use_weather and state.city_code or "",
      temp        = use_weather and state.temp_str or "",
      cpu_ic      = "",
      cpu         = cpu_u,
      mem_ic      = "",
      mem_used    = mem_u,
      mem_free    = mem_f,
      net_ic      = "󰓅",
      net_speed   = net_curr,
      net_avg     = net_avg,
      batt_ic     = batt_ic,
      batt_num    = batt_num,
      ssh         = ssh_str,
    }

    -- ステータス文字列の生成
    local final_status = config.format:gsub("%$([%a%d_]+)", function(key)
      return replace_map[key:lower()] or ("$" .. key)
    end)

    -- 右ステータスバーの描画
    local render_list = {
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = config.separator_left },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
    }

    -- メモリのアイコン()を探して特定箇所の色を変更
    local first_idx = final_status:find("")
    local second_idx = first_idx and final_status:find("", first_idx + 1) or nil
    local target_idx = second_idx or first_idx

    if target_idx then
      table.insert(render_list, { Text = final_status:sub(1, target_idx - 1) })
      table.insert(render_list, { Foreground = { Color = config.color_background } })
      table.insert(render_list, { Text = "" })
      table.insert(render_list, { Foreground = { Color = config.color_text } })
      table.insert(render_list, { Text = final_status:sub(target_idx + 1) })
    else
      table.insert(render_list, { Text = final_status })
    end

    -- 右側のセパレータを追加（入れ子エラーを修正）
    table.insert(render_list, { Background = { Color = config.color_background } })
    table.insert(render_list, { Foreground = { Color = config.color_foreground } })
    table.insert(render_list, { Text       = config.separator_right })

    window:set_right_status(wezterm.format(render_list))
  end)
end


return M

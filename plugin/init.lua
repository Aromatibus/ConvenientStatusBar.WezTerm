local wezterm = require 'wezterm'
local M       = {}

-- (中略: weather_icons, state, run_child_cmd, format_bps, calc_net_speed, get_sys_resources, get_pane_info, fetch_wea_data は変更なし)

--- ==========================================
--- メイン
--- ==========================================
function M.setup(opts)
  local def_fmt =
    " $SSH $Cal_ic $Year.$Month.$Day($Week) $Clock_ic $Time24 " ..
    "$Loc_ic $City $Weather_ic $Temp " ..
    "$CPU_ic $CPU $MEM_ic $MEM_USED $MEM_FREE $Net_ic $Net_speed($Net_avg) "

  local config              = {
    startup_delay           = (opts and opts.startup_delay) or 5,
    weather_api_key         = opts and opts.weather_api_key,
    weather_lang            = (opts and opts.weather_lang) or "en",
    weather_city            = (opts and opts.weather_city) or "",
    weather_units           = (opts and opts.weather_units) or "metric",
    weather_update_interval = 600,
    net_update_interval     = 3,
    net_avg_samples         = 10,
    color_text              = (opts and opts.color_text) or "#ffffff",
    color_foreground        = (opts and opts.color_foreground) or "#7aa2f7",
    color_background        = (opts and opts.color_background) or "#1a1b26",
    format                  = (opts and opts.format) or def_fmt,
  }

  wezterm.on('update-right-status', function(window, pane)
    local now        = os.time()
    local is_waiting = (now - state.proc_start) < config.startup_delay

    if config.weather_api_key and not is_waiting and (now - state.last_wea_upd > config.weather_update_interval) then
      fetch_wea_data(config)
    end

    local net_curr, net_avg = calc_net_speed(config, is_waiting)
    local cpu_usage, mem_used, mem_free = get_sys_resources()
    local pane_info = get_pane_info(pane)

    -- 1. 文字列置換用のマップを作成 (ここでは mem_free は純粋な文字列)
    local replace_map = {
      cal_ic      = "",
      clock_ic    = "",
      loc_ic      = "",
      net_ic      = "󰓅",
      cpu_ic      = "",
      mem_ic      = "",
      year        = wezterm.strftime('%Y'),
      month       = wezterm.strftime('%m'),
      day         = wezterm.strftime('%d'),
      week        = wezterm.strftime('%a'),
      time24      = wezterm.strftime('%H:%M'),
      city        = state.city_name,
      weather_ic  = state.weather_ic,
      temp        = state.temp_str,
      cpu         = cpu_usage,
      mem_used    = mem_used,
      mem_free    = mem_free, -- 一旦普通の文字列として格納
      net_speed   = net_curr,
      net_avg     = net_avg,
      ssh         = pane_info.ssh ~= "" and ("󰢩 " .. pane_info.ssh) or "",
    }

    -- 2. $変数を置換して、全体の文字列を組み立てる
    local raw_status = config.format:gsub("%$([%a%d_]+)", function(key)
      local val = replace_map[key:lower()]
      return val ~= nil and tostring(val) or ("$" .. key)
    end)

    -- 3. フリーメモリのアイコン箇所だけ色を変えるためのテーブルを構成
    -- 文字列を mem_free の前後で分割して、アイコンの色設定を挟み込む
    local parts = {}
    table.insert(parts, { Background = { Color = config.color_foreground } })
    table.insert(parts, { Foreground = { Color = config.color_text } })

    -- 全体のテキストを走査し、$MEM_FREE のアイコン部分だけ色指定を挿入
    -- 簡略化のため、完成した文字列内のアイコンを置換
    local final_parts = {
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text = "" },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
    }

    -- ステータス文字列をループで処理せず、直接構成
    -- アイコン「」を見つけて、その前後の色を変える
    local start_idx, end_idx = raw_status:find("")
    if start_idx then
      -- アイコンより前の部分
      table.insert(final_parts, { Text = raw_status:sub(1, start_idx - 1) })
      -- アイコン部分のみ文字色を背景色に
      table.insert(final_parts, { Foreground = { Color = config.color_background } })
      table.insert(final_parts, { Text = raw_status:sub(start_idx, end_idx) })
      -- アイコン直後で文字色を元に戻す
      table.insert(final_parts, { Foreground = { Color = config.color_text } })
      -- 残りの部分
      table.insert(final_parts, { Text = raw_status:sub(end_idx + 1) })
    else
      table.insert(final_parts, { Text = raw_status })
    end

    table.insert(final_parts, { Background = { Color = config.color_background } })
    table.insert(final_parts, { Foreground = { Color = config.color_foreground } })
    table.insert(final_parts, { Text = "" })

    window:set_right_status(wezterm.format(final_parts))
  end)
end

return M

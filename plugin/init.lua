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

    -- 全項目を純粋な文字列として定義
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
      mem_free    = mem_free,
      net_speed   = net_curr,
      net_avg     = net_avg,
      ssh         = pane_info.ssh ~= "" and ("󰢩 " .. pane_info.ssh) or "",
    }

    -- $変数を置換して一つの長い文字列を作る
    local final_str = config.format:gsub("%$([%a%d_]+)", function(key)
      local val = replace_map[key:lower()]
      return val ~= nil and tostring(val) or ("$" .. key)
    end)

    -- 描画用リストの組み立て
    local render_list = {
      { Background = { Color = config.color_background } },
      { Foreground = { Color = config.color_foreground } },
      { Text       = "" },
      { Background = { Color = config.color_foreground } },
      { Foreground = { Color = config.color_text } },
    }

    -- 文字列をスキャンして、フリーメモリのアイコン「」の部分だけ色を変える
    -- 文字列の中に「」が2つある場合（使用メモリと空きメモリ）を考慮し、
    -- 後ろにある方の「」（空きメモリ用）をターゲットにします
    local first_ic_start, first_ic_end = final_str:find("")
    local second_ic_start, second_ic_end = nil, nil
    
    if first_ic_start then
      second_ic_start, second_ic_end = final_str:find("", first_ic_end + 1)
    end

    local target_start = second_ic_start or first_ic_start
    local target_end = second_ic_end or first_ic_end

    if target_start then
      -- アイコンより前
      table.insert(render_list, { Text = final_str:sub(1, target_start - 1) })
      -- アイコン：文字色のみを背景色（#1a1b26）に変更
      table.insert(render_list, { Foreground = { Color = config.color_background } })
      table.insert(render_list, { Text = final_str:sub(target_start, target_end) })
      -- アイコン後：文字色を元の色（白）に戻す
      table.insert(render_list, { Foreground = { Color = config.color_text } })
      -- 残りの文字列
      table.insert(render_list, { Text = final_str:sub(target_end + 1) })
    else
      table.insert(render_list, { Text = final_str })
    end

    -- 閉じ
    table.insert(render_list, { Background = { Color = config.color_background } })
    table.insert(render_list, { Foreground = { Color = config.color_foreground } })
    table.insert(render_list, { Text = "" })

    window:set_right_status(wezterm.format(render_list))
  end)
end

return M
